extends Control
## The container lays out this slot; its child is free to animate its transform.
@onready var content: Control = get_child(0)
func _ready() -> void:
	content.set_anchors_preset(Control.PRESET_TOP_LEFT)
	content.position = Vector2.ZERO
	content.minimum_size_changed.connect(_measure)
	content.visibility_changed.connect(_measure)
	resized.connect(_fit_content)
	_measure()
	_fit_content()
func _measure() -> void:
	visible = content.visible
	custom_minimum_size = content.get_combined_minimum_size() if content.visible else Vector2.ZERO

func _fit_content() -> void:
	content.size = size
