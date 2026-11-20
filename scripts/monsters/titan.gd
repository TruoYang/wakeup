extends Monster
## Thủy Quái: khổng lồ, trồi lên từ hồ, đi dọc các con đường. Nhìn từ trên cao, nghe tiếng động lớn, giẫm bằng chân.

const HEIGHT := 56.0          # thân cao 56m: gấp ba dãy nhà 5 tầng
const G := 1.5                # hệ số phóng to thân
const EMERGE_AT := 25.0

var legs: Array[MonsterLeg] = []
var hull: Node3D
var tentacles: Array[Node3D] = []
var route: Array[Vector3] = []
var _night_t := 40.0
var _t := 0.0
var _state_t := 0.0
var _stomp_pos := Vector3.ZERO
var _rage := 0.0
var _roar_cd := 0.0
var _mat: ShaderMaterial
var _step_group := 0
var _group_t := 0.0
var _neck: Node3D


## Một đốt thuôn nối từ a tới b (toạ độ trong `parent`).
func _seg(parent: Node3D, a: Vector3, b: Vector3, r0: float, r1: float, mat: Material, seed_v: int) -> void:
	var n := Node3D.new()
	parent.add_child(n)
	var y := (a - b).normalized()
	var x := y.cross(Vector3.FORWARD)
	if x.length() < 0.1:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	n.transform = Transform3D(Basis(x, y, x.cross(y).normalized()), a)
	MonsterMesh.add(n, MonsterMesh.limb(a.distance_to(b), r0, r1, seed_v, 0.22), mat)


