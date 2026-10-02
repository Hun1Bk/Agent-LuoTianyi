import pathlib, subprocess

godot = "D:/godot/godot4.7.1/godot.exe"

script = """extends SceneTree

func _initialize():
	run.call_deferred()

func run():
	root.size = Vector2i(1040, 720)
	
	# Split Layout
	var split = HSplitContainer.new()
	split.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	split.add_theme_constant_override("separation", 0)
	root.add_child(split)
	
	# Left: Live2D Character Area
	var left_side = Control.new()
	left_side.custom_minimum_size = Vector2(360, 0)
	split.add_child(left_side)
	
	var bg_l2d = TextureRect.new()
	bg_l2d.texture = load("res://assets/ui/bg2.jpg")
	bg_l2d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_l2d.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_l2d.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	left_side.add_child(bg_l2d)
	
	# Left Header
	var l_head = MarginContainer.new()
	l_head.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	l_head.add_theme_constant_override("margin_left", 20)
	l_head.add_theme_constant_override("margin_top", 20)
	var l_vbox = VBoxContainer.new()
	var l_name = Label.new()
	l_name.text = "洛天依"
	l_name.add_theme_font_size_override("font_size", 26)
	l_name.add_theme_color_override("font_color", Color(0.18, 0.28, 0.36, 1))
	l_vbox.add_child(l_name)
	
	var l_sub = Label.new()
	l_sub.text = "把平凡的日子，慢慢说给我听。"
	l_sub.add_theme_font_size_override("font_size", 12)
	l_sub.add_theme_color_override("font_color", Color(0.35, 0.45, 0.52, 1))
	l_vbox.add_child(l_sub)
	
	var exp_btn = Button.new()
	exp_btn.text = "微笑脸 ⌵"
	var exp_box = StyleBoxFlat.new()
	exp_box.bg_color = Color(1, 1, 1, 0.85)
	exp_box.border_width_left = 1
	exp_box.border_width_top = 1
	exp_box.border_width_right = 1
	exp_box.border_width_bottom = 1
	exp_box.border_color = Color(0.8, 0.9, 0.96, 0.8)
	exp_box.set_corner_radius_all(14)
	exp_box.content_margin_left = 12
	exp_box.content_margin_right = 12
	exp_btn.add_theme_stylebox_override("normal", exp_box)
	exp_btn.add_theme_font_size_override("font_size", 12)
	exp_btn.add_theme_color_override("font_color", Color(0.2, 0.3, 0.38, 1))
	l_vbox.add_child(exp_btn)
	l_head.add_child(l_vbox)
	left_side.add_child(l_head)
	
	# Live2D Avatar Placeholder
	var char_pic = TextureRect.new()
	char_pic.texture = load("res://assets/ui/login_portrait.png")
	char_pic.custom_minimum_size = Vector2(260, 260)
	char_pic.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	char_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	char_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	left_side.add_child(char_pic)
	
	# Right: Chat Workspace Card
	var right_side = PanelContainer.new()
	right_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var r_box = StyleBoxFlat.new()
	r_box.bg_color = Color(0.97, 0.985, 0.995, 1.0)
	r_box.border_width_left = 1
	r_box.border_color = Color(0.88, 0.93, 0.97, 1.0)
	right_side.add_theme_stylebox_override("panel", r_box)
	split.add_child(right_side)
	
	var r_margin = MarginContainer.new()
	r_margin.add_theme_constant_override("margin_left", 28)
	r_margin.add_theme_constant_override("margin_right", 28)
	r_margin.add_theme_constant_override("margin_top", 20)
	r_margin.add_theme_constant_override("margin_bottom", 20)
	right_side.add_child(r_margin)
	
	var r_col = VBoxContainer.new()
	r_col.add_theme_constant_override("separation", 14)
	r_margin.add_child(r_col)
	
	# Right Header
	var r_header = HBoxContainer.new()
	var h_title = Label.new()
	h_title.text = "和天依聊聊"
	h_title.add_theme_font_size_override("font_size", 22)
	h_title.add_theme_color_override("font_color", Color(0.18, 0.28, 0.35, 1))
	r_header.add_child(h_title)
	
	# Status Badge
	var badge = Label.new()
	badge.text = "  ● 在线陪伴中"
	badge.add_theme_font_size_override("font_size", 12)
	badge.add_theme_color_override("font_color", Color(0.2, 0.72, 0.45, 1))
	r_header.add_child(badge)
	
	var r_sp = Control.new()
	r_sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r_header.add_child(r_sp)
	
	var mode_btn = Button.new()
	mode_btn.text = "日常聊天 ⌵"
	var mode_box = StyleBoxFlat.new()
	mode_box.bg_color = Color(1, 1, 1, 0.9)
	mode_box.border_width_left = 1
	mode_box.border_width_top = 1
	mode_box.border_width_right = 1
	mode_box.border_width_bottom = 1
	mode_box.border_color = Color(0.85, 0.91, 0.96, 1)
	mode_box.set_corner_radius_all(14)
	mode_box.content_margin_left = 14
	mode_box.content_margin_right = 14
	mode_btn.add_theme_stylebox_override("normal", mode_box)
	mode_btn.add_theme_font_size_override("font_size", 12)
	mode_btn.add_theme_color_override("font_color", Color(0.25, 0.36, 0.44, 1))
	r_header.add_child(mode_btn)
	r_col.add_child(r_header)
	
	# Subtle time pill
	var time_pill = Label.new()
	time_pill.text = "今天 14:32 · 以下为界面演示内容"
	time_pill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_pill.add_theme_font_size_override("font_size", 11)
	time_pill.add_theme_color_override("font_color", Color(0.6, 0.68, 0.74, 1))
	r_col.add_child(time_pill)
	
	# Chat Messages Area
	var msg_scroll = VBoxContainer.new()
	msg_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	msg_scroll.add_theme_constant_override("separation", 16)
	r_col.add_child(msg_scroll)
	
	# Assistant Message 1
	var m1 = HBoxContainer.new()
	m1.add_theme_constant_override("separation", 12)
	var a1_avatar = TextureRect.new()
	a1_avatar.texture = load("res://assets/ui/tianyi_icon.png")
	a1_avatar.custom_minimum_size = Vector2(40, 40)
	a1_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	a1_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	m1.add_child(a1_avatar)
	
	var a1_panel = PanelContainer.new()
	var a1_box = StyleBoxFlat.new()
	a1_box.bg_color = Color(1, 1, 1, 1)
	a1_box.set_corner_radius_all(16)
	a1_box.corner_radius_top_left = 4
	a1_box.border_width_left = 1
	a1_box.border_width_top = 1
	a1_box.border_width_right = 1
	a1_box.border_width_bottom = 1
	a1_box.border_color = Color(0.88, 0.93, 0.97, 1)
	a1_box.shadow_color = Color(0.12, 0.28, 0.42, 0.06)
	a1_box.shadow_size = 8
	a1_box.shadow_offset = Vector2(0, 2)
	a1_box.content_margin_left = 18
	a1_box.content_margin_top = 14
	a1_box.content_margin_right = 18
	a1_box.content_margin_bottom = 14
	a1_panel.add_theme_stylebox_override("panel", a1_box)
	var a1_lbl = Label.new()
	a1_lbl.text = "你回来啦。今天过得怎么样？"
	a1_lbl.add_theme_font_size_override("font_size", 14)
	a1_lbl.add_theme_color_override("font_color", Color(0.18, 0.26, 0.32, 1))
	a1_panel.add_child(a1_lbl)
	m1.add_child(a1_panel)
	msg_scroll.add_child(m1)
	
	# User Message 1
	var m2 = HBoxContainer.new()
	m2.add_theme_constant_override("separation", 12)
	m2.alignment = BoxContainer.ALIGNMENT_END
	var u1_panel = PanelContainer.new()
	var u1_box = StyleBoxFlat.new()
	u1_box.bg_color = Color(0.35, 0.74, 0.98, 1)
	u1_box.set_corner_radius_all(16)
	u1_box.corner_radius_bottom_right = 4
	u1_box.border_width_left = 1
	u1_box.border_width_top = 1
	u1_box.border_width_right = 1
	u1_box.border_width_bottom = 1
	u1_box.border_color = Color(0.65, 0.88, 1.0, 0.5)
	u1_box.shadow_color = Color(0.25, 0.65, 0.95, 0.22)
	u1_box.shadow_size = 8
	u1_box.shadow_offset = Vector2(0, 3)
	u1_box.content_margin_left = 18
	u1_box.content_margin_top = 14
	u1_box.content_margin_right = 18
	u1_box.content_margin_bottom = 14
	u1_panel.add_theme_stylebox_override("panel", u1_box)
	var u1_lbl = Label.new()
	u1_lbl.text = "终于忙完了，想在这里休息一会儿。"
	u1_lbl.add_theme_font_size_override("font_size", 14)
	u1_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	u1_panel.add_child(u1_lbl)
	m2.add_child(u1_panel)
	
	var u1_avatar = TextureRect.new()
	u1_avatar.texture = load("res://assets/ui/user_icon.png")
	u1_avatar.custom_minimum_size = Vector2(40, 40)
	u1_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	u1_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	m2.add_child(u1_avatar)
	msg_scroll.add_child(m2)
	
	# Assistant Message 2
	var m3 = HBoxContainer.new()
	m3.add_theme_constant_override("separation", 12)
	var a2_avatar = TextureRect.new()
	a2_avatar.texture = load("res://assets/ui/tianyi_icon.png")
	a2_avatar.custom_minimum_size = Vector2(40, 40)
	a2_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	a2_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	m3.add_child(a2_avatar)
	
	var a2_panel = PanelContainer.new()
	a2_panel.add_theme_stylebox_override("panel", a1_box)
	var a2_lbl = Label.new()
	a2_lbl.text = "那就慢慢来吧，不用急着说些什么。\\n我就在这里，陪你把今天的心情一点点放下来。"
	a2_lbl.add_theme_font_size_override("font_size", 14)
	a2_lbl.add_theme_color_override("font_color", Color(0.18, 0.26, 0.32, 1))
	a2_panel.add_child(a2_lbl)
	m3.add_child(a2_panel)
	msg_scroll.add_child(m3)
	
	# Bottom Integrated Composer Card
	var comp_panel = PanelContainer.new()
	comp_panel.custom_minimum_size = Vector2(0, 120)
	var comp_box = StyleBoxFlat.new()
	comp_box.bg_color = Color(1, 1, 1, 1)
	comp_box.border_width_left = 1
	comp_box.border_width_top = 1
	comp_box.border_width_right = 1
	comp_box.border_width_bottom = 1
	comp_box.border_color = Color(0.84, 0.90, 0.95, 1.0)
	comp_box.set_corner_radius_all(18)
	comp_box.shadow_color = Color(0.15, 0.30, 0.45, 0.06)
	comp_box.shadow_size = 10
	comp_box.shadow_offset = Vector2(0, 3)
	comp_box.content_margin_left = 16
	comp_box.content_margin_right = 16
	comp_box.content_margin_top = 12
	comp_box.content_margin_bottom = 12
	comp_panel.add_theme_stylebox_override("panel", comp_box)
	
	var comp_vbox = VBoxContainer.new()
	comp_vbox.add_theme_constant_override("separation", 8)
	
	# Text input
	var c_input = TextEdit.new()
	c_input.placeholder_text = "给天依发一条消息… (Shift+Enter 换行)"
	c_input.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	c_input.flat = true
	c_input.add_theme_font_size_override("font_size", 14)
	c_input.add_theme_color_override("font_color", Color(0.2, 0.28, 0.35, 1))
	comp_vbox.add_child(c_input)
	
	# Bottom action dock
	var c_actions = HBoxContainer.new()
	var btn_img = Button.new()
	btn_img.text = "📷 发送图片"
	var pill_box = StyleBoxFlat.new()
	pill_box.bg_color = Color(0.94, 0.97, 0.99, 1)
	pill_box.set_corner_radius_all(12)
	pill_box.content_margin_left = 12
	pill_box.content_margin_right = 12
	pill_box.content_margin_top = 6
	pill_box.content_margin_bottom = 6
	btn_img.add_theme_stylebox_override("normal", pill_box)
	btn_img.add_theme_font_size_override("font_size", 12)
	btn_img.add_theme_color_override("font_color", Color(0.35, 0.48, 0.58, 1))
	c_actions.add_child(btn_img)
	
	var btn_voice = Button.new()
	btn_voice.text = "🔊 语音已开启"
	btn_voice.add_theme_stylebox_override("normal", pill_box)
	btn_voice.add_theme_font_size_override("font_size", 12)
	btn_voice.add_theme_color_override("font_color", Color(0.35, 0.48, 0.58, 1))
	c_actions.add_child(btn_voice)
	
	var act_sp = Control.new()
	act_sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c_actions.add_child(act_sp)
	
	var btn_send = Button.new()
	btn_send.text = "发送  ↑"
	btn_send.custom_minimum_size = Vector2(92, 34)
	var send_box = StyleBoxFlat.new()
	send_box.bg_color = Color(0.32, 0.74, 0.98, 1)
	send_box.set_corner_radius_all(17)
	send_box.border_width_left = 1
	send_box.border_width_top = 1
	send_box.border_width_right = 1
	send_box.border_width_bottom = 1
	send_box.border_color = Color(0.65, 0.88, 1.0, 0.7)
	send_box.shadow_color = Color(0.25, 0.68, 0.95, 0.3)
	send_box.shadow_size = 6
	send_box.shadow_offset = Vector2(0, 2)
	btn_send.add_theme_stylebox_override("normal", send_box)
	btn_send.add_theme_stylebox_override("hover", send_box)
	btn_send.add_theme_font_size_override("font_size", 13)
	btn_send.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	c_actions.add_child(btn_send)
	
	comp_vbox.add_child(c_actions)
	comp_panel.add_child(comp_vbox)
	r_col.add_child(comp_panel)
	
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/redesign-preview/new_chat_concept.png")
	print("CHAT_SAVED")
	quit(0)
"""

pathlib.Path("client-godot/tests/render_chat.gd").write_text(script, encoding="utf-8")
res = subprocess.run([godot, "--path", "client-godot", "--script", "res://tests/render_chat.gd"], capture_output=True, text=True)
print(res.stdout)
