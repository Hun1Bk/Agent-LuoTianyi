extends Window
const Style = preload("res://src/preview/preview_style.gd")
var _logger: RefCounted
var _runs := preload("res://src/ui/unified_dropdown.gd").new()
var _search := LineEdit.new()
var _module := preload("res://src/ui/unified_dropdown.gd").new()
var _level := preload("res://src/ui/unified_dropdown.gd").new()
var _follow := CheckBox.new()
var _text := RichTextLabel.new()
var _status := Label.new()
var _picker := FileDialog.new()
var _selected := ""
var _export_id := ""

func _init(logger: RefCounted) -> void:
	_logger = logger
	title = "客户端日志 · " + preload("res://src/release_info.gd").title()
	size = Vector2i(960,620)
	min_size = Vector2i(660,400)
	visible = false
	transient = false

func _ready() -> void:
	theme = Style.make_theme()
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel",Style.box(Color("111923"),0,14))
	add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var filters := HBoxContainer.new()
	column.add_child(filters)
	_runs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filters.add_child(_runs)
	_runs.activated.connect(func(index):
		_selected = index
		_refresh())
	_level.set_items([{"id":"all","label":"全部级别"},{"id":"INFO","label":"INFO"},{"id":"WARN","label":"WARN"},{"id":"ERROR","label":"ERROR"}])
	filters.add_child(_level)
	var modules: Array = [{"id":"all","label":"全部模块"}]
	for module in _logger.MODULES:
		modules.append({"id":module,"label":module})
	_module.set_items(modules)
	filters.add_child(_module)
	_level.activated.connect(func(_index): _refresh())
	_module.activated.connect(func(_index): _refresh())
	_search.placeholder_text = "搜索时间、活动或错误码"
	_search.text_changed.connect(func(_value): _refresh())
	column.add_child(_search)
	_text.selection_enabled = true
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_color_override("default_color",Color("d6e5ee"))
	_text.add_theme_font_size_override("normal_font_size",14)
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Cascadia Mono","Consolas","Microsoft YaHei UI"])
	_text.add_theme_font_override("normal_font",mono)
	column.add_child(_text)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	_follow.text = "跟随最新"
	_follow.add_theme_color_override("font_color",Color("d6e5ee"))
	_follow.button_pressed = true
	_follow.toggled.connect(func(value):
		_text.scroll_following = value
		if value:
			_text.scroll_to_line(maxi(0,_text.get_line_count()-1)))
	_text.scroll_following = true
	actions.add_child(_follow)
	actions.add_child(Style.button("复制显示记录",func(): DisplayServer.clipboard_set(_text.get_parsed_text())))
	actions.add_child(Style.button("导出完整诊断 ZIP",func():
		_export_id = _selected
		_picker.current_file = "agentluo-diagnostics-" + _selected + ".zip"
		_picker.popup_centered_ratio(.7)))
	_status.add_theme_color_override("font_color",Color("ffd58a"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	_picker.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_picker.access = FileDialog.ACCESS_FILESYSTEM
	_picker.filters = PackedStringArray(["*.zip ; ZIP 诊断包"])
	_picker.use_native_dialog = true
	add_child(_picker)
	_picker.file_selected.connect(func(path):
		var error: Error = _logger.export_run(_export_id,path)
		_status.text = "所选启动的完整诊断已导出（未上传）。" if error == OK else "导出失败（%s），请选择尚不存在且可写的文件。" % error)
	close_requested.connect(hide)
	_logger.entry_added.connect(func(entry):
		if visible and _selected == _logger.get_run_id() and _matches(entry):
			_append(entry))
	_logger.write_failed.connect(func(_error): _status.text = "日志写盘失败，当前窗口仍可查看内存记录；归档可能不完整。")

func open() -> void:
	var options: Array = []
	_selected = _logger.get_run_id() if _selected.is_empty() else _selected
	var runs: Array = _logger.list_runs()
	if not runs.any(func(run): return run.id == _logger.get_run_id()):
		runs.push_front({"id":_logger.get_run_id(),"started":"本次启动（未能保存）","closed":false,"active":true,"complete":false})
	for run in runs:
		var caption: String = run.started
		if run.id == _logger.get_run_id():
			caption += " · 本次启动"
		elif not run.closed:
			caption += " · 运行中" if run.active else " · 未正常结束"
		options.append({"id":run.id,"label":caption})
	_runs.set_items(options)
	_runs.set_selected_id(_selected)
	_selected = _runs.get_selected_id()
	_refresh()
	show()
	grab_focus()

func _refresh() -> void:
	_text.clear()
	var entries: Array = _logger.read_entries(_selected)
	for entry in entries:
		if _matches(entry):
			_append(entry)
	_status.text = "共 %s 条记录；筛选只影响显示，导出包含整次启动。" % entries.size()
	for run in _logger.list_runs():
		if run.id == _selected and not run.complete:
			_status.text += " 此次归档不完整。"

func _matches(entry: Dictionary) -> bool:
	return (_level.get_selected_id() == "all" or entry.level == _level.get_selected_id()) and (_module.get_selected_id() == "all" or entry.module == _module.get_selected_id()) and (_search.text.is_empty() or JSON.stringify(entry).to_lower().contains(_search.text.to_lower()))

func _append(entry: Dictionary) -> void:
	_text.push_color({"INFO":Color("d6e5ee"),"WARN":Color("ffd58a"),"ERROR":Color("ff8c8c")}[entry.level])
	var metrics := entry.duplicate()
	for key in ["time","level","module","message","event"]:
		metrics.erase(key)
	_text.add_text("%s [%s] [%s] %s · %s %s\n" % [entry.time,entry.level,entry.module,entry.message,entry.event,JSON.stringify(metrics)])
	_text.pop()
