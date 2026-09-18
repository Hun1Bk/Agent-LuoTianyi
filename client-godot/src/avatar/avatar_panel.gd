extends Control
## View owns pointer gestures; framing owns the persisted transform.
const Driver = preload("res://src/avatar/avatar_driver.gd")
const Framing = preload("res://src/avatar/avatar_framing.gd")
const SETTINGS := "user://avatar_framing.cfg"
var avatar = Driver.new()
var framing = Framing.new()
var _dragging := false
var _error_label := Label.new()


func _ready() -> void:
	clip_contents = true
	var background := TextureRect.new()
	background.texture = load("res://assets/ui/bg2.jpg")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil := ColorRect.new()
	veil.color = Color(0.96, 0.98, 1.0, 0.18)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(avatar)
	add_child(_error_label)
	_error_label.position = Vector2(20, 80)
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if avatar.load_avatar("res://assets/live2d/luo/model.model3.json") != OK:
		_error_label.text = "角色加载失败，请检查资源是否完整。"
		return
	var restored: Error = framing.load_settings(SETTINGS)
	if restored != OK and restored != ERR_FILE_NOT_FOUND:
		_error_label.text = "未能恢复角色位置，已使用默认构图。"
	resized.connect(_layout_avatar)
	_layout_avatar()
	gui_input.connect(_handle_pointer)
	var reset_button := Button.new()
	reset_button.text = "重置位置"
	reset_button.tooltip_text = "滚轮缩放 · 右键拖动"
	add_child(reset_button)
	reset_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	reset_button.position = Vector2(18, size.y - 50)
	reset_button.pressed.connect(func():
		framing.reset()
		_layout_avatar()
		_save())
	resized.connect(func(): reset_button.position = Vector2(18, size.y - 50))


func _layout_avatar() -> void:
	if avatar.get_status().loaded:
		avatar.transform = framing.get_transform(size, avatar.get_status().canvas_size)
	_error_label.size.x = maxf(0, size.x - 40)


func _handle_pointer(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
			if not _dragging:
				_save()
			accept_event()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			framing.zoom_by(1.1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.1)
			_layout_avatar()
			_save()
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_dragging = false
			_save()
			return
		framing.pan_by(event.relative, size)
		_layout_avatar()
		accept_event()


func _save() -> void:
	if framing.save_settings(SETTINGS) != OK:
		_error_label.text = "当前角色位置无法保存，重启后将恢复上次设置。"


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and _dragging:
		_dragging = false
		_save()


func _process(_delta: float) -> void:
	var minimized := get_window().mode == Window.MODE_MINIMIZED
	avatar.visible = not minimized
	avatar.process_mode = Node.PROCESS_MODE_DISABLED if minimized else Node.PROCESS_MODE_INHERIT
