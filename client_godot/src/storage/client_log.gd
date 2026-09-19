extends RefCounted
func _init(_directory: String = "user://logs", _max_bytes: int = 2097152) -> void:
	pass
func record(_event: String, _fields: Dictionary = {}) -> Error:
	return ERR_UNAVAILABLE
func get_directory() -> String:
	return ""
