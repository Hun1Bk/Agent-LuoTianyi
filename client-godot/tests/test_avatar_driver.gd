extends SceneTree

const Driver = preload("res://src/avatar/avatar_driver.gd")
const MODEL = "res://assets/live2d/luo/model.model3.json"
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("FAIL: ", message)


func _run() -> void:
	if not ClassDB.class_exists("GDCubismUserModel"):
		print("ENVIRONMENT ERROR: gd_cubism is not loaded")
		quit(2)
		return
	var driver = Driver.new()
	root.add_child(driver)
	check(not driver.get_status().loaded, "initially unloaded")
	var loaded: Error = driver.load_avatar(MODEL)
	check(loaded == OK, "complete model loads through AvatarDriver")
	if loaded == OK:
		await process_frame
		check(driver.get_status().canvas_size.x > 0, "loaded model reports real canvas")
		check(driver.apply_expression("喜欢脸"), "Chinese expression command accepted")
		check(driver.get_status().expression == "like", "command selects mapped expression")
		check(not driver.apply_expression("missing"), "unknown expression rejected")
		check(driver.get_status().expression == "like", "invalid expression preserves state")
		check(driver.play_motion("倾听点头"), "existing motion starts")
		check(not driver.play_motion("倾听点头", 99), "invalid motion index rejected")
		driver.set_mouth_openness(0.5)
		check(is_equal_approx(driver.get_status().mouth_openness, 0.5), "speech opens mouth")
		driver.set_mouth_openness(2.0)
		check(is_equal_approx(driver.get_status().mouth_openness, 1.0), "mouth clamps to one")
		driver.set_mouth_openness(-1.0)
		check(is_equal_approx(driver.get_status().mouth_openness, 1.0), "release restores like base mouth")
		check(driver.load_avatar("res://missing.model3.json") == ERR_FILE_NOT_FOUND, "missing model rejected")
		check(driver.get_status().loaded, "failed preload preserves existing model")
	driver.free()
	print("Avatar driver: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
