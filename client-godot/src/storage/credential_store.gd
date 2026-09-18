extends RefCounted
func _init(_security: Object, _root: String = "user://accounts") -> void:
	pass
func save(_server: String, _username: String, _token: String) -> Error:
	return ERR_UNAVAILABLE
func read(_server: String, _username: String) -> Dictionary:
	return {"ok":false, "code":"NOT_FOUND", "token":""}
func forget(_server: String, _username: String) -> Error:
	return ERR_UNAVAILABLE
