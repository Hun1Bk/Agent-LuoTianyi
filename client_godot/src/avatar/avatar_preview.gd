extends Control
## Isolated graphical smoke scene, usable from the exported executable.
const Driver = preload("res://src/avatar/avatar_driver.gd")
var avatar = Driver.new()


func _ready() -> void:
	add_child(avatar)
	var result: Error = avatar.load_avatar("res://assets/live2d/luo/model.model3.json")
	if result != OK:
		push_error("Avatar load failed: %s" % result)
		get_tree().quit(1)
		return
	resized.connect(_fit)
	_fit()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			await get_tree().create_timer(2.0).timeout
			await RenderingServer.frame_post_draw
			var saved := get_viewport().get_texture().get_image().save_png(argument.trim_prefix("--capture="))
			get_tree().quit(0 if saved == OK else 1)


func _fit() -> void:
	var canvas: Vector2 = avatar.get_status().canvas_size
	var factor: float = minf(size.x / canvas.x, size.y / canvas.y) * 0.95
	avatar.scale = Vector2.ONE * factor
	avatar.position = size / 2.0
