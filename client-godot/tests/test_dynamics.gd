extends SceneTree
var failures: Array[String] = []
func check(value: bool,text: String) -> void:
	if not value:
		failures.append(text)
		print("FAIL: ",text)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	if not ResourceLoader.exists("res://src/session/dynamics_controller.gd"):
		check(false,"dynamics controller available")
		quit(1)
		return
	var controller = load("res://src/session/dynamics_controller.gd").new()
	root.add_child(controller)
	var scope := {"server":OS.get_environment("GODOT_TEST_SERVER"),"username":"read","message_token":"fixture-token"}
	await controller.start(scope)
	check(controller.get_state().unread==123,"initial unread query")
	await controller.refresh()
	check(controller.get_posts().size()==10 and controller.get_state().unread==123,"reading ten posts does not clear unread")
	await controller.load_more()
	check(controller.get_posts().size()==12 and not controller.get_state().has_more,"opaque cursor paging deduplicates posts")
	await controller.load_comments("d0")
	check(controller.get_comments("d0").items.size()==20,"comments first twenty")
	await controller.load_comments("d0",true)
	check(controller.get_comments("d0").items.size()==22,"comments page merge")
	await controller.mark_read()
	check(controller.get_state().unread==0,"explicit mark read clears unread")
	scope.username = "fail-unread"
	await controller.start(scope)
	await controller.refresh_unread()
	check(controller.get_state().unread==123 and controller.get_state().unread_code=="HTTP_ERROR","failed unread poll preserves count")
	scope.username = "fail-write"
	await controller.start(scope)
	await controller.mark_read()
	check(controller.get_state().unread==123,"failed mark read preserves count")
	scope.username = "slow"
	controller.start(scope)
	controller.stop()
	await create_timer(0.6).timeout
	check(controller.get_posts().is_empty() and controller.get_state().unread==0,"logout isolates pending reads")
	controller.queue_free()
	await process_frame
	print("Dynamics: ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
