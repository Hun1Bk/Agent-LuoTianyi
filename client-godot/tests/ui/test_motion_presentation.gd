extends SceneTree
## Run through run_feature_tests.py --gpu with isolated account data.
var failures: Array[String] = []
const CAPTURES := "res://artifacts/ui-motion/captures"
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		print("FAIL: ", label)
func until(condition: Callable) -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while not condition.call() and Time.get_ticks_msec() < deadline: await process_frame
	check(condition.call(), "fixture state settles")
func capture(window: Window, name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(window.get_texture().get_image().save_png(CAPTURES.path_join(name + ".png")) == OK, "capture " + name)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(CAPTURES)
	var security = ClassDB.instantiate("WindowsSecurity")
	var directory := "user://motion-presentation-%s" % Time.get_ticks_usec()
	var session = load("res://src/session/account_session.gd").new(load("res://src/network/account_api.gd").new(security), load("res://src/storage/godot_storage_service.gd").new(directory + "/account.cfg", load("res://src/storage/credential_store.gd").new(security, directory + "/tokens")))
	var app = load("res://scenes/main.tscn").instantiate()
	app.setup(session, directory + "/window.cfg")
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await until(func(): return not app._suppress_transition)
	var view = app.get_node("%AccountForm")
	view.select_mode("register")
	await create_timer(.35).timeout
	await capture(root, "login-register")
	view.select_mode("login")
	await session.set_server(OS.get_environment("GODOT_TEST_SERVER"))
	view.get_node("%Username").text = "reject"
	view.get_node("%Password").text = "synthetic"
	view.get_node("%Submit").pressed.emit()
	await until(func(): return not view._busy)
	await process_frame
	check(view.get_node("%Status").has_theme_color_override("font_color"), "failed login emphasizes its error")
	await create_timer(.4).timeout
	await capture(root, "login-failed")
	view.get_node("%Username").text = "visual_busy"
	view.get_node("%Password").text = "synthetic"
	view.get_node("%Submit").pressed.emit()
	await process_frame
	await capture(root, "login-spinner")
	await until(func(): return app._chat_view != null and app._chat.get_state().phase == "ready")
	session.logout()
	await session.perform("login", OS.get_environment("GODOT_TEST_SERVER"), {"username":"visual","password":"synthetic"}, false)
	await until(func(): return app._chat_view != null and app._chat.get_state().phase == "ready")
	await until(func(): return not app._chat._waiting_history)
	await _chat_proof(app)
	await _window_proof(app)
	await session.perform("login", OS.get_environment("GODOT_TEST_SERVER"), {"username":"visual","password":"synthetic"}, true, true)
	app.queue_free()
	await process_frame
	await _automatic_login_proof(directory, security)
	print("Motion presentation: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)

func _automatic_login_proof(directory: String, security: Object) -> void:
	var storage = load("res://src/storage/godot_storage_service.gd").new(directory + "/account.cfg", load("res://src/storage/credential_store.gd").new(security, directory + "/tokens"))
	var account = load("res://src/session/account_session.gd").new(load("res://src/network/account_api.gd").new(security), storage)
	var app = load("res://scenes/main.tscn").instantiate()
	app.setup(account, directory + "/window.cfg")
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await until(func(): return not app._suppress_transition)
	check(app._chat_view != null and app.get_node("%Split").modulate.a == 1.0 and app.get_node("%Navigation").modulate.a == 1.0, "startup auto-login suppresses workspace transition")
	app.queue_free()
	await process_frame

func _chat_proof(app: Control) -> void:
	var session: Node = app._chat
	var queue = session._transport._outbox
	var id: String = session.send_text("这条消息用来验证明确拒收后的重发。")
	var now := Time.get_ticks_msec()
	queue.take_ready(now, true)
	await process_frame
	await capture(root, "chat-sending")
	queue.acknowledge(id, {"ok":false,"code":"REJECTED","retryable":false}, now + 1)
	await process_frame
	var bubble = app._chat_view.get_node("%Scroll")._nodes[id]
	check(bubble.get_node("%RetrySend").visible, "explicit rejection shows retry action")
	await capture(root, "chat-retry")
	bubble.get_node("%RetrySend").pressed.emit()
	await until(func(): return session._by_id[id].status == "sent")
	check(session._by_id[id].id == id, "UI retry keeps the original bubble")
	await until(func(): return session.get_messages().any(func(message): return message.role == "assistant"))
	await capture(root, "chat-accepted")
	for style in ["flat", "crystal"]:
		check(app._services.ui_style.save_preferences(style, "svg") == OK, "apply proof theme")
		session._receive({"type":"agent_state_changed","payload":{"state":"waiting"}})
		session._receive({"type":"agent_state_changed","payload":{"state":"thinking"}})
		var count: int = session.get_messages().size()
		await process_frame
		check(app._chat_view.get_node("%Scroll")._typing.visible and session.get_messages().size() == count, "thinking decoration remains UI-only")
		await capture(root, "chat-typing-" + style)
	session._receive({"type":"agent_state_changed","payload":{"state":"waiting"}})

func _window_proof(app: Control) -> void:
	app.get_node("%NavDynamics").pressed.emit()
	var dynamics = app.find_child("DynamicsWindow", true, false)
	dynamics._open_publisher()
	var overlay = dynamics._publisher
	await create_timer(.3).timeout
	overlay.get_node("%PublishDraft").text = "保留草稿，确认关闭后才退出发布。"
	var panel: Control = overlay.get_node("Center/PanelSlot/Panel")
	check(dynamics.get_visible_rect().encloses(panel.get_global_rect()), "publisher panel fits its owning window")
	await capture(dynamics, "publish-overlay")
	overlay.close_requested.emit()
	check(overlay.get_node("%DiscardDialog").visible and overlay.is_dirty(), "publisher protects draft during exit")
	await capture(overlay.get_node("%DiscardDialog"), "publish-confirm")
	overlay.get_node("%DiscardDialog").get_ok_button().pressed.emit()
	var overlay_id: int = overlay.get_instance_id()
	await until(func(): return not is_instance_id_valid(overlay_id))
	dynamics.hide()
	var texture: Texture2D = load("res://assets/ui/bg2.jpg")
	var viewer = app._images_presenter.open_image(root, func(): return texture)
	await create_timer(.2).timeout
	await capture(viewer, "image-fit")
	var area: Control = viewer.get_node("%ImageScroll")
	var wheel := InputEventMouseButton.new()
	var previous_zoom: float = viewer._zoom
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = area.get_global_rect().get_center()
	viewer.push_input(wheel, true)
	await create_timer(.2).timeout
	check(viewer._zoom > previous_zoom, "native wheel input zooms the image")
	await capture(viewer, "image-wheel-zoom")
	viewer.get_node("%OriginalSize").pressed.emit()
	await create_timer(.2).timeout
	await capture(viewer, "image-original")
	viewer.close_requested.emit()
	await until(func(): return not viewer.visible)
	check(viewer.get_node("%Picture").texture == null, "animated image close releases texture")
