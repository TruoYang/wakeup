extends CanvasLayer
## HUD: la bàn + mục tiêu, bản đồ nhỏ, chỉ báo quái vật, hình người thể hiện thương tích,
## vòng chỉ số, vũ khí đang cầm, lời nhắc tương tác, thông báo, và các lớp phủ (bị thương, dưới nước, bị săn).

const INK := Color("ebe5d8")
const DIM := Color("9a958b")
const FAINT := Color(0.92, 0.9, 0.85, 0.16)
const PANEL := Color(0.06, 0.07, 0.08, 0.72)
const AMBER := Color("e4a03a")
const RED := Color("cf4a3b")
const GREEN := Color("86b47f")
const BLUE := Color("73a5c6")
const INJURY_COLOR := {"bleed": Color("cf4a3b"), "fracture": Color("e08a3a"), "wound": Color("d06a5a"), "infect": Color("8fb04a"), "pain": Color("e4c03a")}

var world: Node
var canvas: Control
var font: Font
var toasts: Array[Dictionary] = []
var _hurt := 0.0
var _vignette: GradientTexture2D
var _t := 0.0
var _mini_zoom := 1.0


func _ready() -> void:
	world = get_parent()
	font = ThemeDB.fallback_font
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	canvas.draw.connect(_draw_hud)
	_build_minimap()
	Game.toast.connect(_on_toast)
	Game.hurt.connect(func(amount: float, _k: String) -> void: _hurt = minf(1.0, _hurt + amount / 30.0))
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 1))
	g.add_point(0.55, Color(1, 1, 1, 0))
	_vignette = GradientTexture2D.new()
	_vignette.gradient = g
	_vignette.fill = GradientTexture2D.FILL_RADIAL
	_vignette.fill_from = Vector2(0.5, 0.5)
	_vignette.fill_to = Vector2(1.0, 0.5)
	_vignette.width = 128
	_vignette.height = 128


func _on_toast(text: String, kind: String) -> void:
	for t in toasts:
		if t.text == text and t.life > 1.0:
			t.life = 5.0
			return
	toasts.append({"text": text, "kind": kind, "life": 4.5 if text.length() < 60 else 6.5})
	if toasts.size() > 4:
		toasts.pop_front()


func _process(delta: float) -> void:
	_t += delta
	_hurt = maxf(0.0, _hurt - delta * 0.9)
	for i in range(toasts.size() - 1, -1, -1):
		toasts[i].life -= delta
		if toasts[i].life <= 0.0:
			toasts.remove_at(i)
	if _sleep_t >= 0.0:
		_sleep_t += delta
		if _sleep_t >= 2.6 and not _sleep_sent:
			_sleep_sent = true
			world.request_sleep()
		if _sleep_t > 7.6:
			_sleep_t = -1.0
	if Input.is_action_just_pressed("map_zoom") and not world.ui_open():
		_mini_zoom = 2.0 if _mini_zoom < 1.5 else 1.0
	canvas.queue_redraw()


func _text(pos: Vector2, text: String, size := 14, color := INK, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	canvas.draw_string(font, pos + Vector2(1, 1), text, align, width, size, Color(0, 0, 0, 0.55 * color.a))
	canvas.draw_string(font, pos, text, align, width, size, color)


var _sb := StyleBoxFlat.new()


## Bảng nền bo tròn góc.
func _panel(rect: Rect2, color := PANEL, radius := 12) -> void:
	_sb.bg_color = color
	_sb.border_color = FAINT
	_sb.set_border_width_all(1)
	_sb.set_corner_radius_all(mini(radius, int(minf(rect.size.x, rect.size.y) * 0.5)))
	_sb.anti_aliasing = true
	canvas.draw_style_box(_sb, rect)


# ------------------------------------------------------------------ cảnh đi ngủ
var _sleep_t := -1.0
var _sleep_from := 22.0
var _sleep_sent := false


func sleeping() -> bool:
	return _sleep_t >= 0.0


## Nằm xuống giường: màn hình tối dần, đồng hồ quay tới 6 giờ sáng, rồi sáng dần.
func start_sleep() -> void:
	if _sleep_t >= 0.0:
		return
	_sleep_t = 0.0
	_sleep_sent = false
	_sleep_from = world.weather.hour
	Sfx.play("door", -10.0)


func _draw_sleep(size: Vector2) -> void:
	var t := _sleep_t
	var a := clampf(t / 2.2, 0.0, 1.0) if t < 5.2 else clampf(1.0 - (t - 5.2) / 2.3, 0.0, 1.0)
	# mí mắt khép lại từ trên xuống và dưới lên
	var lid := size.y * 0.5 * a * a
	canvas.draw_rect(Rect2(0, 0, size.x, lid + 2.0), Color.BLACK)
	canvas.draw_rect(Rect2(0, size.y - lid - 2.0, size.x, lid + 2.0), Color.BLACK)
	canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, a * 0.85))
	if t > 1.2 and t < 6.4:
		var ta := clampf((t - 1.2) / 0.8, 0.0, 1.0) * clampf((6.4 - t) / 0.8, 0.0, 1.0)
		var line := "Bạn nằm xuống. Bên ngoài, mặt đất vẫn rung lên từng nhịp…" if t < 3.0 else ("Đêm trôi qua." if t < 4.6 else "Trời sáng rồi.")
		_text(Vector2(0, size.y * 0.5 - 20), line, 22, Color(INK, ta), HORIZONTAL_ALIGNMENT_CENTER, size.x)
		# kim đồng hồ quay từ giờ đi ngủ tới 6 giờ sáng
		var k := clampf((t - 2.4) / 2.2, 0.0, 1.0)
		var span := fposmod(6.0 - _sleep_from, 24.0)
		var hr := fposmod(_sleep_from + span * k * k * (3.0 - 2.0 * k), 24.0)
		_text(Vector2(0, size.y * 0.5 + 34), "%02d:%02d" % [int(hr), int((hr - floorf(hr)) * 60.0)], 44, Color(AMBER, ta), HORIZONTAL_ALIGNMENT_CENTER, size.x)


