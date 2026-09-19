extends SceneTree
const Transport = preload("res://src/network/websocket_transport.gd")
const Session = preload("res://src/session/chat_session.gd")
const View = preload("res://src/ui/chat_view.gd")
const Log = preload("res://src/storage/client_log.gd")
var failures: Array[String] = []
var capture := AudioEffectCapture.new()
var peak := 0.0
var expressions: Array[String] = []
var mouth := -1.0
var mouth_max := 0.0

func check(value: bool, description: String) -> void:
	if not value:
		failures.append(description)
		print("FAIL: ", description)

func until(predicate: Callable, timeout: int = 2500) -> bool:
	var deadline := Time.get_ticks_msec() + timeout
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame
		for sample in capture.get_buffer(capture.get_frames_available()):
			peak = maxf(peak, absf(sample.x))
	return predicate.call()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	AudioServer.add_bus_effect(0,capture)
	var directory := "user://voice-chat-test-%s" % Time.get_ticks_usec()
	var session = Session.new(Transport.new(),Log.new(directory))
	root.add_child(session)
	session.expression_requested.connect(func(value): expressions.append(value))
	session.mouth_changed.connect(func(value): mouth = value; mouth_max = maxf(mouth_max,value))
	session.start({"server":OS.get_environment("GODOT_TEST_SERVER") + "/prefix", "username":"audio", "message_token":"message-test"})
	check(await until(func(): return session.get_state().phase == "ready"), "loopback voice connection authenticates")
	session.send_text("stream")
	check(await until(func(): return session.get_state().get("speaking",false)), "received WAV reaches actual playing state")
	check(session.get_messages().size() == 2 and expressions == ["微笑脸"], "later text and expression wait for preceding sound")
	check(await until(func(): return session.get_messages().size() == 3 and session.get_audio_state().queued == 0), "both replies finish in order")
	check(peak > .05 and expressions == ["微笑脸","normal"], "real network audio reaches mixer")
	check(mouth_max > .05 and mouth == -1.0, "chat forwards actual mouth progress and restoration")
	peak = 0
	capture.clear_buffer()
	session.send_text("hidden")
	check(await until(func(): return session.get_state().get("speaking",false)), "hidden ephemeral voice still plays")
	check(await until(func(): return session.get_audio_state().queued == 0), "hidden reply finishes")
	check(peak > .05 and session.get_messages().size() == 4, "hidden audio has output without bubble")
	session.send_text("bad")
	check(await until(func(): return session.get_state().code == "AUDIO_ERROR"), "decode failure reported to UI")
	check(session.get_messages().any(func(message): return message.text == "voice-bad"), "malformed audio preserves text")
	var view := View.new(session)
	root.add_child(view)
	await process_frame
	var sliders := view.find_children("*", "HSlider",true,false)
	check(sliders.size() == 1, "chat exposes volume control")
	if sliders.size() == 1:
		sliders[0].value = .35
		check(is_equal_approx(session.get_audio_state().volume,.35), "volume UI calls public controller")
	session.send_text("stop")
	check(await until(func(): return session.get_state().speaking), "stop test begins real voice")
	for button in view.find_children("*", "Button",true,false):
		if button.text == "停止语音":
			button.pressed.emit()
	await process_frame
	check(not session.get_state().speaking and mouth == -1.0, "stop button silences and restores mouth")
	check(not session.get_messages().any(func(message): return message.text == "stop-next"), "stop before terminal does not advance next reply")
	session.send_text("continue")
	check(await until(func(): return session.get_messages().any(func(message): return message.text == "stop-final")), "stop still accepts final text update")
	check(await until(func(): return session.get_messages().any(func(message): return message.text == "stop-next") and session.get_audio_state().queued == 0), "next reply resumes after stopped reply terminal")
	session.send_text("disconnect")
	check(await until(func(): return session.get_state().get("speaking",false)), "unfinished stream begins")
	session.send_text("close")
	check(await until(func(): return session.get_state().phase != "ready"), "fixture disconnect observed")
	check(not session.get_state().get("speaking",false), "disconnect releases active voice")
	check(mouth == -1.0 and session.get_audio_state().queued == 0, "disconnect releases streams and mouth")
	check(session.get_messages().any(func(message): return message.text == "voice-disconnect"), "disconnect preserves displayed voice text")
	var logs := FileAccess.get_file_as_string(directory + "/client.jsonl")
	check(logs.contains("audio_playback_started") and logs.contains("audio_playback_finished") and logs.contains("audio_error"), "network to playback has diagnostic trail")
	session.stop()
	view.queue_free()
	session.queue_free()
	await process_frame
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	DirAccess.remove_absolute(directory + "/client.jsonl")
	DirAccess.remove_absolute(directory)
	print("Voice chat: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
