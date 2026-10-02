extends Control
const UiMotion = preload("res://src/ui/ui_motion.gd")
signal close_requested
signal published(id: String)
var _controller: Node
@onready var _draft: TextEdit = %PublishDraft
@onready var _send: Button = %PublishButton
@onready var _status: Label = %PublishStatus
var _writing := false
var _closing := false
func setup(controller: Node) -> void:
	_controller = controller
func _ready() -> void:
	close_requested.connect(_request_close)
	%CancelPublish.pressed.connect(func(): close_requested.emit())
	%DiscardDialog.confirmed.connect(_close_overlay)
	_send.pressed.connect(_publish)
func is_dirty() -> bool:
	return _writing or not _draft.text.is_empty()
func _publish() -> void:
	if _writing or _closing: return
	_writing = true
	_send.disabled = true
	_draft.editable = false
	var result: Dictionary = await _controller.publish(_draft.text)
	if _closing: return
	_writing = false
	_send.disabled = false
	_draft.editable = true
	if result.ok:
		_draft.clear()
		published.emit(result.item_id)
		_close_overlay()
	else:
		_status.text = "发布结果不确定，请先刷新核实；草稿已保留。" if result.code in ["TIMEOUT","NETWORK_ERROR"] else "发布失败，草稿已保留（%s）。"%result.code

func open() -> void:
	if _closing: return
	show()
	UiMotion.fade_in(get_node("Shade"), 0.2)
	UiMotion.slide_fade_in(get_node("Center/PanelSlot/Panel"), 24.0, UiMotion.DUR_BASE, 0.0, true)
	_draft.grab_focus()
func _close_overlay() -> void:
	if _closing: return
	_closing = true
	_send.disabled = true
	_draft.editable = false
	%CancelPublish.disabled = true
	UiMotion.cancel(get_node("Center/PanelSlot/Panel"), "slide")
	UiMotion.fade_out(get_node("Shade"), UiMotion.DUR_FAST)
	UiMotion.pop_out(get_node("Center/PanelSlot/Panel")).finished.connect(queue_free)
func _request_close() -> void:
	if _closing: return
	if is_dirty():
		%DiscardDialog.popup_centered()
		%DiscardDialog.get_cancel_button().grab_focus()
	else: _close_overlay()
func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and not %DiscardDialog.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_requested.emit()
