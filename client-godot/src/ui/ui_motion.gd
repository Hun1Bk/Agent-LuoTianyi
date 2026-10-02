extends RefCounted
## Node-owned, cancellable motion. Layout sizes are never animated.
const DUR_INSTANT := 0.12
const DUR_FAST := 0.18
const DUR_BASE := 0.25
const DUR_SLOW := 0.4
const CHANNELS := &"_ui_motion_channels"
const WINDOW_LOOPS := &"_ui_motion_window_loops"
const WINDOW_ACTIVE := &"_ui_motion_window_active"

static func cancel(node: Node, channel: String, reset: bool = true) -> void:
	var channels: Dictionary = node.get_meta(CHANNELS, {})
	if not channels.has(channel): return
	var entry: Dictionary = channels[channel]
	channels.erase(channel)
	if entry.tween != null and entry.tween.is_valid(): entry.tween.kill()
	if reset:
		for property in entry.reset: node.set_indexed(NodePath(property), entry.reset[property])

static func cancel_all(node: Node) -> void:
	var channels: Dictionary = node.get_meta(CHANNELS, {})
	for channel in channels.keys(): cancel(node, channel)

static func _begin(node: Node, channel: String, reset: Dictionary = {}, restart: Callable = Callable()) -> Tween:
	cancel(node, channel)
	if not node.has_meta(CHANNELS):
		node.set_meta(CHANNELS, {})
		node.tree_exiting.connect(func(): cancel_all(node))
		if node is CanvasItem:
			node.visibility_changed.connect(func(): _visibility_changed(node))
	var channels: Dictionary = node.get_meta(CHANNELS)
	var token := Time.get_ticks_usec()
	channels[channel] = {"tween":null, "reset":reset, "token":token, "restart":restart}
	if restart.is_valid():
		var window: Window = node.get_window()
		if not window.has_meta(WINDOW_LOOPS): window.set_meta(WINDOW_LOOPS, {})
		window.get_meta(WINDOW_LOOPS)[node.get_instance_id()] = weakref(node)
		if not window.get_meta(WINDOW_ACTIVE, true): return null
	var tween := node.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	channels[channel].tween = tween
	tween.finished.connect(func():
		if channels.has(channel) and channels[channel].token == token: channels.erase(channel))
	return tween

static func _visibility_changed(node: CanvasItem) -> void:
	if node.is_visible_in_tree(): return
	var ancestor: Node = node
	while ancestor is CanvasItem:
		if not ancestor.visible:
			cancel_all(node)
			return
		ancestor = ancestor.get_parent()
	# A native window can disappear without changing its contents' visible flags.
	_update_loops(node, false)
	var channels: Dictionary = node.get_meta(CHANNELS, {})
	for channel in channels.keys():
		if not channels[channel].restart.is_valid(): cancel(node, channel)

## Window.mode does not emit CanvasItem visibility_changed when minimized.
static func update_window(window: Window, active: bool) -> void:
	window.set_meta(WINDOW_ACTIVE, active)
	var nodes: Dictionary = window.get_meta(WINDOW_LOOPS, {})
	for id in nodes.keys():
		var node = nodes[id].get_ref()
		if node == null:
			nodes.erase(id)
			continue
		_update_loops(node, active)

static func _update_loops(node: CanvasItem, active: bool) -> void:
	var channels: Dictionary = node.get_meta(CHANNELS, {})
	for channel in channels.keys():
		var entry: Dictionary = channels[channel]
		if not entry.restart.is_valid(): continue
		if active and node.is_visible_in_tree():
			if entry.tween == null: entry.restart.call()
		elif entry.tween != null:
			if entry.tween.is_valid(): entry.tween.kill()
			entry.tween = null
			for property in entry.reset: node.set_indexed(NodePath(property), entry.reset[property])

static func fade_in(node: CanvasItem, duration: float = DUR_FAST, from_alpha: float = 0.0, delay: float = 0.0) -> Tween:
	var tween := _begin(node, "fade", {"modulate:a":1.0})
	node.modulate.a = from_alpha
	tween.tween_property(node, "modulate:a", 1.0, duration).set_delay(delay)
	return tween

static func fade_out(node: CanvasItem, duration: float = DUR_FAST) -> Tween:
	var alpha := node.modulate.a
	cancel(node, "fade", false)
	var tween := _begin(node, "fade", {"modulate:a":1.0}).set_ease(Tween.EASE_IN)
	node.modulate.a = alpha
	tween.tween_property(node, "modulate:a", 0.0, duration)
	return tween