func build() -> void:
	mname = "Thủy Quái"
	state = "dormant"
	var lc := city.lake_rect.get_center()
	global_position = Vector3(lc.x, -HEIGHT - 14.0, lc.y)
	# Màu như bản cũ: xám trắng nhợt, phần tối xám đậm.
	MonsterMesh.rough = 0.25
	_mat = MonsterMesh.flesh(Color("bdbcb1"), Color("a3a297"), Color("8d8c83"), {"bump": 0.25, "wetness": 0.12, "vein_amount": 0.0, "scale": 0.05, "pulse": 0.1})
	var dark := MonsterMesh.flesh(Color("8d8c83"), Color("7a7970"), Color("6a6962"), {"bump": 0.25, "wetness": 0.1, "vein_amount": 0.0, "scale": 0.08, "pulse": 0.06})
	hull = Node3D.new()
	add_child(hull)
	hull.position.y = HEIGHT
	hull.scale = Vector3.ONE * G
	MonsterMesh.add(hull, MonsterMesh.blob(Vector3(9.0, 6.5, 15.0), 1, 0.2, 0.5, 1.6), _mat)
	MonsterMesh.add(hull, MonsterMesh.blob(Vector3(7.0, 5.0, 9.0), 2, 0.22, 0.6, 1.3), _mat, Vector3(0, 3.0, -2.0))
	# Các sợi rủ dưới bụng
	for k in 46:
		var len := rng.randf_range(3.0, 9.0)
		var st := MonsterMesh.add(hull, MonsterMesh.limb(len, 0.2, 0.08, 20 + k % 5, 0.3), dark, Vector3(rng.randf_range(-6, 6), -4.6, rng.randf_range(-6, 12)), Vector3(rng.randf_range(-0.15, 0.15), 0, rng.randf_range(-0.15, 0.15)))
		if k % 5 == 0:
			tentacles.append(st)
	# Gờ sống lưng
	for k in 9:
		MonsterMesh.add(hull, MonsterMesh.blob(Vector3(1.2, 2.2, 1.2), 3 + k % 3, 0.2, 0.3, 0.6), dark, Vector3(0, 6.0, -10.0 + k * 2.6))
	# Cổ rủ về phía trước và xuống dưới + đầu
	_neck = Node3D.new()
	hull.add_child(_neck)
	var pts := [Vector3(0, 1, 12), Vector3(0, -1, 16.5), Vector3(0, -5, 19.5), Vector3(0, -9.5, 21)]
	for k in 3:
		_seg(_neck, pts[k], pts[k + 1], 4.4 - k * 0.6, 3.8 - k * 0.6, _mat, 30 + k)
	MonsterMesh.add(_neck, MonsterMesh.blob(Vector3(3.6, 3.0, 6.4), 5, 0.2, 0.5), _mat, Vector3(0, -11.0, 22.5), Vector3(1.0, 0, 0))
	var eye := StandardMaterial3D.new()
	eye.albedo_color = Color("1a1612")
	eye.roughness = 0.1
	for sx: float in [-1.0, 1.0]:
		MonsterMesh.add(_neck, SphereMesh.new(), eye, Vector3(sx * 2.2, -10.2, 22.2), Vector3.ZERO, Vector3.ONE * 0.9)
	var maw := StandardMaterial3D.new()
	maw.albedo_color = Color("1a0f0c")
	maw.roughness = 0.2
	MonsterMesh.add(_neck, MonsterMesh.blob(Vector3(1.5, 0.8, 1.6), 6, 0.1, 0.0, 0.6), maw, Vector3(0, -14.2, 24.2), Vector3(1.0, 0, 0))
	# Hai xúc tu dài dưới cổ
	for sx2: float in [-1.0, 1.0]:
		var tn := Node3D.new()
		tn.position = Vector3(sx2 * 2.0, -12.5, 21.0)
		_neck.add_child(tn)
		MonsterMesh.add(tn, MonsterMesh.limb(15.0, 0.34, 0.06, 40, 0.25), _mat)
		tentacles.append(tn)
	# Bốn chân: mỗi đốt dài 25m
	# Thân dày thêm: vai, hông, bụng, các nếp da xếp lớp; không dùng gai.
	MonsterMesh.rough = 0.45
	var fold := MonsterMesh.flesh(Color("a9a89d"), Color("8d8c83"), Color("6f6e66"), {"bump": 0.5, "wetness": 0.1, "vein_amount": 0.0, "scale": 0.09, "pulse": 0.08})
	MonsterMesh.add(hull, MonsterMesh.blob(Vector3(10.5, 5.5, 8.0), 7, 0.2, 0.5, 1.2), _mat, Vector3(0, -1.0, 8.5))       # ức, vai
	MonsterMesh.add(hull, MonsterMesh.blob(Vector3(10.0, 5.0, 8.0), 8, 0.2, 0.5, 1.2), _mat, Vector3(0, -1.2, -8.5))      # hông
	MonsterMesh.add(hull, MonsterMesh.blob(Vector3(7.5, 4.5, 12.0), 9, 0.25, 0.6, 1.2), fold, Vector3(0, -4.0, 0.0))      # bụng sệ
	for k2 in 7:
		# các nếp da vắt ngang lưng
		MonsterMesh.add(hull, MonsterMesh.blob(Vector3(9.3 - absf(k2 - 3) * 0.5, 1.0, 1.9), 10 + k2 % 3, 0.2, 0.3, 0.9), fold, Vector3(0, 5.2 - absf(k2 - 3) * 0.35, -11.0 + k2 * 3.7))
	for sxp: float in [-1.0, 1.0]:
		for szp: float in [-1.0, 1.0]:
			MonsterMesh.add(hull, MonsterMesh.blob(Vector3(4.6, 4.6, 5.2), 14, 0.2, 0.5, 0.9), _mat, Vector3(sxp * 6.4, -2.4, szp * 9.0))    # u vai / u hông nơi chân mọc ra
	MonsterMesh.add(_neck, MonsterMesh.blob(Vector3(3.6, 3.2, 4.2), 15, 0.2, 0.5, 0.9), fold, Vector3(0, 0.2, 13.5))        # bướu gáy
	MonsterMesh.add(_neck, MonsterMesh.blob(Vector3(2.0, 1.6, 3.4), 16, 0.2, 0.4, 0.7), fold, Vector3(0, -12.6, 21.0), Vector3(1.0, 0, 0))   # hàm dưới
	# Chân: đùi to bắp, khớp gối phồng, ống chân dày, bàn chân ba ngón
	var upper := MonsterMesh.limb(37.0, 6.2, 4.4, 30, 0.25)
	var lower := MonsterMesh.limb(37.0, 4.2, 2.9, 31, 0.25)
	var foot := MonsterMesh.blob(Vector3(5.2, 2.2, 6.0), 32, 0.22, 0.4, 0.9)
	var thigh := MonsterMesh.blob(Vector3(6.8, 9.0, 6.4), 33, 0.22, 0.5, 0.9)
	var knee := MonsterMesh.blob(Vector3(5.0, 4.2, 5.0), 34, 0.2, 0.4, 0.8)
	var calf := MonsterMesh.blob(Vector3(4.2, 8.0, 4.6), 35, 0.2, 0.5, 0.8)
	var toe := MonsterMesh.blob(Vector3(1.7, 1.3, 3.4), 36, 0.2, 0.3, 0.6)
	var ring := MonsterMesh.blob(Vector3(4.6, 1.0, 4.6), 37, 0.15, 0.2, 0.7)
	MonsterMesh.rough = 1.0
	for sx3: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var leg := MonsterLeg.new()
			add_child(leg)
			leg.l1 = 37.0
			leg.l2 = 37.0
			leg.hip_local = Vector3(sx3 * 9.0, HEIGHT - 3.0, sz * 13.5)
			leg.rest_local = Vector3(sx3 * 3.2, 0.0, sz * 21.0)      # chân đặt sát tim đường: cả bàn chân (rộng ~5m) nằm trong lòng đường 14m
			leg.stride = 15.0
			leg.step_time = 1.9
			leg.lift = 11.0
			leg.group = 0 if (sx3 * sz > 0.0) else 1
			leg.knee_dir = Vector3(sx3 * 0.12, 0.55, sz * 0.9)       # gối gập về trước / sau (không chĩa ngang ra hai bên) để ống chân không xiên vào dãy nhà
			leg.build(upper, lower, _mat, foot, _mat)
			MonsterMesh.add(leg._upper, thigh, _mat, Vector3(0, -8.0, 0))
			MonsterMesh.add(leg._upper, knee, fold, Vector3(0, -36.5, 0))
			MonsterMesh.add(leg._lower, calf, _mat, Vector3(0, -9.0, 0))
			for kr in 3:
				MonsterMesh.add(leg._lower, ring, fold, Vector3(0, -22.0 - kr * 4.0, 0), Vector3.ZERO, Vector3.ONE * (0.82 - kr * 0.08))   # nếp da quanh ống chân
			for kt in 3:
				MonsterMesh.add(leg._lower, toe, fold, Vector3((kt - 1) * 3.0, -37.0, 3.6), Vector3(0, (kt - 1) * -0.35, 0))
			leg.planted.connect(_on_foot_planted)
			leg.place = _foot_spot
			legs.append(leg)
	visible = false


