extends Monster
## Dực Quái: bay vòng trên cao, soi người ngoài trời (mái nhà che được), phun cầu lửa. Tiếng nổ của nó chọc giận Thủy Quái.

const ALTITUDE := 95.0
const SPAN := 82.0        # nửa sải cánh: cả hai cánh rộng hơn 160m, che cả một mảng trời

var hull: Node3D
var wings: Array[Node3D] = []
var throat: MeshInstance3D
var tail: Node3D
var _mat: ShaderMaterial
var _dest := Vector3.ZERO
var _state_t := 0.0
var _fire_cd := 4.0
var _orbit := 0.0
var _charge := 0.0
var _flap_cd := 0.0
var balls: Array[Dictionary] = []      # cầu lửa đang bay (máy chủ mô phỏng, máy khác vẽ theo)


## Màng cánh: một tấm da căng giữa vai, cổ tay và bốn ngón dài, mép sau lượn vòng cung giữa các ngón.
func _membrane(side: float, pts: Array, root: Vector3) -> ArrayMesh:
	var verts := PackedVector3Array()
	var edge: Array[Vector3] = []
	for k in pts.size() - 1:
		var a: Vector3 = pts[k]
		var b: Vector3 = pts[k + 1]
		for m in 7:
			var t := m / 7.0
			var p := a.lerp(b, t)
			# mép lõm vào giữa hai đầu ngón
			var inward := (Vector3.ZERO - p).normalized()
			edge.append(p + inward * sin(t * PI) * a.distance_to(b) * 0.16)
	edge.append(pts[pts.size() - 1])
	edge.append(root)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in edge.size() - 1:
		for p: Vector3 in ([Vector3.ZERO, edge[k], edge[k + 1]] if side > 0.0 else [Vector3.ZERO, edge[k + 1], edge[k]]):
			st.add_vertex(Vector3(p.x * side, p.y, p.z))
	st.generate_normals()
	return st.commit()


func _bone(parent: Node3D, a: Vector3, b: Vector3, r0: float, r1: float, mat: Material) -> void:
	var n := Node3D.new()
	parent.add_child(n)
	var y := (a - b).normalized()
	var x := y.cross(Vector3.UP)
	if x.length() < 0.1:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	n.transform = Transform3D(Basis(x, y, x.cross(y).normalized()), a)
	MonsterMesh.add(n, MonsterMesh.limb(a.distance_to(b), r0, r1, 61, 0.1), mat)


