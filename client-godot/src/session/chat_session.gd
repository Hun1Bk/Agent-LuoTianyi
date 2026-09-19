extends Node
signal changed
signal state_changed(state: Dictionary)
signal expression_requested(command: String)
var _transport: Node
var _logger: RefCounted
var _messages: Array[Dictionary] = []
var _by_id: Dictionary = {}
var _replies: Dictionary = {}
var _finished: Dictionary = {}
var _state := {"phase":"idle", "code":"", "thinking":false}

func _init(transport: Node, logger: RefCounted = null) -> void:
	_transport = transport
	_logger = logger
	add_child(transport)
	transport.state_changed.connect(_connection_changed)
	transport.delivery_changed.connect(_delivery_changed)
	transport.event_received.connect(_receive)
	transport.system_error.connect(_system_error)

func start(session: Dictionary) -> Error:
	stop()
	return _transport.start(session)

func send_text(text: String) -> String:
	if text.strip_edges().is_empty():
		return ""
	var id: String = _transport.send_event("user_text", {"message":text, "llm_mode":{"types":[]}}, true)
	if id.is_empty():
		_system_error("SEND_REJECTED")
		return ""
	var message := {"id":id, "role":"user", "text":text, "status":"queued", "code":""}
	_messages.append(message)
	_by_id[id] = message
	changed.emit()
	return id

func get_messages() -> Array[Dictionary]:
	return _messages.duplicate(true)

func get_state() -> Dictionary:
	return _state.duplicate(true)

func get_log_directory() -> String:
	return _logger.get_directory() if _logger != null else ""

func stop() -> void:
	_transport.stop()
	_messages.clear()
	_by_id.clear()
	_replies.clear()
	_finished.clear()
	_state = {"phase":"idle", "code":"", "thinking":false}
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
	state_changed.emit(get_state())

func _delivery_changed(id: String, status: String, code: String) -> void:
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
		_replies[id] = {"text":"", "expression":"", "display":true, "final":false, "audio_error":false}
	var reply: Dictionary = _replies[id]
	if payload.get("text") is String and not payload.text.is_empty():
		reply.text = payload.text
	if payload.get("expression") is String and not payload.expression.is_empty():
		reply.expression = payload.expression
	if payload.get("display_in_chat", true) == false:
		reply.display = false
	reply.audio_error = reply.audio_error or payload.get("audio_error", false) == true
	reply.final = reply.final or payload.get("is_final_package", true) == true or reply.audio_error
	_present_replies()

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
		if not reply.final:
			break
		_finished[id] = true
		_replies.erase(id)

func _exit_tree() -> void:
	stop()
