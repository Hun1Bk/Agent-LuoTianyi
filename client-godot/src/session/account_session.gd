extends Node
signal changed(state: Dictionary)
func _init(api: Node, _store: RefCounted, _settings_path: String = "user://account.cfg") -> void:
	add_child(api)
func perform(_operation: String, _server: String, _fields: Dictionary, _remember: bool = false) -> Dictionary:
	return {"ok":false, "code":"UNAVAILABLE", "storage_error":false}
func resume() -> Dictionary:
	return {"ok":false, "code":"NO_SAVED_LOGIN", "storage_error":false}
func cancel() -> void:
	pass
func logout() -> Error:
	return ERR_UNAVAILABLE
func get_login_defaults() -> Dictionary:
	return {"server":"", "username":"", "remember":false}
func get_session() -> Dictionary:
	return {}
