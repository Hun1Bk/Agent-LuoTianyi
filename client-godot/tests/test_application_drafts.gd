extends SceneTree
var failures: Array[String] = []
func check(value: bool,text: String) -> void:
	if not value:
		failures.append(text)
		print("FAIL: ",text)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var path := "user://draft-app-test-%s"%Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(path)
	var security = ClassDB.instantiate("WindowsSecurity")
	var session = load("res://src/session/account_session.gd").new(load("res://src/network/account_api.gd").new(security),load("res://src/storage/credential_store.gd").new(security,path+"/tokens"),path+"/account.cfg")
	var app = load("res://src/application.gd").new(session,path+"/window.cfg")
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	await session.perform("login",OS.get_environment("GODOT_TEST_SERVER"),{"username":"ui","password":"synthetic-password","request_token":false},false)
	await process_frame
	var menus: Array = app.find_children("*","MenuButton",true,false)
	var menu: PopupMenu = menus.filter(func(n): return n.text == "更多 ···")[0].get_popup()
	check(menu.get_item_index(3)>=0,"chat menu exposes preferences")
	if menu.get_item_index(3)>=0:
		menu.id_pressed.emit(3)
		await create_timer(.15).timeout
		var windows: Array = app.find_children("*","Window",true,false).filter(func(n): return n.title == "相处模式")
		check(windows.size()==1,"preferences opens independent window")
		if windows.size()==1:
			menu.id_pressed.emit(3)
			check(app.find_children("*","Window",true,false).filter(func(n): return n.title == "相处模式").size()==1,"repeated open focuses same window")
			var input: TextEdit = windows[0].find_children("*","TextEdit",true,false)[0]
			input.text = "new draft"
			input.text_changed.emit()
			root.close_requested.emit()
			var dialogs: Array = app.find_children("*","ConfirmationDialog",true,false).filter(func(n): return n.visible)
			check(not dialogs.is_empty(),"app exit asks before discarding settings")
			if not dialogs.is_empty():
				dialogs[0].get_cancel_button().pressed.emit()
			menu.id_pressed.emit(2)
			dialogs = app.find_children("*","ConfirmationDialog",true,false).filter(func(n): return n.visible)
			check(not session.get_session().is_empty() and not dialogs.is_empty(),"logout waits for draft decision")
			if not dialogs.is_empty():
				dialogs[0].get_cancel_button().pressed.emit()
				check(windows[0].is_dirty(),"default cancel retains sensitive drafts")
				menu.id_pressed.emit(2)
				dialogs[0].get_ok_button().pressed.emit()
				await process_frame
				check(session.get_session().is_empty(),"confirmed discard completes logout")
	app.queue_free()
	await process_frame
	for folder in ["logs","reading"]:
		if not DirAccess.dir_exists_absolute(path+"/"+folder):
			continue
		for file in DirAccess.get_files_at(path+"/"+folder):
			DirAccess.remove_absolute(path+"/"+folder+"/"+file)
		DirAccess.remove_absolute(path+"/"+folder)
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path+"/"+file)
	DirAccess.remove_absolute(path)
	print("Application drafts: ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
