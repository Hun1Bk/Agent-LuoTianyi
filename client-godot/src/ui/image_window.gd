extends Window
@export var window_system: Resource = preload("res://src/platform/window_system.gd").new()
const UiMotion = preload("res://src/ui/ui_motion.gd")
var _source: WeakRef
var _previous_focus: WeakRef
var _provider: Callable
var _confirm: Callable
var _active := false
var _hidden_by_source := false
var _fitting := true
var _zoom := 1.0
var _dragging := false

func _ready() -> void:
	close_requested.connect(func(): close_image(false))
	%CloseImage.pressed.connect(func(): close_requested.emit())
	%RetryImage.pressed.connect(_load_image)
	%FitImage.pressed.connect(func(): _fitting = true; _resize_image(true))
	%OriginalSize.pressed.connect(func(): _fitting = false; _set_zoom(1.0, %ImageScroll.size * 0.5))
	%ZoomOut.pressed.connect(func(): _zoom_by(.8))
	%ZoomIn.pressed.connect(func(): _zoom_by(1.25))
	%ConfirmImage.pressed.connect(_confirm_image)
	%ImageScroll.resized.connect(_resize_image)
	%ImageScroll.gui_input.connect(_image_input)
	focus_exited.connect(func(): _dragging = false)
	visibility_changed.connect(func():
		if not visible:
			_dragging = false
			UiMotion.cancel(%Picture, "transform", false))

func _confirm_image() -> void:
	if not _active: return
	if _confirm.is_valid() and _confirm.call(%Picture.texture): close_image(false)
	else: %Feedback.text = "图片暂时无法发送，请检查当前连接后重试。图片已保留。"

func present(source: Window, provider: Callable, confirm: Callable = Callable()) -> void:
	UiMotion.cancel(%Picture, "transform", false)
	_dragging = false
	_source = weakref(source)
	var focus := source.gui_get_focus_owner()
	_previous_focus = weakref(focus) if focus != null else null
	_provider = provider
	_confirm = confirm
	_active = true
	_hidden_by_source = false
	_fitting = true
	_zoom = 1
	%Feedback.text = ""
	%ConfirmImage.visible = confirm.is_valid()
	%CloseImage.text = "取消" if confirm.is_valid() else "关闭"
	_load_image()
	_reveal()
	_resize_image.call_deferred()

func _reveal() -> void:
	%Chrome.open_window()

func _load_image() -> void:
	UiMotion.cancel(%Picture, "transform", false)
	var texture: Texture2D = _provider.call() if _provider.is_valid() else null
	%Picture.texture = texture
	%Picture.visible = texture != null
	%ImageError.visible = texture == null
	%RetryImage.visible = texture == null
	for button in [%ZoomIn,%ZoomOut,%FitImage,%OriginalSize,%ConfirmImage]: button.disabled = texture == null
	if texture != null:
		%Picture.custom_minimum_size = texture.get_size()
		%Picture.size = texture.get_size()
		_resize_image()

func _resize_image(animated: bool = false) -> void:
	var texture: Texture2D = %Picture.texture
	if texture == null: return
	if _fitting:
		var available: Vector2 = (%ImageScroll.size-Vector2(20,20)).max(Vector2.ONE)
		_zoom = minf(available.x / texture.get_width(), available.y / texture.get_height())
	var origin: Vector2 = (%ImageScroll.size - texture.get_size() * _zoom) * 0.5 if _fitting else %Picture.position
	_apply_transform(origin, animated)

func _zoom_by(factor: float, anchor: Vector2 = Vector2(-1, -1)) -> void:
	if not _active or %Picture.texture == null: return
	if anchor.x < 0: anchor = %ImageScroll.size * 0.5
	_fitting = false
	_set_zoom(clampf(_zoom * factor, .05, 8.0), anchor)

func _set_zoom(value: float, anchor: Vector2) -> void:
	if %Picture.texture == null: return
	var pixel: Vector2 = (anchor - %Picture.position) / maxf(.001, %Picture.scale.x)
	_zoom = value
	_apply_transform(anchor - pixel * _zoom, true)

func _apply_transform(origin: Vector2, animated: bool) -> void:
	UiMotion.cancel(%Picture, "transform", false)
	origin = _clamp_position(origin, _zoom)
	if animated: UiMotion.transform_to(%Picture, Vector2.ONE * _zoom, origin)
	else:
		%Picture.scale = Vector2.ONE * _zoom
		%Picture.position = origin
	%ZoomLabel.text = "%s%%" % roundi(_zoom * 100)

func _clamp_position(origin: Vector2, zoom: float) -> Vector2:
	var extent: Vector2 = %Picture.size * zoom
	var viewport_size: Vector2 = %ImageScroll.size
	for axis in 2:
		origin[axis] = (viewport_size[axis]-extent[axis])*0.5 if extent[axis] <= viewport_size[axis] else clampf(origin[axis], viewport_size[axis]-extent[axis], 0.0)
	return origin

func _image_input(event: InputEvent) -> void:
	if not _active or %Picture.texture == null or not event is InputEventMouseButton: return
	if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
		_zoom_by(1.25 if event.button_index == MOUSE_BUTTON_WHEEL_UP else .8, event.position)
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		UiMotion.cancel(%Picture, "transform", false)
		_zoom = %Picture.scale.x
		_fitting = false

## Lifecycle callers close immediately; a user's close request animates.
func close_image(immediate: bool = true) -> void:
	_active = false
	_hidden_by_source = false
	_dragging = false
	UiMotion.cancel(%Picture, "transform", false)
	%Chrome.close_window(_finish_close, immediate)

func _finish_close() -> void:
	hide()
	%Picture.texture = null
	_provider = Callable()
	_confirm = Callable()
	var source = _source.get_ref() if _source != null else null
	if is_instance_valid(source) and not window_system.minimized(source):
		window_system.focus(source)
		var control = _previous_focus.get_ref() if _previous_focus != null else null
		if is_instance_valid(control) and control.is_visible_in_tree(): control.grab_focus()

func _process(_delta: float) -> void:
	if not _active: return
	var source = _source.get_ref() if _source != null else null
	if not is_instance_valid(source): close_image(); return
	if window_system.minimized(source):
		if not _hidden_by_source and not window_system.minimized(self):
			_hidden_by_source = true
			hide()
	elif _hidden_by_source:
		_hidden_by_source = false
		_reveal()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_requested.emit()
	elif _dragging and event is InputEventMouseMotion:
		%Picture.position = _clamp_position(%Picture.position + event.relative, %Picture.scale.x)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dragging = false
