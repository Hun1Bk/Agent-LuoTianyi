extends SceneTree
const Cache = preload("res://src/storage/audio_cache.gd")
const Samples = preload("res://tests/support/audio_samples.gd")
var failures: Array[String] = []
func check(value: bool, description: String) -> void:
	if not value:
		failures.append(description)
		print("FAIL: ",description)

func _initialize() -> void:
	var root := "user://cache-test-%s" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(root)
	var cache := Cache.new(root)
	check(cache.set_scope("https://TEST.invalid:443/", "A") == OK, "valid scope created")
	var bytes := Samples.tone(.08)
	var decoder = ClassDB.instantiate("PcmStreamDecoder")
	decoder.append(bytes)
	var status: Dictionary = decoder.finish()
	var waveform := PackedFloat32Array()
	waveform.resize(24)
	waveform.fill(.2)
	check(cache.begin("one") == OK, "cache begins")
	check(cache.append("one",bytes.slice(0,17)) == OK and cache.append("one",bytes.slice(17)) == OK, "cache stores split stream")
	check(cache.lookup("one").is_empty(), "partial stream invisible")
	check(cache.commit("one",status,waveform) == OK, "validated stream committed")
	var restored := Cache.new(root)
	restored.set_scope("https://test.invalid", "A")
	var entry := restored.lookup("one")
	check(not entry.is_empty(), "cache persists across instances and normalized server")
	if not entry.is_empty():
		check(FileAccess.get_file_as_bytes(entry.path) == bytes, "original bytes preserved")
		check(is_equal_approx(entry.duration,.08) and entry.waveform.size() == 24, "duration and waveform restored")
	check(restored.begin("one") == ERR_ALREADY_EXISTS, "complete file never overwritten")
	cache.begin("partial")
	cache.append("partial",bytes)
	cache.abort_all()
	check(cache.lookup("partial").is_empty(), "aborted stream not published")
	cache.begin("invalid")
	cache.append("invalid",bytes)
	var broken := status.duplicate()
	broken.finished = false
	check(cache.commit("invalid",broken,waveform) != OK and cache.lookup("invalid").is_empty(), "unfinished decoder cannot commit")
	cache.begin("truthy")
	cache.append("truthy",bytes)
	broken = status.duplicate()
	broken.finished = "false"
	check(cache.commit("truthy",broken,waveform) != OK and cache.lookup("truthy").is_empty(), "nonboolean finished state rejected")
	restored.set_scope("https://test.invalid", "B")
	check(restored.lookup("one").is_empty(), "account isolation")
	restored.begin("one")
	restored.append("one",bytes)
	restored.commit("one",status,waveform)
	check(cache.clear() == OK and cache.lookup("one").is_empty() and not restored.lookup("one").is_empty(), "manual clear only current account")
	restored.set_scope("https://other.invalid", "B")
	check(restored.lookup("one").is_empty(), "server isolation")
	restored.set_scope("https://test.invalid", "B")
	entry = restored.lookup("one")
	if not entry.is_empty():
		var file := FileAccess.open(entry.path,FileAccess.WRITE)
		file.store_8(0)
		file.close()
		check(restored.lookup("one").is_empty(), "truncated cache not exposed")
	var obstacle := root + "/obstacle"
	if DirAccess.dir_exists_absolute(root):
		var file := FileAccess.open(obstacle,FileAccess.WRITE)
		file.close()
		var unwritable := Cache.new(obstacle + "/child")
		check(unwritable.set_scope("https://test.invalid","A") != OK and unwritable.begin("x") != OK, "unwritable scope reports failure")
		DirAccess.remove_absolute(obstacle)
	restored.clear()
	cache.abort_all()
	# Test owns this temporary root; remove only files/directories it generated.
	for folder in DirAccess.get_directories_at(root):
		for file in DirAccess.get_files_at(root.path_join(folder)):
			DirAccess.remove_absolute(root.path_join(folder).path_join(file))
		DirAccess.remove_absolute(root.path_join(folder))
	DirAccess.remove_absolute(root)
	print("Audio cache: ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