func _draw_hud() -> void:
	var size := canvas.size
	var p: CharacterBody3D = world.local_player()
	_draw_overlays(size)
	if p == null:
		return
	if world.ui_open() or Game.won:
		mini_root.visible = false
		mini_top.visible = false
	if not world.ui_open() and not Game.won:
		_draw_compass(size, p)
		_draw_minimap(Vector2(104, 104), 84.0, p)
		_draw_awareness(size)
		_draw_body_and_vitals(size)
		_draw_hands(size)
		_draw_hotbar(size)
		_draw_scan(size)
		_draw_hold(size)
		_draw_center(size, p)
	_draw_toasts(size)
	if _sleep_t >= 0.0:
		_draw_sleep(size)


# ------------------------------------------------------------------ lớp phủ toàn màn hình
func _draw_overlays(size: Vector2) -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if Game.submerged:
		canvas.draw_rect(rect, Color(0.04, 0.26, 0.28, 0.42))
		if Game.breath < 35.0:
			canvas.draw_texture_rect(_vignette, rect, false, Color(0, 0, 0, (1.0 - Game.breath / 35.0) * 0.95))
	var low := clampf((35.0 - Game.hp) / 35.0, 0.0, 1.0) * (0.35 + 0.15 * sin(_t * 4.0))
	var a := maxf(_hurt * 0.75, low)
	if a > 0.01:
		canvas.draw_texture_rect(_vignette, rect, false, Color(0.75, 0.05, 0.03, a))
	if Game.hunted and not Game.dead:
		var pulse := 0.25 + 0.2 * sin(_t * 6.0)
		canvas.draw_texture_rect(_vignette, rect, false, Color(0.9, 0.3, 0.05, pulse * 0.5))
	if Game.dead:
		canvas.draw_rect(rect, Color(0.1, 0.0, 0.0, 0.45))