## --- Chỗ đặt chân
## Lúc đi lang thang (không đuổi ai) chân chỉ đặt lên chỗ trống: lòng đường, vỉa hè, sân, bãi cỏ, đống đổ nát.
## Chỗ muốn đặt mà vướng nhà thì tìm chỗ trống gần nhất trong vòng 16m. Khi đang đuổi / giẫm người chơi thì cứ giẫm
## thẳng (nhà thường bị phá), riêng nhà cốt truyện (nhà mình, nhà bác Tư, văn phòng, siêu thị, công trình mốc) luôn tránh.
const FOOT_R := 5.0           # bán kính bàn chân (để cả bàn chân nằm ngoài nhà chứ không chỉ tâm)
const _GRID := 24.0
static var _bgrid: Dictionary = {}          # ô lưới -> các toà nhà chồng lên ô đó (dựng một lần)
static var _bgrid_city: Object = null


func _grid_build() -> void:
	if _bgrid_city == city and not _bgrid.is_empty():
		return
	_bgrid.clear()
	_bgrid_city = city
	for b in city.buildings:
		var rc: Rect2 = (b.rect as Rect2).grow(FOOT_R)
		for gx in range(floori(rc.position.x / _GRID), floori(rc.end.x / _GRID) + 1):
			for gz in range(floori(rc.position.y / _GRID), floori(rc.end.y / _GRID) + 1):
				var k := Vector2i(gx, gz)
				if not _bgrid.has(k):
					_bgrid[k] = []
				(_bgrid[k] as Array).append(b)


