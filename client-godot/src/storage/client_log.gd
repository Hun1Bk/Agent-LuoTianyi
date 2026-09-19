extends RefCounted
const METRICS := ["has_audio", "audio_chars", "bytes", "frames", "sample_rate", "channels", "bits", "final", "audio_error", "queued", "volume", "latency_ms", "skips"]
var _directory: String
var _max_bytes: int
var _token := RegEx.new()

func _init(directory: String = "user://logs", max_bytes: int = 2097152) -> void:
	_directory = directory
	_max_bytes = maxi(4096, max_bytes)
	_token.compile("^[a-zA-Z0-9_]{1,64}$")

func record(event: String, fields: Dictionary = {}) -> Error:
	if _token.search(event) == null:
		return ERR_INVALID_PARAMETER
	var entry := {"time":Time.get_datetime_string_from_system(true) + "Z", "elapsed_ms":Time.get_ticks_msec(), "event":event}
	for key in METRICS:
		var value: Variant = fields.get(key)
		if value is bool or value is int or (value is float and is_finite(value)):
			entry[key] = value
	for key in ["phase", "code"]:
		if fields.get(key) is String and _token.search(fields[key]) != null:
			entry[key] = fields[key]
	if fields.get("reply_id") is String:
		entry.reply_id = fields.reply_id.sha256_text().left(12)
	var line := JSON.stringify(entry) + "\n"
	if line.to_utf8_buffer().size() > 4096:
		return ERR_OUT_OF_MEMORY
	var ancestor := _directory
	while not ancestor.is_empty():
		if FileAccess.file_exists(ancestor):
			return ERR_CANT_CREATE
		var parent := ancestor.get_base_dir()
		if parent == ancestor:
			break
		ancestor = parent
	var error := DirAccess.make_dir_recursive_absolute(_directory)
	if error != OK:
		return error
	var path := _directory.path_join("client.jsonl")
	if FileAccess.file_exists(path):
		var existing := FileAccess.open(path, FileAccess.READ)
		if existing == null:
			return FileAccess.get_open_error()
		var size := existing.get_length()
		existing.close()
		if size + line.to_utf8_buffer().size() > _max_bytes:
			for index in [2, 1]:
				var target := _directory.path_join("client.%s.jsonl" % index)
				if FileAccess.file_exists(target):
					error = DirAccess.remove_absolute(target)
					if error != OK:
						return error
				var source := path if index == 1 else _directory.path_join("client.1.jsonl")
				if FileAccess.file_exists(source):
					error = DirAccess.rename_absolute(source, target)
					if error != OK:
						return error
	var file := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.seek_end()
	file.store_string(line)
	file.flush()
	error = file.get_error()
	file.close()
	return error

func get_directory() -> String:
	return ProjectSettings.globalize_path(_directory)
