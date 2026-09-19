extends SceneTree
var failures: Array[String] = []
func check(value: bool,label: String) -> void:
	if not value:
		failures.append(label)
		print("FAIL: ",label)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var controller = load("res://src/session/dynamics_controller.gd").new()
	root.add_child(controller)
	await controller.start({"server":OS.get_environment("GODOT_TEST_SERVER"),"username":"detail","message_token":"fixture-token"})
	await controller.refresh()
	var script = load("res://src/ui/dynamics_window.gd")
	if not script.get_script_method_list().any(func(method): return method.name == "select_post"):
		check(false,"two-pane selection available")
		controller.queue_free()
		await process_frame
		quit(1)
		return
	var window = script.new(controller,"user://detail-test.cfg")
	root.add_child(window)
	window.open()
	await process_frame
	check(window.get_selected_id().is_empty(),"opening has no selection")
	check(window.select_post("d0"),"select known post")
	await create_timer(.15).timeout
	var draft = window.find_child("CommentDraft",true,false)
	draft.text = "ordinary draft"
	check(window.is_dirty(),"comment draft counted")
	window.select_post("d1")
	window.select_post("d0")
	check(draft.text == "ordinary draft" and draft.is_visible_in_tree(),"switch preserves correct draft")
	var replies = window.find_children("*","Button",true,false).filter(func(b): return b.text == "回复" and b.is_visible_in_tree())
	check(not replies.is_empty(),"explicit inline reply actions")
	if not replies.is_empty():
		replies[0].pressed.emit()
		var reply = window.find_child("ReplyDraft",true,false)
		reply.text = "reply draft"
		window.find_child("CancelReply",true,false).pressed.emit()
		check(reply.text == "reply draft" and window.is_dirty(),"cancel target keeps reply text")
	window.queue_free()
	await process_frame
	controller.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://detail-test.cfg")
	print("Dynamics detail: ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