# ------------------------------------------------------------------ la bàn + mục tiêu
func _draw_compass(size: Vector2, p: CharacterBody3D) -> void:
	var w := minf(460.0, size.x * 0.42)
	var cx := size.x * 0.5
	var y := 22.0
	_panel(Rect2(cx - w * 0.5, y, w, 26))
	var yaw := p.global_rotation.y           # 0 = nhìn về -Z (bắc)
	var heading := -yaw
	var span := deg_to_rad(110.0)
	for i in 24:
		var ang := i * TAU / 24.0
		var d := wrapf(ang - heading, -PI, PI)
		if absf(d) > span * 0.5:
			continue
		var x := cx + d / span * w
		var major := i % 6 == 0
		canvas.draw_line(Vector2(x, y + (4 if major else 12)), Vector2(x, y + 22), INK if major else DIM, 2.0 if major else 1.0)
		if major:
			_text(Vector2(x - 20, y + 44), ["B", "Đ", "N", "T"][i / 6], 13, INK, HORIZONTAL_ALIGNMENT_CENTER, 40)
	canvas.draw_colored_polygon([Vector2(cx - 6, y - 2), Vector2(cx + 6, y - 2), Vector2(cx, y + 7)], AMBER)
	# dấu mục tiêu (chương 1: chỉ có sau khi Thủy Quái trồi lên)
	if not world.has_objective():
		var label0: String = Game.objective
		var tw0 := font.get_string_size(label0, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 30
		_panel(Rect2(cx - tw0 * 0.5, y + 52, tw0, 28))
		_text(Vector2(cx - tw0 * 0.5, y + 71), label0, 15, INK, HORIZONTAL_ALIGNMENT_CENTER, tw0)
		return
	var o: Vector3 = world.objective_pos()
	var to := o - p.global_position
	var bearing := atan2(to.x, -to.z)
	var dd := wrapf(bearing - heading, -PI, PI)
	var mx := cx + clampf(dd / span, -0.5, 0.5) * w
	canvas.draw_colored_polygon([Vector2(mx, y + 4), Vector2(mx + 7, y + 13), Vector2(mx, y + 22), Vector2(mx - 7, y + 13)], GREEN)
	# đồng đội
	for q in get_tree().get_nodes_in_group("players"):
		if q == p:
			continue
		var tq: Vector3 = q.global_position - p.global_position
		var dq := wrapf(atan2(tq.x, -tq.z) - heading, -PI, PI)
		if absf(dq) < span * 0.5:
			canvas.draw_circle(Vector2(cx + dq / span * w, y + 13), 4.0, BLUE)
	var dist := Vector2(to.x, to.z).length()
	var label := "%s  ·  %dm" % [Game.objective, int(dist)]
	var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 48
	_panel(Rect2(cx - tw * 0.5, y + 52, tw, 28))
	canvas.draw_circle(Vector2(cx - tw * 0.5 + 13, y + 66), 4.0, GREEN)
	_text(Vector2(cx - tw * 0.5 + 16, y + 71), label, 15, INK, HORIZONTAL_ALIGNMENT_CENTER, tw - 22)
	if Game.god:
		_text(Vector2(cx - 150, y + 104), "CHẾ ĐỘ THẦN · [G] BAY", 13, AMBER, HORIZONTAL_ALIGNMENT_CENTER, 300)


# ------------------------------------------------------------------ bản đồ nhỏ
const MINI := 204.0
var mini_root: Panel
var mini: Control
var mini_top: Control


## Bản đồ nhỏ hình tròn, cùng kiểu bản đồ giấy với bản đồ lớn. Nội dung được cắt gọn trong hình tròn.
func _build_minimap() -> void:
	mini_root = Panel.new()
	mini_root.position = Vector2(16, 16)
	mini_root.size = Vector2(MINI, MINI)
	mini_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("ffffff")
	sb.set_corner_radius_all(int(MINI * 0.5))
	sb.anti_aliasing = true
	mini_root.add_theme_stylebox_override("panel", sb)
	mini_root.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	add_child(mini_root)
	mini = Control.new()
	mini.set_anchors_preset(Control.PRESET_FULL_RECT)
	mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mini_root.add_child(mini)
	mini.draw.connect(_draw_mini)
	mini_top = Control.new()
	mini_top.position = Vector2(16, 16)
	mini_top.size = Vector2(MINI, MINI)
	mini_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mini_top)
	mini_top.draw.connect(_draw_mini_frame)


