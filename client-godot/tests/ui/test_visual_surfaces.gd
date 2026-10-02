extends SceneTree
var failures: Array[String] = []
func check(ok: bool,label: String) -> void:
	if not ok:
		failures.append(label)
		print("FAIL: ",label)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var theme: Theme = load("res://theme/app_theme.tres")
	check(theme.has_stylebox("panel","AppSurface"),"application surfaces use theme resources")
	check(theme.has_stylebox("normal","TerminalSurface"),"log terminal has a dark content surface")
	check(ResourceLoader.exists("res://scenes/ui/frost_surface.tscn"),"frost is a scene-authored control")
	if ResourceLoader.exists("res://scenes/ui/frost_surface.tscn"):
		var frost = load("res://scenes/ui/frost_surface.tscn").instantiate()
		check(frost is ColorRect and frost.material is ShaderMaterial,"frost uses a Godot control and material")
		frost.blur_enabled = false
		root.add_child(frost)
		check(frost.material == null and frost.color.a == 1.0,"disabled blur falls back to readable solid color")
		frost.queue_free()
	var audio = load("res://scenes/ui/message_audio.tscn").instantiate()
	root.add_child(audio)
	var wave = audio.get_node("%Wave")
	check(wave.get_child_count() == 24,"waveform bars exist in scene before data")
	if wave.get_child_count() == 24:
		wave.values = PackedFloat32Array([.2,.8])
		wave.progress = .5
		_check_wave(wave)
	audio.queue_free()
	await process_frame
	print("Visual surfaces: ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)

func _check_wave(wave: Control) -> void:
	var first: ColorRect = wave.get_child(0).get_node("Bar")
	var second: ColorRect = wave.get_child(1).get_node("Bar")
	check(first.color.b > second.color.b and first.color != wave.remaining_color and second.color != wave.played_color,"waveform smoothly blends across the playback boundary")
	check(first.custom_minimum_size.y == 2 and second.custom_minimum_size.y == 2 and first.scale.y != second.scale.y,"waveform height uses transforms without changing layout sizes")
