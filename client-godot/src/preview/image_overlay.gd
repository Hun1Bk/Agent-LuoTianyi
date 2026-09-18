extends PanelContainer
const Style = preload("res://src/preview/preview_style.gd")
signal confirmed(texture: Texture2D)
var _picture := TextureRect.new()
var _scroll := ScrollContainer.new()
var _zoom := 1.0
var feedback := Label.new()

func _init(texture: Texture2D, pending: bool) -> void:
	add_theme_stylebox_override("panel", Style.box(Color("f7fafc"), 16, 20))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	var bar := HBoxContainer.new()
	column.add_child(bar)
	var heading := Style.label("待发送图片" if pending else "图片预览", 19)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(heading)
	bar.add_child(Style.button("－", func(): _resize_image(0.8)))
	bar.add_child(Style.button("＋", func(): _resize_image(1.25)))
	bar.add_child(Style.button("取消" if pending else "关闭", queue_free))
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)
	_picture.texture = texture
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_picture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_picture)
	if pending:
		feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(feedback)
		column.add_child(Style.button("发送图片 · 离线演示", func(): confirmed.emit(texture)))
	resized.connect(func(): _resize_image(1.0))

func _resize_image(factor: float) -> void:
	_zoom = clampf(_zoom * factor, 0.3, 4.0)
	var original := _picture.texture.get_size()
	var available := Vector2(maxf(100, size.x - 60), maxf(100, size.y - 130))
	_picture.custom_minimum_size = original * minf(available.x / original.x, available.y / original.y) * _zoom

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
