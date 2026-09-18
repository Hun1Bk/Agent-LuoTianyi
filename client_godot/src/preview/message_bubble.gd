extends HBoxContainer
const Style = preload("res://src/preview/preview_style.gd")
signal image_opened(texture: Texture2D)
var _body: VBoxContainer
var _text: RichTextLabel

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
	var avatar := TextureRect.new()
	avatar.texture = load("res://assets/ui/user_icon.png" if own else "res://assets/ui/tianyi_icon.png")
	avatar.custom_minimum_size = Vector2(36, 36)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 5)
	if not own:
		add_child(avatar)
	add_child(_body)
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", Style.box(Color("dff1f5") if own else Color.WHITE, 12, 13))
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
		var status: String = {"sent":"已发送 · 演示", "sending":"发送中… · 演示", "failed":"发送失败 · 演示"}.get(message.status, "")
		var caption := Style.label(status, 11, Color("b57373") if message.status == "failed" else Color("93a6af"))
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_body.add_child(caption)
		add_child(avatar)
	resized.connect(_resize_bubble)
	_resize_bubble()

func _resize_bubble() -> void:
	_body.custom_minimum_size.x = maxf(140, size.x * 0.76)
