extends Monster
## Bạch Trùng: con sâu thịt trắng dài ~64m, mù và điếc, chỉ bò dọc lòng đường. Bị nó đè hay đứng trước đầu nó thì bị ngoạm.

const SEGMENTS := 40
const SPACING := 2.1

var route: Array[Vector3] = []
var trail: Array[Vector3] = []
var segs: Array[Node3D] = []
var seg_r: Array[float] = []
var head: Node3D
var _hurt_cd: Dictionary = {}
var _warn_cd := 0.0
var _squelch_cd := 0.0


func build() -> void:
	mname = "Bạch Trùng"
	state = "crawl"
	_lay_on_road()
	var flesh := MonsterMesh.flesh(Color("cfc4b6"), Color("a8988a"), Color("8a3a2e"), {"bump": 1.3, "wetness": 0.75, "vein_amount": 0.55, "scale": 0.7, "pulse": 0.06})
	var flesh2 := MonsterMesh.flesh(Color("b8aa9c"), Color("8f7f72"), Color("8a3a2e"), {"bump": 1.5, "wetness": 0.6, "vein_amount": 0.7, "scale": 0.7, "pulse": 0.06})
	var raw := MonsterMesh.flesh(Color("a8584a"), Color("7a3a30"), Color("5a1410"), {"bump": 1.2, "wetness": 1.0, "scale": 1.2})
	var tooth := MonsterMesh.bone(Color("e8dcc4"))
	head = Node3D.new()
	head.top_level = true
	head.scale = Vector3.ONE * 1.45
	add_child(head)
	MonsterMesh.add(head, MonsterMesh.blob(Vector3(1.9, 1.6, 2.6), 70, 0.25, 0.8), flesh2, Vector3(0, 1.6, 1.2), Vector3(0.6, 0, 0))
	MonsterMesh.add(head, MonsterMesh.blob(Vector3(2.4, 1.8, 1.6), 71, 0.28, 0.9), flesh2, Vector3(0, 2.3, 0.1))
	var maw := StandardMaterial3D.new()
	maw.albedo_color = Color("2a0806")
	maw.roughness = 0.15
	MonsterMesh.add(head, MonsterMesh.blob(Vector3(1.1, 0.5, 0.8), 72, 0.1, 0.0, 0.6), maw, Vector3(0, 0.55, 2.5))
	for i in 12:
		var a := i / 12.0 * TAU
		MonsterMesh.add(head, MonsterMesh.spike(0.09, 0.5), tooth, Vector3(cos(a) * 0.95, 0.55 + sin(a) * 0.42, 2.9), Vector3(PI * 0.5, 0, 0))
	for sg: float in [-1.0, 1.0]:
		MonsterMesh.add(head, MonsterMesh.blob(Vector3(0.5, 1.2, 0.9), 73, 0.25, 0.6, 0.6), raw, Vector3(sg * 1.6, 1.9, 0.5))
	var leg_mesh := MonsterMesh.limb(3.8, 0.55, 0.18, 74, 0.3)
	for k in SEGMENTS:
		var r := 3.4 + k * 0.35 if k < 3 else (4.5 + sin(k * 0.35) * 0.25 if k < SEGMENTS - 8 else maxf(1.4, 4.5 - (k - SEGMENTS + 9) * 0.4))
		var g := Node3D.new()
		g.top_level = true
		add_child(g)
		MonsterMesh.add(g, MonsterMesh.blob(Vector3(r, r * 0.95, 1.75), 75 + k % 5, 0.16, 0.5, 0.75), flesh if k % 2 == 0 else flesh2)
		if k % 3 == 0:
			MonsterMesh.add(g, MonsterMesh.blob(Vector3(0.5, 0.25, 0.6), 80 + k % 3, 0.3, 0.4, 0.5), raw, Vector3(rng.randf_range(-r, r) * 0.7, rng.randf_range(0.2, r * 0.8), 0))
		# Cặp chân ngắn, ngoe nguẩy
		if k % 2 == 1 and r > 1.8:
			for sg2: float in [-1.0, 1.0]:
				var l := MonsterMesh.add(g, leg_mesh, flesh, Vector3(sg2 * r * 0.8, -r * 0.2, 0), Vector3(0, 0, sg2 * 0.9))
				l.set_meta("side", sg2)
				l.set_meta("phase", k * 0.7)
				l.name = "Leg%d" % (0 if sg2 < 0 else 1)
		segs.append(g)
		seg_r.append(r)


