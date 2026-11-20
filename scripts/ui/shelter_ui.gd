extends CanvasLayer
## Giao diện Chương 2: sổ ghi buổi sáng, bảng chia khẩu phần, sự kiện ở cửa hầm, lựa chọn ban đêm, màn chuyển cảnh.

const INK := Color("ece8df")
const DIM := Color("a09a8e")
const AMBER := Color("e3a23a")

var sh: Node3D
var root: Control
var _panel: PanelContainer
var _box: VBoxContainer
var _fade: ColorRect
var _fade_label: Label
var _open := false


func setup(shelter: Node3D) -> void:
	sh = shelter
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.make()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.02, 0.02, 0.03, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(760, 0)
	center.add_child(_panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	_panel.add_child(margin)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 12)
	margin.add_child(_box)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	_fade_label = Label.new()
	_fade_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fade_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fade_label.add_theme_font_size_override("font_size", 44)
	_fade_label.add_theme_color_override("font_color", INK)
	_fade_label.modulate.a = 0.0
	_fade.add_child(_fade_label)
	root.visible = false


func is_open() -> bool:
	return _open


func close_all() -> void:
	_open = false
	root.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _begin(title: String, sub := "") -> void:
	for c in _box.get_children():
		c.queue_free()
	_open = true
	root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 30)
	t.add_theme_color_override("font_color", INK)
	_box.add_child(t)
	if sub != "":
		var s := Label.new()
		s.text = sub
		s.add_theme_font_size_override("font_size", 13)
		s.add_theme_color_override("font_color", AMBER)
		_box.add_child(s)


func _text(body: String) -> void:
	var l := Label.new()
	l.text = body
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(700, 0)
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", INK)
	l.add_theme_constant_override("line_spacing", 5)
	_box.add_child(l)


func _button(label: String, cb: Callable, primary := false, enabled := true) -> Button:
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(700, 40)
	b.disabled = not enabled
	if primary:
		b.theme_type_variation = "Primary"
	b.pressed.connect(func() -> void:
		Sfx.play("ui_click", -6.0)
		cb.call())
	_box.add_child(b)
	return b


# ------------------------------------------------------------------ sổ ghi / radio
## button rỗng: máy này không phải chủ phòng, chỉ đọc và chờ.
func show_journal(title: String, body: String, button: String, cb: Callable) -> void:
	_begin(title, sh.summary())
	_text(body)
	if button != "":
		_button(button, cb, true)
	else:
		_note("Chờ chủ phòng bắt đầu ngày mới…")
		_button("Đóng sổ", close_all)


