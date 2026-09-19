extends Control
## Composition root: owns account services and keeps the offline preview separate.
const Api = preload("res://src/network/account_api.gd")
const Store = preload("res://src/storage/credential_store.gd")
const Session = preload("res://src/session/account_session.gd")
const AccountView = preload("res://src/ui/account_view.gd")
const Avatar = preload("res://src/avatar/avatar_panel.gd")
const Chat = preload("res://src/session/chat_session.gd")
const Transport = preload("res://src/network/websocket_transport.gd")
const ChatView = preload("res://src/ui/chat_view.gd")
var _session: Node
var _chat: Node
var _chat_view: Control
var _split: HSplitContainer
var _center: CenterContainer
var _avatar: Control
var _ratio := 0.45
var _layout_ready := false
var _layout_path: String

func _init(account_session: Node = null, layout_path: String = "user://window_layout.cfg") -> void:
	_session = account_session
	_layout_path = layout_path


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
	if _session == null:
		var security = ClassDB.instantiate("WindowsSecurity")
		_session = Session.new(Api.new(security), Store.new(security))
	add_child(_session)
	_chat = Chat.new(Transport.new())
	add_child(_chat)
	_split = HSplitContainer.new()
	_center = CenterContainer.new()
	_avatar = Avatar.new()
	_chat.expression_requested.connect(func(command): _avatar.avatar.apply_expression(command))
	add_child(_split)
	_split.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_avatar.custom_minimum_size.x = 290
	_split.add_child(_avatar)
	_center.custom_minimum_size.x = 440
	_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_split.add_child(_center)
	var form := AccountView.new(_session)
	form.custom_minimum_size.x = 390
	_center.add_child(form)
	_session.changed.connect(_account_changed)
	var settings := ConfigFile.new()
	if settings.load(_layout_path) == OK:
		var ratio: Variant = settings.get_value("layout", "ratio", 0.45)
		if (ratio is float or ratio is int) and is_finite(float(ratio)):
			_ratio = clampf(float(ratio), 0.3, 0.6)
	_split.dragged.connect(func(_offset):
		_ratio = _avatar.size.x / maxf(size.x, 1)
		settings.set_value("layout", "ratio", _ratio)
		if settings.save(_layout_path) != OK:
			push_warning("Window layout save failed"))
	resized.connect(_resize_split)
	await get_tree().process_frame
	_layout_ready = true
	_resize_split()
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

func _account_changed(state: Dictionary) -> void:
	if state.phase == "signed_in":
		_center.hide()
		if _chat_view == null:
			_chat_view = ChatView.new(_chat)
			_chat_view.custom_minimum_size.x = 440
			_chat_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_split.add_child(_chat_view)
			_chat_view.logout_requested.connect(func(): _session.logout())
		_chat.start(_session.get_session())
	else:
		_chat.stop()
		if _chat_view != null:
			_chat_view.hide()
			_chat_view.queue_free()
			_chat_view = null
		_center.show()
	_resize_split()

func _resize_split() -> void:
	if _layout_ready:
		_split.split_offset = roundi(size.x * _ratio)
