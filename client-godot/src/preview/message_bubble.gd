extends HBoxContainer
const Style = preload("res://src/preview/preview_style.gd")
signal audio_action(action: String)
var _audio: Control
signal image_opened(texture: Texture2D)
signal image_action(action: String)
var _history_picture: TextureRect
var _image_button: Button
var _image_status := "idle"
var _body: VBoxContainer
var _text: RichTextLabel
var _caption: Label

func configure(message: Dictionary, image_texture: Texture2D = null) -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	if message.role == "system":
		var caption := Style.label(message.text, 12, Color("8a9ba4"))
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(caption)
		return
	var own: bool = message.role == "user"
	alignment = BoxContainer.ALIGNMENT_END if own else BoxContainer.ALIGNMENT_BEGIN
	var avatar := Style.avatar("res://assets/ui/user_icon.png" if own else "res://assets/ui/tianyi_icon.png")
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 5)
	if not own:
		add_child(avatar)
	add_child(_body)
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", Style.box(Style.USER_BUBBLE if own else Color.WHITE, 12, 13))
	_body.add_child(bubble)
	var content := VBoxContainer.new()
	bubble.add_child(content)
	_text = RichTextLabel.new()
	_text.text = message.text
	_text.fit_content = true
	_text.selection_enabled = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_text)
	if message.get("type") == "image":
		_history_picture = TextureRect.new()
		_history_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_history_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_history_picture.custom_minimum_size.y = 135
		_history_picture.hide()
		content.add_child(_history_picture)
		_history_picture.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				image_action.emit("preview"))
		_image_button = Style.button("加载图片…",func(): image_action.emit("retry" if _image_status == "error" else "preview"))
		content.add_child(_image_button)
	if image_texture != null:
		var picture := TextureRect.new()
		picture.texture = image_texture
		picture.custom_minimum_size = Vector2(0, 135)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		content.add_child(picture)
		picture.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				image_opened.emit(image_texture))
	if own:
		_caption = Style.label("", 11)
		_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_body.add_child(_caption)
		add_child(avatar)
	update_message(message)
	resized.connect(_resize_bubble)
	_resize_bubble()

func _resize_bubble() -> void:
	_body.custom_minimum_size.x = maxf(140, size.x * 0.76)

func update_message(message: Dictionary) -> void:
	if _text != null and _text.text != message.text:
		_text.text = message.text
	if _caption != null:
		_caption.text = {"waiting_history":"等待历史同步…", "queued":"等待发送…", "sent":"已发送", "sending":"发送中…", "failed":"发送失败", "uncertain":"无法确认送达，请勿重复发送"}.get(message.status, "")
		if message.get("demo", false):
			_caption.text += " · 演示"
		_caption.add_theme_color_override("font_color", Color("b57373") if message.status in ["failed", "uncertain"] else Color("93a6af"))

func set_audio_state(state: Dictionary) -> void:
	if _body == null:
		return
	if _audio == null and (state.available or not state.code.is_empty()):
		_audio = preload("res://src/ui/message_audio.gd").new()
		_body.add_child(_audio)
		_audio.action.connect(func(value): audio_action.emit(value))
	if _audio != null:
		_audio.update_state(state)

func set_image_state(state: Dictionary) -> void:
	if _history_picture == null:
		return
	_image_status = state.status
	_history_picture.texture = state.texture
	_history_picture.visible = state.status == "ready"
	_image_button.disabled = state.status in ["idle","loading"]
	_image_button.text = {"idle":"加载图片…","loading":"正在下载图片…","ready":"打开原图","error":"图片加载失败 · 重试"}.get(state.status,"")
	if state.code == "CACHE_WRITE_FAILED":
		_image_button.text += " · 未能缓存"
