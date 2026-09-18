extends RefCounted


func zoom_by(_factor: float) -> void:
	pass


func pan_by(_delta: Vector2, _size: Vector2) -> void:
	pass


func reset() -> void:
	pass


func get_transform(_panel: Vector2, _canvas: Vector2) -> Transform2D:
	return Transform2D.IDENTITY


func save_settings(_path: String) -> Error:
	return ERR_UNAVAILABLE


func load_settings(_path: String) -> Error:
	return ERR_UNAVAILABLE
