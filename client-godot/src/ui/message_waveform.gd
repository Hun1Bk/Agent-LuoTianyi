extends HBoxContainer
## Data drives scene-authored controls; no drawing or node construction happens here.
@export var played_color := Color("66ccff")
@export var remaining_color := Color("9eb6c4")
var values := PackedFloat32Array():
	set(value):
		if values == value: return
		values = value
		_refresh()
var progress := 0.0:
	set(value):
		progress = value
		_refresh()
func _ready() -> void:
	resized.connect(_refresh)
	_refresh()
func _refresh() -> void:
	if not is_node_ready(): return
	var count := mini(values.size(),get_child_count())
	for index in get_child_count():
		var slot := get_child(index) as Control
		slot.visible = index < count
		if index >= count: continue
		var bar := slot.get_node("Bar") as ColorRect
		var height := maxf(2, clampf(values[index], 0, 1) * size.y)
		bar.pivot_offset = bar.size * 0.5
		var blend := smoothstep(-1.0, 1.0, progress * count - index - 0.5)
		bar.color = remaining_color.lerp(played_color, blend)
		bar.scale.y = height / maxf(2, bar.size.y) * lerpf(1.0, 1.12, 1.0 - absf(blend * 2.0 - 1.0))
