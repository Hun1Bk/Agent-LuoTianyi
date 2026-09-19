extends ScrollContainer
const Style = preload("res://src/preview/preview_style.gd")
var _controller: Node
var _post: Dictionary
var _column := VBoxContainer.new()
var _body := RichTextLabel.new()
var _comments := VBoxContainer.new()
var _draft := TextEdit.new()
var _reply_draft := TextEdit.new()
var _reply_box := VBoxContainer.new()
var _reply_label := Label.new()
var _cancel := Button.new()
var _send := Button.new()
var _reply_send := Button.new()
var _load := Button.new()
var _status := Label.new()
var _notice := Label.new()
var _parent := ""
var _rows := {}
var _writing := false
var _refresh_failed := false

func _init(controller: Node,post: Dictionary) -> void:
	_controller = controller
	_post = post.duplicate(true)
	horizontal_scroll_mode = SCROLL_MODE_DISABLED
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

func _ready() -> void:
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.add_theme_constant_override("separation",14)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,18)
	add_child(margin)
	margin.add_child(_column)
	var header := HBoxContainer.new()
	_column.add_child(header)
	header.add_child(Style.avatar(avatar_path(_post),42))
	var identity := VBoxContainer.new()
	header.add_child(identity)
	identity.add_child(Style.label(_post.author_name,18))
	identity.add_child(Style.label(_post.created_at,12,Color("94999f")))
	_body.fit_content = true
	_body.scroll_active = false
	_body.selection_enabled = true
	_column.add_child(_body)
	_column.add_child(_notice)
	_notice.text = "此动态不可评论。"
	_column.add_child(_draft)
	_setup_input(_draft,"CommentDraft","写下你的留言…")
	_send.text = "发送评论"
	_send.size_flags_horizontal = Control.SIZE_SHRINK_END
	Style.primary(_send)
	_send.pressed.connect(func(): _submit(false))
	_column.add_child(_send)
	_column.add_child(HSeparator.new())
	_column.add_child(Style.label("评论 · 仅你与天依可见",15,Color("818991")))
	_column.add_child(_comments)
	_comments.add_theme_constant_override("separation",16)
	_column.add_child(_reply_box)
	_reply_box.add_child(_reply_label)
	_reply_box.add_child(_reply_draft)
	_setup_input(_reply_draft,"ReplyDraft","写下回复…")
	var actions := HBoxContainer.new()
	_reply_box.add_child(actions)
	_cancel.name = "CancelReply"
	_cancel.text = "取消回复对象"
	_cancel.pressed.connect(func():
		_parent = ""
		_place_reply())
	actions.add_child(_cancel)
	_reply_send.text = "发送回复"
	Style.primary(_reply_send)
	_reply_send.pressed.connect(func(): _submit(true))
	actions.add_child(_reply_send)
	_reply_box.hide()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(_status)
	_column.add_child(_load)
	_load.pressed.connect(func():
		if _refresh_failed:
			_refresh_failed = false
			await refresh_comments()
		else:
			var state: Dictionary = _controller.get_comments(_post.id)
			await _controller.load_comments(_post.id,state.loaded and state.has_more))
	get_v_scroll_bar().value_changed.connect(func(_value): _at_bottom())
	_controller.changed.connect(update_comments)
	update_post(_post)
	update_comments()

func _setup_input(input: TextEdit,node_name: String,hint: String) -> void:
	input.name = node_name
	input.placeholder_text = hint
	input.custom_minimum_size.y = 90
	input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	input.add_theme_stylebox_override("normal",Style.box(Color("f5f7fa"),8,12))

func update_post(post: Dictionary) -> void:
	_post = post.duplicate(true)
	if _body.text != _post.content: _body.text = _post.content
	_notice.visible = not _post.allow_comment
	_draft.editable = _post.allow_comment and not _writing
	_reply_draft.editable = _draft.editable
	_send.disabled = not _draft.editable
	_reply_send.disabled = _send.disabled

func is_dirty() -> bool:
	return _writing or not _draft.text.is_empty() or not _reply_draft.text.is_empty()

