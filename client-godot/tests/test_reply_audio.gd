extends SceneTree
const Audio = preload("res://src/media/reply_audio.gd")
const Samples = preload("res://tests/support/audio_samples.gd")
const Log = preload("res://src/storage/client_log.gd")
var failures: Array[String] = []
var received: Array[String] = []
var played: Array[String] = []
var codes: Dictionary = {}
var mouth := -1.0
var mouth_max := 0.0
var peak := 0.0
var capture := AudioEffectCapture.new()

func check(value: bool, description: String) -> void:
	if not value:
		failures.append(description)
		print("FAIL: ", description)

func collect() -> void:
	var buffer := capture.get_buffer(capture.get_frames_available())
	for sample in buffer:
		peak = maxf(peak, absf(sample.x))

func until(predicate: Callable, timeout: int = 2200) -> bool:
	var deadline := Time.get_ticks_msec() + timeout
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame
		collect()
	return predicate.call()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	AudioServer.add_bus_effect(0, capture)
	var directory := "user://audio-test-%s" % Time.get_ticks_usec()
	var audio := Audio.new(Log.new(directory))
	root.add_child(audio)
	audio.receive_finished.connect(func(id, _code): received.append(id))
	audio.playback_finished.connect(func(id, code): played.append(id); codes[id] = code)
	audio.mouth_changed.connect(func(value): mouth = value; mouth_max = maxf(mouth_max, value))
	var bytes := Samples.tone()
	audio.append_reply_audio("first", Marshalls.raw_to_base64(bytes.slice(0,17)), false)
	audio.play_reply("first")
	audio.append_reply_audio("first", Marshalls.raw_to_base64(bytes.slice(17,5001)), false)
	check(await until(func(): return audio.get_state().playing), "stream starts before final packet")
	audio.append_reply_audio("second", Marshalls.raw_to_base64(Samples.tone(.12,48000)), true)
	check(not played.has("second"), "later reply buffered without playback")
	audio.append_reply_audio("first", Marshalls.raw_to_base64(bytes.slice(5001)), true)
	check(received.has("first") and not played.has("first"), "reception completes before actual playback")
	check(await until(func(): return played.has("first")), "generator drains after final")
	check(peak > .05 and mouth_max > .05 and mouth == -1.0, "mixer has nonzero audio and mouth restores")
	check(codes.get("first") == "", "valid audio completes without failure")
	audio.play_reply("second")
	check(await until(func(): return played.has("second")), "different sample rate next reply plays")
	check(played == ["first", "second"], "reply order preserved")
	audio.set_volume(0)
	check(audio.get_state().volume == 0.0, "volume applied")
	peak = 0
	capture.clear_buffer()
	audio.append_reply_audio("muted", Marshalls.raw_to_base64(bytes), true)
	audio.play_reply("muted")
	check(await until(func(): return played.has("muted")), "muted playback still completes")
	check(peak < .0001, "volume zero mutes real mixer output")
	audio.set_volume(NAN)
	check(audio.get_state().volume == 0.0, "nonfinite volume ignored")
	audio.set_volume(1)
	audio.append_reply_audio("stop", Marshalls.raw_to_base64(bytes), false)
	audio.play_reply("stop")
	await until(func(): return audio.get_state().playing)
	audio.stop_current()
	audio.stop_current()
	check(not audio.get_state().playing and mouth == -1.0, "stop is immediate and restores mouth")
	audio.append_reply_audio("stop", "", true)
	check(await until(func(): return played.has("stop")) and codes.get("stop") == "STOPPED", "stopped UUID consumes terminal without restart")
	for id in ["empty", "bad", "error"]:
		audio.append_reply_audio(id, "" if id == "empty" else ("%%%" if id == "bad" else Marshalls.raw_to_base64(bytes)), true, id == "error")
		audio.play_reply(id)
		check(await until(func(): return played.has(id)), "empty or failed reply terminates")
	check(codes.get("empty") == "" and codes.get("bad") == "INVALID_BASE64" and codes.get("error") == "AUDIO_ERROR", "terminal error codes distinguish no audio")
	audio.append_reply_audio("reset", Marshalls.raw_to_base64(bytes), false)
	audio.play_reply("reset")
	audio.reset()
	audio.reset()
	check(audio.get_state().queued == 0 and not audio.get_state().playing, "reset releases unfinished streams")
	check(not played.has("reset"), "reset does not emit old account completion")
	var log_text := FileAccess.get_file_as_string(directory + "/client.jsonl") if FileAccess.file_exists(directory + "/client.jsonl") else ""
	for event in ["audio_received", "audio_format", "audio_decoded", "audio_receive_finished", "audio_playback_started", "audio_playback_finished", "INVALID_BASE64"]:
		check(log_text.contains(event), "diagnostic stage " + event)
	audio.queue_free()
	await process_frame
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	DirAccess.remove_absolute(directory + "/client.jsonl")
	DirAccess.remove_absolute(directory)
	print("Reply audio mixer: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
