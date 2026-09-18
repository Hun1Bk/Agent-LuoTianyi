extends Node2D
## Interface skeleton; the contract test supplies the missing behavior.


func load_avatar(_model_path: String) -> Error:
	return ERR_UNAVAILABLE


func apply_expression(_command: String) -> bool:
	return false


func play_motion(_group: String, _index: int = 0) -> bool:
	return false


func set_mouth_openness(_value: float) -> void:
	pass


func get_status() -> Dictionary:
	return {"loaded": false, "canvas_size": Vector2.ZERO,
		"expression": "", "motion_groups": [], "mouth_openness": 0.0}