func update_comments() -> void:
	if not is_node_ready(): return
	var state: Dictionary = _controller.get_comments(_post.id)
	_load.visible = state.busy or state.has_more or not state.loaded or state.code not in ["","OK"]
	_load.disabled = state.busy
	_load.text = "加载中…" if state.busy else ("加载更多评论" if state.loaded else "加载评论")
	if state.code not in ["","OK"]:
		_load.text = "重试评论"
		_status.text = "评论加载失败（%s），已保留现有内容。"%state.code
	elif _status.text.begins_with("评论加载失败"):
		_status.text = ""
	var names := {}
	for item in state.items: names[item.id] = item.author_name
	for index in state.items.size():
		var item: Dictionary = state.items[index]
		if not _rows.has(item.id):
			var row := VBoxContainer.new()
			_comments.add_child(row)
			_rows[item.id] = row
			var line := HBoxContainer.new()
			row.add_child(line)
			line.add_child(Style.avatar(avatar_path(item),34))
			var content := VBoxContainer.new()
			content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.add_child(content)
			content.add_child(Style.label(item.author_name,14,Color("65717d")))
			var body := RichTextLabel.new()
			body.fit_content = true
			body.scroll_active = false
			body.selection_enabled = true
			var target: String = str(item.get("parent_comment_id","") if item.get("parent_comment_id") != null else "")
			body.text = ("回复 %s："%names.get(target,"较早评论") if not target.is_empty() else "")+item.content
			content.add_child(body)
			var footer := HBoxContainer.new()
			content.add_child(footer)
			var time := Style.label(relative_time(item.created_at),12,Color("94999f"))
			time.tooltip_text = item.created_at
			footer.add_child(time)
			var reply := Style.button("回复",func():
				if _writing: return
				_parent = item.id
				_reply_label.text = "回复 "+item.author_name
				_place_reply()
				_reply_draft.grab_focus())
			reply.flat = true
			reply.disabled = not _post.allow_comment
			footer.add_child(reply)
			row.add_child(HSeparator.new())
		_comments.move_child(_rows[item.id],index)

func _place_reply() -> void:
	var destination: Node = _column if _parent.is_empty() else _rows.get(_parent,_column)
	if _reply_box.get_parent() != destination: _reply_box.reparent(destination)
	if _parent.is_empty():
		_column.move_child(_reply_box,_comments.get_index())
		_reply_label.text = "已取消回复对象，文字保留为留言草稿"
	_cancel.visible = not _parent.is_empty()
	_reply_send.text = "发送评论" if _parent.is_empty() else "发送回复"
	_reply_box.visible = not _parent.is_empty() or not _reply_draft.text.is_empty()

func _submit(reply: bool) -> void:
	if _writing or not _post.allow_comment: return
	var input := _reply_draft if reply else _draft
	_writing = true
	update_post(_post)
	_cancel.disabled = true
	var result: Dictionary = await _controller.comment(_post.id,input.text,_parent if reply else "")
	_writing = false
	update_post(_post)
	_cancel.disabled = false
	if result.ok:
		input.clear()
		if reply:
			_parent = ""
			_place_reply()
		_status.text = "评论已发送。"
	else:
		_status.text = "发送结果不确定，请先刷新核实；草稿已保留。" if result.code in ["TIMEOUT","NETWORK_ERROR"] else "评论失败，草稿已保留（%s）。"%result.code

func refresh_comments() -> void:
	await _controller.refresh_comments(_post.id)
	_refresh_failed = _controller.get_comments(_post.id).code not in ["","OK"]

func _at_bottom() -> void:
	if not is_visible_in_tree(): return
	var bar := get_v_scroll_bar()
	var state: Dictionary = _controller.get_comments(_post.id)
	if bar.value+bar.page >= bar.max_value-24 and state.loaded and state.has_more and not state.busy and state.code in ["","OK"]:
		_controller.load_comments(_post.id,true)

static func avatar_path(item: Dictionary) -> String:
	return "res://assets/ui/tianyi_icon.png" if item.author_type == "agent" else "res://assets/ui/user_icon.png"

static func relative_time(raw: String) -> String:
	if raw.length() != 19: return raw
	var pattern := RegEx.new()
	pattern.compile("^\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}$")
	if pattern.search(raw) == null: return raw
	var year := int(raw.substr(0,4))
	var month := int(raw.substr(5,2))
	var day := int(raw.substr(8,2))
	if year < 1 or month < 1 or month > 12: return raw
	var days := [31,29 if year%400==0 or (year%4==0 and year%100!=0) else 28,31,30,31,30,31,31,30,31,30,31]
	if day < 1 or day > days[month-1] or int(raw.substr(11,2)) > 23 or int(raw.substr(14,2)) > 59 or int(raw.substr(17,2)) > 59: return raw
	var normalized := raw.replace(" ","T")
	var epoch := Time.get_unix_time_from_datetime_string(normalized)
	if Time.get_datetime_string_from_unix_time(epoch) != normalized: return raw
	var age := int(Time.get_unix_time_from_system())-(epoch-8*3600)
	if age < 0: return raw
	if age < 60: return "刚刚"
	if age < 3600: return "%s分钟前"%(age/60)
	if age < 86400: return "%s小时前"%(age/3600)
	if age < 7*86400: return "%s天前"%(age/86400)
	return raw.left(10)
