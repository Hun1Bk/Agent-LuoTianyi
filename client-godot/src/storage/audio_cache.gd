extends RefCounted
func _init(_root: String = "user://audio", _logger: RefCounted = null) -> void:
	pass
func set_scope(_server: String, _username: String) -> Error:
	return ERR_UNAVAILABLE
func begin(_id: String) -> Error:
	return ERR_UNAVAILABLE
func append(_id: String, _bytes: PackedByteArray) -> Error:
	return ERR_UNAVAILABLE
func commit(_id: String, _status: Dictionary, _waveform: PackedFloat32Array) -> Error:
	return ERR_UNAVAILABLE
func lookup(_id: String) -> Dictionary:
	return {}
func abort(_id: String) -> void:
	pass
func abort_all() -> void:
	pass
func clear() -> Error:
	return ERR_UNAVAILABLE
