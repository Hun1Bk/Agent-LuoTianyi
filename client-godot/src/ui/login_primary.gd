extends Button
@onready var gradient: TextureRect = get_node("Gradient")
func _ready() -> void:
	resized.connect(_resize_gradient)
	_resize_gradient()
func _resize_gradient() -> void:
	(gradient.material as ShaderMaterial).set_shader_parameter("rect_size", size)
func _process(_delta: float) -> void:
	gradient.modulate = Color(1, 1, 1, 0.55) if disabled else (Color(0.9, 0.96, 1) if is_pressed() else (Color(1.05, 1.05, 1.05) if is_hovered() else Color.WHITE))