static func _story(b: Dictionary) -> bool:
	return b.kind in ["home", "tu", "office", "mall"] or b.get("landmark", false)


## Toà nhà còn đứng mà bàn chân đặt ở q sẽ đè lên (rỗng nếu chỗ đó trống). Nhà đã sập / đổ nát thì giẫm được.
func _blocker(q: Vector3, story_only: bool) -> Dictionary:
	var k := Vector2i(floori(q.x / _GRID), floori(q.z / _GRID))
	var p2 := Vector2(q.x, q.z)
	for b: Dictionary in _bgrid.get(k, []):
		if b.get("ruined", false) or b.get("damage", "") == "collapse":
			continue
		if story_only and not _story(b):
			continue
		if (b.rect as Rect2).grow(FOOT_R).has_point(p2):
			return b
	return {}


func _foot_spot(want: Vector3) -> Vector3:
	_grid_build()
	var attacking := state in ["hunt", "rage", "stomp"]
	if _blocker(want, attacking).is_empty():
		return want
	# tìm chỗ trống gần nhất: các vòng tròn quanh chỗ muốn đặt, ưu tiên phía trước theo hướng đi
	var fwd := forward()
	for r: float in [3.0, 5.0, 7.5, 10.0, 13.0, 16.0]:
		var best := Vector3.INF
		var best_s := -1e9
		for i in 16:
			var a := i * TAU / 16.0
			var q := want + Vector3(cos(a) * r, 0.0, sin(a) * r)
			if not _blocker(q, attacking).is_empty():
				continue
			var sc := (q - global_position).dot(fwd) * 0.05 - q.distance_to(want)
			if sc > best_s:
				best_s = sc
				best = q
		if best != Vector3.INF:
			return best
	return want


func hunting() -> bool:
	return state in ["hunt", "stomp", "rage"]


func hit_spheres() -> Array:
	var out := [[global_position + Vector3(0, HEIGHT, 0), 21.0], [global_position + Vector3(0, HEIGHT - 16.0, 0) + forward() * 33.0, 8.0]]
	for l in legs:
		out.append([l.foot + Vector3(0, 6.0, 0), 4.0])
	return out


func _on_foot_planted(pos: Vector3) -> void:
	if state == "dormant":
		return
	Sfx.play_at("titan_stomp", pos, 4.0, 45.0, 0.8)
	mgr.shake_from(pos, 1.0, 150.0, 0.45)      # mỗi bước chân: rung mạnh, chậm, lan rất xa
	mgr.world.fx.dust(pos, 6.0)
	mgr.world.civs.crush(pos, 5.5)
	if multiplayer.is_server():
		mgr.world.titan_step(pos)
	if multiplayer.is_server():
		for p: Node3D in mgr.players():
			var d := Vector2(p.global_position.x - pos.x, p.global_position.z - pos.z).length()
			if d < 5.2 and p.global_position.y < 5.0 and not mgr.covered(p.global_position, 20.0):
				mgr.hurt(p, 55.0, "crush")


func heard(pos: Vector3, loud: float, source: String) -> void:
	if state == "dormant" or state == "emerge":
		return
	if loud >= 0.75 and global_position.distance_to(pos) < 170.0:
		last_seen = pos
		if source == "flyer":
			_rage = 16.0
			if state != "rage":
				state = "rage"
				mgr.fire(self, "roar")
		elif not hunting():
			state = "investigate"
		route.clear()


