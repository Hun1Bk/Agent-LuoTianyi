extends "res://src/ui/draft_window.gd"
var _settings: Node
var _types: Array = []
var _drafts := {}
var _current := ""
var _selector := OptionButton.new()
var _copy := OptionButton.new()
var _fields := {}
var _enabled := CheckBox.new()
var _json := CheckBox.new()
var _thinking := CheckBox.new()
var _params := TextEdit.new()
var _status := Label.new()
var _requirements := Label.new()
var _save_button := Button.new()
var _plain := ConfirmationDialog.new()
var _refreshing := false
var _executor: Node
var _test_button: Button
var _test_dialog: ConfirmationDialog
var _test_snapshot := {}
var _test_type := ""

func _init(settings: Node,executor: Node = null) -> void:
	_settings = settings
	_executor = executor
	title = "LLM / VLM 模型设置"
	size = Vector2i(660,780)
	min_size = Vector2i(520,600)

func _ready() -> void:
	super._ready()
	var scroll := ScrollContainer.new()
	add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",10)
	scroll.add_child(column)
	column.add_child(Style.label("每个用途独立配置，保存不会调用供应商",18))
	column.add_child(_selector)
	_selector.item_selected.connect(func(index): _select(index))
	column.add_child(_requirements)
	_requirements.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_enabled.text = "启用此用途的本地模型"
	column.add_child(_enabled)
	_enabled.toggled.connect(func(_value): _edit())
	for pair in [["provider","服务商名称"],["base_url","Base URL（例如 https://example.com/v1）"],["api_key","API Key"],["model","模型名称"]]:
		column.add_child(Style.label(pair[1],14))
		var input := LineEdit.new()
		input.name = "ModelName" if pair[0] == "model" else pair[0]
		input.secret = pair[0] == "api_key"
		_fields[pair[0]] = input
		column.add_child(input)
		input.text_changed.connect(func(_value): _edit())
	_json.text = "声明支持 JSON 输出"
	_thinking.text = "声明支持 thinking"
	for flag in [_json,_thinking]:
		column.add_child(flag)
		flag.toggled.connect(func(_value): _edit())
	column.add_child(Style.label("高级 JSON 参数（非流式）",14))
	_params.custom_minimum_size.y = 120
	_params.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_params.text_changed.connect(_edit)
	column.add_child(_params)
	var row := HBoxContainer.new()
	column.add_child(row)
	row.add_child(_copy)
	var copy_button := Button.new()
	copy_button.text = "复制该用途配置"
	row.add_child(copy_button)
	copy_button.pressed.connect(_copy_selected)
	_save_button.text = "保存当前用途"
	Style.primary(_save_button)
	column.add_child(_save_button)
	if _executor != null:
		_test_button = Button.new()
		_test_button.text = "手动测试当前配置"
		column.add_child(_test_button)
		_test_dialog = ConfirmationDialog.new()
		_test_dialog.title = "测试可能消耗供应商额度"
		_test_dialog.dialog_text = "将使用当前草稿发送一次固定短输入，不发送聊天历史。成功仅表示本次请求可用。"
		_test_dialog.cancel_button_text = "取消"
		add_child(_test_dialog)
		_test_button.pressed.connect(func():
			_test_snapshot = _config()
			_test_type = _current
			if not _test_snapshot.is_empty():
				_test_dialog.popup_centered()
				_test_dialog.get_cancel_button().grab_focus())
		_test_dialog.confirmed.connect(_test)
	_save_button.pressed.connect(func(): _save(false))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	_plain.title = "密钥保护失败"
	_plain.dialog_text = "Windows 未能保护 API Key。是否明确选择在本机以明文保存？默认取消保存。"
	_plain.ok_button_text = "明文保存"
	_plain.cancel_button_text = "取消保存"
	add_child(_plain)
	_plain.confirmed.connect(func(): _save(true))
	_settings.changed.connect(_update)
	_update(_settings.get_state())

func is_dirty() -> bool:
	for id in _drafts:
		if _drafts[id] != _as_draft(_settings.get_config(id)):
			return true
	return false

func _as_draft(config: Dictionary) -> Dictionary:
	var draft := config.duplicate(true)
	draft.params_text = JSON.stringify(config.get("params",{}),"  ")
	return draft

func _update(state: Dictionary) -> void:
	_save_button.disabled = state.phase != "ready"
	if _types.is_empty() and state.phase == "ready":
		_types = _settings.get_types()
		for type in _types:
			_selector.add_item(type.name)
			_copy.add_item(type.name)
			_drafts[type.id] = _as_draft(_settings.get_config(type.id))
		if not _types.is_empty():
			_select(0)
	if state.phase != "ready":
		_status.text = "正在获取模型用途…" if state.phase == "loading" else "无法读取模型用途（%s），可关闭后重新打开。"%state.code

func _select(index: int) -> void:
	_current = _types[index].id
	_refreshing = true
	var draft: Dictionary = _drafts[_current]
	for key in _fields:
		_fields[key].text = draft.get(key,"")
	_enabled.button_pressed = draft.enabled
	_json.button_pressed = draft.model_capabilities.can_use_json
	_thinking.button_pressed = draft.model_capabilities.can_enable_thinking
	_params.text = draft.params_text
	var type: Dictionary = _types[index]
	_requirements.text = "%s · %s\n要求：JSON %s / thinking %s"%[type.model_kind.to_upper(),type.description,"是" if type.requires_json else "否","是" if type.requires_thinking else "否"]
	_refreshing = false
	_status.text = "能力勾选是配置声明，不代表已完成全面认证。"

func _edit() -> void:
	if _refreshing or _current.is_empty():
		return
	var draft: Dictionary = _drafts[_current]
	for key in _fields:
		draft[key] = _fields[key].text
	draft.enabled = _enabled.button_pressed
	draft.model_capabilities = {"can_use_json":_json.button_pressed,"can_enable_thinking":_thinking.button_pressed}
	draft.params_text = _params.text
	_status.text = "有未保存的修改。"

func _config() -> Dictionary:
	var config: Dictionary = _drafts.get(_current,{}).duplicate(true)
	var parsed: Variant = JSON.parse_string(config.get("params_text",""))
	if not parsed is Dictionary:
		_status.text = "高级参数必须是有效 JSON 对象。"
		return {}
	config.erase("params_text")
	config.params = parsed
	return config

func _save(allow_plain: bool) -> void:
	var config := _config()
	if config.is_empty():
		return
	var result: Dictionary = _settings.save(_current,config,allow_plain)
	if result.ok:
		_drafts[_current] = _as_draft(config)
		_select(_selector.selected)
		_status.text = "已保存；后续委托使用新配置。"
	elif result.code == "PLAINTEXT_CONFIRMATION_REQUIRED":
		_plain.popup_centered()
		_plain.get_cancel_button().grab_focus()
	else:
		_status.text = "保存失败，草稿已保留（%s）。"%result.code

func _copy_selected() -> void:
	if _current.is_empty() or _copy.selected < 0:
		return
	var copied: Dictionary = _settings.copy_config(_drafts[_types[_copy.selected].id],_current)
	_drafts[_current] = copied
	_select(_selector.selected)
	_status.text = "已复制为草稿；保存时按目标用途重新校验。"

func _test() -> void:
	_test_button.disabled = true
	_status.text = "正在测试…"
	var result: Dictionary = await _executor.test_config(_test_type,_test_snapshot)
	_test_snapshot.clear()
	_test_button.disabled = false
	_status.text = "本次请求成功；不代表已全面认证模型能力。" if result.ok else "测试失败（%s）。"%result.code