func _note(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(700, 0)
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", DIM)
	_box.add_child(l)


# ------------------------------------------------------------------ sự kiện
func show_event() -> void:
	var ev: Dictionary = sh.current
	if ev.is_empty():
		return
	var kind: String = sh._event_kind
	_begin(ev.title, "Đêm thứ %d · ở cửa hầm" % sh.day if kind == "night" else ("Buổi sáng ngày %d" % sh.day if kind == "morning" else "Ngoài phố, trong đêm"))
	_text(sh.current_text)
	if sh.current_done:
		if sh._local_event or sh.is_host():
			_button("Tiếp tục", sh.continue_after_event, true)
		else:
			_note("Chờ chủ phòng bấm tiếp tục…")
		return
	var shared: bool = not sh._local_event and sh._peers().size() > 1
	var tally: Dictionary = {}
	for p: int in sh.votes:
		tally[sh.votes[p]] = int(tally.get(sh.votes[p], 0)) + 1
	var choices: Array = ev.choices
	for i in choices.size():
		var ch: Dictionary = choices[i]
		if sh.disabled.has(i):
			continue
		var ok: bool = not ch.has("need") or sh.need_ok(ch.need)
		var label: String = ("🔍  " if ch.get("info", false) else "▸  ") + str(ch.t)
		if not ok:
			label += "   (%s)" % sh.need_text(ch.need)
		if tally.has(i):
			label += "    ✋ %d phiếu" % int(tally[i])
		var mine: bool = int(sh.votes.get(sh.my_id(), -1)) == i
		_button(label, sh.vote.bind(i), mine, ok)
	if shared:
		_note("Cả phòng bỏ phiếu (%d/%d đã chọn). Hoà phiếu thì theo chủ phòng. Dò xét (🔍) thì ai bấm cũng được." % [sh.votes.size(), sh._peers().size()])


# ------------------------------------------------------------------ cuốn sổ chia khẩu phần (chủ phòng ghi, cả phòng cùng xem)
func show_rations() -> void:
	var host: bool = sh.is_host()
	var plan: Dictionary = sh.plan
	_begin("SỔ CHIA KHẨU PHẦN", "Ngày %d · mỗi người nhịn ăn được vài ngày, nhịn uống thì ít hơn. Chia xong là trời tối." % sh.day)
	if not host:
		_note("Chủ phòng đang ghi sổ. Bạn nhìn thấy từng dòng họ đánh dấu.")
	var used_f := 0
	var used_w := 0
	var used_m := 0
	for id: String in plan:
		used_f += 1 if plan[id].eat else 0
		used_w += 1 if plan[id].drink else 0
		used_m += 1 if plan[id].med else 0
	var stock := Label.new()
	stock.text = "Trong kho:  đồ ăn %d (dùng %d)   ·   nước %d (dùng %d)   ·   kháng sinh %d (dùng %d)" % [sh.food, used_f, sh.water, used_w, int(sh.meds.get("khangsinh", 0)), used_m]
	stock.add_theme_color_override("font_color", AMBER)
	_box.add_child(stock)
	for f: Dictionary in sh.family:
		if not f.alive or not plan.has(f.id):
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_box.add_child(row)
		var name_l := Label.new()
		name_l.text = "%s%s\n%s" % [f.name, "  (bạn)" if int(f.get("peer", 0)) == sh.my_id() else "", sh.status_of(f)]
		name_l.custom_minimum_size = Vector2(330, 0)
		name_l.add_theme_font_size_override("font_size", 15)
		name_l.add_theme_color_override("font_color", Color("e08a7a") if (f.sick or int(f.hunger) >= 3 or int(f.thirst) >= 2) else INK)
		row.add_child(name_l)
		for key: String in ["eat", "drink", "med"]:
			if key == "med" and not f.sick:
				continue
			var b := Button.new()
			var on: bool = plan[f.id][key]
			b.text = ("✔ " if on else "") + {"eat": "Ăn", "drink": "Uống", "med": "Kháng sinh"}[key]
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(112, 40)
			if on:
				b.theme_type_variation = "Primary"
			var left: int = {"eat": sh.food - used_f, "drink": sh.water - used_w, "med": int(sh.meds.get("khangsinh", 0)) - used_m}[key]
			b.disabled = not host or (not on and left <= 0)
			var fid: String = f.id
			b.pressed.connect(func() -> void:
				Sfx.play("ui_click", -8.0)
				sh.set_plan(fid, key, not on))
			row.add_child(b)
	if not sh.guests.is_empty():
		_note("Người ở nhờ (%s) ăn chung: cứ hai ngày hết một phần ăn và một phần nước mỗi người." % ", ".join(sh.guests.map(func(x: Dictionary) -> String: return str(x.name))))
	if host:
		_button("Chia xong. Cả nhà đi ngủ.", func() -> void: sh.confirm_rations(sh.plan), true)
		_button("Để sau", sh.close_rations)
	else:
		_button("Đóng sổ (chủ phòng vẫn đang ghi)", close_all)


# ------------------------------------------------------------------ đêm: ngủ hay ra ngoài
func show_night_choice() -> void:
	_begin("ĐÊM THỨ %d" % sh.day, sh.summary())
	_text("Căn hầm đã yên. Mai và con đã ngủ.\n\nBên trên, thành phố mất điện hoàn toàn: chỉ còn ánh trăng soi được vài con phố, phần còn lại tối như mực. Đèn pin soi được đường, nhưng cũng báo cho mọi thứ biết bạn đang ở đâu.")
	if sh._peers().size() > 1:
		_note("Mỗi người tự chọn. Ai ra ngoài thì lúc về phải gõ cửa, người ở lại quyết định mở hay không. Không phải tiếng gõ nào cũng là người thật: hãy hỏi nhau qua kênh thoại trước khi mở.")
	_button("Ngủ tới sáng (ở lại canh hầm)", func() -> void: sh.night_pick("sleep"), true)
	_button("Cầm đèn pin, leo lên tìm đồ (về trước khi trời sáng)", func() -> void: sh.night_pick("out"))


func show_wait() -> void:
	var outs: Array[String] = []
	for p: int in sh.night:
		if sh.night[p] == "out":
			outs.append(str(sh.member_of_peer(p).get("name", "?")))
	if outs.is_empty():
		close_all()
		return
	# không chiếm màn hình: người ở lại vẫn đi lại trong hầm được
	close_all()
	Game.say("Đang ở ngoài: %s. Đêm kết thúc khi mọi người đã về hầm. (Tới thang nếu bạn cũng muốn ra ngoài.)" % ", ".join(outs))


func show_knock(who: String) -> void:
	_begin("CÓ TIẾNG GÕ CỬA HẦM", "Đêm thứ %d" % sh.day)
	_text("Ba tiếng gõ lên nắp hầm.\n\n— %s đây. Mở cửa, về rồi.\n\nĐúng giọng của %s. Nhưng đêm nay, giọng nói thì chưa đủ để tin." % [who, who])
	_note("Hỏi lại %s qua kênh thoại của các bạn xem có đúng họ đang đứng ở cửa hầm không." % who)
	_button("Mở cửa cho %s" % who, func() -> void: sh.answer_knock(true), true)
	_button("Không mở", func() -> void: sh.answer_knock(false))


# ------------------------------------------------------------------ chuyển cảnh
func fade(text: String) -> void:
	_fade_label.text = text
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.5)
	tw.parallel().tween_property(_fade_label, "modulate:a", 1.0, 0.5)
	tw.tween_interval(1.4)
	tw.tween_property(_fade, "color:a", 0.0, 0.6)
	tw.parallel().tween_property(_fade_label, "modulate:a", 0.0, 0.4)