func build() -> void:
	mname = "Dực Quái"
	state = "circle"
	global_position = Vector3(city.bounds.end.x - 40.0, ALTITUDE, city.bounds.position.y + 30.0)
	_dest = _waypoint()
	MonsterMesh.rough = 0.2
	# Màu tối, đậm: nhìn từ dưới lên là một bóng đen khổng lồ.
	_mat = MonsterMesh.flesh(Color("27323b"), Color("1e272e"), Color("161d22"), {"bump": 0.2, "wetness": 0.15, "vein_amount": 0.0, "scale": 0.1, "pulse": 0.02})
	var belly := MonsterMesh.flesh(Color("56676f"), Color("46555c"), Color("3a474d"), {"bump": 0.2, "wetness": 0.1, "vein_amount": 0.0, "scale": 0.1})
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color("2f3c46")
	skin.roughness = 0.75
	skin.cull_mode = BaseMaterial3D.CULL_DISABLED
	skin.backlight_enabled = true
	skin.backlight = Color(0.35, 0.16, 0.1)      # nắng xuyên qua màng cánh ửng đỏ
	var beak := MonsterMesh.bone(Color("11161a"))
	hull = Node3D.new()
	add_child(hull)
	MonsterMesh.add(hull, MonsterMesh.blob(Vector3(5.5, 4.2, 20.0), 60, 0.2, 0.5, 1.4), _mat)
	MonsterMesh.add(hull, MonsterMesh.blob(Vector3(4.4, 2.6, 15.0), 61, 0.2, 0.4, 1.2), belly, Vector3(0, -2.2, 1.0))
	MonsterMesh.add(hull, MonsterMesh.blob(Vector3(7.5, 4.8, 9.0), 62, 0.2, 0.5, 1.2), _mat, Vector3(0, 0.6, 5.0))    # ức và vai
	# cổ dài + đầu hẹp + mỏ
	_bone(hull, Vector3(0, 1.0, 17.0), Vector3(0, 2.4, 31.0), 3.2, 1.9, _mat)
	var head := Node3D.new()
	head.position = Vector3(0, 2.6, 33.0)
	hull.add_child(head)
	MonsterMesh.add(head, MonsterMesh.blob(Vector3(2.6, 2.1, 6.0), 63, 0.2, 0.4), _mat, Vector3(0, 0, 3.0))
	MonsterMesh.add(head, MonsterMesh.spike(1.6, 9.0), beak, Vector3(0, -0.2, 12.0), Vector3(PI * 0.5, 0, 0))
	MonsterMesh.add(head, MonsterMesh.spike(1.0, 4.5), _mat, Vector3(0, 2.6, 0.5), Vector3(-0.9, 0, 0))      # mào sau gáy
	var eye := StandardMaterial3D.new()
	eye.albedo_color = Color("ffb347")
	eye.emission_enabled = true
	eye.emission = Color("ff9a2a")
	eye.emission_energy_multiplier = 3.0
	for sx: float in [-1.0, 1.0]:
		MonsterMesh.add(head, SphereMesh.new(), eye, Vector3(sx * 1.9, 0.8, 5.5), Vector3.ZERO, Vector3.ONE * 0.9)
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color("ff7a1a")
	tm.emission_enabled = true
	tm.emission = Color("ff5a10")
	tm.emission_energy_multiplier = 0.3
	throat = MonsterMesh.add(hull, MonsterMesh.blob(Vector3(2.4, 1.8, 3.4), 64, 0.15, 0.3, 0.6), tm, Vector3(0, -1.2, 19.0))
	# đuôi dài, cuối đuôi xoè hình quạt
	tail = Node3D.new()
	tail.position = Vector3(0, 0, -17.0)
	hull.add_child(tail)
	_bone(tail, Vector3.ZERO, Vector3(0, 0, -34.0), 3.0, 0.6, _mat)
	var fan := _membrane(1.0, [Vector3(9, 0, -40), Vector3(4, 0, -48), Vector3(0, 0, -50)], Vector3(0, 0, -30))
	var fan_node := Node3D.new()
	fan_node.position = Vector3(0, 0, 0)
	tail.add_child(fan_node)
	for sg0: float in [-1.0, 1.0]:
		var fm := MeshInstance3D.new()
		fm.mesh = fan
		fm.material_override = skin
		fm.scale = Vector3(sg0, 1, 1)
		fm.position = Vector3(0, 0, 30.0)
		fan_node.add_child(fm)
	for i in 9:
		MonsterMesh.add(hull, MonsterMesh.spike(0.9, 3.4 - i * 0.2), beak, Vector3(0, 4.0, 12.0 - i * 3.4), Vector3(-0.6, 0, 0))
	# hai cánh: xương cánh tay, cổ tay, bốn ngón dài; màng da căng giữa các ngón
	for sg: float in [-1.0, 1.0]:
		var w := Node3D.new()
		w.position = Vector3(sg * 5.0, 2.0, 7.0)
		hull.add_child(w)
		var wrist := Vector3(34, 1.5, 12)
		var tips := [Vector3(SPAN, 0, 6), Vector3(SPAN - 9, 0, -16), Vector3(SPAN - 30, 0, -30), Vector3(SPAN - 54, 0, -30)]
		var mm := MeshInstance3D.new()
		mm.mesh = _membrane(sg, [wrist, tips[0], tips[1], tips[2], tips[3]], Vector3(0, 0, -20))
		mm.material_override = skin
		mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		mm.extra_cull_margin = 40.0
		w.add_child(mm)
		_bone(w, Vector3.ZERO, Vector3(wrist.x * sg, wrist.y, wrist.z), 2.4, 1.5, _mat)
		for tp: Vector3 in tips:
			_bone(w, Vector3(wrist.x * sg, wrist.y, wrist.z), Vector3(tp.x * sg, tp.y, tp.z), 1.2, 0.25, _mat)
		MonsterMesh.add(w, MonsterMesh.spike(0.9, 5.0), beak, Vector3(wrist.x * sg, wrist.y, wrist.z + 3.0), Vector3(PI * 0.5, 0, 0))     # vuốt ở cổ tay
		wings.append(w)
	MonsterMesh.rough = 1.0


func _waypoint() -> Vector3:
	var p := city.road_point(rng)
	return Vector3(p.x, ALTITUDE + rng.randf_range(-8.0, 12.0), p.z)


func hunting() -> bool:
	return state == "attack"


func hit_spheres() -> Array:
	return [[global_position, 14.0], [global_position + forward() * 30.0, 6.0]]


func on_shot(_attacker: int) -> void:
	state = "circle"
	_dest = _waypoint()
	forget()
	mgr.fire(self, "shriek")