func _draw_mini() -> void:
	var p: CharacterBody3D = world.local_player()
	if p == null:
		return
	var city: City = world.city
	var c := Vector2(MINI, MINI) * 0.5
	var scale := 1.05 * _mini_zoom
	var pp := Vector2(p.global_position.x, p.global_position.z)
	var view := MINI * 0.5 / scale + 30.0
	var to := func(w: Vector2) -> Vector2: return c + (w - pp) * scale
	# khối nhà (vỉa hè) trên nền đường
	var pal := UiTheme.map_pal()
	var ink: Color = pal.ink
	mini.draw_rect(Rect2(Vector2.ZERO, Vector2(MINI, MINI)), pal.road)
	for r in City.ROWS:
		for cc in City.COLS:
			var bc := City.block_center(cc, r)
			if absf(bc.x - pp.x) > view + City.BW * 0.5 or absf(bc.z - pp.y) > view + City.BD * 0.5:
				continue
			var rect := Rect2(to.call(Vector2(bc.x - City.BW * 0.5, bc.z - City.BD * 0.5)), Vector2(City.BW, City.BD) * scale)
			mini.draw_rect(rect, pal.edge)
			mini.draw_rect(rect.grow(-1.0), UiTheme.cell_color(Vector2i(cc, r), pal))
	var lzr := City.zone_rect(City.LAKE_ZONE)
	mini.draw_rect(Rect2(to.call(lzr.position), lzr.size * scale), pal.grass)
	var prr := City.zone_rect(City.PARK_ZONE)
	var frr := City.zone_rect(City.FOREST_ZONE)
	mini.draw_rect(Rect2(to.call(prr.position), prr.size * scale), pal.field)
	mini.draw_rect(Rect2(to.call(frr.position), frr.size * scale), pal.forest)
	if scale > 0.9:
		for xf: Transform3D in city._tree_xf:
			if absf(xf.origin.x - pp.x) < view and absf(xf.origin.z - pp.y) < view and xf.basis.get_scale().x > 0.01:
				mini.draw_circle(to.call(Vector2(xf.origin.x, xf.origin.z)), 1.6 * scale, pal.tree)
	for hz: Rect2i in City.HOODS:
		var hr := City.zone_rect(hz)
		mini.draw_rect(Rect2(to.call(hr.position), hr.size * scale), pal.block)
		mini.draw_rect(Rect2(to.call(hr.position), hr.size * scale), pal.edge, false, 1.0)
	var lk: Rect2 = city.lake_rect
	mini.draw_rect(Rect2(to.call(lk.position), lk.size * scale), pal.lake)
	mini.draw_rect(Rect2(to.call(lk.position), lk.size * scale), pal.lake_edge, false, 1.2)
	for lr: Rect2 in city.lake_land:
		mini.draw_rect(Rect2(to.call(lr.position), lr.size * scale), pal.grass)
	# nhà
	for b in city.buildings:
		var rc: Rect2 = b.rect
		var ctr := rc.get_center()
		if absf(ctr.x - pp.x) > view or absf(ctr.y - pp.y) > view:
			continue
		var col := UiTheme.building_color(b, pal)
		if b.has("poly"):
			var pp2 := PackedVector2Array()
			for v: Vector2 in b.poly:
				pp2.append(to.call(v))
			mini.draw_colored_polygon(pp2, col)
			pp2.append(pp2[0])
			mini.draw_polyline(pp2, ink if ink.a > 0.0 else col.darkened(0.18), 1.0)
			continue
		var mrr := Rect2(to.call(rc.position), rc.size * scale).grow(-0.5)
		mini.draw_rect(mrr, col)
		mini.draw_rect(mrr, ink if ink.a > 0.0 else col.darkened(0.18), false, float(pal.ink_w))
	for er: Rect2 in city.extras:
		if absf(er.get_center().x - pp.x) < view and absf(er.get_center().y - pp.y) < view:
			mini.draw_rect(Rect2(to.call(er.position), er.size * scale), pal.extra)
	# đường sắt trên cao
	var rl: Rail = city.rail
	for i in range(1, rl.pts.size()):
		var a3 := rl.pts[i - 1]
		if absf(a3.x - pp.x) > view or absf(a3.z - pp.y) > view or rl.in_gap(rl.dist[i]):
			continue
		mini.draw_line(to.call(Vector2(a3.x, a3.z)), to.call(Vector2(rl.pts[i].x, rl.pts[i].z)), Color("4a4a50"), 4.0)
		mini.draw_line(to.call(Vector2(a3.x, a3.z)), to.call(Vector2(rl.pts[i].x, rl.pts[i].z)), Color("9fd0a8"), 1.5)
	for st: Dictionary in rl.stations:
		var spn := rl.frame(st.s).p as Vector3
		if absf(spn.x - pp.x) < view and absf(spn.z - pp.y) < view:
			mini.draw_circle(to.call(Vector2(spn.x, spn.z)), 5.0, Color("2a2a2e"))
			mini.draw_circle(to.call(Vector2(spn.x, spn.z)), 3.5, Color("5fb06a"))
	# đường bị chặn + khe nứt + cửa hầm
	for br: Rect2 in city.barricades:
		mini.draw_rect(Rect2(to.call(br.position), br.size * scale), Color("c8685a"))
	for ch in city.chasms:
		mini.draw_rect(Rect2(to.call((ch.rect as Rect2).position), (ch.rect as Rect2).size * scale), Color("3a2a24"))
	for ex: float in city.tunnel.entrances:
		var ep: Vector2 = to.call(Vector2(ex + 3.0, city.tunnel.z))
		mini.draw_circle(ep, 6.5, Color(0, 0, 0, 0.65))
		mini.draw_circle(ep, 5.0, Color("3a7a9a"))
		mini.draw_arc(ep, 5.0, 0, TAU, 16, Color.WHITE, 1.2)
		mini.draw_string(font, ep + Vector2(-4, 4), "H", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)
	# đường gợi ý
	if world.has_objective():
		var route := city.guide_route(p.global_position, world.objective_pos())
		var line2 := PackedVector2Array()
		for rp: Vector3 in route:
			line2.append(to.call(Vector2(rp.x, rp.z)))
		mini.draw_polyline(line2, Color(1, 1, 1, 0.95), 6.0, true)
		dash_poly(mini, line2, Color("1a73e8"), 3.5, 8.0)
	# xe máy còn chạy
	for bk in world.bikes.list:
		if bk.rider == 0 and not bk.broken and absf(bk.pos.x - pp.x) < view and absf(bk.pos.z - pp.y) < view:
			mini.draw_circle(to.call(Vector2(bk.pos.x, bk.pos.z)), 2.6, Color("d9a24a"))
	# quái vật (cần đeo đồng hồ định vị)
	if Game.has_watch():
		for m: Monster in world.monsters.list:
			if m.state == "dormant":
				continue
			var mp: Vector2 = to.call(Vector2(m.global_position.x, m.global_position.z))
			if m.kind == "crawler":        # quái nhỏ: chỉ là một chấm đỏ khi ở trong tầm
				if m.state != "dead" and (mp - c).length() < MINI * 0.5 - 6.0:
					mini.draw_circle(mp, 4.5, Color(0.1, 0.05, 0.05))
					mini.draw_circle(mp, 3.2, Color(0.9, 0.25, 0.18))
				continue
			var d := mp - c
			if d.length() > MINI * 0.5 - 12.0:
				mp = c + d.normalized() * (MINI * 0.5 - 12.0)     # ở ngoài tầm: ghim vào mép để biết hướng
			if Game.god:        # vòng tầm nhìn chỉ hiện ở chế độ thần
				mini.draw_circle(mp, 16.0, Color(0.85, 0.2, 0.16, 0.16))
				mini.draw_arc(mp, 16.0, 0, TAU, 24, Color(0.8, 0.16, 0.12, 0.7), 1.5)
			var tex := Items.icon("mon_" + ("wander" if m.kind == "grub" else m.kind))
			if tex:
				mini.draw_texture_rect(tex, Rect2(mp - Vector2(10, 10), Vector2(20, 20)), false)
	# đồng đội
	for q in get_tree().get_nodes_in_group("players"):
		if q != p:
			var qp: Vector2 = to.call(Vector2(q.global_position.x, q.global_position.z))
			mini.draw_circle(qp, 6.0, Color("111111"))
			mini.draw_circle(qp, 4.5, Color("73a5c6"))
	# mục tiêu (ngoài tầm thì ghim vào mép)
	if world.has_objective():
		var o: Vector3 = world.objective_pos()
		var op: Vector2 = to.call(Vector2(o.x, o.z))
		var od := op - c
		if od.length() > MINI * 0.5 - 14.0:
			op = c + od.normalized() * (MINI * 0.5 - 14.0)
		mini.draw_circle(op, 8.5, Color(0, 0, 0, 0.65))
		mini.draw_circle(op, 6.5, Color("d98a1a"))
		mini.draw_arc(op, 6.5, 0, TAU, 20, Color.WHITE, 1.4)
		mini.draw_arc(op, 11.0 + 2.0 * sin(_t * 4.0), 0, TAU, 20, Color("1a73e8"), 2.0)
	# người chơi: mũi tên trắng viền đen
	var f := Vector2(-sin(p.global_rotation.y), -cos(p.global_rotation.y))
	var sd := Vector2(-f.y, f.x)
	mini.draw_colored_polygon([c + f * 13.0, c - f * 9.0 + sd * 8.5, c - f * 4.0, c - f * 9.0 - sd * 8.5], Color.WHITE)
	mini.draw_colored_polygon([c + f * 10.5, c - f * 7.0 + sd * 6.3, c - f * 3.0, c - f * 7.0 - sd * 6.3], Color("1a73e8"))


