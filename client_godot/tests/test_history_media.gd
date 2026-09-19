extends SceneTree
var failures: Array[String] = []
func check(value: bool,text: String) -> void:
	if not value:
		failures.append(text)
		print("FAIL: ",text)
func until(predicate: Callable) -> bool:
	var end := Time.get_ticks_msec()+2500
	while not predicate.call() and Time.get_ticks_msec()<end:
		await process_frame
	return predicate.call()
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	check(ResourceLoader.exists("res://src/storage/history_images.gd"),"history images recover by UUID")
	if not failures.is_empty():
		quit(1)
		return
	var directory := "user://images-test-%s"%Time.get_ticks_usec()
	var script = load("res://src/storage/history_images.gd")
	var images = script.new(directory)
	root.add_child(images)
	var scope := {"server":OS.get_environment("GODOT_TEST_SERVER"),"username":"images","message_token":"message-test"}
	images.start(scope)
	check(images.get_state("sample").status == "idle","nothing downloaded before visibility")
	images.ensure("sample")
	check(await until(func(): return images.get_state("sample").status == "ready"),"actual image HTTP bytes decode")
	check(images.preview("sample").get_size() == Vector2(2,2),"in-client preview uses original image")
	images.stop()
	images.start(scope)
	images.ensure("sample")
	check(await until(func(): return images.get_state("sample").status == "ready"),"scope restart restores disk image without request")
	images.ensure("broken")
	check(await until(func(): return images.get_state("broken").status == "error"),"bad image explicit failure")
	images.retry("broken")
	check(await until(func(): return images.get_state("broken").status == "ready"),"explicit retry recovers image")
	images.ensure("slow")
	await create_timer(.05).timeout
	images.stop()
	var other := scope.duplicate()
	other.username = "other"
	images.start(other)
	images.ensure("sample")
	check(await until(func(): return images.get_state("sample").status == "ready"),"new account fetches own image")
	await create_timer(.35).timeout
	check(images.get_state("slow").status == "idle","old account late image ignored")
	images.queue_free()
	await process_frame
	for folder in DirAccess.get_directories_at(directory):
		for file in DirAccess.get_files_at(directory.path_join(folder)):
			DirAccess.remove_absolute(directory.path_join(folder).path_join(file))
		DirAccess.remove_absolute(directory.path_join(folder))
	DirAccess.remove_absolute(directory)
	print("History media: ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