## Đặt con sâu nằm sẵn dọc lòng đường: đầu ở cuối một đoạn đường dài, cả thân trải ngược về phía sau theo
## đúng các đoạn đường đã đi qua (không duỗi thẳng xuyên qua khối nhà), đầu hướng theo chiều bò.
func _lay_on_road() -> void:
	var need := SEGMENTS * SPACING + 30.0
	var pts: Array[Vector3] = []
	for attempt in 20:
		var a := city.node_pos(Vector2i(2 + (rng.randi() % 15), rng.randi() % (City.ROWS + 1)))
		if not city.node_open(city.nearest_node(a)):
			continue
		pts = city.road_route(a, city.road_point(rng), rng)
		pts.push_front(a)
		var total := 0.0
		for i in pts.size() - 1:
			total += pts[i].distance_to(pts[i + 1])
		if total >= need:
			break
	# đi dọc đường gấp khúc một quãng `need`: chỗ dừng là đầu, phần đã qua là thân
	var walked: Array[Vector3] = [pts[0]]
	var left := need
	var i2 := 0
	while i2 < pts.size() - 1 and left > 0.0:
		var seg := pts[i2].distance_to(pts[i2 + 1])
		if seg >= left:
			walked.append(pts[i2].lerp(pts[i2 + 1], left / seg))
			left = 0.0
			break
		walked.append(pts[i2 + 1])
		left -= seg
		i2 += 1
	global_position = walked[walked.size() - 1]
	var dir := global_position - walked[maxi(0, walked.size() - 2)]
	yaw = atan2(dir.x, dir.z) if dir.length() > 0.1 else 0.0
	route.clear()
	for k in range(i2 + 1, pts.size()):
		route.append(pts[k])
	# trail[0] là đầu, càng về sau càng xa: lấy mẫu mỗi 0,6m ngược theo đường đã đi
	trail.clear()
	var back := walked.duplicate()
	back.reverse()
	trail.append(back[0])
	for k in range(back.size() - 1):
		var a2: Vector3 = back[k]
		var b2: Vector3 = back[k + 1]
		var steps := maxi(1, int(a2.distance_to(b2) / 0.6))
		for s in range(1, steps + 1):
			trail.append(a2.lerp(b2, float(s) / steps))


func hit_spheres() -> Array:
	var out := [[head.global_position + Vector3(0, 1.6, 0), 3.0]]
	for i in range(0, segs.size(), 3):
		out.append([segs[i].global_position, seg_r[i]])
	return out


func on_shot(_attacker: int) -> void:
	pass


