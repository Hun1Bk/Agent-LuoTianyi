extends PanelContainer
const Style = preload("res://src/preview/preview_style.gd")
var _controller: Node
var _post: Dictionary
var _body := RichTextLabel.new()
var _comments := VBoxContainer.new()
var _draft := TextEdit.new()
var _reply := Label.new()
var _status := Label.new()
var _send := Button.new()
var _load := Button.new()
var _parent := ""
var _signature := ""
var _expanded := false
var _writing := false
var _expand := Button.new()
var _collapsed_height := 144.0

func _init(controller: Node,post: Dictionary) -> void:
	_controller = controller
	_post = post.duplicate(true)

func _ready() -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color.WHITE
	panel.set_corner_radius_all(14)
	panel.content_margin_left = 18
	panel.content_margin_right = 18
	panel.content_margin_top = 16
	panel.content_margin_bottom = 16
	add_theme_stylebox_override("panel",panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	header.add_child(Style.avatar("res://assets/ui/tianyi_icon.png" if _post.author_type == "agent" else "res://assets/ui/user_icon.png",38))
	var identity := VBoxContainer.new()
	header.add_child(identity)
	identity.add_child(Style.label(_post.author_name,17))
	identity.add_child(Style.label(_post.created_at+ (" · 私密" if _post.get("visibility") == "private" else ""),12))
	_body.text = _post.content
	_body.selection_enabled = true
	_body.scroll_active = false
	_collapsed_height = ceil(_body.get_theme_font("normal_font").get_height(_body.get_theme_font_size("normal_font_size")))*6+_body.get_theme_constant("line_separation")*5
	_body.custom_minimum_size.y = _collapsed_height
	column.add_child(_body)
	_expand.text = "展开全文"
	column.add_child(_expand)
	_expand.pressed.connect(func():
		_expanded = not _expanded
		_body.fit_content = _expanded
		_body.custom_minimum_size.y = 0 if _expanded else _collapsed_height
		_expand.text = "收起" if _expanded else "展开全文")
	column.add_child(HSeparator.new())
	column.add_child(_comments)
	_load.pressed.connect(func():
		var state: Dictionary = _controller.get_comments(_post.id)
		_controller.load_comments(_post.id,state.loaded and state.has_more))
	column.add_child(_load)
	column.add_child(_reply)
	var cancel := Button.new()
	cancel.text = "取消回复对象"
	cancel.pressed.connect(func():
		_parent = ""
		_reply.text = "")
	column.add_child(cancel)
	_draft.placeholder_text = "写评论…" if _post.allow_comment else "此动态不可评论"
	_draft.custom_minimum_size.y = 70
	_draft.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_draft.editable = _post.allow_comment
	column.add_child(_draft)
	_send.text = "发送评论"
	_send.disabled = not _post.allow_comment
	_send.pressed.connect(_submit)
	column.add_child(_send)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	update_comments()
	_fit_body.call_deferred()
	_body.resized.connect(func(): _fit_body.call_deferred())

func _fit_body() -> void:
	if _expanded:
		return
	var height := _body.get_content_height()
	_body.custom_minimum_size.y = minf(height,_collapsed_height)
	_expand.visible = height > _collapsed_height

func is_dirty() -> bool:
	return not _draft.text.is_empty() or _writing

func update_comments() -> void:
	var state: Dictionary = _controller.get_comments(_post.id)
	_load.text = "加载中…" if state.busy else ("加载更多评论" if state.loaded else "查看评论")
	_load.disabled = state.busy
	_load.visible = not state.loaded or state.has_more
	if not state.code.is_empty() and state.code != "OK":
		_status.text = "评论加载失败（%s），可重试。"%state.code
		_load.visible = true
		_load.text = "重试评论"
	var signature := JSON.stringify(state.items)
	if signature == _signature:
		return
	_signature = signature
	for child in _comments.get_children():
		_comments.remove_child(child)
		child.queue_free()
	var names := {}
	for item in state.items:
		names[item.id] = item.author_name
	for item in state.items:
		var text := RichTextLabel.new()
		text.fit_content = true
		text.selection_enabled = true
		text.bbcode_enabled = false
		var target := ""
		if item.get("parent_comment_id") is String and not item.parent_comment_id.is_empty():
			target = " 回复 "+str(names.get(item.parent_comment_id,"较早评论"))
		text.text = item.author_name+target+"："+item.content
		_comments.add_child(text)
		if _post.allow_comment:
			text.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			text.gui_input.connect(func(event):
				if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
					_parent = item.id
					_reply.text = "回复 "+item.author_name
					_draft.grab_focus())

func _submit() -> void:
	if _writing:
		return
	_writing = true
	_send.disabled = true
	_draft.editable = false
	var result: Dictionary = await _controller.comment(_post.id,_draft.text,_parent)
	_writing = false
	_send.disabled = not _post.allow_comment
	_draft.editable = _post.allow_comment
	if result.ok:
		_draft.text = ""
		_parent = ""
		_reply.text = ""
		_status.text = "评论已发送。"
	else:
		_status.text = "发送结果不确定，请先刷新核实；草稿已保留。" if result.code in ["TIMEOUT","NETWORK_ERROR"] else "评论失败，草稿已保留（%s）。"%result.code
