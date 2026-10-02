extends HBoxContainer
const UiMotion = preload("res://src/ui/ui_motion.gd")
func _ready() -> void:
	visibility_changed.connect(_motion)
	_motion()
func _motion() -> void:
	var dots: HBoxContainer = get_node("Panel/Dots")
	for index in dots.get_child_count():
		var dot: Control = dots.get_child(index)
		UiMotion.cancel(dot, "dot")
		if is_visible_in_tree(): UiMotion.typing_dot(dot, index * 0.1)
