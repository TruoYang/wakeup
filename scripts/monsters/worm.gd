extends Monster
## Thổ Trùng: sống dưới đất, không có mắt. Nghe tiếng bước chân từ rất xa; ngồi đi rón rén thì nó không biết.
## Khi tới nơi: mặt đất rung, nứt ra, rồi nó phóng lên đớp.

var segs: Array[MeshInstance3D] = []
var mound: MeshInstance3D
var jaws: Node3D
var _state_t := 0.0
var _strike := Vector3.ZERO
var _dest := Vector3.ZERO
var _erupt_t := -1.0
var _erupt_from := Vector3.ZERO
var _erupt_to := Vector3.ZERO
var _rumble_cd := 0.0
var _prev_pos: Dictionary = {}


func build() -> void:
	mname = "Thổ Trùng"
	state = "roam"
	global_position = city.node_pos(city.nearest_node(city.road_point(rng)))
	_dest = city.road_point(rng)
	# Màu như bản cũ: nâu đất, các khoanh nhạt hơn.
	var mat := MonsterMesh.flesh(Color("5e4535"), Color("8a6a52"), Color("3a2a20"), {"bump": 1.5, "wetness": 0.35, "vein_amount": 0.3, "scale": 0.5, "pulse": 0.05})
	var band := MonsterMesh.flesh(Color("a8907a"), Color("8a6a52"), Color("5e4535"), {"bump": 1.4, "wetness": 0.3, "vein_amount": 0.2, "scale": 0.5})
	for k in 14:
		var r := 5.0 - k * 0.22             # to gấp rưỡi bản cũ
		var mi := MonsterMesh.add(self, MonsterMesh.blob(Vector3(r, r, r * 1.25), 40 + k % 4, 0.2, 0.5, 0.8), band if k % 3 == 1 else mat)
		mi.top_level = true
		mi.visible = false
		segs.append(mi)
	jaws = Node3D.new()
	segs[0].add_child(jaws)
	var tooth := MonsterMesh.bone()
	jaws.scale = Vector3.ONE * 2.1
	for k in 5:
		var a := k / 5.0 * TAU
		MonsterMesh.add(jaws, MonsterMesh.spike(0.8, 3.4), tooth, Vector3(cos(a) * 1.5, sin(a) * 1.5, 2.6), Vector3(PI * 0.5 - sin(a) * 0.35, 0, cos(a) * 0.35))
	for k in 16:
		var a2 := k / 16.0 * TAU
		MonsterMesh.add(jaws, MonsterMesh.spike(0.14, 0.8), tooth, Vector3(cos(a2) * 1.3, sin(a2) * 1.3, 2.2), Vector3(PI * 0.5, 0, 0))
	var throat := StandardMaterial3D.new()
	throat.albedo_color = Color("200605")
	MonsterMesh.add(jaws, MonsterMesh.blob(Vector3(1.5, 1.5, 0.6), 44, 0.1, 0.0, 0.6), throat, Vector3(0, 0, 2.0))
	# Ụ đất chạy trên mặt đường khi nó di chuyển bên dưới
	mound = MonsterMesh.add(self, MonsterMesh.blob(Vector3(2.6, 0.75, 3.6), 45, 0.3, 0.4, 0.6), Mats.get_mat("dirt"))
	mound.position.y = -0.1


func hunting() -> bool:
	return state in ["track", "warn", "erupt"]


func hit_spheres() -> Array:
	var out := []
	if state == "erupt":
		for s in segs:
			if s.visible:
				out.append([s.global_position, 5.0])
	return out


func heard(pos: Vector3, loud: float, _source: String) -> void:
	# Nghe cả tiếng người khác chạy, tiếng đồ vỡ, tiếng nổ - nhưng chỉ trong tầm vừa phải.
	var reach := 75.0 if loud >= 0.75 else 38.0
	if loud >= 0.5 and state in ["roam", "track"] and global_position.distance_to(pos) < reach:
		last_seen = pos
		state = "track"


var _breach_t := 25.0