func server_tick(delta: float) -> void:
	_t += delta
	_state_t += delta
	_roar_cd -= delta
	match state:
		"dormant":
			if mgr.world.play_time >= EMERGE_AT:
				state = "emerge"
				_state_t = 0.0
				mgr.fire(self, "emerge")
			return
		"emerge":
			global_position.y = move_toward(global_position.y, 0.0, delta * (HEIGHT + 14.0) / 7.0)
			if global_position.y >= -0.01:
				state = "wander"
			return
	mgr.world.titan_brush(global_position, forward())
	# Mắt ở trên cao: thấy người ngoài đường, mái nhà che được.
	var eye := global_position + Vector3(0, HEIGHT - 15.0, 0) + forward() * 33.0     # mắt ở đầu, cổ rủ xuống
	var seen: Node3D = null
	if night_blind():
		cool_down(delta)
		# ban đêm không thấy người, nhưng thỉnh thoảng giẫm nát bừa một ngôi nhà gần đó
		_night_t -= delta
		if _night_t <= 0.0 and state == "wander":
			_night_t = rng.randf_range(30.0, 60.0)
			var pick := Vector3.INF
			for b in city.buildings:
				if b.kind in ["home", "tu", "office", "mall"] or b.get("landmark", false) or b.has("damage"):
					continue
				if City.cell_kind(b.cell) == "slum":
					continue          # khu tập thể dựng lại rất nặng (cả cụm 2x2 ô): không giẫm bừa vào đó
				var cc: Vector2 = (b.rect as Rect2).get_center()
				var d := Vector2(cc.x - global_position.x, cc.y - global_position.z).length()
				if d > 14.0 and d < 34.0 and rng.randf() < 0.35:
					pick = Vector3(cc.x, 0.2, cc.y)
					break
			if pick != Vector3.INF:
				state = "stomp"
				_state_t = 0.0
				_stomp_pos = pick
				last_seen = pick
				turn_to(pick - global_position, 10.0, 1.0)
				mgr.fire(self, "windup", _stomp_pos)
	else:
		seen = look_for_players(delta, eye, 120.0, Vector3.ZERO, -1.0, 0.75)
	if seen:
		target_id = seen.get_multiplayer_authority()
		last_seen = seen.global_position
		lost_t = 0.0
		if state in ["wander", "investigate"]:
			state = "hunt"
			route.clear()
			if _roar_cd <= 0.0:
				_roar_cd = 14.0
				mgr.fire(self, "roar")
	else:
		lost_t += delta
	_rage = maxf(0.0, _rage - delta)
	# Mất dấu quá 20 giây thì bỏ đi.
	if state in ["hunt", "investigate"] and lost_t > 20.0:
		state = "wander"
		target_id = 0
		forget()
		route.clear()
	var speed := 4.6
	match state:
		"wander":
			if route.is_empty():
				route = city.road_route(global_position, city.road_point(rng), rng)
		"investigate":
			speed = 5.5
			if route.is_empty():
				route = [last_seen]
			if global_position.distance_to(last_seen) < 12.0:
				state = "wander"
				route.clear()
		"hunt", "rage":
			speed = 8.4 if state == "rage" else 6.4
			route = [last_seen]
			var flat := Vector2(last_seen.x - global_position.x, last_seen.z - global_position.z).length()
			if seen and flat < 26.0:
				state = "stomp"
				_state_t = 0.0
				_stomp_pos = seen.global_position
				mgr.fire(self, "windup", _stomp_pos)
			elif (lost_t > 9.0 and state == "hunt") or (state == "rage" and _rage <= 0.0 and lost_t > 4.0) or flat < 9.0 and lost_t > 2.0:
				state = "wander"
				target_id = 0
				route.clear()
		"stomp":
			speed = 0.0
			if _state_t >= 1.15:
				mgr.fire(self, "slam", _stomp_pos)
				for p: Node3D in mgr.players():
					var d := p.global_position.distance_to(_stomp_pos)
					if d < 6.5 and not mgr.covered(p.global_position, 20.0):
						mgr.hurt(p, lerpf(75.0, 25.0, d / 6.5), "crush")
				mgr.world.civs.crush(_stomp_pos, 6.5)
				mgr.world.titan_step(_stomp_pos)
				state = "hunt"
				_state_t = 0.0
	if speed > 0.0 and not route.is_empty():
		var to := route[0] - global_position
		to.y = 0.0
		if to.length() < 8.0:
			route.remove_at(0)
		else:
			var off := turn_to(to, 0.4, delta)
			var mv := speed * (0.35 if off > 0.8 else 1.0)
			mv *= pace()
			global_position += forward() * mv * delta
			speed_now = mv
	else:
		speed_now = 0.0
	# Tháp phát sóng cao 72m là công trình cốt truyện (không bị phá): thân nó rộng nên đi vòng, không xuyên qua tháp
	if city.tower_pos != Vector3.ZERO:
		var away := Vector3(global_position.x - city.tower_pos.x, 0.0, global_position.z - city.tower_pos.z)
		var keep := 40.0
		if away.length() < keep:
			var dir := away.normalized() if away.length() > 0.5 else forward().cross(Vector3.UP)
			global_position += dir * minf(keep - away.length(), 6.0 * delta)
		# điểm đến nằm sát chân tháp thì bỏ qua (không thì nó cứ đứng húc mãi vào vùng cấm)
		if not route.is_empty() and Vector2(route[0].x - city.tower_pos.x, route[0].z - city.tower_pos.z).length() < keep:
			route.remove_at(0)
	global_position.x = clampf(global_position.x, city.bounds.position.x + 12.0, city.bounds.end.x - 12.0)
	global_position.z = clampf(global_position.z, city.bounds.position.y + 12.0, city.bounds.end.y - 12.0)


