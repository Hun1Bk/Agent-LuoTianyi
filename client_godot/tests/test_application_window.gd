extends SceneTree
const App = preload("res://src/application.gd")
const Session = preload("res://src/session/account_session.gd")
const Store = preload("res://src/storage/credential_store.gd")
const Api = preload("res://src/network/account_api.gd")
const DEFAULT_SERVER := "https://www-api.u3493359.nyat.app:11664"
var failures: Array[String] = []

func check(value: bool, description: String) -> void:
	if not value:
		failures.append(description)
		print("FAIL: ", description)

func field(view: Node, hint: String) -> LineEdit:
	for node in view.find_children("*", "LineEdit", true, false):
		if node.placeholder_text == hint:
			return node
	return null

func button(view: Node, caption: String) -> void:
	for node in view.find_children("*", "Button", true, false):
		if node.text == caption and node.is_visible_in_tree():
			node.pressed.emit()
			return
	check(false, "visible button: " + caption)

func until(predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + 3000
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	return predicate.call()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var folder := "user://application-test-%s" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder)
	var settings_path := folder + "/account.cfg"
	var security = ClassDB.instantiate("WindowsSecurity")
	var store = Store.new(security, folder + "/tokens")
	var session = Session.new(Api.new(security), store, settings_path)
	check(session.get_login_defaults().server == DEFAULT_SERVER, "fresh account uses legacy release server")
	var app := App.new(session, folder + "/layout.cfg")
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	await process_frame
	check(root.size == Vector2i(660, 800) and root.min_size == Vector2i(480, 640), "login window is compact")
	check(app.find_children("*", "TextEdit", true, false).is_empty(), "signed-out window has no chat composer")
	check(app.find_children("*", "Node2D", true, false).is_empty(), "first login does not create or render avatar")
	check(field(app, "服务器地址").text == DEFAULT_SERVER, "default server visible in account form")
	var endpoint := OS.get_environment("GODOT_TEST_SERVER")
	field(app, "服务器地址").text = endpoint
	field(app, "用户名").text = "reject"
	field(app, "密码").text = "synthetic-password"
	button(app, "登录")
	check(await until(func(): return field(app, "密码").editable), "failed login settles")
	check(session.get_session().is_empty() and root.size == Vector2i(660, 800), "failed login stays compact")
	field(app, "用户名").text = "test"
	button(app, "登录")
	check(await until(func(): return not session.get_session().is_empty()), "real account login succeeds")
	await process_frame
	check(root.size == Vector2i(1200, 800) and root.min_size == Vector2i(960, 640), "successful login expands window")
	var composers := app.find_children("*", "TextEdit", true, false)
	check(composers.size() == 1 and composers[0].is_visible_in_tree(), "expanded window shows chat")
	check(not field(app, "服务器地址").is_visible_in_tree(), "expanded window hides account form")
	root.size = Vector2i(1280, 820)
	var windowed := root.mode == Window.MODE_WINDOWED
	button(app, "退出登录")
	await process_frame
	check(root.size == Vector2i(660, 800) and field(app, "服务器地址").is_visible_in_tree(), "logout returns compact account window")
	check(app.find_children("*", "Node2D", true, false).is_empty(), "logout releases avatar drawing resources")
	field(app, "密码").text = "synthetic-password"
	button(app, "登录")
	await until(func(): return not session.get_session().is_empty())
	if windowed:
		check(root.size == Vector2i(1280, 820), "relogin restores expanded size from this run")
	else:
		print("SKIP: native window size restoration requires windowed display")
	button(app, "退出登录")
	app.queue_free()
	await process_frame
	var restored = Session.new(Api.new(security), store, settings_path)
	check(restored.get_login_defaults().server == endpoint, "saved custom server takes precedence")
	restored.free()
	var file := FileAccess.open(settings_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"server":"", "username":"test", "remember":true}))
	file.close()
	var empty_config = Session.new(Api.new(security), store, settings_path)
	check(empty_config.get_login_defaults().server == DEFAULT_SERVER and not empty_config.get_login_defaults().remember, "empty saved server falls back without auto login")
	empty_config.free()
	DirAccess.remove_absolute(settings_path)
	DirAccess.remove_absolute(folder)
	print("Application window: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