func server_tick(delta: float) -> void:
	_state_t += delta
	_fire_cd -= delta
	# Chỉ có mắt: không nghe được gì, và ban đêm thì không nhìn thấy người.
	var seen: Node3D = null
	if night_blind():
		cool_down(delta)
		# ban đêm không thấy người, nhưng thỉnh thoảng phun một quả cầu lửa bừa xuống phố
		if _fire_cd <= 0.0:
			_fire_cd = rng.randf_range(12.0, 26.0)
			var from0 := global_position + forward() * 44.0 + Vector3(0, 1.0, 0)
			var to0 := global_position + forward() * rng.randf_range(40.0, 90.0) + Vector3(rng.randf_range(-25.0, 25.0), 0.0, rng.randf_range(-25.0, 25.0))
			to0.y = 0.3
			var t0 := from0.distance_to(to0) / 40.0
			var vel0 := (to0 - from0) / t0 + Vector3(0, 4.9 * t0 * 0.5, 0)
			balls.append({"p": from0, "v": vel0, "t": 0.0})
			mgr.fire(self, "spit", [from0, vel0])
	else:
		seen = look_for_players(delta, global_position + forward() * 36.0, 200.0, Vector3.ZERO, -1.0, 0.8, 0.15)
	if seen:
		# Chỉ tấn công người ngoài trời (không có mái che).
		target_id = seen.get_multiplayer_authority()
		last_seen = seen.global_position
		lost_t = 0.0
		if state == "circle":
			state = "attack"
			_state_t = 0.0
			_fire_cd = 2.2
			mgr.fire(self, "shriek")
	else:
		lost_t += delta
	var goal := _dest
	var speed := 20.0 * pace()
	if state == "attack":
		_orbit += delta * 0.5
		goal = last_seen + Vector3(cos(_orbit) * 70.0, ALTITUDE - 25.0, sin(_orbit) * 70.0)
		speed = 23.0 * pace()
		if _fire_cd <= 0.0 and seen:
			_fire_cd = 3.8
			var from := global_position + forward() * 44.0 + Vector3(0, 1.0, 0)
			var to := seen.global_position + Vector3(0, 0.5, 0)
			var t := from.distance_to(to) / 40.0
			var vel := (to - from) / t + Vector3(0, 4.9 * t * 0.5, 0)
			balls.append({"p": from, "v": vel, "t": 0.0})
			mgr.fire(self, "spit", [from, vel])
		if lost_t > 8.0:
			state = "circle"
			target_id = 0
			_dest = _waypoint()
	elif global_position.distance_to(_dest) < 25.0:
		_dest = _waypoint()
	var to2 := goal - global_position
	turn_to(to2, 0.45, delta)
	var f := forward()
	global_position += Vector3(f.x, clampf(to2.y * 0.4, -4.0, 4.0) / speed, f.z) * speed * delta
	speed_now = speed
	# Cầu lửa
	for i in range(balls.size() - 1, -1, -1):
		var b: Dictionary = balls[i]
		var next: Vector3 = b.p + b.v * delta
		b.v.y -= 4.9 * delta
		b.t += delta
		var hit: bool = not mgr.clear_line(b.p, next)
		b.p = next
		if hit or next.y <= 0.15 or b.t > 8.0:
			balls.remove_at(i)
			_explode(next)


func _explode(pos: Vector3) -> void:
	mgr.fire(self, "boom", pos)
	for p: Node3D in mgr.players():
		var d := p.global_position.distance_to(pos)
		mgr.world.civs.crush(pos, 4.0)
		if d < 4.2 and mgr.clear_line(pos + Vector3(0, 0.6, 0), p.global_position + Vector3(0, 1.0, 0)):
			mgr.hurt(p, lerpf(36.0, 10.0, d / 4.2), "burn")
	mgr.hear(pos, 1.0, "flyer")


func event(ev: String, arg: Variant) -> void:
	match ev:
		"shriek":
			Sfx.play_at("flyer_shriek", global_position, 8.0, 70.0, 0.8)
		"spit":
			_charge = 1.0
			Sfx.play_at("fireball", global_position, 6.0, 60.0)
			mgr.world.fx.fireball(arg[0], arg[1])
		"boom":
			var pos: Vector3 = arg
			Sfx.play_at("explosion", pos, 4.0, 30.0)
			mgr.shake_from(pos, 0.7, 45.0)
			mgr.world.fx.explosion(pos, 4.0)
			mgr.world.fx.stop_fireball_near(pos)


func visual_tick(delta: float) -> void:
	rotation.y = yaw
	var tt := Time.get_ticks_msec() * 0.001
	# Vỗ cánh chậm rãi, nặng nề.
	var flap := sin(tt * 1.15)
	hull.position.y = -flap * 3.0
	hull.rotation.z = sin(tt * 0.4) * 0.1
	hull.rotation.x = sin(tt * 0.3) * 0.04
	for i in wings.size():
		var sg := -1.0 if i == 0 else 1.0
		wings[i].rotation.z = sg * (flap * 0.38 + 0.08)
		wings[i].rotation.y = sg * sin(tt * 1.15 - 0.8) * 0.08
	tail.rotation.y = sin(tt * 0.6) * 0.12
	tail.rotation.x = sin(tt * 1.15 - 1.2) * 0.06
	_flap_cd -= delta
	if flap < -0.92 and _flap_cd <= 0.0:
		_flap_cd = 4.0
		Sfx.play_at("flyer_flap", global_position, 8.0, 90.0, 0.5)
		mgr.shake_from(Vector3(global_position.x, 0.0, global_position.z), 0.1, 60.0, 0.3)     # luồng gió khi nó vỗ cánh ngay trên đầu
	_charge = maxf(0.0, _charge - delta * 0.8)
	(throat.material_override as StandardMaterial3D).emission_energy_multiplier = 0.3 + _charge * 6.0 + (1.2 if state == "attack" else 0.0)