func event(ev: String, arg: Variant) -> void:
	match ev:
		"emerge":
			visible = true
			Sfx.play_at("titan_roar", global_position + Vector3(0, 20, 0), 8.0, 90.0)
			Sfx.play_at("splash", global_position + Vector3(0, 6, 0), 6.0, 40.0, 0.6)
			mgr.shake_from(global_position, 0.7, 220.0)
			Game.say("Mặt hồ nổi sóng dữ dội… Thứ gì đó đang trồi lên.", "bad")
		"roar":
			Sfx.play_at("titan_roar", global_position + Vector3(0, HEIGHT, 0), 8.0, 90.0)
			mgr.shake_from(global_position, 0.45, 220.0)
		"windup":
			Sfx.play_at("titan_groan", global_position + Vector3(0, HEIGHT, 0), 4.0, 40.0)
		"slam":
			var pos: Vector3 = arg
			Sfx.play_at("titan_stomp", pos, 6.0, 40.0, 0.7)
			mgr.shake_from(pos, 1.0, 110.0)
			mgr.world.fx.dust(pos, 9.0)
			mgr.world.fx.crater(pos, 5.0)


func visual_tick(delta: float) -> void:
	if state == "dormant":
		visible = false
		return
	visible = true
	rotation.y = yaw
	_t += delta * 0.0
	var tt := Time.get_ticks_msec() * 0.001
	hull.position.y = HEIGHT + sin(tt * 0.5) * 1.2 - (6.0 if state == "stomp" else 0.0)
	_neck.rotation.x = sin(tt * 0.5) * 0.05
	_neck.rotation.y = sin(tt * 0.33) * 0.12
	hull.rotation.z = sin(tt * 0.6) * 0.03
	hull.rotation.x = sin(tt * 0.45) * 0.03 + (0.12 if state == "stomp" else 0.0)
	for i in tentacles.size():
		tentacles[i].rotation = Vector3(sin(tt * 0.8 + i) * 0.25 - speed_now * 0.03, 0, cos(tt * 0.7 + i * 1.7) * 0.25)
	# Hai nhóm chân bước xen kẽ
	_group_t += delta
	var any_stepping := false
	for l in legs:
		if l.stepping():
			any_stepping = true
	if not any_stepping and _group_t > 0.3:
		_step_group = 1 - _step_group
		_group_t = 0.0
	var xf := Transform3D(Basis(Vector3.UP, yaw), global_position)
	var vel := forward() * speed_now
	for l in legs:
		l.ground_y = maxf(0.0, global_position.y)
		l.visible = global_position.y > -HEIGHT - 4.0
		l.update(delta, xf, vel, l.group == _step_group)
