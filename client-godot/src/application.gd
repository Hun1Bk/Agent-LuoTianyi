extends Control
## Composition root: owns account services and keeps the offline preview separate.
const Api = preload("res://src/network/account_api.gd")
const Store = preload("res://src/storage/credential_store.gd")
const Session = preload("res://src/session/account_session.gd")
const AccountView = preload("res://src/ui/account_view.gd")
const Avatar = preload("res://src/avatar/avatar_panel.gd")
var _session: Node


func _ready() -> void:
	get_window().min_size = Vector2i(960, 640)
	theme = preload("res://src/preview/preview_style.gd").make_theme()
	if "--preview" in OS.get_cmdline_user_args():
		add_child(load("res://scenes/chat_preview.tscn").instantiate())
		return
	if not ClassDB.class_exists("WindowsSecurity"):
		var error := Label.new()
		error.text = "凭据保护组件缺失，请重新解压完整程序。"
		add_child(error)
		push_error("WindowsSecurity extension missing")
		return
	var security = ClassDB.instantiate("WindowsSecurity")
	_session = Session.new(Api.new(security), Store.new(security))
	add_child(_session)
	var split := HSplitContainer.new()
	add_child(split)
	split.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var avatar := Avatar.new()
	avatar.custom_minimum_size.x = 290
	split.add_child(avatar)
	var center := CenterContainer.new()
	center.custom_minimum_size.x = 440
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(center)
	var form := AccountView.new(_session)
	form.custom_minimum_size.x = 390
	center.add_child(form)
	await get_tree().process_frame
	split.split_offset = roundi(size.x * 0.45)
	var capture := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			capture = argument.trim_prefix("--capture=")
	if not capture.is_empty():
		await get_tree().create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		var saved := get_viewport().get_texture().get_image().save_png(capture)
		get_tree().quit(0 if saved == OK else 1)
	elif DisplayServer.get_name() != "headless":
		_session.resume()
