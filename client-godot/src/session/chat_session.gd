extends Node
signal changed
signal state_changed(state: Dictionary)
signal expression_requested(command: String)
func _init(transport: Node) -> void:
	add_child(transport)
func start(_session: Dictionary) -> Error:
	return ERR_UNAVAILABLE
func send_text(_text: String) -> String:
	return ""
func get_messages() -> Array[Dictionary]:
	return []
func get_state() -> Dictionary:
	return {"phase":"idle", "code":"", "thinking":false}
func stop() -> void:
	pass