func server_tick(delta: float) -> void:
	if route.is_empty():
		route = city.road_route(global_position, city.road_point(rng), rng)
	var to := route[0] - global_position
	to.y = 0.0
	if to.length() < 1.5:
		route.remove_at(0)
		return
	var off := turn_to(to, 0.5, delta)
	var speed := 1.0 if off > 0.6 else 2.4
	global_position += forward() * speed * pace() * delta
	global_position.y = 0.0
	speed_now = speed
	# Một bức tường thịt di động: đè lên ai thì người đó bị nghiền; đầu thì ngoạm.
	for p: Node3D in mgr.players():
		var pos := p.global_position
		if pos.y > 5.0 or pos.y < -1.0:
			continue
		var pid := p.get_multiplayer_authority()
		_hurt_cd[pid] = float(_hurt_cd.get(pid, 0.0)) - delta
		if _hurt_cd[pid] > 0.0:
			continue
		var at_head := Vector2(pos.x - global_position.x, pos.z - global_position.z).length() < 4.8
		var under := false
		if not at_head:
			for i in segs.size():
				var s := segs[i].global_position
				if Vector2(pos.x - s.x, pos.z - s.z).length() < seg_r[i] + 0.4:
					under = true
					break
		if at_head:
			_hurt_cd[pid] = 1.0
			mgr.hurt(p, 34.0, "slash")
			mgr.fire(self, "bite")
		elif under:
			_hurt_cd[pid] = 0.9
			mgr.hurt(p, 16.0, "crush")


func event(ev: String, _arg: Variant) -> void:
	if ev == "bite":
		Sfx.play_at("grub_bite", global_position + Vector3(0, 1.5, 0), 3.0, 16.0)


## Điểm cách đầu một quãng `dist` dọc theo vệt đã bò. Tính từ đúng vị trí đầu hiện tại (không chỉ từ mẩu vệt
## ghi gần nhất), nên thân trườn liền mạch theo đầu thay vì đứng yên rồi giật lên từng nấc 0,5m.
func _point_at(dist: float) -> Array:
	var acc := 0.0
	for i in range(-1, trail.size() - 1):
		var a := global_position if i < 0 else trail[i]
		var b := trail[i + 1]
		var l := a.distance_to(b)
		if acc + l >= dist:
			var t := (dist - acc) / maxf(l, 0.001)
			return [a.lerp(b, t), atan2(a.x - b.x, a.z - b.z)]
		acc += l
	return [trail[trail.size() - 1], yaw]


func visual_tick(delta: float) -> void:
	var tt := Time.get_ticks_msec() * 0.001
	if trail[0].distance_to(global_position) > 0.5:
		trail.insert(0, global_position)
		if trail.size() > 210:
			trail.pop_back()
	head.global_position = global_position + Vector3(0, sin(tt * 3.0) * 0.1, 0)
	head.rotation = Vector3(0, yaw + sin(tt * 0.9) * 0.15, 0)
	for k in segs.size():
		var pa := _point_at(1.6 + (k + 1) * SPACING)
		var w := sin(tt * 3.2 - k * 0.7)
		var g := segs[k]
		g.global_position = (pa[0] as Vector3) + Vector3(0, maxf(1.0, seg_r[k] * 0.87) + w * 0.16, 0)
		g.rotation = Vector3(0.03, pa[1], w * 0.02)
		g.scale = Vector3(1.0 + w * 0.04, 1.0, 1.0)
		for nm: String in ["Leg0", "Leg1"]:
			var l := g.get_node_or_null(nm) as Node3D
			if l:
				var sg: float = l.get_meta("side")
				l.rotation = Vector3(sin(tt * 5.0 + float(l.get_meta("phase"))) * 0.5, 0, sg * (0.9 + cos(tt * 5.0 + float(l.get_meta("phase"))) * 0.2))
	_squelch_cd -= delta
	var cam := get_viewport().get_camera_3d()
	if cam and _squelch_cd <= 0.0 and cam.global_position.distance_to(global_position) < 50.0:
		_squelch_cd = 1.6
		mgr.shake_from(global_position, 0.12, 30.0, 0.8)      # trườn qua: rung nhẹ, đều
		Sfx.play_at("grub_squelch", global_position, 0.0, 14.0)
	_warn_cd -= delta
	if cam and _warn_cd <= 0.0 and cam.global_position.y < 6.0 and cam.global_position.distance_to(global_position) < 18.0:
		_warn_cd = 14.0
		Game.say("Bạch Trùng đang bò tới, chiếm gần hết lòng đường. Nó không thấy, không nghe: tránh sang lề hoặc vào nhà.")
