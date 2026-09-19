extends Button
## Shared stable-ID selector / action menu. Popup details remain private.
signal activated(id: String)
const Style = preload("res://src/preview/preview_style.gd")
var action_menu := false
var _items: Array = []
var _selected := ""
var _popup := PopupPanel.new()
var _scroll := ScrollContainer.new()
var _rows := VBoxContainer.new()
var _buttons: Array[Button] = []
var _focus_index := -1
var _owner_geometry := Rect2i()

func _init(actions: bool = false) -> void:
	action_menu = actions
	custom_minimum_size.y = 40
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	clip_text = true

func _ready() -> void:
	_popup.visible = false
	_popup.force_native = true
	add_child(_popup)
	_popup.theme = Style.make_theme()
	var panel := Style.box(Color.WHITE,10,6)
	panel.border_color = Color("dce1e5")
	panel.set_border_width_all(1)
	panel.shadow_color = Color(0,0,0,.12)
	panel.shadow_size = 4
	_popup.add_theme_stylebox_override("panel",panel)
	_popup.add_child(_scroll)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.add_child(_rows)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation",0)
	_popup.window_input.connect(_key_input)
	pressed.connect(func():
		if is_menu_open(): close_menu()
		else: open_menu())
	_build()

func set_items(items: Array) -> Error:
	var ids := {}
	for item in items:
		if not item is Dictionary: return ERR_INVALID_PARAMETER
		if item.get("separator",false): continue
		if not item.get("id") is String or item.id.is_empty() or not item.get("label") is String or ids.has(item.id):
			return ERR_INVALID_PARAMETER
		ids[item.id] = true
	_items = items.duplicate(true)
	if not _available(_selected):
		_selected = ""
		for item in _items:
			if not item.get("separator",false) and not item.get("disabled",false):
				_selected = item.id
				break
	_caption()
	if is_node_ready(): _build()
	return OK

func get_items() -> Array:
	return _items.duplicate(true)

func set_selected_id(id: String) -> bool:
	if not _available(id): return false
	_selected = id
	_caption()
	return true

func get_selected_id() -> String:
	return _selected

func set_item_enabled(id: String, enabled: bool) -> void:
	var items := get_items()
	for item in items:
		if item.get("id","") == id: item.disabled = not enabled
	set_items(items)

func _available(id: String) -> bool:
	return _items.any(func(item): return item.get("id","") == id and not item.get("separator",false) and not item.get("disabled",false))

func _caption() -> void:
	if action_menu: return
	text = ""
	for item in _items:
		if item.get("id","") == _selected:
			text = item.label + "  ▾"

func _build() -> void:
	close_menu()
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_buttons.clear()
	for item in _items:
		if item.get("separator",false):
			_rows.add_child(HSeparator.new())
			continue
		var row := Button.new()
		row.text = item.label
		row.set_meta("id",item.id)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size.y = 42
		row.disabled = item.get("disabled",false)
		row.gui_input.connect(_key_input)
		row.add_theme_stylebox_override("normal",Style.box(Color.WHITE,6,12))
		row.add_theme_stylebox_override("hover",Style.box(Color("f0f2f4"),6,12))
		row.add_theme_color_override("font_color",Color("353c43"))
		row.pressed.connect(func(): _activate(item.id))
		_rows.add_child(row)
		_buttons.append(row)

func open_menu() -> void:
	if disabled or not is_node_ready() or _buttons.is_empty(): return
	var owner := get_window()
	_owner_geometry = Rect2i(owner.position,owner.size)
	var screen := DisplayServer.screen_get_usable_rect(owner.current_screen)
	# Embedded canvas coordinates must be transformed to native screen pixels.
	var transform := get_screen_transform()
	var origin := Vector2i(transform * Vector2.ZERO)
	var bottom := Vector2i(transform * Vector2(0,size.y))
	var scale_y := transform.get_scale().y
	var width := maxi(int(size.x * transform.get_scale().x),230)
	for row in _buttons:
		width = maxi(width,int(row.get_combined_minimum_size().x)+32)
	width = mini(width,screen.size.x)
	var height := mini(_buttons.size()*42+24,mini(420,screen.size.y))
	var y := bottom.y
	if y + height > screen.end.y: y = origin.y-height
	y = clampi(y,screen.position.y,screen.end.y-height)
	_popup.content_scale_factor = maxf(1.0,scale_y)
	_popup.popup(Rect2i(Vector2i(clampi(origin.x,screen.position.x,screen.end.x-width),y),Vector2i(width,height)))
	_focus_index = -1
	for index in _buttons.size():
		var row := _buttons[index]
		row.text = ("✓  " if not action_menu and row.get_meta("id") == _selected else "    ") + _label(row.get_meta("id"))
		if row.get_meta("id") == _selected: _focus_index = index
	if _focus_index >= 0: _buttons[_focus_index].grab_focus()

func _label(id: String) -> String:
	for item in _items:
		if item.get("id","") == id: return item.label
	return ""

func close_menu() -> void:
	_popup.hide()

func is_menu_open() -> bool:
	return _popup.visible

func _activate(id: String) -> void:
	if disabled or not _available(id): return
	set_selected_id(id)
	close_menu()
	activated.emit(id)

func _key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed: return
	match event.keycode:
		KEY_ESCAPE: close_menu()
		KEY_ENTER,KEY_KP_ENTER:
			if _focus_index >= 0: _activate(_buttons[_focus_index].get_meta("id"))
		KEY_DOWN,KEY_UP:
			var direction := 1 if event.keycode == KEY_DOWN else -1
			for step in _buttons.size():
				_focus_index = posmod(_focus_index+direction,_buttons.size())
				if not _buttons[_focus_index].disabled:
					_buttons[_focus_index].grab_focus()
					_scroll.ensure_control_visible(_buttons[_focus_index])
					break
		_: return
	_popup.set_input_as_handled()

func _process(_delta: float) -> void:
	if not is_menu_open(): return
	var owner := get_window()
	if not is_visible_in_tree() or disabled or owner.mode == Window.MODE_MINIMIZED or Rect2i(owner.position,owner.size) != _owner_geometry:
		close_menu()
