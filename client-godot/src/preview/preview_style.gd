extends RefCounted
const ACCENT := Color("66ccff")
const INK := Color("304553")
const SURFACE := Color("f5f8fb")
const USER_BUBBLE := Color("dff3ff")

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
	for type in ["Label", "Button", "OptionButton", "LineEdit", "TextEdit", "RichTextLabel", "PopupMenu", "CheckBox"]:
		result.set_color("font_color", type, INK)
	result.set_color("default_color", "RichTextLabel", INK)
	result.set_color("font_placeholder_color", "TextEdit", Color("9aaeb8"))
	result.set_color("font_placeholder_color", "LineEdit", Color("8299a6"))
	for type in ["Button", "OptionButton", "MenuButton"]:
		result.set_stylebox("normal", type, box(Color("eef6fb"), 8, 9))
		result.set_stylebox("hover", type, box(Color("dff3ff"), 8, 9))
		result.set_stylebox("pressed", type, box(Color("b7e6ff"), 8, 9))
		result.set_stylebox("disabled", type, box(Color("edf1f4"), 8, 9))
		result.set_stylebox("focus", type, _focus())
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			result.set_color(state, type, INK)
		result.set_color("font_disabled_color", type, Color("9aabb7"))
	result.set_type_variation("PrimaryButton", "Button")
	for pair in [["normal",ACCENT],["hover",Color("8ad8ff")],["pressed",Color("43b8f0")]]:
		result.set_stylebox(pair[0], "PrimaryButton", box(pair[1], 9, 10))
	for type in ["TextEdit", "LineEdit"]:
		result.set_stylebox("normal", type, box(Color.WHITE, 8, 12))
		result.set_stylebox("focus", type, _focus())
		result.set_color("selection_color", type, Color("b7e6ff"))
		result.set_color("caret_color", type, INK)
	result.set_stylebox("panel", "PopupMenu", box(Color.WHITE, 10, 8))
	result.set_stylebox("hover", "PopupMenu", box(Color("dff3ff"), 6, 6))
	result.set_color("font_hover_color", "PopupMenu", INK)
	result.set_constant("v_separation", "PopupMenu", 12)
	result.set_stylebox("slider", "HSlider", box(Color("dcecf5"), 2, 2))
	result.set_stylebox("grabber_area", "HSlider", box(ACCENT, 2, 2))
	result.set_stylebox("grabber_area_highlight", "HSlider", box(ACCENT, 2, 2))
	result.set_stylebox("focus", "HSlider", _focus())
	result.set_icon("grabber", "HSlider", _dot(ACCENT))
	result.set_icon("grabber_highlight", "HSlider", _dot(Color("43b8f0")))
	result.set_icon("grabber_disabled", "HSlider", _dot(Color("b7c6d0")))
	return result

static func _focus() -> StyleBoxFlat:
	var style := box(Color.TRANSPARENT, 8, 0)
	style.border_color = ACCENT
	style.set_border_width_all(2)
	return style

static func _dot(color: Color) -> Texture2D:
	var image := Image.create(16,16,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in 16:
		for x in 16:
			if Vector2(x-7.5,y-7.5).length() <= 6:
				image.set_pixel(x,y,color)
	return ImageTexture.create_from_image(image)

static func primary(node: Button) -> void:
	node.theme_type_variation = "PrimaryButton"

static func avatar(path: String, pixels: int = 38) -> TextureRect:
	var node := TextureRect.new()
	node.texture = load(path)
	node.custom_minimum_size = Vector2(pixels,pixels)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){ vec4 p=texture(TEXTURE,UV); float a=1.0-smoothstep(0.47,0.5,length(UV-vec2(0.5))); COLOR=vec4(mix(vec3(0.91,0.97,1.0),p.rgb,p.a),a); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	node.material = material
	return node

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