func _draw_mini_frame() -> void:
	var c := Vector2(MINI, MINI) * 0.5
	mini_top.draw_arc(c, MINI * 0.5 - 1.0, 0, TAU, 64, Color(0.07, 0.08, 0.09), 5.0, true)
	mini_top.draw_arc(c, MINI * 0.5 - 3.5, 0, TAU, 64, Color(0.92, 0.9, 0.85, 0.22), 1.0, true)
	# chữ B (bắc) trên mép
	mini_top.draw_circle(c + Vector2(0, -MINI * 0.5 + 3.0), 9.0, Color("111111"))
	mini_top.draw_string(font, c + Vector2(-10, -MINI * 0.5 + 7.0), "B", HORIZONTAL_ALIGNMENT_CENTER, 20, 11, Color("ebe5d8"))


## Dòng chữ dưới bản đồ nhỏ: giờ, thời tiết, đồng hồ, phòng chơi.
func _draw_minimap(_c: Vector2, _r: float, _p: CharacterBody3D) -> void:
	var show: bool = not world.ui_open() and not Game.won
	mini_root.visible = show
	mini_top.visible = show
	mini.queue_redraw()
	var x := 22.0
	var y := 16.0 + MINI + 22.0
	var clock: String = world.weather.clock_text() if Game.has_clock() else world.weather.part_of_day()
	_panel(Rect2(x - 6, y - 16, MINI, 44 if not Net.is_online() else 78), PANEL, 12)
	_text(Vector2(x + 4, y), "%s · %s" % [clock, world.weather.kind_name()], 13, INK)
	_text(Vector2(x + 4, y + 18), "Đồng hồ định vị: hiện quái vật" if Game.has_watch() else "Chưa đeo đồng hồ định vị", 11, AMBER if Game.has_watch() else DIM)
	if Net.is_online():
		var names := PackedStringArray()
		for id: int in Net.players:
			names.append(str(Net.players[id]))
		_text(Vector2(x + 4, y + 36), "Phòng %d/%d: %s" % [Net.players.size(), Net.MAX_PLAYERS, ", ".join(names)], 11, BLUE)
		if Net.mode == Net.Mode.HOST:
			_text(Vector2(x + 4, y + 52), "IP: " + ", ".join(Net.local_addresses()), 10, DIM)


