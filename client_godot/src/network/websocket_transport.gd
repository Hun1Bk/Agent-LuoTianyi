extends Node
signal state_changed(state: Dictionary)
signal delivery_changed(id: String, state: String, code: String)
signal event_received(event: Dictionary)
signal system_error(code: String)
func _init(_clock: Callable = Callable()) -> void:
	pass
func start(_session: Dictionary) -> Error:
	return ERR_UNAVAILABLE
func send_event(_type: String, _payload: Dictionary, _durable: bool = false) -> String:
	return ""
func get_state() -> Dictionary:
	return {"phase":"idle", "code":""}
func stop() -> void:
	pass
