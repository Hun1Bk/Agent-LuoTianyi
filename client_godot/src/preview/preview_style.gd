extends RefCounted

static func box(color: Color, radius: int = 12, padding: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

static func make_theme() -> Theme:
	var result := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei"])
	result.default_font = font
	result.default_font_size = 15
	for type in ["Label", "Button", "OptionButton", "LineEdit", "TextEdit", "RichTextLabel"]:
		result.set_color("font_color", type, Color("344c59"))
	result.set_color("default_color", "RichTextLabel", Color("344c59"))
	result.set_color("font_placeholder_color", "TextEdit", Color("9aaeb8"))
	result.set_color("font_placeholder_color", "LineEdit", Color("8299a6"))
	result.set_stylebox("normal", "Button", box(Color("edf4f5"), 8, 9))
	result.set_stylebox("hover", "Button", box(Color("dfedf0"), 8, 9))
	result.set_stylebox("pressed", "Button", box(Color("cce8ec"), 8, 9))
	result.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), 8, 0))
	result.set_stylebox("normal", "TextEdit", box(Color("ffffff"), 8, 12))
	return result

static func label(text: String, size: int = 15, color: Color = Color("344c59")) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	return node

static func button(text: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.pressed.connect(action)
	return node
