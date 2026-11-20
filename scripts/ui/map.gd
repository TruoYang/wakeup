extends CanvasLayer

const HudScript := preload("res://scripts/ui/hud.gd")
## Bản đồ lớn: phóng to/thu nhỏ bằng con lăn, kéo để di chuyển. Chế độ thần: nhấp đúp để dịch chuyển.

const INK := Color("ebe5d8")
const DIM := Color("9a958b")

var world: Node
var canvas: Control
var font: Font
var zoom := 2.6
var center := Vector2.ZERO
var _drag := false


func _ready() -> void:
	world = get_parent()
	font = ThemeDB.fallback_font
	visible = false
	canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(canvas)
	canvas.draw.connect(_draw_map)
	canvas.gui_input.connect(_on_input)


func is_open() -> bool:
	return visible


func open() -> void:
	var p: CharacterBody3D = world.local_player()
	if p:
		center = Vector2(p.global_position.x, p.global_position.z)
	zoom = 2.6
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.play("ui_open", -10.0)


func close() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	if visible:
		canvas.queue_redraw()


func _to_screen(w: Vector2) -> Vector2:
	return canvas.size * 0.5 + (w - center) * zoom


func _to_world(s: Vector2) -> Vector2:
	return center + (s - canvas.size * 0.5) / zoom


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(event.position, 1.2)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(event.position, 1.0 / 1.2)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_drag = event.pressed
			if event.pressed and event.double_click and Game.god:
				var w := _to_world(event.position)
				var p: CharacterBody3D = world.local_player()
				if p:
					p.global_position = Vector3(w.x, 0.4 if not Game.fly else maxf(p.global_position.y, 20.0), w.y)
					p.velocity = Vector3.ZERO
					Game.say("Đã dịch chuyển.")
	elif event is InputEventMouseMotion and _drag:
		center -= event.relative / zoom


func _zoom_at(pos: Vector2, factor: float) -> void:
	var before := _to_world(pos)
	zoom = clampf(zoom * factor, 1.4, 9.0)
	center += before - _to_world(pos)


