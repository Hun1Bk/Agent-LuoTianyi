extends MarginContainer
signal logout_requested
const Style = preload("res://src/preview/preview_style.gd")
const Bubble = preload("res://src/preview/message_bubble.gd")
const Composer = preload("res://src/preview/composer_input.gd")
var _session: Node
var _scroll := ScrollContainer.new()
var _messages := VBoxContainer.new()
var _input = Composer.new()
var _status := Label.new()
var _latest := Button.new()
var _bubbles: Dictionary = {}
var _empty := Label.new()
var _refresh_pending := false
var _refresh_again := false
var _stop_voice: Button

func _init(session: Node) -> void:
	_session = session

func _ready() -> void:
	theme = Style.make_theme()
	for side in ["left", "right", "top", "bottom"]:
		add_theme_constant_override("margin_" + side, 22)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var title := Style.label("和天依聊聊", 23)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var logs := Style.button("打开日志", func(): OS.shell_open(_session.get_log_directory()))
	logs.disabled = _session.get_log_directory().is_empty()
	heading.add_child(logs)
	heading.add_child(Style.button("退出登录", func(): logout_requested.emit()))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 13)
	_status.add_theme_color_override("font_color", Color("607f8d"))
	column.add_child(_status)
	var audio_controls := HBoxContainer.new()
	column.add_child(audio_controls)
	audio_controls.add_child(Style.label("语音音量", 12))
	var volume := HSlider.new()
	volume.min_value = 0
	volume.max_value = 1
	volume.step = .01
	volume.value = _session.get_audio_state().volume
	volume.custom_minimum_size.x = 110
	volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume.tooltip_text = "回复语音自动播放；拖到最左侧静音"
	volume.value_changed.connect(func(value): _session.set_volume(value))
	audio_controls.add_child(volume)
	_stop_voice = Style.button("停止语音", func(): _session.stop_voice())
	audio_controls.add_child(_stop_voice)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_messages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_messages.add_theme_constant_override("separation", 17)
	_scroll.add_child(_messages)
	_empty.text = "从一句问候开始"
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.custom_minimum_size.y = 180
	_messages.add_child(_empty)
	_latest.text = "回到最新 ↓"
	_latest.hide()
	_latest.pressed.connect(_to_latest)
	column.add_child(_latest)
	_input.placeholder_text = "想说些什么？"
	_input.custom_minimum_size.y = 92
	_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	column.add_child(_input)
	_input.send_requested.connect(_send)
	_input.text_changed.connect(func():
		var lines: int = _input.get_line_count()
		for line in _input.get_line_count():
			lines += _input.get_line_wrap_count(line)
		_input.custom_minimum_size.y = clampf(lines * 24 + 30, 92, 150))
	var footer := HBoxContainer.new()
	column.add_child(footer)
	var hint := Style.label("Enter 发送 · Shift + Enter 换行", 11, Color("94a5af"))
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(hint)
	var send := Style.button("发送  ↑", _send)
	send.custom_minimum_size.x = 96
	send.add_theme_stylebox_override("normal", Style.box(Color("bde5ed"), 9, 10))
	footer.add_child(send)
	_session.changed.connect(_refresh)
	_session.state_changed.connect(_state_changed)
	_state_changed(_session.get_state())
	_refresh()

func _send() -> void:
	if not _session.send_text(_input.text).is_empty():
		_input.clear()

func _refresh() -> void:
	if _refresh_pending:
		_refresh_again = true
		return
	_refresh_pending = true
	_refresh_messages.call_deferred()

func _refresh_messages() -> void:
	var bar := _scroll.get_v_scroll_bar()
	var follow := bar.value >= bar.max_value - bar.page - 24
	var previous := bar.value
	var messages: Array[Dictionary] = _session.get_messages()
	_empty.visible = messages.is_empty()
	var current_ids: Dictionary = {}
	for message in messages:
		current_ids[message.id] = true
	for id in _bubbles.keys():
		if not current_ids.has(id):
			var bubble: Node = _bubbles[id]
			_messages.remove_child(bubble)
			bubble.queue_free()
			_bubbles.erase(id)
	for message in messages:
		if _bubbles.has(message.id):
			_bubbles[message.id].update_message(message)
		else:
			var bubble := Bubble.new()
			_messages.add_child(bubble)
			bubble.configure(message)
			_bubbles[message.id] = bubble
	await get_tree().process_frame
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	# Do not override a scroll gesture made while the containers were laying out.
	if is_equal_approx(bar.value, previous):
		if follow:
			_to_latest()
		else:
			_scroll.scroll_vertical = roundi(previous)
			_latest.visible = true
	_refresh_pending = false
	if _refresh_again:
		_refresh_again = false
		_refresh()

func _to_latest() -> void:
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)
	_latest.hide()

func _state_changed(state: Dictionary) -> void:
	_status.text = {"idle":"连接已关闭", "connecting":"正在连接…", "authenticating":"正在验证账户…",
		"ready":"已连接", "reconnecting":"正在重新连接 · 可以继续输入", "auth_rejected":"聊天凭据已失效，请退出后重新登录。"}.get(state.phase, "")
	if state.thinking:
		_status.text = "天依正在想一想…"
	if state.get("speaking", false):
		_status.text += " · 正在播放语音"
	_stop_voice.disabled = not state.get("speaking", false)
	if state.code == "AUDIO_ERROR":
		_status.text += " · 本条语音暂时无法播放，文字已保留。"
	elif state.code == "SEND_REJECTED":
		_status.text += " · 暂时无法发送，内容已保留。"
	elif state.code == "INVALID_RESPONSE":
		_status.text += " · 收到的数据不完整。"
	elif state.phase == "ready" and not state.code.is_empty():
		_status.text += " · 服务器暂时无法处理请求，请稍后重试。"
