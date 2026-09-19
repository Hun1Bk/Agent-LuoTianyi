extends "res://src/ui/draft_window.gd"
var _controller: Node
var _fields: Dictionary = {}
var _status := Label.new()
var _save := Button.new()
var _reload := Button.new()
var _refreshing := false
var _presets: Array[Button] = []
func _init(controller: Node) -> void:
	_controller = controller
	title = "相处模式"
	size = Vector2i(600,620)
	min_size = Vector2i(480,520)
func _ready() -> void:
	super._ready()
	add_child(_controller)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,22)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	margin.add_child(column)
	column.add_child(Style.label("和天依相处的方式",22))
	for pair in [["relationship","关系"],["speaking_style","表达风格"],["personality_text","性格关键词"],["custom_context","补充上下文"]]:
		column.add_child(Style.label(pair[1],14))
		if pair[0] in ["relationship","speaking_style"]:
			var row := HBoxContainer.new()
			column.add_child(row)
			var input := LineEdit.new()
			input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			input.placeholder_text = pair[1]+"（可自定义）"
			_fields[pair[0]] = input
			row.add_child(input)
			input.text_changed.connect(func(_text): _edit())
			var presets := preload("res://src/ui/unified_dropdown.gd").new()
			_presets.append(presets)
			var values: Dictionary = {"friend":"朋友","confidant":"知己","idol":"偶像","partner":"搭档","family":"家人"} if pair[0] == "relationship" else {"lively":"活泼可爱","gentle":"温柔可人","quiet":"文静恬淡"}
			var options: Array = [{"id":"custom","label":"自定义"}]
			for id in values:
				options.append({"id":id,"label":values[id]})
			presets.set_items(options)
			presets.set_meta("field",pair[0])
			presets.set_meta("values",values)
			row.add_child(presets)
			presets.activated.connect(func(id):
				if id != "custom":
					input.text = values[id]
					_edit())
		else:
			var input := TextEdit.new()
			input.placeholder_text = "用逗号、顿号或换行分隔" if pair[0] == "personality_text" else "想让天依了解的相处背景"
			input.custom_minimum_size.y = 80 if pair[0] == "personality_text" else 120
			input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
			_fields[pair[0]] = input
			column.add_child(input)
			input.text_changed.connect(_edit)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	_reload.text = "重新加载"
	_reload.pressed.connect(_controller.reload)
	actions.add_child(_reload)
	_save.text = "保存相处模式"
	Style.primary(_save)
	_save.pressed.connect(_controller.save)
	actions.add_child(_save)
	_controller.changed.connect(_update)
	_update(_controller.get_state())
func is_dirty() -> bool:
	return _controller.get_state().dirty
func _edit() -> void:
	if _refreshing:
		return
	var fields := {}
	for key in _fields:
		fields[key] = _fields[key].text
	_controller.edit(fields)
func _update(state: Dictionary) -> void:
	_refreshing = true
	for key in _fields:
		var value: String = state.fields.get(key,"")
		if _fields[key].text != value:
			_fields[key].text = value
		_fields[key].editable = state.phase == "ready"
	_refreshing = false
	for presets in _presets:
		presets.disabled = state.phase != "ready"
		var values: Dictionary = presets.get_meta("values")
		var value: String = _fields[presets.get_meta("field")].text
		presets.set_selected_id("custom")
		for id in values:
			if values[id] == value: presets.set_selected_id(id)
	_save.disabled = not state.can_save
	_reload.disabled = state.phase in ["loading","saving"] or state.dirty
	_status.text = {"idle":"", "loading":"正在读取相处偏好…", "saving":"正在合并服务器最新设置并保存…", "error":"加载失败，请重试。加载成功前不能保存。", "ready":"有未保存的修改。" if state.dirty else "已从服务器读取。"}.get(state.phase,"")
	if state.phase == "ready" and state.code != "OK":
		_status.text = "保存失败，输入已保留（%s）。"%state.code
