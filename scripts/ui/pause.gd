extends CanvasLayer
## Menu tạm dừng: cài đặt (độ rung, độ nhạy chuột, âm lượng, đồ hoạ, độ khó), chế độ thần (cần mật khẩu), về màn hình chính.

var world: Node
var root: Control
var _god_btn: Button
var _god_row: HBoxContainer
var _god_edit: LineEdit
var _god_err: Label
var _labels: Dictionary = {}
var _quality_btn: Button
var _style_btn: Button
var _diff_btn: Button


func _ready() -> void:
	world = get_parent()
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func is_open() -> bool:
	return visible


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_god_row.visible = false
	_god_err.text = ""
	_update_labels()
	if not Net.is_online():
		get_tree().paused = true


func close() -> void:
	visible = false
	get_tree().paused = false
	Game.save_settings()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause") and get_tree().paused:
		close()
		get_viewport().set_input_as_handled()


func _label(text: String, size := 14, color := Color("ebe5d8")) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _slider(parent: Control, key: String, title: String, lo: float, hi: float, step: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var l := _label(title, 14)
	l.custom_minimum_size = Vector2(190, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Game.settings[key])
	s.custom_minimum_size = Vector2(220, 0)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var v := _label("", 13, Color("e4a03a"))
	v.custom_minimum_size = Vector2(60, 0)
	row.add_child(v)
	_labels[key] = v
	s.value_changed.connect(func(val: float) -> void:
		Game.settings[key] = val
		Game.apply_settings()
		_update_labels()
		var p: CharacterBody3D = world.local_player()
		if key == "fov" and p:
			p.camera.fov = val)


func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.make()
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.05, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(520, 0)
	margin.add_child(col)
	col.add_child(_label("TẠM DỪNG", 34))
	col.add_child(_label("Chơi chung thì thế giới vẫn chạy khi bạn mở menu này.", 12, Color("9a958b")))
	var resume := Button.new()
	resume.text = "▶  Tiếp tục   [Esc]"
	resume.theme_type_variation = "Primary"
	resume.custom_minimum_size = Vector2(0, 42)
	resume.pressed.connect(close)
	col.add_child(resume)

	col.add_child(_label("CÀI ĐẶT", 12, Color("9a958b")))
	_slider(col, "shake", "Độ rung màn hình", 0.0, 1.0, 0.05)
	_slider(col, "sens", "Độ nhạy chuột", 0.3, 2.5, 0.05)
	_slider(col, "volume", "Âm lượng", 0.0, 1.0, 0.05)
	_slider(col, "fov", "Góc nhìn", 60.0, 100.0, 1.0)
	_quality_btn = Button.new()
	_quality_btn.pressed.connect(func() -> void:
		Game.settings.quality = (int(Game.settings.quality) + 1) % 3
		world.weather.apply_quality()
		_update_labels())
	col.add_child(_quality_btn)
	_style_btn = Button.new()
	_style_btn.pressed.connect(func() -> void:
		Game.settings.style = 0 if Game.toon() else 1
		world.weather.apply_quality()
		_update_labels())
	col.add_child(_style_btn)
	_diff_btn = Button.new()
	_diff_btn.pressed.connect(func() -> void:
		Game.difficulty = {"easy": "normal", "normal": "hard", "hard": "easy"}[Game.difficulty]
		_update_labels())
	col.add_child(_diff_btn)

	_god_btn = Button.new()
	_god_btn.pressed.connect(_on_god_pressed)
	col.add_child(_god_btn)
	_god_row = HBoxContainer.new()
	col.add_child(_god_row)
	_god_edit = LineEdit.new()
	_god_edit.placeholder_text = "Mật khẩu chế độ thần"
	_god_edit.secret = true
	_god_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_god_edit.text_submitted.connect(func(_t: String) -> void: _try_god())
	_god_row.add_child(_god_edit)
	var ok := Button.new()
	ok.text = "Bật"
	ok.pressed.connect(_try_god)
	_god_row.add_child(ok)
	_god_err = _label("", 13, Color("cf4a3b"))
	col.add_child(_god_err)

	var menu := Button.new()
	menu.text = "Về màn hình chính"
	menu.theme_type_variation = "Quiet"
	menu.custom_minimum_size = Vector2(0, 42)
	menu.pressed.connect(func() -> void: world.back_to_menu())
	col.add_child(menu)
	col.add_child(_label("WASD đi · Shift chạy · C ngồi · Space nhảy · E nhặt / tương tác · Chuột trái đánh, bắn, dùng món trên tay · Chuột phải dùng món tay trái
Tab túi đồ · 1-4 hoặc lăn chuột đổi món · F đổi tay · Q ném · M bản đồ · V góc nhìn · L đèn pin · Z phóng bản đồ nhỏ", 12, Color("9a958b")))


func _update_labels() -> void:
	(_labels.shake as Label).text = "%d%%" % int(float(Game.settings.shake) * 100)
	(_labels.sens as Label).text = "x%.2f" % float(Game.settings.sens)
	(_labels.volume as Label).text = "%d%%" % int(float(Game.settings.volume) * 100)
	(_labels.fov as Label).text = "%d°" % int(Game.settings.fov)
	_quality_btn.text = "Đồ hoạ: %s" % ["Thấp", "Vừa", "Cao"][int(Game.settings.quality)]
	_style_btn.text = "Phong cách: %s" % ("Vẽ tay" if Game.toon() else "Tả thực")
	_diff_btn.text = "Độ khó: %s" % Game.diff().name
	_diff_btn.disabled = Net.is_online() and Net.mode != Net.Mode.HOST
	_god_btn.text = "Chế độ thần: %s" % ("Bật" if Game.god else "Tắt")


func _on_god_pressed() -> void:
	if Game.god:
		Game.god = false
		Game.fly = false
		Game.say("Chế độ thần: TẮT")
		_update_labels()
		return
	_god_row.visible = true
	_god_edit.text = ""
	_god_err.text = ""
	_god_edit.grab_focus()


func _try_god() -> void:
	if _god_edit.text.strip_edges() == Game.GOD_PASSWORD:
		Game.god = true
		_god_row.visible = false
		_god_err.text = ""
		Game.say("Chế độ thần: BẬT. G để bay, kho đồ trong Túi, nhấp đúp bản đồ để dịch chuyển.", "good")
		Game.inventory_changed.emit()
	else:
		_god_err.text = "Sai mật khẩu."
		Sfx.play("empty")
	_update_labels()
