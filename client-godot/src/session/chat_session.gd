extends Node
signal message_audio_changed(id: String, state: Dictionary)
signal changed
signal state_changed(state: Dictionary)
signal expression_requested(command: String)
signal mouth_changed(value: float)
const Audio = preload("res://src/media/reply_audio.gd")
var _transport: Node
var _media: Node
var _logger: RefCounted
var _messages: Array[Dictionary] = []
var _by_id: Dictionary = {}
var _replies: Dictionary = {}
var _finished: Dictionary = {}
var _state := {"phase":"idle", "code":"", "thinking":false, "speaking":false}
var _history: Node
var _waiting_history := false
var _pending_history: Dictionary = {}
var _wire_ids: Dictionary = {}

func _init(transport: Node, logger: RefCounted = null, media: Node = null, history: Node = null) -> void:
	_transport = transport
	_logger = logger
	_media = media if media != null else Audio.new(logger)
	add_child(_media)
	_media.playback_finished.connect(_audio_finished)
	_media.message_audio_changed.connect(func(id,state):
		if _by_id.has(id):
			message_audio_changed.emit(id,state))
	_media.mouth_changed.connect(func(value): mouth_changed.emit(value))
	_media.state_changed.connect(func(state):
		_state.speaking = state.playing
		state_changed.emit(get_state()))
	add_child(transport)
	transport.state_changed.connect(_connection_changed)
	transport.delivery_changed.connect(_delivery_changed)
	transport.event_received.connect(_receive)
	transport.system_error.connect(_system_error)
	_history = history
	if history != null:
		add_child(history)
		history.page_received.connect(_history_page)
		history.boundary_ready.connect(_release_history_sends)
		history.state_changed.connect(func(_value): state_changed.emit(get_state()))

func start(session: Dictionary) -> Error:
	stop()
	_media.set_scope(session.get("server",""),session.get("username",""))
	var result: Error = _transport.start(session)
	if result == OK and _history != null:
		_waiting_history = true
		_history.start(session)
	return result

func send_text(text: String) -> String:
	if text.strip_edges().is_empty() or _state.phase in ["idle","auth_rejected"]:
		return ""
	var id: String
	if _waiting_history:
		if _pending_history.size() >= 128 or text.to_utf8_buffer().size() > 8*1024*1024-1024:
			_system_error("SEND_REJECTED")
			return ""
		id = "local-" + Crypto.new().generate_random_bytes(16).hex_encode()
		_pending_history[id] = text
	else:
		id = _transport.send_event("user_text", {"message":text, "llm_mode":{"types":[]}}, true)
	if id.is_empty():
		_system_error("SEND_REJECTED")
		return ""
	var message := {"id":id, "role":"user", "text":text, "status":"waiting_history" if _waiting_history else "queued", "code":""}
	_messages.append(message)
	_by_id[id] = message
	if _logger != null:
		_logger.record("message_queued", {"reply_id":id})
	changed.emit()
	return id

func get_messages() -> Array[Dictionary]:
	return _messages.duplicate(true)

func get_state() -> Dictionary:
	var result := _state.duplicate(true)
	result.history = get_history_state()
	return result

func get_log_directory() -> String:
	return _logger.get_directory() if _logger != null else ""

func set_volume(value: float) -> void:
	_media.set_volume(value)

func get_audio_state() -> Dictionary:
	return _media.get_state()

func stop_voice() -> void:
	_media.stop_current()

func stop() -> void:
	_waiting_history = false
	_pending_history.clear()
	_wire_ids.clear()
	if _history != null:
		_history.stop()
	_transport.stop()
	_media.set_scope("", "")
	_messages.clear()
	_by_id.clear()
	_replies.clear()
	_finished.clear()
	_state = {"phase":"idle", "code":"", "thinking":false, "speaking":false}
	changed.emit()
	state_changed.emit(get_state())

func _connection_changed(connection: Dictionary) -> void:
	if _logger != null:
		_logger.record("connection_state", connection)
	_state.phase = connection.phase
	_state.code = connection.code
	if connection.phase != "ready":
		_state.thinking = false
		for id in _replies:
			_finished[id] = true
		_replies.clear()
		_media.reset()
	state_changed.emit(get_state())

func _delivery_changed(id: String, status: String, code: String) -> void:
	id = _wire_ids.get(id,id)
	if _logger != null:
		_logger.record("message_delivery", {"reply_id":id,"phase":status,"code":code})
	if _by_id.has(id):
		_by_id[id].status = status
		_by_id[id].code = code
		changed.emit()

func _system_error(code: String) -> void:
	if _logger != null:
		_logger.record("system_error", {"code":code})
	_state.code = code
	state_changed.emit(get_state())

