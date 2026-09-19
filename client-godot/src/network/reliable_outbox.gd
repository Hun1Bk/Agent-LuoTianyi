extends RefCounted
signal delivery_changed(id: String, state: String, code: String)
func enqueue(_type: String, _payload: Dictionary, _durable: bool, _now_ms: int) -> String:
	return ""
func take_ready(_now_ms: int, _connected: bool) -> Array[Dictionary]:
	return []
func acknowledge(_reply_to: String, _payload: Dictionary, _now_ms: int) -> void:
	pass
func disconnected(_now_ms: int) -> void:
	pass
func stop(_code: String = "TRANSPORT_STOPPED") -> void:
	pass