func _text(pos: Vector2, text: String, size := 13, color := INK, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	canvas.draw_string(font, pos + Vector2(1, 1), text, align, width, size, Color(0, 0, 0, 0.6))
	canvas.draw_string(font, pos, text, align, width, size, color)


func _dashed(a: Vector2, b: Vector2, color: Color, width := 2.0, dash := 9.0, gap := 7.0) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.5:
		return
	var n := d / l
	var t := fmod(Time.get_ticks_msec() * 0.012, dash + gap)
	var x := -t
	while x < l:
		var s0 := maxf(x, 0.0)
		var s1 := minf(x + dash, l)
		if s1 > s0:
			canvas.draw_line(a + n * s0, a + n * s1, color, width, true)
		x += dash + gap


func _badge(pos: Vector2, size: float, color: Color, letter: String) -> void:
	var r := Rect2(pos - Vector2(size, size) * 0.5, Vector2(size, size))
	canvas.draw_rect(r.grow(1.5), Color(0, 0, 0, 0.55))
	canvas.draw_rect(r, color)
	canvas.draw_string(font, Vector2(r.position.x, r.position.y + size * 0.76), letter, HORIZONTAL_ALIGNMENT_CENTER, size, int(size * 0.72), Color(1, 1, 1, 0.96))


## Biểu tượng kiểu bản HTML: chấm tròn màu, viền trắng, hình vẽ trắng, bóng tối phía dưới.
func _disc(c: Vector2, radius: float, col: Color) -> void:
	canvas.draw_circle(c + Vector2(0, radius * 0.12), radius + maxf(1.5, radius * 0.22), Color(0, 0, 0, 0.65))
	canvas.draw_circle(c, radius, col)
	canvas.draw_arc(c, radius, 0, TAU, 28, Color.WHITE, maxf(1.2, radius * 0.16), true)


func _shop_icon(kind: String, c: Vector2, size: float) -> void:
	_disc(c, size * 0.56, Color(City.SHOPS[kind].color))
	size *= 0.78
	var w := Color(1, 1, 1, 0.97)
	var u := size / 10.0
	var lw := maxf(1.2, u * 1.1)
	match kind:
		"grocery":
			canvas.draw_rect(Rect2(c + Vector2(-3, -1) * u, Vector2(6, 3.4) * u), w)
			canvas.draw_arc(c + Vector2(0, -1) * u, 2.4 * u, PI, TAU, 10, w, lw)
		"pharmacy":
			canvas.draw_rect(Rect2(c + Vector2(-1, -3.2) * u, Vector2(2, 6.4) * u), w)
			canvas.draw_rect(Rect2(c + Vector2(-3.2, -1) * u, Vector2(6.4, 2) * u), w)
		"clothes":
			canvas.draw_colored_polygon([c + Vector2(-1.4, -3) * u, c + Vector2(1.4, -3) * u, c + Vector2(3.6, -1.4) * u, c + Vector2(2.6, 0.2) * u, c + Vector2(1.8, -0.4) * u, c + Vector2(1.8, 3.2) * u, c + Vector2(-1.8, 3.2) * u, c + Vector2(-1.8, -0.4) * u, c + Vector2(-2.6, 0.2) * u, c + Vector2(-3.6, -1.4) * u], w)
		"shoes":
			canvas.draw_colored_polygon([c + Vector2(-3, -2.6) * u, c + Vector2(-0.6, -2.6) * u, c + Vector2(-0.4, 0.2) * u, c + Vector2(3.4, 1.2) * u, c + Vector2(3.4, 2.6) * u, c + Vector2(-3, 2.6) * u], w)
		"bags":
			canvas.draw_rect(Rect2(c + Vector2(-2.6, -1.2) * u, Vector2(5.2, 4.4) * u), w)
			canvas.draw_arc(c + Vector2(0, -1.2) * u, 1.6 * u, PI, TAU, 10, w, lw)
		"hardware":
			canvas.draw_line(c + Vector2(-2.6, 2.6) * u, c + Vector2(1.4, -1.4) * u, w, lw * 1.5)
			canvas.draw_arc(c + Vector2(2.0, -2.0) * u, 1.5 * u, 0.6, 4.6, 10, w, lw * 1.3)
		"bike":
			canvas.draw_arc(c + Vector2(-2.2, 1.2) * u, 1.6 * u, 0, TAU, 12, w, lw)
			canvas.draw_arc(c + Vector2(2.2, 1.2) * u, 1.6 * u, 0, TAU, 12, w, lw)
			canvas.draw_line(c + Vector2(-2.2, 1.2) * u, c + Vector2(0.2, -1.8) * u, w, lw)
			canvas.draw_line(c + Vector2(0.2, -1.8) * u, c + Vector2(2.2, 1.2) * u, w, lw)
		"food":
			canvas.draw_arc(c + Vector2(0, -0.2) * u, 3.0 * u, 0, PI, 12, w, lw * 1.6)
			canvas.draw_line(c + Vector2(-3.2, -0.2) * u, c + Vector2(3.2, -0.2) * u, w, lw)
			canvas.draw_line(c + Vector2(-1, -1.6) * u, c + Vector2(-1, -3.2) * u, w, lw)
			canvas.draw_line(c + Vector2(1, -1.6) * u, c + Vector2(1, -3.2) * u, w, lw)
		"cafe":
			canvas.draw_rect(Rect2(c + Vector2(-2.4, -1.6) * u, Vector2(3.8, 4.2) * u), w)
			canvas.draw_arc(c + Vector2(1.6, 0.4) * u, 1.3 * u, -PI * 0.5, PI * 0.5, 8, w, lw)


const H_STREETS := ["Đường Lê Lợi", "Đường Bờ Hồ", "Đường Trần Hưng Đạo", "Đường Nguyễn Huệ"]
const V_STREETS := ["Phố Hàng Bông", "Phố Hàng Gai", "Phố Tràng Tiền", "Phố Bà Triệu", "Phố Huế", "Phố Lò Đúc", "Phố Hàng Bài"]
var _card := StyleBoxFlat.new()


func _rounded(rect: Rect2, color: Color, radius := 12, border := Color(0, 0, 0, 0), bw := 0) -> void:
	_card.bg_color = color
	_card.border_color = border
	_card.set_border_width_all(bw)
	_card.set_corner_radius_all(mini(radius, int(minf(rect.size.x, rect.size.y) * 0.5)))
	_card.anti_aliasing = true
	_card.shadow_size = 0
	canvas.draw_style_box(_card, rect)


## Ghim địa điểm hình giọt nước có nhãn.
func _pin(pos: Vector2, color: Color, glyph: String, label: String) -> void:
	var top := pos + Vector2(0, -26)
	canvas.draw_circle(pos + Vector2(0, 2), 5.0, Color(0, 0, 0, 0.25))
	canvas.draw_colored_polygon([pos, top + Vector2(-10, 6), top + Vector2(10, 6)], color.darkened(0.25))
	canvas.draw_circle(top, 13.0, color.darkened(0.25))
	canvas.draw_circle(top, 11.0, color)
	canvas.draw_circle(top, 7.5, Color(1, 1, 1, 0.95))
	canvas.draw_string(font, top + Vector2(-10, 5), glyph, HORIZONTAL_ALIGNMENT_CENTER, 20, 13, color.darkened(0.3))
	if label != "":
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 16
		_rounded(Rect2(top.x - w * 0.5, top.y - 36, w, 20), Color(1, 1, 1, 0.95), 10, color.darkened(0.2), 1)
		canvas.draw_string(font, Vector2(top.x - w * 0.5, top.y - 21), label, HORIZONTAL_ALIGNMENT_CENTER, w, 12, Color(0.12, 0.12, 0.14))


func _ink(pos: Vector2, text: String, size: int, color: Color, width := 200.0) -> void:
	canvas.draw_string_outline(font, pos - Vector2(width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_CENTER, width, size, 4, Color(0.98, 0.96, 0.9, 0.9))
	canvas.draw_string(font, pos - Vector2(width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_CENTER, width, size, color)


## Nhãn chữ đậm màu tối có viền trắng, đọc rõ trên nền sáng.
func _tag(pos: Vector2, text: String, size: int, color := Color("26323e"), width := 200.0) -> void:
	canvas.draw_string_outline(font, pos - Vector2(width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_CENTER, width, size, 5, Color(1, 1, 1, 0.92))
	canvas.draw_string(font, pos - Vector2(width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_CENTER, width, size, color)


## Bản đồ kiểu bản HTML: nền tối, phẳng, màu trầm; đường xám, nhà xám, cửa hàng ngả màu loại hàng;
## biểu tượng là chấm tròn viền trắng; đường gợi ý màu hổ phách; quái vật có vòng nguy hiểm đỏ.
func _draw_map() -> void:
	var city: City = world.city
	var size := canvas.size
	var t := Time.get_ticks_msec() * 0.001
	var pal := UiTheme.map_pal()
	var ink: Color = pal.ink
	canvas.draw_rect(Rect2(Vector2.ZERO, size), pal.bg)
	var b := city.bounds
	canvas.draw_rect(Rect2(_to_screen(b.position), b.size * zoom).grow(3.0), pal.frame)
	canvas.draw_rect(Rect2(_to_screen(b.position), b.size * zoom), pal.road)
	# --- khối nhà: viền vỉa hè + nền trong
	for r in City.ROWS:
		for c in City.COLS:
			var bc := City.block_center(c, r)
			var rect := Rect2(_to_screen(Vector2(bc.x - City.BW * 0.5, bc.z - City.BD * 0.5)), Vector2(City.BW, City.BD) * zoom)
			canvas.draw_rect(rect, pal.edge)
			canvas.draw_rect(rect.grow(-1.0), UiTheme.cell_color(Vector2i(c, r), pal))
	# vạch tim đường
	for j2 in City.ROWS + 1:
		var z := City.road_z(j2)
		canvas.draw_dashed_line(_to_screen(Vector2(b.position.x, z)), _to_screen(Vector2(b.end.x, z)), pal.centre, 1.0, 2.4 * zoom)
	for i2 in City.COLS + 1:
		var x := City.road_x(i2)
		canvas.draw_dashed_line(_to_screen(Vector2(x, b.position.y)), _to_screen(Vector2(x, b.end.y)), pal.centre, 1.0, 2.4 * zoom)
	# --- công viên hồ và công viên lớn (phủ lên cả các con đường nằm bên trong)
	var lzr := City.zone_rect(City.LAKE_ZONE)
	canvas.draw_rect(Rect2(_to_screen(lzr.position), lzr.size * zoom), pal.grass)
	var frr := City.zone_rect(City.FOREST_ZONE)
	var prr := City.zone_rect(City.PARK_ZONE)
	canvas.draw_rect(Rect2(_to_screen(prr.position), prr.size * zoom), pal.field)
	canvas.draw_rect(Rect2(_to_screen(frr.position), frr.size * zoom), pal.forest)
	for hz: Rect2i in City.HOODS:
		var hr := City.zone_rect(hz)
		canvas.draw_rect(Rect2(_to_screen(hr.position), hr.size * zoom), pal.block)
		canvas.draw_rect(Rect2(_to_screen(hr.position), hr.size * zoom), pal.edge, false, 1.2)
		_tag(_to_screen(hr.get_center()), "KHU TẬP THỂ", 13, Color("6a5a3a"), 160.0)
	for zr: Rect2 in [lzr, prr]:
		canvas.draw_rect(Rect2(_to_screen(zr.position), zr.size * zoom), pal.edge, false, 1.2)
	_tag(_to_screen(frr.get_center()), "RỪNG CÂY", 13, Color("2f5a2a"), 140.0)
	_tag(_to_screen(Vector2((frr.end.x + prr.end.x) * 0.5, prr.get_center().y)), "BÃI CỎ", 13, Color("4a6a2a"), 140.0)
	var cr := city.crane_pos
	_tag(_to_screen(Vector2(cr.x, cr.z)) + Vector2(0, -12), "CẦN CẨU", 12, Color("8a6a00"), 140.0)
	canvas.draw_circle(_to_screen(Vector2(cr.x, cr.z)), 4.0, Color("e8b21c"))
	canvas.draw_line(_to_screen(Vector2(cr.x, cr.z)), _to_screen(Vector2(cr.x - 46.0, cr.z)), Color("e8b21c"), 2.0)
	# --- hồ
	canvas.draw_rect(Rect2(_to_screen(city.lake_rect.position), city.lake_rect.size * zoom), pal.lake)
	canvas.draw_rect(Rect2(_to_screen(city.lake_rect.position), city.lake_rect.size * zoom), pal.lake_edge, false, 1.5)
	for lr: Rect2 in city.lake_land:
		canvas.draw_rect(Rect2(_to_screen(lr.position), lr.size * zoom), pal.grass)
	# --- nhà
	for bd in city.buildings:
		var rc: Rect2 = bd.rect
		var sr := Rect2(_to_screen(rc.position), rc.size * zoom).grow(-0.5)
		if not Rect2(Vector2.ZERO, size).grow(10.0).intersects(sr):
			continue
		var col := UiTheme.building_color(bd, pal)
		if bd.has("poly"):
			var pp := PackedVector2Array()
			for v: Vector2 in bd.poly:
				pp.append(_to_screen(v))
			canvas.draw_colored_polygon(pp, col)
			pp.append(pp[0])
			canvas.draw_polyline(pp, ink if ink.a > 0.0 else col.darkened(0.18), 1.0)
			continue
		canvas.draw_rect(sr, col)
		canvas.draw_rect(sr, ink if ink.a > 0.0 else col.darkened(0.18), false, float(pal.ink_w) if zoom > 1.2 else 1.0)
	for er: Rect2 in city.extras:
		var esr := Rect2(_to_screen(er.position), er.size * zoom)
		if Rect2(Vector2.ZERO, size).intersects(esr):
			canvas.draw_rect(esr, pal.extra)
	# --- đường bị chặn, khe nứt, cây đổ
	for br: Rect2 in city.barricades:
		var bsr := Rect2(_to_screen(br.position), br.size * zoom)
		canvas.draw_rect(bsr, Color("c8685a"))
		canvas.draw_line(bsr.position, bsr.end, Color("7a2a20"), 2.0)
		canvas.draw_line(Vector2(bsr.end.x, bsr.position.y), Vector2(bsr.position.x, bsr.end.y), Color("7a2a20"), 2.0)
	for ch in city.chasms:
		canvas.draw_rect(Rect2(_to_screen((ch.rect as Rect2).position), (ch.rect as Rect2).size * zoom), Color("3a2a24"))
		if zoom > 2.4:
			_tag(_to_screen((ch.rect as Rect2).get_center()) + Vector2(0, -7), {"plank": "ván bắc qua", "tree": "cây đổ", "slab": "mảng tường", "ruin": "đống đổ nát"}.get(ch.kind, ""), 11, Color("8a2a20"), 140.0)
	if zoom > 2.0:
		for xf: Transform3D in city._tree_xf:
			if xf.basis.get_scale().x > 0.01:
				canvas.draw_circle(_to_screen(Vector2(xf.origin.x, xf.origin.z)), 1.5 * zoom, pal.tree)
		for car in city.cars:
			var cp0 := _to_screen(Vector2(car.pos.x, car.pos.z))
			var along_x: bool = absf(sin(float(car.yaw))) > 0.7
			var cs := Vector2(4.2, 1.8) * zoom if along_x else Vector2(1.8, 4.2) * zoom
			canvas.draw_rect(Rect2(cp0 - cs * 0.5, cs), Color("9aa0a6"))
	# --- công trình đặc thù
	for lm: Dictionary in city.landmarks:
		var lp := _to_screen(Vector2((lm.pos as Vector3).x, (lm.pos as Vector3).z))
		_tag(lp, str(lm.name), 13, Color("6a2a20"), 180.0)
	if city.tower_pos != Vector3.ZERO:
		var tp := _to_screen(Vector2(city.tower_pos.x, city.tower_pos.z))
		canvas.draw_circle(tp, 6.0, Color("c8302a"))
		canvas.draw_circle(tp, 3.0, Color.WHITE)
	# --- đường sắt trên cao
	var rl: Rail = city.rail
	var prev := Vector2.ZERO
	for i in rl.pts.size():
		var sp := _to_screen(Vector2(rl.pts[i].x, rl.pts[i].z))
		if i > 0 and not rl.in_gap(rl.dist[i]):
			canvas.draw_line(prev, sp, Color("4a4a50"), maxf(3.0, 6.0 * zoom * 0.5))
			canvas.draw_line(prev, sp, Color("9fd0a8"), maxf(1.0, 2.0 * zoom * 0.5))
		prev = sp
	for g2 in rl.gaps:
		var gp := rl.frame((g2.x + g2.y) * 0.5).p as Vector3
		var gs := _to_screen(Vector2(gp.x, gp.z))
		canvas.draw_line(gs + Vector2(-7, -7), gs + Vector2(7, 7), Color("e0453a"), 3.0)
		canvas.draw_line(gs + Vector2(-7, 7), gs + Vector2(7, -7), Color("e0453a"), 3.0)
	for st: Dictionary in rl.stations:
		var spn := rl.frame(st.s).p as Vector3
		var ss := _to_screen(Vector2(spn.x, spn.z))
		canvas.draw_circle(ss, 8.0, Color("2a2a2e"))
		canvas.draw_circle(ss, 6.0, Color("5fb06a"))
		_tag(ss + Vector2(0, -16), str(st.name), 12, Color("2a5a30"), 160.0)
	# --- hầm đi bộ
	var tn: Dictionary = city.tunnel
	canvas.draw_dashed_line(_to_screen(Vector2(tn.x0, tn.z)), _to_screen(Vector2(tn.x1, tn.z)), Color("3a7a9a"), 2.5, 2.2 * zoom)
	var bxs := _to_screen(Vector2(tn.block_x, tn.z))
	canvas.draw_line(bxs + Vector2(-6, -6), bxs + Vector2(6, 6), Color("e0453a"), 3.0)
	canvas.draw_line(bxs + Vector2(-6, 6), bxs + Vector2(6, -6), Color("e0453a"), 3.0)
	# --- vòng nguy hiểm của quái vật (cần đeo đồng hồ định vị)
	var mons: Array = []
	if Game.has_watch():
		for m: Monster in world.monsters.list:
			if m.state != "dormant":
				mons.append(m)
	for m2: Monster in (mons if Game.god else []):
		var ms0 := _to_screen(Vector2(m2.global_position.x, m2.global_position.z))
		var rad: float = {"titan": 60.0, "stalker": 45.0, "worm": 40.0, "flyer": 70.0, "grub": 12.0, "crawler": 6.0, "towereye": 42.0}.get(m2.kind, 30.0)
		canvas.draw_circle(ms0, rad * zoom, Color(0.85, 0.2, 0.16, 0.14))
		canvas.draw_arc(ms0, rad * zoom, 0, TAU, 48, Color(0.8, 0.16, 0.12, 0.7), 1.8, true)
	# --- đường gợi ý: nét đen dày bên dưới, nét hổ phách đứt đoạn bên trên
	var me: CharacterBody3D = world.local_player()
	var o: Vector3 = world.objective_pos()
	if me and world.has_objective():
		var line := PackedVector2Array()
		for rp: Vector3 in city.guide_route(me.global_position, world.objective_pos()):
			line.append(_to_screen(Vector2(rp.x, rp.z)))
		canvas.draw_polyline(line, Color(1, 1, 1, 0.95), 9.0, true)
		HudScript.dash_poly(canvas, line, Color("1a73e8"), 5.0, 12.0)
	# --- biểu tượng
	var isz := clampf(7.0 + zoom * 2.2, 9.0, 17.0)
	if zoom > 1.7:
		for bd2 in city.buildings:
			var cen := _to_screen((bd2.rect as Rect2).get_center())
			if not Rect2(Vector2.ZERO, size).grow(20.0).has_point(cen):
				continue
			if bd2.kind == "shop":
				_shop_icon(bd2.shop, cen, isz * 1.8)
			elif bd2.kind in ["mall", "super", "restaurant"]:
				var ik: String = "food" if bd2.kind == "restaurant" else "grocery"
				_shop_icon(ik, cen, isz * 2.4)
				if zoom >= 2.4:
					_tag(cen + Vector2(0, isz * 1.4 + 14), str(bd2.name), 12, Color("3a2a26"))
	for ex: float in tn.entrances:
		var ep := _to_screen(Vector2(ex + 3.0, tn.z))
		_disc(ep, isz * 0.9, Color("3a7a9a"))
		canvas.draw_string(font, ep + Vector2(-10, 5), "H", HORIZONTAL_ALIGNMENT_CENTER, 20, int(isz * 0.95), Color.WHITE)
	if zoom > 2.4:
		for bk in world.bikes.list:
			if bk.rider == 0 and not bk.broken:
				_disc(_to_screen(Vector2(bk.pos.x, bk.pos.z)), 4.0, Color("d9a24a"))
	# văn phòng, nhà ông Tư, nhà
	var offp := _to_screen(Vector2(city.start_pos.x, city.start_pos.z))
	_disc(offp, isz, Color("4a6a8a"))
	_tag(offp + Vector2(0, isz + 16), "Văn phòng", 12, Color("26323e"))
	if world.stage >= 1:
		var tup := _to_screen(Vector2(city.tu_pos.x, city.tu_pos.z))
		_disc(tup, isz * 1.2, Color("86b47f"))
		canvas.draw_string(font, tup + Vector2(-10, 5), "T", HORIZONTAL_ALIGNMENT_CENTER, 20, int(isz), Color.WHITE)
		_tag(tup + Vector2(0, isz + 18), "NHÀ ÔNG TƯ", 13, Color("2a6a2a"))
	if world.has_objective():
		var hp := _to_screen(Vector2(city.home_pos.x, city.home_pos.z))
		_disc(hp, isz * 1.6, Color("d98a1a"))
		canvas.draw_colored_polygon([hp + Vector2(0, -isz * 0.9), hp + Vector2(isz * 0.9, -isz * 0.05), hp + Vector2(-isz * 0.9, -isz * 0.05)], Color.WHITE)
		canvas.draw_rect(Rect2(hp + Vector2(-isz * 0.55, -isz * 0.05), Vector2(isz * 1.1, isz * 0.75)), Color.WHITE)
		_tag(hp + Vector2(0, isz * 1.6 + 20), "NHÀ", 15, Color("9a5a00"))
		var os := _to_screen(Vector2(o.x, o.z))
		canvas.draw_arc(os, isz * 2.2 + 4.0 * sin(t * 4.0), 0, TAU, 28, Color("1a73e8"), 2.5, true)
	# --- quái vật
	for m3: Monster in mons:
		var ms := _to_screen(Vector2(m3.global_position.x, m3.global_position.z))
		if m3.kind == "crawler":
			if m3.state != "dead":
				canvas.draw_circle(ms, 5.5, Color(0.1, 0.05, 0.05))
				canvas.draw_circle(ms, 4.0, Color(0.9, 0.25, 0.18))
			continue
		var tex := Items.icon("mon_" + ("wander" if m3.kind == "grub" else m3.kind))
		if tex:
			canvas.draw_texture_rect(tex, Rect2(ms - Vector2(17, 17), Vector2(34, 34)), false)
		_tag(ms + Vector2(0, 34), m3.mname, 14, Color("b0201a"), 160.0)
	# --- người chơi: mũi tên trắng viền đen
	for q in get_tree().get_nodes_in_group("players"):
		var ps := _to_screen(Vector2(q.global_position.x, q.global_position.z))
		var mine: bool = q.is_local()
		var fwd := Vector2(-sin(q.global_rotation.y), -cos(q.global_rotation.y))
		var sd := Vector2(-fwd.y, fwd.x)
		canvas.draw_colored_polygon([ps + fwd * 16.0, ps - fwd * 11.0 + sd * 10.0, ps - fwd * 5.0, ps - fwd * 11.0 - sd * 10.0], Color.WHITE)
		canvas.draw_colored_polygon([ps + fwd * 13.0, ps - fwd * 8.5 + sd * 7.5, ps - fwd * 3.5, ps - fwd * 8.5 - sd * 7.5], Color("1a73e8") if mine else Color("8a4fb0"))
		if not mine:
			_tag(ps + Vector2(0, -16), q.net_name, 12, Color("5a2f80"), 140.0)
	# --- tiêu đề + chú giải (bảng tối như các menu khác)
	var panel := Rect2(20, 20, 284, 412)
	_rounded(panel, Color(0.06, 0.07, 0.08, 0.94), 10, Color(0.92, 0.9, 0.85, 0.15), 1)
	var lx := 40.0
	var ly := 58.0
	_text(Vector2(lx, ly), "BẢN ĐỒ", 30)
	_text(Vector2(lx, ly + 22), "%s · %s" % [world.weather.clock_text() if Game.has_clock() else world.weather.part_of_day() + " (chưa đeo đồng hồ)", world.weather.kind_name()], 12, DIM)
	ly += 54.0
	for k6: String in City.SHOPS:
		_shop_icon(k6, Vector2(lx + 8, ly - 5), 16.0)
		_text(Vector2(lx + 28, ly), str(City.SHOPS[k6].name).capitalize(), 12, INK)
		ly += 22.0
	_disc(Vector2(lx + 8, ly - 5), 8.0, Color("3a7a9a"))
	canvas.draw_string(font, Vector2(lx - 2, ly - 1), "H", HORIZONTAL_ALIGNMENT_CENTER, 20, 10, Color.WHITE)
	_text(Vector2(lx + 28, ly), "Cửa hầm đi bộ", 12, INK)
	ly += 22.0
	canvas.draw_dashed_line(Vector2(lx, ly - 5), Vector2(lx + 18, ly - 5), Color("1a73e8"), 4.0, 6.0)
	_text(Vector2(lx + 28, ly), "Đường gợi ý tới mục tiêu", 12, INK)
	ly += 22.0
	canvas.draw_rect(Rect2(lx, ly - 11, 16, 12), Color("c8685a"))
	_text(Vector2(lx + 28, ly), "Đường bị chặn / nhà sập", 12, INK)
	ly += 26.0
	if Game.has_watch():
		_text(Vector2(lx, ly), "Đồng hồ định vị: đang hiện quái vật", 12, Color("e4a03a"))
	else:
		_text(Vector2(lx, ly), "Chưa đeo đồng hồ định vị:", 12, DIM)
		_text(Vector2(lx, ly + 17), "không thấy quái vật trên bản đồ.", 12, DIM)
	# --- la bàn, thước tỉ lệ, phím
	var cc := Vector2(size.x - 58, 64)
	canvas.draw_circle(cc, 30.0, Color(0.06, 0.07, 0.08, 0.9))
	canvas.draw_arc(cc, 30.0, 0, TAU, 32, Color(0.92, 0.9, 0.85, 0.2), 1.0, true)
	canvas.draw_colored_polygon([cc + Vector2(0, -24), cc + Vector2(7, 0), cc + Vector2(-7, 0)], Color("cf4a3b"))
	canvas.draw_colored_polygon([cc + Vector2(0, 24), cc + Vector2(7, 0), cc + Vector2(-7, 0)], Color(0.8, 0.8, 0.78))
	_text(cc + Vector2(-20, -34), "B", 13, INK, HORIZONTAL_ALIGNMENT_CENTER, 40)
	var bar := 50.0 * zoom
	var bx := size.x - 40.0 - bar
	_rounded(Rect2(bx - 14, size.y - 74, bar + 28, 44), Color(0.06, 0.07, 0.08, 0.9), 8)
	canvas.draw_line(Vector2(bx, size.y - 44), Vector2(bx + bar, size.y - 44), INK, 2.0)
	canvas.draw_line(Vector2(bx, size.y - 49), Vector2(bx, size.y - 39), INK, 2.0)
	canvas.draw_line(Vector2(bx + bar, size.y - 49), Vector2(bx + bar, size.y - 39), INK, 2.0)
	_text(Vector2(bx, size.y - 54), "50 m", 12, INK, HORIZONTAL_ALIGNMENT_CENTER, bar)
	var hint := "Con lăn: phóng to/thu nhỏ   ·   Kéo chuột: di chuyển   ·   M / Esc: đóng" + ("   ·   Nhấp đúp: dịch chuyển" if Game.god else "")
	var hw := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 28
	_rounded(Rect2(20, size.y - 52, hw, 30), Color(0.06, 0.07, 0.08, 0.9), 8)
	_text(Vector2(34, size.y - 32), hint, 13, DIM)
