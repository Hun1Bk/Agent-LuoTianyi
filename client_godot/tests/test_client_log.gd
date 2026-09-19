extends SceneTree
const Log = preload("res://src/storage/client_log.gd")
var failures: Array[String] = []
func check(value: bool, description: String) -> void:
	if not value:
		failures.append(description)
		print("FAIL: ", description)
func _initialize() -> void:
	var directory := "user://log-test-%s" % Time.get_ticks_usec()
	var log = Log.new(directory, 4096)
	check(log.record("reply_received", {"reply_id":"synthetic-uuid", "has_audio":true, "audio_chars":128,
		"final":false, "token":"SECRET-TOKEN", "audio":"SECRET-AUDIO", "text":"SECRET-TEXT", "code":"bad secret code"}) == OK, "diagnostic record written")
	var file := directory + "/client.jsonl"
	check(FileAccess.file_exists(file), "log file exists")
	if FileAccess.file_exists(file):
		var contents := FileAccess.get_file_as_string(file)
		var entry: Dictionary = JSON.parse_string(contents.strip_edges())
		check(entry.get("has_audio") == true and entry.get("audio_chars") == 128, "audio receipt metadata retained")
		check(entry.get("reply_id") == "synthetic-uuid".sha256_text().left(12), "reply correlation is hashed")
		check(not contents.contains("SECRET") and not contents.contains("bad secret code"), "unapproved fields and raw error text excluded")
		check(entry.has("time") and entry.has("elapsed_ms"), "timestamps recorded")
	for index in range(120):
		log.record("audio_decoded", {"frames":index, "bytes":48000, "sample_rate":24000})
	check(FileAccess.file_exists(directory + "/client.1.jsonl") and FileAccess.file_exists(directory + "/client.2.jsonl"), "log rotation is bounded")
	var bad = Log.new(file + "/impossible")
	check(bad.record("test") != OK, "write failure reported")
	for path in ["client.jsonl", "client.1.jsonl", "client.2.jsonl"]:
		DirAccess.remove_absolute(directory + "/" + path)
	DirAccess.remove_absolute(directory)
	print("Client diagnostics: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
