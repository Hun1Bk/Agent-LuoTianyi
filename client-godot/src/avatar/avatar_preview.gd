extends "res://src/avatar/avatar_panel.gd"
## Isolated graphical smoke scene, usable from the exported executable.


func _ready() -> void:
	super._ready()
	if not avatar.get_status().loaded:
		push_error("Avatar load failed")
		get_tree().quit(1)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			await get_tree().create_timer(2.0).timeout
			await RenderingServer.frame_post_draw
			var saved := get_viewport().get_texture().get_image().save_png(argument.trim_prefix("--capture="))
			get_tree().quit(0 if saved == OK else 1)
