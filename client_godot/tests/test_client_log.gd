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
	log.record("client_started")
	check(log.has_method("read_entries"), "startup records remain queryable from launch")
	if not log.has_method("read_entries"):
		DirAccess.remove_absolute(directory + "/client.jsonl")
		DirAccess.remove_absolute(directory)
		quit(1)
		return
	for index in range(120):
		check(log.record("reply_received", {"reply_id":"synthetic-uuid", "frames":index,
			"has_audio":true,"token":"SECRET-TOKEN", "text":"SECRET-TEXT", "code":"bad secret code"}) == OK, "record written")
	var entries: Array = log.read_entries()
	check(entries.size() == 121 and entries[0].event == "client_started", "no truncation of launch records")
	var raw := JSON.stringify(entries)
	check(not raw.contains("SECRET") and not raw.contains("bad secret code"), "secrets excluded")
	check(entries[1].reply_id == "synthetic-uuid".sha256_text().left(12), "correlation hashed")
	check(entries[1].has_audio and entries[1].has("module") and entries[1].has("level"), "terminal metadata present")
	log.record("system_error", {"code":"SECRET_TOKEN", "phase":"SECRET_ACCOUNT"})
	check(not JSON.stringify(log.read_entries()).contains("SECRET"), "code-shaped secrets are not logged")
	var id: String = log.get_run_id()
	log.finish()
	log.finish()
	check(log.read_entries().size() == 123, "finish is idempotent")
	check(log.record("after_finish") != OK, "closed run immutable")
	var observer = Log.new(directory)
	check(observer.read_entries(id).size() == 123, "complete run recovered across instances")
	var zip_path := directory + "/diagnostic.zip"
	check(observer.export_run(id, zip_path) == OK, "export whole selected startup")
	var zip := ZIPReader.new()
	check(zip.open(zip_path) == OK, "export is valid ZIP")
	check(zip.get_files().size() == 3, "only diagnostic entries included")
	for name in zip.get_files():
		check(not zip.read_file(name).get_string_from_utf8().contains("SECRET"), "all ZIP entries sanitized")
	check(zip.read_file("events.jsonl").get_string_from_utf8().contains("client_started"), "export retains beginning")
	check(zip.read_file("readable.txt").get_string_from_utf8().contains("客户端启动"), "readable Chinese explanation")
	zip.close()
	check(observer.export_run(id, zip_path) != OK, "export does not overwrite")
	observer.record("client_started")
	var active: String = observer.get_run_id()
	for index in range(53):
		var run = Log.new(directory)
		run.record("client_started")
		run.finish()
	var runs: Array = observer.list_runs()
	check(runs.size() == 50, "50 startup retention")
	check(not observer.read_entries(active).is_empty(), "another active instance protected")
	check(observer.read_entries(id).is_empty(), "old finished run evicted whole")
	check(observer.read_entries("../diagnostic").is_empty(), "path traversal rejected")
	observer.finish()
	var bad = Log.new(zip_path + "/impossible")
	check(bad.record("client_started") != OK, "write failure surfaced")
	check(bad.read_entries().size() == 1, "failed disk write retained for current viewer")
	for file in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("Client startup diagnostics: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
