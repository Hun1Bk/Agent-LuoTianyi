extends SceneTree
const App = preload("res://src/application.gd")
const Log = preload("res://src/storage/client_log.gd")
var failures: Array[String] = []
func check(value: bool, text: String) -> void:
	if not value:
		failures.append(text)
		print("FAIL: ",text)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var directory := "user://log-window-test-%s" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	var security = ClassDB.instantiate("WindowsSecurity")
	var account = load("res://src/session/account_session.gd").new(load("res://src/network/account_api.gd").new(security),load("res://src/storage/credential_store.gd").new(security,directory+"/accounts"),directory+"/account.cfg")
	var app = App.new(account,directory+"/layout.cfg")
	root.add_child(app)
	await process_frame
	var buttons := app.find_children("*","Button",true,false)
	var open_button: Button
	for button in buttons:
		if button.text == "打开日志":
			open_button = button
	check(open_button != null,"login has open logs action")
	if open_button != null:
		open_button.pressed.emit()
		await process_frame
		var windows := app.find_children("*","Window",true,false).filter(func(w): return w.title.contains("日志"))
		check(windows.size() == 1 and windows[0].visible,"one nonmodal log window opens")
		if windows.size() == 1:
			var window: Window = windows[0]
			var texts := window.find_children("*","RichTextLabel",true,false)
			check(texts.size() == 1 and texts[0].get_parsed_text().contains("客户端启动"),"late opening retains first startup entry")
			open_button.pressed.emit()
			window.close_requested.emit()
			check(not window.visible,"close hides log window")
			open_button.pressed.emit()
			check(window.visible,"reopen retains same window")
	app.queue_free()
	await process_frame
	var observer = Log.new(directory+"/logs")
	var runs: Array = observer.list_runs() if observer.has_method("list_runs") else []
	check(runs.size() == 1 and runs[0].closed,"application exit closes startup archive")
	for file in DirAccess.get_files_at(directory+"/logs"):
		DirAccess.remove_absolute(directory+"/logs/"+file)
	DirAccess.remove_absolute(directory+"/logs")
	DirAccess.remove_absolute(directory)
	print("Log window: ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
