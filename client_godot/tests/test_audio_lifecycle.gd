extends SceneTree
const Audio = preload("res://src/media/reply_audio.gd")
const Samples = preload("res://tests/support/audio_samples.gd")
var failures: Array[String] = []
var now := 0
var received: Array[String] = []
var played: Array[String] = []
var codes: Dictionary = {}

func check(value: bool, description: String) -> void:
	if not value:
		failures.append(description)
		print("FAIL: ", description)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var audio := Audio.new(null,func(): return now)
	root.add_child(audio)
	audio.receive_finished.connect(func(id, _code): received.append(id))
	audio.playback_finished.connect(func(id, code): played.append(id); codes[id] = code)
	audio.append_reply_audio("text", "", true)
	audio.play_reply("text")
	await process_frame
	await process_frame
	audio.append_reply_audio("text", "", true)
	audio.play_reply("text")
	await process_frame
	await process_frame
	check(received.count("text") == 1 and played.count("text") == 1, "completed UUID rejects duplicate termination")
	audio.append_reply_audio("bad", "A===", true)
	audio.play_reply("bad")
	audio.stop_current()
	await process_frame
	await process_frame
	check(codes.get("bad") == "INVALID_BASE64", "stop does not overwrite decode error")
	audio.append_reply_audio("timeout", "", false)
	audio.play_reply("timeout")
	now = 60001
	await process_frame
	await process_frame
	check(codes.get("timeout") == "AUDIO_TIMEOUT", "missing continuation terminates at 60 seconds")
	audio.reset()
	for i in 16:
		audio.append_reply_audio("queue-%s" % i, "", false)
	audio.append_reply_audio("overflow", "", true)
	check(codes.get("overflow") == "BUFFER_LIMIT", "17th pending reply rejected")
	audio.append_reply_audio("queue-0", "", true)
	audio.play_reply("queue-0")
	await process_frame
	await process_frame
	audio.append_reply_audio("overflow", "", true)
	audio.play_reply("overflow")
	await process_frame
	await process_frame
	check(played.count("overflow") == 1 and received.count("overflow") == 1, "rejected UUID cannot restart after capacity frees")
	audio.reset()
	var header := Samples.tone(0)
	header.encode_u32(40,0xffffffff)
	var pcm := PackedByteArray()
	pcm.resize(2*1024*1024)
	var encoded := Marshalls.raw_to_base64(pcm)
	for i in 8:
		var id := "memory-%s" % i
		audio.append_reply_audio(id,Marshalls.raw_to_base64(header),false)
		audio.append_reply_audio(id,encoded,false)
		audio.append_reply_audio(id,encoded,false)
	audio.append_reply_audio("memory-7",encoded,false)
	check(received.has("memory-7"), "aggregate memory bound fails receiving stream")
	audio.play_reply("memory-7")
	await process_frame
	await process_frame
	check(codes.get("memory-7") == "BUFFER_LIMIT", "aggregate decoder buffers bounded across UUIDs")
	audio.reset()
	audio.queue_free()
	await process_frame
	print("Audio lifecycle: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
