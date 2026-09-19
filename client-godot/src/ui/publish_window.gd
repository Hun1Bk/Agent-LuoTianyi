extends "res://src/ui/draft_window.gd"
signal published(id: String)
var _controller: Node
var _draft := TextEdit.new()
var _send := Button.new()
var _status := Label.new()
var _writing := false
func _init(controller: Node) -> void:
	_controller = controller
	title = "发布动态"
	visible = false
	force_native = true
	transient = true
	size = Vector2i(520,350)
	min_size = Vector2i(400,300)
func _ready() -> void:
	super._ready()
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel",Style.box(Style.SURFACE,0,18))
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	panel.add_child(column)
	column.add_child(Style.label("分享此刻的想法",20))
	_draft.name = "PublishDraft"
	_draft.placeholder_text = "想和天依分享些什么？"
	_draft.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_draft.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_draft)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	_send.name = "PublishButton"
	_send.text = "发布文字动态"
	Style.primary(_send)
	column.add_child(_send)
	_send.pressed.connect(_publish)
func is_dirty() -> bool:
	return _writing or not _draft.text.is_empty()
func _publish() -> void:
	if _writing: return
	_writing = true
	_send.disabled = true
	_draft.editable = false
	var result: Dictionary = await _controller.publish(_draft.text)
	_writing = false
	_send.disabled = false
	_draft.editable = true
	if result.ok:
		_draft.clear()
		published.emit(result.item_id)
		queue_free()
	else:
		_status.text = "发布结果不确定，请先刷新核实；草稿已保留。" if result.code in ["TIMEOUT","NETWORK_ERROR"] else "发布失败，草稿已保留（%s）。"%result.code