# ------------------------------------------------------------------ chỉ báo bị phát hiện + tiếng ồn
func _draw_awareness(size: Vector2) -> void:
	var x := size.x - 250.0
	var y := 22.0
	_panel(Rect2(x, y, 228, 62))
	var a := Game.awareness
	var label := "AN TOÀN"
	var col := GREEN
	if Game.hunted:
		label = "ĐANG BỊ SĂN"
		col = RED
	elif a > 0.05:
		label = "CÓ THỨ NGHE THẤY BẠN" if Game.sense == "hear" else "CÓ THỨ NHÌN THẤY BẠN"
		col = AMBER.lerp(RED, a)
	# con mắt
	var ec := Vector2(x + 34, y + 31)
	var pts := PackedVector2Array()
	for i in 25:
		var t := i / 24.0
		pts.append(ec + Vector2(lerpf(-22, 22, t), -sin(t * PI) * 12.0))
	for i in 25:
		var t2 := 1.0 - i / 24.0
		pts.append(ec + Vector2(lerpf(-22, 22, t2), sin(t2 * PI) * 12.0))
	canvas.draw_polyline(pts, col, 2.0, true)
	var open := 3.0 + a * 7.0 + (2.0 * sin(_t * 8.0) if Game.hunted else 0.0)
	canvas.draw_circle(ec, open, col)
	_text(Vector2(x + 66, y + 24), label, 12, col)
	# thanh tiếng ồn 6 vạch
	_text(Vector2(x + 66, y + 48), "TIẾNG ỒN", 10, DIM)
	for i in 6:
		var on := Game.noise > (i + 0.5) / 6.5
		canvas.draw_circle(Vector2(x + 134 + i * 15, y + 44), 5.0, (AMBER if i < 4 else RED) if on else FAINT)


# ------------------------------------------------------------------ hình người + chỉ số
func _part_color(part: String) -> Color:
	var worst := ""
	for inj in Game.injuries:
		if inj.part == part:
			if worst == "" or ["pain", "wound", "infect", "fracture", "bleed"].find(inj.type) > ["pain", "wound", "infect", "fracture", "bleed"].find(worst):
				worst = inj.type
	if worst == "":
		return Color(0.92, 0.9, 0.85, 0.3)
	var c: Color = INJURY_COLOR[worst]
	return c.lerp(Color.WHITE, 0.25 + 0.25 * sin(_t * 5.0)) if worst == "bleed" else c


func _pill(rect: Rect2, color: Color, radius: int) -> void:
	_sb.bg_color = color
	_sb.set_border_width_all(0)
	_sb.set_corner_radius_all(radius)
	canvas.draw_style_box(_sb, rect)


func _ring(c: Vector2, r: float, value: float, color: Color, label: String) -> void:
	canvas.draw_circle(c, r + 4, PANEL)
	canvas.draw_arc(c, r, 0, TAU, 40, FAINT, 5.0)
	var v := clampf(value / 100.0, 0.0, 1.0)
	if v > 0.005:
		var col := color if value > 25.0 else color.lerp(RED, 0.5 + 0.5 * sin(_t * 6.0))
		canvas.draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * v, 40, col, 5.0, true)
	_text(Vector2(c.x - r, c.y + 5), str(int(ceilf(value))), 15, INK, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0)
	_text(Vector2(c.x - r - 6, c.y + r + 18), label, 10, DIM, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0 + 12)


func _draw_body_and_vitals(size: Vector2) -> void:
	var x := 22.0
	var y := size.y - 168.0
	_panel(Rect2(x, y, 96, 146))
	# hình người: đầu, thân, tay, chân
	var bx := x + 48.0
	var by := y + 14.0
	canvas.draw_circle(Vector2(bx, by + 10), 10.0, _part_color("head"))
	_pill(Rect2(bx - 15, by + 23, 30, 42), _part_color("torso"), 9)
	_pill(Rect2(bx - 27, by + 24, 9, 40), _part_color("arm_l"), 5)
	_pill(Rect2(bx + 18, by + 24, 9, 40), _part_color("arm_r"), 5)
	_pill(Rect2(bx - 15, by + 68, 13, 50), _part_color("leg_l"), 6)
	_pill(Rect2(bx + 2, by + 68, 13, 50), _part_color("leg_r"), 6)
	# các vòng chỉ số
	var ry := size.y - 64.0
	_ring(Vector2(x + 148, ry), 24.0, Game.hp, RED, "MÁU")
	_ring(Vector2(x + 216, ry), 24.0, Game.food, AMBER, "ĐÓI")
	_ring(Vector2(x + 284, ry), 24.0, Game.water, BLUE, "KHÁT")
	# sức bền
	var sw := 190.0
	_pill(Rect2(x + 124, size.y - 113, sw, 7), FAINT, 4)
	_pill(Rect2(x + 124, size.y - 113, maxf(7.0, sw * Game.stamina / 100.0), 7), INK if Game.stamina > 20.0 else RED, 4)
	_text(Vector2(x + 124, size.y - 118), "SỨC", 10, DIM)
	# hơi thở (chỉ hiện khi đang nín thở)
	if Game.breath < 99.0:
		_pill(Rect2(x + 124, size.y - 137, sw, 7), FAINT, 4)
		_pill(Rect2(x + 124, size.y - 137, maxf(7.0, sw * Game.breath / 100.0), 7), BLUE if Game.breath > 30.0 else RED, 4)
		_text(Vector2(x + 124, size.y - 142), "HƠI THỞ", 10, BLUE)
	# danh sách thương tích + cách chữa
	var iy := y - 10.0
	var shown := 0
	for inj in Game.injuries:
		if shown >= 4:
			break
		var col: Color = INJURY_COLOR[inj.type]
		var line := "%s · %s  →  %s" % [Game.INJURY_NAMES[inj.type], Game.PART_NAMES[inj.part].to_lower(), Game.INJURY_CURE[inj.type]]
		canvas.draw_circle(Vector2(x + 2, iy - 4), 3.0, col)
		_text(Vector2(x + 9, iy), line, 12, col)
		iy -= 20.0
		shown += 1


