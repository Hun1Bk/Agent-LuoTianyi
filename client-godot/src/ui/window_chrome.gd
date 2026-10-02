extends Control
const UiMotion = preload("res://src/ui/ui_motion.gd")
@export var motion_target_path: NodePath
var _closing := false
var _generation := 0
@export var login_mode := false
@export var host: Resource = preload("res://src/platform/window_host.gd").new()
func _enter_tree() -> void:
	host.attach(get_window(),login_mode)
func _ready() -> void:
	UiMotion.update_window(get_window(), host.is_presentation_active())
	get_window().visibility_changed.connect(func():
		UiMotion.update_window(get_window(), host.is_presentation_active())
		var target := _motion_target()
		if target != null and not get_window().visible: UiMotion.cancel_all(target))
func _motion_target() -> Control:
	return null if motion_target_path.is_empty() else get_node_or_null(motion_target_path) as Control
func set_login_mode(enabled: bool) -> void:
	login_mode = enabled
	host.set_login_mode(enabled)
func configure(store: RefCounted, key: String) -> void:
	host.configure(store,key)
func select_layout(key: String, size: Vector2i, minimum: Vector2i) -> void:
	host.select_layout(key,size,minimum)
func open_window() -> void:
	var reveal := not get_window().visible
	var reopening := _closing
	_generation += 1
	_closing = false
	var target := _motion_target()
	if target != null and reopening: UiMotion.cancel(target, "pop")
	host.open_window()
	if target != null and (reveal or reopening): UiMotion.pop_in(target, UiMotion.DUR_FAST, 0.96)

func close_window(on_closed: Callable, immediate: bool = false) -> void:
	if _closing and not immediate: return
	_generation += 1
	var generation := _generation
	var target := _motion_target()
	if immediate or target == null or not get_window().visible:
		_closing = false
		if target != null: UiMotion.cancel_all(target)
		on_closed.call()
		return
	_closing = true
	var tween := UiMotion.pop_out(target)
	tween.finished.connect(func():
		if generation == _generation:
			_closing = false
			on_closed.call())
func _process(delta: float) -> void:
	host.tick(delta)
	UiMotion.update_window(get_window(), host.is_presentation_active())
func _exit_tree() -> void:
	host.detach()
