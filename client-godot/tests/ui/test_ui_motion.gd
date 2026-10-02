extends SceneTree
const UiMotion = preload("res://src/ui/ui_motion.gd")
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		print("FAIL: ", label)
func until(condition: Callable, timeout: int = 2000) -> void:
	var deadline := Time.get_ticks_msec() + timeout
	while not condition.call() and Time.get_ticks_msec() < deadline: await process_frame
	check(condition.call(), "asynchronous transition completes")
func frames(count: int = 12) -> void:
	for frame in count: await process_frame
func run() -> void:
	root.size = Vector2i(960, 640)
	await _test_cancel()
	await _test_list()
	await _test_window()
	await _test_image()
	print("UI motion: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)

func _test_cancel() -> void:
	var control := Control.new()
	root.add_child(control)
	control.position = Vector2(20, 30)
	var first := UiMotion.floaty(control)
	UiMotion.floaty(control)
	check(not first.is_valid(), "repeated loop replaces its predecessor")
	control.hide()
	check(control.position == Vector2(20, 30) and control.get_meta(UiMotion.CHANNELS).is_empty(), "hidden node stops loop and restores transform")
	control.show()
	UiMotion.spin(control)
	UiMotion._update_loops(control, false)
	check(control.rotation == 0.0 and control.get_meta(UiMotion.CHANNELS).spin.tween == null, "minimized window kills and resets its loops")
	UiMotion._update_loops(control, true)
	check(control.get_meta(UiMotion.CHANNELS).spin.tween != null, "restored window restarts visible loops")
	UiMotion.cancel_all(control)
	UiMotion.press_bounce(control)
	control.queue_free()
	await process_frame

func _test_list() -> void:
	var list = load("res://scenes/ui/virtual_message_list.tscn").instantiate()
	root.add_child(list)
	list.size = Vector2(620, 300)
	var messages: Array[Dictionary] = []
	for index in 20: messages.append({"id":str(index),"role":"assistant","text":"历史消息 %s" % index,"status":"received","code":""})
	list.set_messages(messages)
	await frames()
	list.scroll_to_message("8")
	await frames()
	var anchor: Dictionary = list.get_reading_anchor()
	list.set_typing(true)
	await frames()
	check(list.get_reading_anchor().id == anchor.id and list.get_visible_ids().all(func(id): return id in list._indices), "typing does not move history reader or enter business IDs")
	var older: Array[Dictionary] = [{"id":"older","role":"assistant","text":"更早历史","status":"received","code":""}]
	list.set_messages(older + messages)
	await frames()
	check(list.get_reading_anchor().id == anchor.id, "history pagination preserves anchor with typing present")
	list.scroll_to_message("older")
	await frames()
	check(list._nodes.older.modulate.a == 1.0 and not list._nodes.older.has_meta(UiMotion.CHANNELS), "history insertion never plays arrival motion")
	list.scroll_to_latest()
	await frames()
	var fresh: Array[Dictionary] = [{"id":"live","role":"assistant","text":"实时回复","status":"received","code":""}]
	var fresh_ids: Array[String] = ["live"]
	list.set_typing(false)
	list.set_messages(older + messages + fresh, fresh_ids)
	check(list._nodes.live.modulate.a < 1.0, "explicit live arrival fades in")
	await until(func(): return list._nodes.live.modulate.a == 1.0)
	list.scroll_to_message("8")
	await frames()
	list.smooth_scroll_to_latest()
	list.set_messages(older + messages + fresh)
	await until(func(): return not list._smooth_follow)
	check(list.is_at_latest(), "smooth scrolling retargets after a layout update")
	list.scroll_to_message("8")
	await frames()
	list.smooth_scroll_to_latest()
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_UP
	list._user_input(key)
	check(not list._smooth_follow and list._scroll_tween == null, "user input cancels smooth follow")
	list.queue_free()
	await process_frame

func _test_window() -> void:
	var window := Window.new()
	window.visible = false
	var body := PanelContainer.new()
	body.name = "Body"
	window.add_child(body)
	var chrome = load("res://scenes/ui/window_chrome.tscn").instantiate()
	chrome.motion_target_path = NodePath("../Body")
	window.add_child(chrome)
	root.add_child(window)
	chrome.open_window()
	await frames()
	await _test_minimize(window, chrome)
	var closes: Array[int] = [0]
	chrome.close_window(func(): closes[0] += 1; window.hide())
	chrome.open_window()
	await until(func(): return body.modulate.a == 1.0)
	check(window.visible and closes[0] == 0 and body.scale == Vector2.ONE, "reopen cancels old close callback and restores content")
	chrome.close_window(func(): closes[0] += 1; window.hide(), true)
	check(not window.visible and closes[0] == 1, "account-scope close is immediate")
	window.queue_free()
	await process_frame

func _test_minimize(window: Window, chrome: Control) -> void:
	if DisplayServer.get_name() == "headless": return
	var spinner := Control.new()
	window.add_child(spinner)
	UiMotion.spin(spinner)
	window.mode = Window.MODE_MINIMIZED
	await until(func(): return spinner.get_meta(UiMotion.CHANNELS).get("spin", {}).get("tween") == null)
	check(spinner.rotation == 0.0, "native minimize resets loop rotation")
	chrome.open_window()
	await until(func(): return spinner.get_meta(UiMotion.CHANNELS).get("spin", {}).get("tween") != null)
	spinner.queue_free()
	await process_frame

func _test_image() -> void:
	var window = load("res://scenes/ui/image_window.tscn").instantiate()
	root.add_child(window)
	var image := Image.create(1600, 1200, false, Image.FORMAT_RGBA8)
	image.fill(Color.SKY_BLUE)
	var texture := ImageTexture.create_from_image(image)
	window.present(root, func(): return texture)
	await frames()
	var picture: Control = window.get_node("%Picture")
	window._fitting = false
	window._set_zoom(1.0, window.get_node("%ImageScroll").size * 0.5)
	await until(func(): return not picture.get_meta(UiMotion.CHANNELS, {}).has("transform"))
	var anchor := Vector2(240, 180)
	var pixel := (anchor - picture.position) / picture.scale.x
	window._zoom_by(1.25, anchor)
	await until(func(): return not picture.get_meta(UiMotion.CHANNELS, {}).has("transform"))
	check(((anchor-picture.position)/picture.scale.x).distance_to(pixel) < 1.0, "zoom keeps mouse image pixel fixed")
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	window._image_input(down)
	var origin := picture.position
	var drag := InputEventMouseMotion.new()
	drag.relative = Vector2(20, 15)
	window._input(drag)
	check(picture.position == origin + drag.relative, "left drag pans a large image")
	window._zoom_by(1000)
	check(window._zoom == 8.0, "manual zoom has an upper bound")
	window._zoom_by(.00001)
	await until(func(): return not picture.get_meta(UiMotion.CHANNELS, {}).has("transform"))
	check(window._zoom == .05 and picture.position == (window.get_node("%ImageScroll").size-picture.size*.05)*.5, "small image is centered at lower zoom bound")
	window.close_image()
	check(not window.visible and window.get_node("%Picture").texture == null, "forced image close is immediate")
	window.queue_free()
	await process_frame