static func slide_fade_in(node: Control, offset_y: float = 10.0, duration: float = DUR_FAST, delay: float = 0.0, spring: bool = false) -> Tween:
	cancel(node, "slide")
	var base := node.position
	var tween := _begin(node, "slide", {"position":base, "modulate:a":1.0}).set_parallel()
	node.position.y += offset_y
	node.modulate.a = 0.0
	var movement := tween.tween_property(node, "position", base, duration).set_delay(delay)
	if spring: movement.set_trans(Tween.TRANS_BACK)
	tween.tween_property(node, "modulate:a", 1.0, duration).set_delay(delay)
	return tween

static func pop_in(node: Control, duration: float = DUR_BASE, start_scale: float = 0.94) -> Tween:
	var tween := _begin(node, "pop", {"scale":Vector2.ONE, "modulate:a":1.0}).set_parallel()
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2.ONE * start_scale
	node.modulate.a = 0.0
	tween.tween_property(node, "scale", Vector2.ONE, duration)
	tween.tween_property(node, "modulate:a", 1.0, duration)
	return tween

static func pop_out(node: Control, duration: float = DUR_FAST) -> Tween:
	cancel(node, "pop")
	var tween := _begin(node, "pop", {"scale":Vector2.ONE, "modulate:a":1.0}).set_parallel().set_ease(Tween.EASE_IN)
	tween.tween_property(node, "scale", Vector2.ONE * 0.96, duration)
	tween.tween_property(node, "modulate:a", 0.0, duration)
	return tween

static func shake(node: Control, strength: float = 7.0, duration: float = DUR_SLOW) -> Tween:
	cancel(node, "shake")
	var base := node.position
	var tween := _begin(node, "shake", {"position":base}).set_trans(Tween.TRANS_SINE)
	var offsets := [-strength, strength * 0.85, -strength * 0.6, strength * 0.4, 0.0]
	for offset in offsets: tween.tween_property(node, "position:x", base.x + offset, duration / offsets.size())
	return tween

static func press_bounce(node: Control, pressed_scale: float = 0.96, duration: float = DUR_INSTANT) -> Tween:
	var tween := _begin(node, "press", {"scale":Vector2.ONE})
	node.pivot_offset = node.size * 0.5
	tween.tween_property(node, "scale", Vector2.ONE * pressed_scale, duration * 0.5)
	tween.tween_property(node, "scale", Vector2.ONE, duration * 0.5)
	return tween

static func spin(node: Control, period: float = 0.9) -> Tween:
	var tween := _begin(node, "spin", {"rotation":0.0}, func(): spin(node, period))
	if tween == null: return null
	tween.set_loops().set_trans(Tween.TRANS_LINEAR)
	node.pivot_offset = node.size * 0.5
	tween.tween_property(node, "rotation", TAU, period).from(0.0)
	return tween

static func pulse(node: CanvasItem, low: float = 0.5, high: float = 1.0, period: float = 1.6) -> Tween:
	var tween := _begin(node, "pulse", {"modulate:a":1.0}, func(): pulse(node, low, high, period))
	if tween == null: return null
	tween.set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "modulate:a", low, period * 0.5).from(high)
	tween.tween_property(node, "modulate:a", high, period * 0.5)
	return tween

static func floaty(node: Control, distance: float = 4.0, period: float = 3.2) -> Tween:
	cancel(node, "float")
	var base := node.position
	var tween := _begin(node, "float", {"position":base}, func(): floaty(node, distance, period))
	if tween == null: return null
	tween.set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "position:y", base.y - distance, period * 0.5)
	tween.tween_property(node, "position:y", base.y, period * 0.5)
	return tween

static func typing_dot(node: Control, delay: float) -> Tween:
	var tween := _begin(node, "dot", {"scale":Vector2.ONE, "modulate:a":1.0}, func(): typing_dot(node, delay))
	if tween == null: return null
	tween.set_loops().set_parallel().set_trans(Tween.TRANS_SINE)
	node.pivot_offset = node.size * 0.5
	tween.tween_property(node, "scale", Vector2.ONE * 1.35, 0.25).set_delay(delay)
	tween.tween_property(node, "modulate:a", 0.4, 0.25).set_delay(delay)
	tween.chain().tween_property(node, "scale", Vector2.ONE, 0.25)
	tween.tween_property(node, "modulate:a", 1.0, 0.25)
	tween.chain().tween_interval(0.3 - delay)
	return tween

## Scroll offsets are the sole scalar motion used here.
static func property_to(node: Node, property: String, value: Variant, duration: float, channel: String) -> Tween:
	cancel(node, channel, false)
	var tween := _begin(node, channel)
	tween.tween_property(node, property, value, duration)
	return tween

static func transform_to(node: Control, extent: Vector2, origin: Vector2, duration: float = DUR_FAST) -> Tween:
	cancel(node, "transform", false)
	var tween := _begin(node, "transform").set_parallel()
	tween.tween_property(node, "scale", extent, duration)
	tween.tween_property(node, "position", origin, duration)
	return tween
