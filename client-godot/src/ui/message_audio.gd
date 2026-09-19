extends VBoxContainer
signal action(value: String)
const Style = preload("res://src/preview/preview_style.gd")
var _row := HBoxContainer.new()
var _play := Button.new()
var _stop := Button.new()
var _time := Label.new()
var _error := Label.new()
var _wave := Waveform.new()
var _status := "idle"

class Waveform extends Control:
	var values := PackedFloat32Array()
	var progress := 0.0
	func _draw() -> void:
		if values.is_empty():
			return
		var spacing := size.x/values.size()
		for index in values.size():
			var height := maxf(2.0,values[index]*size.y)
			var color := Style.ACCENT if float(index)/values.size() < progress else Color("9eb6c4")
			draw_line(Vector2((index+.5)*spacing,(size.y-height)/2),Vector2((index+.5)*spacing,(size.y+height)/2),color,2,true)

func _ready() -> void:
	add_child(_row)
	_row.add_theme_constant_override("separation",6)
	_play.add_theme_font_size_override("font_size",12)
	_stop.add_theme_font_size_override("font_size",12)
	_play.pressed.connect(func(): action.emit({"idle":"play","playing":"pause","paused":"resume"}[_status]))
	_row.add_child(_play)
	_wave.custom_minimum_size = Vector2(96,26)
	_wave.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(_wave)
	_time.add_theme_font_size_override("font_size",11)
	_time.add_theme_color_override("font_color",Style.INK)
	_row.add_child(_time)
	_stop.text = "停止"
	_stop.pressed.connect(func(): action.emit("stop"))
	_row.add_child(_stop)
	_error.add_theme_font_size_override("font_size",12)
	_error.text = "语音未能保存"
	add_child(_error)

func update_state(state: Dictionary) -> void:
	visible = state.available or not state.code.is_empty()
	_row.visible = state.available
	_error.visible = not state.code.is_empty()
	_error.text = "语音未能保存" if state.code == "CACHE_WRITE_FAILED" else "语音暂时无法重放"
	_status = state.status
	_play.text = {"idle":"重放","playing":"暂停","paused":"继续"}[_status]
	_play.disabled = state.blocked
	_stop.visible = _status != "idle"
	_time.text = "%.1f 秒" % state.duration if _status == "idle" else "%.1f/%.1f 秒" % [state.position,state.duration]
	_wave.values = state.waveform
	_wave.progress = state.position / state.duration if state.duration > 0 else 0.0
	_wave.queue_redraw()