func _receive(event: Dictionary) -> void:
	var payload: Dictionary = event.payload
	if event.type == "agent_state_changed":
		if payload.get("state") in ["thinking", "waiting"]:
			_state.thinking = payload.state == "thinking"
			state_changed.emit(get_state())
	elif event.type == "agent_message":
		_receive_reply(payload)

func _receive_reply(payload: Dictionary) -> void:
	var id: Variant = payload.get("uuid")
	if not id is String or id.is_empty() or (payload.get("text") != null and not payload.text is String):
		_system_error("INVALID_RESPONSE")
		return
	if _logger != null:
		_logger.record("reply_received", {"reply_id":id, "has_audio":payload.get("audio") is String and not payload.audio.is_empty(),
			"audio_chars":payload.audio.length() if payload.get("audio") is String else 0,
			"final":payload.get("is_final_package", true), "audio_error":payload.get("audio_error", false)})
	if _finished.has(id):
		return
	if not _replies.has(id):
		_replies[id] = {"text":"", "expression":"", "display":true, "final":false, "audio_error":false, "played":false}
	var reply: Dictionary = _replies[id]
	if reply.final:
		return
	if payload.get("text") is String and not payload.text.is_empty():
		reply.text = payload.text
	if payload.get("expression") is String and not payload.expression.is_empty():
		reply.expression = payload.expression
	if payload.get("display_in_chat", true) == false:
		reply.display = false
	reply.audio_error = reply.audio_error or payload.get("audio_error", false) == true
	reply.final = reply.final or payload.get("is_final_package", true) == true or reply.audio_error
	_media.append_reply_audio(id, payload.audio if payload.get("audio") is String else "", reply.final, reply.audio_error, payload.get("is_ephemeral",false) == true)
	_present_replies()

func _audio_finished(id: String, code: String) -> void:
	if not _replies.has(id):
		return
	_replies[id].played = true
	if not code.is_empty() and code != "STOPPED":
		_replies[id].audio_error = true
		_system_error("AUDIO_ERROR")
	_present_replies.call_deferred()

func _present_replies() -> void:
	for id in _replies.keys():
		var reply: Dictionary = _replies[id]
		if reply.display and not reply.text.is_empty():
			if not _by_id.has(id):
				var message := {"id":id, "role":"assistant", "text":reply.text, "status":"received", "code":""}
				_by_id[id] = message
				_messages.append(message)
			else:
				_by_id[id].text = reply.text
			changed.emit()
		if not reply.expression.is_empty():
			expression_requested.emit(reply.expression)
			reply.expression = ""
		if reply.audio_error:
			_system_error("AUDIO_ERROR")
		if not reply.played:
			_media.play_reply(id)
			break
		_finished[id] = true
		_replies.erase(id)

func _exit_tree() -> void:
	stop()

func get_message_audio(id: String) -> Dictionary:
	return _media.get_message_audio(id)

func replay(id: String) -> Error:
	if not _by_id.has(id) or _by_id[id].role != "assistant":
		return ERR_DOES_NOT_EXIST
	return _media.replay(id)

func pause_replay() -> void:
	_media.pause_replay()

func resume_replay() -> void:
	_media.resume_replay()

func stop_replay() -> void:
	_media.stop_replay()

func clear_cache() -> Error:
	var result: Error = _media.clear_cache()
	if result != OK:
		_system_error("CACHE_CLEAR_FAILED")
	return result

func get_history_state() -> Dictionary:
	return _history.get_state() if _history != null else {"phase":"idle","code":"","count":0,"incomplete":false}

func retry_history() -> void:
	if _history != null:
		_history.retry()

func skip_history() -> void:
	if _history != null:
		_history.skip()

func _release_history_sends() -> void:
	_waiting_history = false
	for id in _pending_history:
		var wire: String = _transport.send_event("user_text",{"message":_pending_history[id],"llm_mode":{"types":[]}},true)
		if wire.is_empty():
			_by_id[id].status = "failed"
			_by_id[id].code = "SEND_REJECTED"
		else:
			_wire_ids[wire] = id
			_by_id[id].status = "queued"
	_pending_history.clear()
	changed.emit()

func _history_page(messages: Array[Dictionary]) -> void:
	var prepend: Array[Dictionary] = []
	for message in messages:
		if _by_id.has(message.id):
			# History UUID is authoritative identity, never text/time matching.
			# Preserve live content while moving the item into its history position.
			var existing: Dictionary = _by_id[message.id]
			_messages.erase(existing)
			prepend.append(existing)
		else:
			_by_id[message.id] = message
			prepend.append(message)
	_messages = prepend + _messages
	changed.emit()
