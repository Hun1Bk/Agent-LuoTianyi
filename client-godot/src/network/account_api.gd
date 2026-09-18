extends Node

func _init(_security: Object, _timeout: float = 15.0) -> void:
	pass

static func normalize_server(_address: String) -> String:
	return ""

func request(_operation: String, _server: String, _fields: Dictionary) -> Dictionary:
	return {"ok":false, "code":"UNAVAILABLE", "status":0, "data":{}}

func cancel() -> void:
	pass