func _draw_hold(size: Vector2) -> void:
	if Game.hold_label == "":
		return
	var w := 320.0
	var r := Rect2(size.x * 0.5 - w * 0.5, size.y * 0.5 + 60.0, w, 14.0)
	canvas.draw_rect(r.grow(3.0), Color(0, 0, 0, 0.6))
	canvas.draw_rect(Rect2(r.position, Vector2(w * clampf(Game.hold_prog, 0.0, 1.0), r.size.y)), Color("e3a23a"))
	_text(Vector2(r.position.x, r.position.y - 8.0), Game.hold_label, 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, w)


func _draw_scan(_size: Vector2) -> void:
	if world.play_time > world.scan_until:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var a := clampf((world.scan_until - world.play_time) / 4.0, 0.0, 1.0)
	for m: Array in world.scan_marks:
		var wp: Vector3 = (m[0] as Vector3) + Vector3(0, 0.3, 0)
		if cam.is_position_behind(wp):
			continue
		var sp := cam.unproject_position(wp)
		var col: Color = {"food": Color("e3a23a"), "drink": Color("5aa8e0"), "med": Color("e05a5a")}[m[1]]
		col.a = a
		canvas.draw_circle(sp, 7.0, Color(0, 0, 0, 0.5 * a))
		canvas.draw_circle(sp, 5.0, col)
		var d := cam.global_position.distance_to(wp)
		_text(sp + Vector2(9, 4), "%dm" % int(d), 11, Color(1, 1, 1, a))


# ------------------------------------------------------------------ thanh công cụ (kiểu Minecraft)
func _draw_hotbar(size: Vector2) -> void:
	var cell := 54.0
	var gap := 6.0
	var total := cell * 5 + gap * 4 + 14.0
	var x0 := size.x * 0.5 - total * 0.5
	var y := size.y - cell - 20.0
	for k in 5:
		var off := k == 0
		var x := x0 + k * (cell + gap) + (0.0 if off else 14.0)
		var id: String = Game.offhand if off else Game.hotbar[k - 1]
		var sel := not off and Game.hot_sel == k - 1
		var r := Rect2(x, y, cell, cell)
		_panel(r, Color(0.08, 0.09, 0.1, 0.72) if not sel else Color(0.2, 0.17, 0.1, 0.85), 10)
		if sel:
			canvas.draw_rect(r.grow(1.5), AMBER, false, 2.5)
		if id != "":
			var tex := Items.icon(id)
			if tex:
				canvas.draw_texture_rect(tex, r.grow(-7.0), false)
			var n := Game.count(id)
			if n > 1:
				_text(Vector2(x + cell - 20, y + cell - 6), str(n), 12, INK)
		_text(Vector2(x + 5, y + 14), "F" if off else str(k), 11, DIM)
	_text(Vector2(x0, y - 6), "Tay trái", 10, DIM)


