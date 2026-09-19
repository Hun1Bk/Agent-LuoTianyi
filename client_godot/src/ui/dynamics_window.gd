extends "res://src/ui/draft_window.gd"
var _controller: Node
var _draft := TextEdit.new()
var _send := Button.new()
var _status := Label.new()
var _unread := Label.new()
var _cards := VBoxContainer.new()
var _by_id := {}
var _more := Button.new()
var _writing := false

func _init(controller: Node) -> void:
	_controller = controller
	title = "天依的动态"
	size = Vector2i(620,800)
	min_size = Vector2i(480,600)

func _ready() -> void:
	super._ready()
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,16)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	margin.add_child(column)
	var toolbar := HBoxContainer.new()
	column.add_child(toolbar)
	_unread.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(_unread)
	var refresh := Button.new()
	refresh.text = "刷新动态"
	refresh.pressed.connect(_controller.refresh)
	toolbar.add_child(refresh)
	var read := Button.new()
	read.text = "全部已读"
	read.pressed.connect(_controller.mark_read)
	toolbar.add_child(read)
	_draft.name = "PublishDraft"
	_draft.placeholder_text = "分享此刻的想法…"
	_draft.custom_minimum_size.y = 90
	_draft.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	column.add_child(_draft)
	_send.name = "PublishButton"
	_send.text = "发布文字动态"
	Style.primary(_send)
	_send.pressed.connect(_publish)
	column.add_child(_send)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards.add_theme_constant_override("separation",16)
	scroll.add_child(_cards)
	_more.text = "加载更多动态"
	_more.pressed.connect(_controller.load_more)
	column.add_child(_more)
	_controller.changed.connect(_update)
	_controller.unread_changed.connect(_update_unread)
	_update()
	_update_unread(_controller.get_state().unread)
	if _controller.get_posts().is_empty():
		_controller.refresh()

func is_dirty() -> bool:
	if not _draft.text.is_empty() or _writing:
		return true
	for card in _by_id.values():
		if card.is_dirty():
			return true
	return false

func _update_unread(count: int) -> void:
	_unread.text = "动态 · %s 条未读"%count if count else "动态"
	var code: String = _controller.get_state().unread_code
	if code not in ["","OK"]:
		_unread.text += "（未读操作失败：%s）"%code

func _update() -> void:
	var state: Dictionary = _controller.get_state()
	_more.visible = state.has_more
	_more.disabled = state.busy
	if state.code not in ["","OK"]:
		_status.text = "动态操作失败（%s），已显示内容和草稿保留。"%state.code
	var posts: Array = _controller.get_posts()
	var ids := {}
	for index in posts.size():
		var item: Dictionary = posts[index]
		ids[item.id] = true
		if not _by_id.has(item.id):
			var card = preload("res://src/ui/dynamic_card.gd").new(_controller,item)
			_by_id[item.id] = card
			_cards.add_child(card)
		_cards.move_child(_by_id[item.id],index)
		_by_id[item.id].update_comments()
	for id in _by_id.keys():
		if not ids.has(id) and not _by_id[id].is_dirty():
			_by_id[id].queue_free()
			_by_id.erase(id)
	if posts.is_empty() and state.code in ["","OK"]:
		_status.text = "正在加载…" if state.busy else "还没有动态。"

func _publish() -> void:
	if _writing:
		return
	_writing = true
	_send.disabled = true
	_draft.editable = false
	var result: Dictionary = await _controller.publish(_draft.text)
	_writing = false
	_send.disabled = false
	_draft.editable = true
	if result.ok:
		_draft.text = ""
		_status.text = "动态已发布。"
	else:
		_status.text = "发布结果不确定，请先刷新核实；草稿已保留。" if result.code in ["TIMEOUT","NETWORK_ERROR"] else "发布失败，草稿已保留（%s）。"%result.code