func server_tick(delta: float) -> void:
	_state_t += delta
	# thỉnh thoảng tự phóng vọt lên khỏi mặt đất rồi chui xuống (như cá voi nhảy) — để người chơi thấy nó tồn tại
	if state == "roam":
		_breach_t -= delta
		if _breach_t <= 0.0:
			_breach_t = rng.randf_range(40.0, 80.0)
			var fwd2 := forward()
			mgr.fire(self, "erupt", [global_position, global_position + fwd2 * 28.0])
	# Nghe bước chân: chỉ người đang đứng trên mặt đất và gây tiếng động.
	if state in ["roam", "track"]:
		var best: Node3D = null
		var best_a := 0.0
		for p: Node3D in mgr.players():
			var pid := p.get_multiplayer_authority()
			var a: float = aw.get(pid, 0.0)
			var noise: float = p.net_noise
			var grounded: bool = p.global_position.y < 1.6 and p.global_position.y > -0.5 and (p.net_flags & 2) == 0
			var reach := 44.0 * noise * float(Game.diff().sense)
			var d := global_position.distance_to(p.global_position)
			if grounded and noise > 0.12 and d < reach:
				a = minf(1.0, a + delta * (0.35 + 0.9 * (1.0 - d / reach)))
				sense = "hear"
			else:
				a = maxf(0.0, a - delta * 0.18)
			aw[pid] = a
			if a >= 1.0 and a >= best_a and grounded:
				best = p
				best_a = a
		if best:
			target_id = best.get_multiplayer_authority()
			if best.net_noise > 0.12:
				# đón đầu: con mồi chạy nhanh (hoặc đi xe) thì nó trồi lên ở chỗ con mồi SẮP tới
				var prev: Vector3 = _prev_pos.get(target_id, best.global_position)
				var vel := (best.global_position - prev) / maxf(delta, 0.001)
				vel.y = 0.0
				last_seen = best.global_position + vel.limit_length(15.0) * 1.7
			_prev_pos[target_id] = best.global_position
			lost_t = 0.0
			state = "track"
		else:
			lost_t += delta
	match state:
		"roam":
			_travel(_dest, 4.2, delta)
			if global_position.distance_to(_dest) < 4.0:
				_dest = city.road_point(rng)
		"track":
			_travel(last_seen, 9.5, delta)
			if Vector2(global_position.x - last_seen.x, global_position.z - last_seen.z).length() < 2.2:
				state = "warn"
				_state_t = 0.0
				_strike = Vector3(last_seen.x, 0.0, last_seen.z)
				mgr.fire(self, "warn", _strike)
			elif lost_t > 12.0:
				state = "roam"
				target_id = 0
		"warn":
			speed_now = 0.0
			if _state_t >= 1.35:
				state = "erupt"
				_state_t = 0.0
				var dir := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
				mgr.fire(self, "erupt", [_strike, _strike + dir * 28.0])
		"erupt":
			if _state_t >= 0.3 and _state_t - delta < 0.3:
				for p: Node3D in mgr.players():
					var d2 := Vector2(p.global_position.x - _strike.x, p.global_position.z - _strike.z).length()
					if d2 < 4.6 and p.global_position.y < 6.0:
						mgr.hurt(p, lerpf(68.0, 30.0, d2 / 4.6), "slash")
				mgr.world.civs.crush(_strike, 4.6)
			if _state_t >= 2.4:
				state = "rest"
				_state_t = 0.0
				global_position = _strike
				forget()
		"rest":
			speed_now = 0.0
			if _state_t >= 7.0:
				state = "roam"
				target_id = 0
				_dest = city.road_point(rng)


func _travel(to: Vector3, speed: float, delta: float) -> void:
	var d := to - global_position
	d.y = 0.0
	if d.length() > 0.5:
		turn_to(d, 2.2, delta)
		global_position += forward() * speed * pace() * delta
	global_position.y = 0.0
	speed_now = speed


func event(ev: String, arg: Variant) -> void:
	match ev:
		"warn":
			var pos: Vector3 = arg
			Sfx.play_at("worm_rumble", pos, 4.0, 22.0)
			mgr.shake_from(pos, 0.6, 34.0, 2.6)
			mgr.world.fx.cracks(pos, 4.2)
			mgr.world.fx.dust(pos, 2.5)
		"erupt":
			_erupt_from = arg[0]
			_erupt_to = arg[1]
			_erupt_t = 0.0
			Sfx.play_at("worm_erupt", _erupt_from, 6.0, 40.0)
			mgr.shake_from(_erupt_from, 1.0, 70.0, 1.0)
			mgr.world.fx.dust(_erupt_from, 7.0)
			mgr.world.fx.crater(_erupt_from, 4.6)
			mgr.world.fx.debris(_erupt_from, 14)


func visual_tick(delta: float) -> void:
	var tt := Time.get_ticks_msec() * 0.001
	mound.visible = state in ["roam", "track"]
	mound.rotation.y = yaw
	mound.position.y = -0.15 + sin(tt * 9.0) * 0.05
	if mound.visible:
		_rumble_cd -= delta
		if _rumble_cd <= 0.0:
			_rumble_cd = 0.35
			mgr.world.fx.dust(global_position, 0.9)
			mgr.shake_from(global_position, 0.16 if state == "track" else 0.08, 22.0, 2.4)     # đất rung rần rật khi nó bò bên dưới


## Cú phóng lên khỏi mặt đất vẽ theo từng khung hình (không theo nhịp vật lý 60 lần/giây) cho mượt trên màn hình tần số cao.
func _process(delta: float) -> void:
	if _erupt_t < 0.0 or Game.frozen():
		return
	var tt := Time.get_ticks_msec() * 0.001
	_erupt_t += delta
	var dur := 2.3
	var k := _erupt_t / dur
	for i in segs.size():
		# Từng đốt chạy theo một đường cong vọt lên rồi chui xuống.
		var s := k * 1.55 - i * 0.045
		var m := segs[i]
		if s <= 0.0 or s >= 1.0:
			m.visible = false
			continue
		var p := _erupt_from.lerp(_erupt_to, s)
		p.y = sin(s * PI) * 14.0 - 1.5
		var s2 := s + 0.02
		var p2 := _erupt_from.lerp(_erupt_to, s2)
		p2.y = sin(s2 * PI) * 14.0 - 1.5
		m.visible = true
		m.global_position = p
		m.look_at(p - (p2 - p), Vector3.UP)
		m.rotate_object_local(Vector3.FORWARD, sin(tt * 6.0 + i) * 0.1)
	jaws.scale = Vector3.ONE * (1.4 + sin(tt * 14.0) * 0.08)
	if _erupt_t > dur + 0.4:
		_erupt_t = -1.0
		for m2 in segs:
			m2.visible = false