# ------------------------------------------------------------------ vũ khí, tiền, cân nặng
func _draw_hands(size: Vector2) -> void:
	var w := 230.0
	var x := size.x - w - 22.0
	var y := size.y - 96.0
	_panel(Rect2(x, y, w, 74))
	var weapon: String = Game.equip.weapon
	if weapon != "":
		var tex := Items.icon(weapon)
		if tex:
			canvas.draw_texture_rect(tex, Rect2(x + 8, y + 8, 58, 58), false)
		var def := Items.get_def(weapon)
		_text(Vector2(x + 74, y + 26), def.n, 14, INK)
		var sub := ""
		if def.has("gun"):
			sub = "Đạn: %d" % Game.ammo
		elif def.has("throwable"):
			sub = "Còn %d · [Q] ném" % Game.count(weapon)
		elif def.has("light"):
			sub = "Chuột trái: bật/tắt đèn"
		elif def.get("cat", "") in ["food", "drink", "med"]:
			sub = "Chuột trái: dùng"
		elif def.has("scan"):
			sub = "Chuột trái: quét đồ quanh đây"
		else:
			sub = ("Còn %d lần đánh" % Game.weapon_uses) if def.has("dur") else "Không hỏng"
		_text(Vector2(x + 74, y + 44), sub, 12, AMBER)
	else:
		_text(Vector2(x + 12, y + 26), "Tay không", 14, DIM)
		var th := Game.count("phao") + Game.count("chai")
		if th > 0:
			_text(Vector2(x + 12, y + 44), "[Q] ném pháo/chai (%d)" % th, 12, AMBER)
	var pl: CharacterBody3D = world.local_player()
	if pl and pl.riding_bike():
		_panel(Rect2(x, y - 34, w, 28))
		_text(Vector2(x + 12, y - 15), "XE MÁY · xăng %d%% · [E] xuống xe" % int(pl.bike_fuel), 12, AMBER if pl.bike_fuel > 15.0 else RED)
	_text(Vector2(x + 74 if weapon != "" else x + 12, y + 62), "%.1f/%dkg · %s đ" % [Game.weight(), int(Game.capacity()), Game.format_money(Game.money)], 11, DIM)


# ------------------------------------------------------------------ tâm ngắm, lời nhắc
func _draw_center(size: Vector2, p: CharacterBody3D) -> void:
	var c := size * 0.5
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		canvas.draw_circle(c, 2.5, Color(0, 0, 0, 0.5))
		canvas.draw_circle(c, 1.6, INK)
	else:
		_text(Vector2(c.x - 300, c.y + 60), "Nhấp chuột để điều khiển", 16, INK, HORIZONTAL_ALIGNMENT_CENTER, 600)
	var target: Dictionary = p.target
	if not target.is_empty():
		var label := "[E]  " + str(target.label)
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 26
		_panel(Rect2(c.x - tw * 0.5, c.y + 34, tw, 28))
		_text(Vector2(c.x - tw * 0.5, c.y + 53), label, 15, INK, HORIZONTAL_ALIGNMENT_CENTER, tw)
		# khung ngắm quanh vật thể
		var cam := get_viewport().get_camera_3d()
		if cam and not cam.is_position_behind(target.pos):
			var sp := cam.unproject_position(target.pos)
			var k := 16.0 + 2.0 * sin(_t * 5.0)
			for sx: float in [-1.0, 1.0]:
				for sy: float in [-1.0, 1.0]:
					var corner := sp + Vector2(sx, sy) * k
					canvas.draw_line(corner, corner - Vector2(sx * 8.0, 0), AMBER, 2.0)
					canvas.draw_line(corner, corner - Vector2(0, sy * 8.0), AMBER, 2.0)
	if p.swimming:
		_text(Vector2(c.x - 300, size.y - 150), "Space: nổi lên · C: lặn xuống · nhìn xuống + W: bơi xuống · sát bờ giữ Space để leo lên", 12, DIM, HORIZONTAL_ALIGNMENT_CENTER, 600)


## Thông báo và lời thoại: một cột hẹp bên phải, dưới bảng cảnh giác, không che giữa màn hình.
func _draw_toasts(size: Vector2) -> void:
	var w := 380.0
	var x := size.x - w - 22.0
	var y := 100.0
	var shown := 0
	for i in range(toasts.size() - 1, -1, -1):
		if shown >= 4:
			break
		shown += 1
		var t: Dictionary = toasts[i]
		var a := clampf(float(t.life) / 0.6, 0.0, 1.0)
		var col := INK
		if t.kind == "bad":
			col = Color("f0a090")
		elif t.kind == "good":
			col = Color("b0d8a8")
		var text: String = t.text
		var lines := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, w - 30, 13)
		var hgt := lines.y + 14
		_panel(Rect2(x, y, w, hgt), Color(0.06, 0.07, 0.08, 0.74 * a), 10)
		canvas.draw_circle(Vector2(x + 12, y + 14), 3.5, Color(col, a))
		canvas.draw_multiline_string(font, Vector2(x + 24, y + 19), text, HORIZONTAL_ALIGNMENT_LEFT, w - 34, 13, -1, Color(col, a))
		y += hgt + 6


## Vẽ nét đứt dọc theo cả đường gấp khúc (nét không bị ngắt lại ở mỗi khúc cua).
static func dash_poly(ci: CanvasItem, pts: PackedVector2Array, col: Color, width: float, dash: float) -> void:
	var on := true
	var left := dash
	for k in pts.size() - 1:
		var a := pts[k]
		var b := pts[k + 1]
		var seg := a.distance_to(b)
		var pos := 0.0
		while pos < seg:
			var step := minf(left, seg - pos)
			if on:
				ci.draw_line(a.lerp(b, pos / seg), a.lerp(b, (pos + step) / seg), col, width)
			pos += step
			left -= step
			if left <= 0.001:
				on = not on
				left = dash
