extends PanelContainer
signal log_requested
const Style = preload("res://src/preview/preview_style.gd")
var _session: Node
var _form := VBoxContainer.new()
var _mode := preload("res://src/ui/unified_dropdown.gd").new()
var _fields: Dictionary = {}
var _remember := CheckBox.new()
var _submit := Button.new()
var _cancel := Button.new()
var _status := Label.new()
var _identity := Label.new()
var _logout := Button.new()

func _init(session: Node) -> void:
	_session = session

func _ready() -> void:
	theme = Style.make_theme()
	add_theme_stylebox_override("panel", Style.box(Color("ffffff"), 18, 28))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	add_child(column)
	column.add_child(Style.label("和天依再见面", 25))
	column.add_child(Style.label("登录你的账户，继续这段陪伴。", 13, Color("809ba7")))
	column.add_child(_form)
	_form.add_theme_constant_override("separation", 10)
	_mode.name = "AccountMode"
	_mode.set_items([{"id":"login","label":"密码登录"},{"id":"register","label":"注册账户"},{"id":"reset","label":"邀请码重置账户"}])
	_form.add_child(_mode)
	_mode.activated.connect(func(_index): _apply_mode())
	for item in [["server", "服务器地址"], ["username", "用户名"], ["password", "密码"], ["confirm", "确认密码"], ["invite", "邀请码"]]:
		var field := LineEdit.new()
		field.placeholder_text = item[1]
		field.tooltip_text = "例如 https://你的服务器地址；本地联调可使用 http://127.0.0.1:端口" if item[0] == "server" else item[1]
		field.secret = item[0] in ["password", "confirm", "invite"]
		field.custom_minimum_size.y = 40
		field.add_theme_stylebox_override("normal", Style.box(Color("f0f5f7"), 8, 10))
		_fields[item[0]] = field
		_form.add_child(field)
		field.text_submitted.connect(func(_text): _send())
	_remember.text = "下次自动登录"
	_form.add_child(_remember)
	_submit.custom_minimum_size.y = 42
	Style.primary(_submit)
	_submit.pressed.connect(_send)
	_form.add_child(_submit)
	_cancel.text = "取消请求"
	_cancel.pressed.connect(_session.cancel)
	_cancel.hide()
	column.add_child(_cancel)
	_identity.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_identity.hide()
	column.add_child(_identity)
	_logout.text = "退出登录"
	_logout.hide()
	_logout.pressed.connect(func():
		_clear_secrets()
		_session.logout())
	column.add_child(_logout)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 13)
	_status.add_theme_color_override("font_color", Color("607f8d"))
	column.add_child(_status)
	column.add_child(Style.button("打开日志",func(): log_requested.emit()))
	var defaults: Dictionary = _session.get_login_defaults()
	_fields.server.text = defaults.server
	_fields.username.text = defaults.username
	_remember.button_pressed = defaults.remember
	_session.changed.connect(_update_state)
	_apply_mode()

func _apply_mode() -> void:
	_fields.confirm.visible = _mode.get_selected_id() != "login"
	_fields.invite.visible = _mode.get_selected_id() != "login"
	_remember.visible = _mode.get_selected_id() == "login"
	_submit.text = {"login":"登录","register":"注册","reset":"重置账户"}[_mode.get_selected_id()]

func _send() -> void:
	if _submit.disabled:
		return
	if _mode.get_selected_id() != "login" and _fields.password.text != _fields.confirm.text:
		_status.text = "两次输入的密码不一致。"
		return
	var operation: String = _mode.get_selected_id()
	var fields := {"username":_fields.username.text, "password":_fields.password.text}
	if operation == "login":
		fields.request_token = _remember.button_pressed
	elif operation == "register":
		fields.invite_code = _fields.invite.text
	else:
		fields = {"new_username":_fields.username.text, "new_password":_fields.password.text, "invite_code":_fields.invite.text}
	var response: Dictionary = await _session.perform(operation, _fields.server.text, fields, _remember.button_pressed)
	if response.ok:
		_clear_secrets()
		if operation != "login":
			_mode.set_selected_id("login")
			_apply_mode()
			_status.text = "注册成功，请登录。" if operation == "register" else "账户重置成功，请用新账户登录。"
	else:
		_status.text = _error_text(response.code, response.get("status", 0))

func _update_state(state: Dictionary) -> void:
	var busy: bool = state.phase == "busy"
	var signed_in: bool = state.phase == "signed_in"
	_form.visible = not signed_in
	_cancel.visible = busy
	_identity.visible = signed_in
	_logout.visible = signed_in
	_mode.disabled = busy
	_remember.disabled = busy
	_submit.disabled = busy
	for field in _fields.values():
		field.editable = not busy
	if signed_in:
		_identity.text = "已登录：" + str(_session.get_session().get("username", ""))
		_clear_secrets()
	_status.text = "正在连接账户服务…" if busy else _error_text(state.code)
	if state.storage_error:
		_status.text = "账户操作已结束，但本地凭据无法保存或清除，请检查数据目录权限。"
	_remember.button_pressed = _session.get_login_defaults().remember if not busy else _remember.button_pressed

func _clear_secrets() -> void:
	for field in ["password", "confirm", "invite"]:
		_fields[field].clear()

static func _error_text(code: String, status: int = 0) -> String:
	return {"OK":"登录成功。", "LOGGED_OUT":"已退出登录。", "PENDING":"正在处理…", "CANCELLED":"请求已取消。",
		"AUTH_REJECTED":"用户名或密码错误，或自动登录凭据已失效。", "INVALID_INPUT":"请填写完整信息并检查服务器地址。",
		"TIMEOUT":"连接超时，请稍后重试。", "NETWORK_ERROR":"无法连接服务器，请检查地址和网络。",
		"PUBLIC_KEY_ERROR":"无法获取服务器公钥，请检查服务器地址。", "ENCRYPTION_ERROR":"密码加密失败，请检查密码长度或服务器公钥。",
		"INVALID_RESPONSE":"服务器返回的数据不完整，请稍后重试。", "CREDENTIAL_UNAVAILABLE":"无法读取自动登录凭据，请重新登录。",
		"HTTP_ERROR":"服务器拒绝了请求（%s），请检查账户信息或邀请码。" % status,
		"NO_SAVED_LOGIN":"", "BUSY":"正在处理上一次请求。"}.get(code, "账户操作未完成，请重试。")
