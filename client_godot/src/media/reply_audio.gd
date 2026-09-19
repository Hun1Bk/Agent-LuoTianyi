extends Node
signal receive_finished(id: String, code: String)
signal playback_finished(id: String, code: String)
signal mouth_changed(value: float)
signal state_changed(state: Dictionary)

var _logger: RefCounted
var _streams: Dictionary = {}
var _completed: Dictionary = {}
var _clock: Callable
var _active := ""
var _player := AudioStreamPlayer.new()
var _playback: AudioStreamGeneratorPlayback
var _capacity := 0
var _pushed := 0
var _drain_at := 0
var _volume := 1.0
var _skips := 0
var _invalid_base64 := RegEx.new()

func _init(logger: RefCounted = null, clock: Callable = Callable()) -> void:
	_logger = logger
	_clock = clock if clock.is_valid() else Time.get_ticks_msec
	process_mode = Node.PROCESS_MODE_ALWAYS
	_invalid_base64.compile("^[A-Za-z0-9+/]*={0,2}$")
	add_child(_player)

func append_reply_audio(id: String, encoded: String, final: bool, audio_error: bool = false) -> void:
	if _completed.has(id):
		return
	if not _streams.has(id):
		if _streams.size() >= 16:
			_completed[id] = true
			_log("audio_error", id, {"code":"BUFFER_LIMIT"})
			_log("audio_receive_finished", id, {"code":"BUFFER_LIMIT"})
			_log("audio_playback_finished", id, {"code":"BUFFER_LIMIT"})
			receive_finished.emit(id, "BUFFER_LIMIT")
			playback_finished.emit(id, "BUFFER_LIMIT")
			return
		_streams[id] = {"decoder":null, "final":false, "code":"", "stopped":false,
			"updated":_clock.call(), "format_logged":false}
	var item: Dictionary = _streams[id]
	if item.final:
		return
	item.updated = _clock.call()
	if audio_error:
		_fail(id, "AUDIO_ERROR")
		return
	if not encoded.is_empty() and not item.stopped:
		if encoded.length() > 12 * 1024 * 1024 or encoded.length() % 4 != 0 or _invalid_base64.search(encoded) == null:
			_fail(id, "INVALID_BASE64")
			return
		var bytes := Marshalls.base64_to_raw(encoded)
		if bytes.is_empty() or Marshalls.raw_to_base64(bytes) != encoded:
			_fail(id, "INVALID_BASE64")
			return
		_log("audio_received", id, {"bytes":bytes.size()})
		if item.decoder == null:
			if not ClassDB.class_exists("PcmStreamDecoder"):
				_fail(id, "DECODER_UNAVAILABLE")
				return
			item.decoder = ClassDB.instantiate("PcmStreamDecoder")
		var status: Dictionary = item.decoder.append(bytes)
		if not status.ok:
			_fail(id, status.code)
			return
		if status.sample_rate > 0 and not item.format_logged:
			_log("audio_format", id, status)
			item.format_logged = true
		_log("audio_decoded", id, {"frames":status.decoded_frames, "queued":status.queued_frames})
		var queued_frames := 0
		for other in _streams.values():
			if other.decoder != null:
				queued_frames += int(other.decoder.get_status().queued_frames)
		if queued_frames > 128 * 1024 * 1024 / 8:
			_fail(id, "BUFFER_LIMIT")
			return
	if final:
		if item.decoder != null:
			var status: Dictionary = item.decoder.finish()
			if not status.ok:
				_fail(id, status.code)
				return
		_end_receive(id)

func play_reply(id: String) -> void:
	if _active.is_empty() and _streams.has(id):
		_active = id
		state_changed.emit(get_state())

func get_state() -> Dictionary:
	return {"active_id":_active, "playing":_player.playing, "queued":_streams.size(), "volume":_volume}

func set_volume(value: float) -> void:
	if not is_finite(value):
		return
	_volume = clampf(value, 0, 1)
	_player.volume_linear = _volume
	state_changed.emit(get_state())

func stop_current() -> void:
	if _streams.has(_active):
		var item: Dictionary = _streams[_active]
		item.stopped = true
		if item.code.is_empty():
			item.code = "STOPPED"
		item.decoder = null
		_stop_player()

func reset() -> void:
	for id in _streams:
		_log("audio_playback_finished", id, {"code":"INTERRUPTED"})
	_streams.clear()
	_completed.clear()
	_active = ""
	_stop_player()

func _log(event: String, id: String, fields: Dictionary = {}) -> void:
	if _logger != null:
		fields["reply_id"] = id
		_logger.record(event, fields)

func _end_receive(id: String) -> void:
	var item: Dictionary = _streams[id]
	if not item.final:
		item.final = true
		_log("audio_receive_finished", id, {"code":item.code})
		receive_finished.emit(id, item.code)

func _fail(id: String, code: String) -> void:
	var item: Dictionary = _streams[id]
	item.code = code
	item.decoder = null
	_log("audio_error", id, {"code":code})
	_end_receive(id)
	if id == _active:
		_stop_player()

func _stop_player() -> void:
	_player.stop()
	_playback = null
	_pushed = 0
	_drain_at = 0
	mouth_changed.emit(-1.0)
	state_changed.emit(get_state())

func _complete() -> void:
	var id := _active
	var code: String = _streams[id].code
	_completed[id] = true
	_streams.erase(id)
	_active = ""
	_stop_player()
	_log("audio_playback_finished", id, {"code":code})
	playback_finished.emit(id, code)

func _process(_delta: float) -> void:
	var now: int = _clock.call()
	for id in _streams.keys():
		if not _streams[id].final and now - int(_streams[id].updated) >= 60000:
			_fail(id, "AUDIO_TIMEOUT")
	if not _streams.has(_active):
		return
	var item: Dictionary = _streams[_active]
	if item.decoder == null:
		if item.final:
			_complete()
		return
	var status: Dictionary = item.decoder.get_status()
	if _playback == null:
		if status.sample_rate == 0 or status.queued_frames == 0 or (not item.final and status.queued_frames < status.sample_rate * .08):
			return
		var generator := AudioStreamGenerator.new()
		generator.mix_rate = status.sample_rate
		generator.buffer_length = .25
		_player.stream = generator
		_player.play()
		_playback = _player.get_stream_playback()
		_capacity = _playback.get_frames_available()
		_pushed = 0
		_skips = _playback.get_skips()
		_log("audio_playback_started", _active, {"sample_rate":status.sample_rate, "volume":_volume,
			"latency_ms":AudioServer.get_output_latency() * 1000})
		state_changed.emit(get_state())
	var available := _playback.get_frames_available()
	var buffered := _capacity - available
	var heard := _pushed - buffered - int(AudioServer.get_output_latency() * status.sample_rate)
	mouth_changed.emit(clampf(item.decoder.get_amplitude(heard) * 3.0, 0, 1))
	var skips := _playback.get_skips()
	if skips > _skips and not item.final:
		_log("audio_underrun", _active, {"skips":skips - _skips})
	_skips = skips
	var count := mini(available, mini(int(status.queued_frames), 16384))
	if count > 0:
		var frames: PackedVector2Array = item.decoder.read_frames(count)
		if not _playback.push_buffer(frames):
			_fail(_active, "PLAYBACK_FAILED")
			return
		_pushed += frames.size()
		_drain_at = 0
	elif item.final and buffered == 0:
		if _drain_at == 0:
			_drain_at = now + ceili((AudioServer.get_output_latency() + AudioServer.get_time_to_next_mix()) * 1000) + 10
		elif now >= _drain_at:
			_complete()

func _exit_tree() -> void:
	reset()
