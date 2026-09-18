extends Node
signal changed(state: Dictionary)
const Api = preload("res://src/network/account_api.gd")
var _api: Node
var _store: RefCounted
var _settings_path: String
var _defaults := {"server":"", "username":"", "remember":false}
var _session: Dictionary = {}
var _busy := false
var _generation := 0

func _init(api: Node, store: RefCounted, settings_path: String = "user://account.cfg") -> void:
	_api = api
	_store = store
	_settings_path = settings_path
	add_child(api)
	if FileAccess.file_exists(settings_path):
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(settings_path)) == OK and parser.data is Dictionary:
			var data: Dictionary = parser.data
			if data.get("server") is String and data.get("username") is String and data.get("remember") is bool:
				_defaults = {"server":Api.normalize_server(data.server), "username":data.username, "remember":data.remember}

func perform(operation: String, server: String, fields: Dictionary, remember: bool = false) -> Dictionary:
	if _busy:
		return {"ok":false, "code":"BUSY", "storage_error":false}
	if not _session.is_empty():
		logout()
	_busy = true
	var generation := _generation
	changed.emit({"phase":"busy", "code":"PENDING", "storage_error":false})
	var response: Dictionary = await _api.request(operation, server, fields)
	_busy = false
	response.storage_error = false
	if generation != _generation:
		response = {"ok":false, "code":"CANCELLED", "storage_error":false}
	if response.ok:
		var username: String = fields.get("username", fields.get("new_username", ""))
		_defaults = {"server":Api.normalize_server(server), "username":username, "remember":false}
		if operation in ["login", "auto_login"]:
			_session = response.data.duplicate(true)
			_session.server = _defaults.server
			_session.username = username
			var saved: Error = _store.save(_defaults.server, username, _session.login_token) if remember else _store.forget(_defaults.server, username)
			_defaults.remember = remember and saved == OK
			response.storage_error = saved != OK
		if _write_settings() != OK:
			response.storage_error = true
			_defaults.remember = false
		if response.storage_error:
			_store.forget(_defaults.server, _defaults.username)
	elif operation == "auto_login" and response.code == "AUTH_REJECTED":
		var removed: Error = _store.forget(_defaults.server, _defaults.username)
		_defaults.remember = false
		response.storage_error = _write_settings() != OK or removed != OK
	changed.emit({"phase":"signed_in" if not _session.is_empty() else "signed_out", "code":response.code, "storage_error":response.storage_error})
	return response

func resume() -> Dictionary:
	if not _defaults.remember or _defaults.server.is_empty() or _defaults.username.is_empty():
		return {"ok":false, "code":"NO_SAVED_LOGIN", "storage_error":false}
	var stored: Dictionary = _store.read(_defaults.server, _defaults.username)
	if not stored.ok:
		_defaults.remember = false
		var error := _write_settings()
		changed.emit({"phase":"signed_out", "code":"CREDENTIAL_UNAVAILABLE", "storage_error":error != OK})
		return {"ok":false, "code":"CREDENTIAL_UNAVAILABLE", "storage_error":error != OK}
	return await perform("auto_login", _defaults.server, {"username":_defaults.username, "token":stored.token}, true)

func cancel() -> void:
	_generation += 1
	_api.cancel()

func logout() -> Error:
	cancel()
	_session.clear()
	_defaults.remember = false
	var removed: Error = _store.forget(_defaults.server, _defaults.username)
	var saved := _write_settings()
	changed.emit({"phase":"signed_out", "code":"LOGGED_OUT", "storage_error":removed != OK or saved != OK})
	return removed if removed != OK else saved

func get_login_defaults() -> Dictionary:
	return _defaults.duplicate(true)

func get_session() -> Dictionary:
	return _session.duplicate(true)

func _write_settings() -> Error:
	var file := FileAccess.open(_settings_path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(_defaults))
	file.flush()
	var written := file.get_error()
	file.close()
	var result := DirAccess.rename_absolute(_settings_path + ".tmp", _settings_path) if written == OK else written
	if result != OK:
		DirAccess.remove_absolute(_settings_path + ".tmp")
	return result

func _exit_tree() -> void:
	cancel()
