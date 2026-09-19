extends Node
signal receive_finished(id: String, code: String)
signal playback_finished(id: String, code: String)
signal mouth_changed(value: float)
signal state_changed(state: Dictionary)

func _init(_logger: RefCounted = null) -> void:
	pass

func append_reply_audio(_id: String, _encoded: String, _final: bool, _audio_error: bool = false) -> void:
	pass

func play_reply(_id: String) -> void:
	pass

func get_state() -> Dictionary:
	return {"active_id":"", "playing":false, "queued":0, "volume":1.0}

func set_volume(_value: float) -> void:
	pass

func stop_current() -> void:
	pass

func reset() -> void:
	pass
