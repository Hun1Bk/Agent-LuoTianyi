extends SceneTree
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	if not value:
		failures.append(label)
		print("FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func key(shift: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = true
	event.shift_pressed = shift
	Input.parse_input_event(event)
	await process_frame
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var inputs: Array[Node] = scene.find_children("*", "TextEdit", true, false)
	check(inputs.size() == 1, "single visible composer")
	if inputs.size() == 1:
		var editor: TextEdit = inputs[0]
		editor.grab_focus()
		editor.text = "界面输入回归"
		await key(false)
		check(editor.text.is_empty(), "Enter submits and clears composer")
		await process_frame
		var found := false
		for label in scene.find_children("*", "RichTextLabel", true, false):
			found = found or label.get_parsed_text() == "界面输入回归"
		check(found, "submitted text visible in bubble")
		editor.text = "第一行"
		editor.set_caret_column(3)
		await key(true)
		check(editor.text.contains("\n"), "Shift Enter inserts newline")
		editor.text = " \n "
		await key(false)
		check(not editor.text.is_empty(), "blank input retained")
	await create_timer(1.0).timeout
	scene.queue_free()
	await process_frame
	print("Preview input: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
