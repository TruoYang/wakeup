extends Monster
## Săn Mồi: thú săn bốn chân, nhanh hơn người. Dùng mắt là chính; mất dấu khi bạn khuất sau tường hoặc chui vào nhà cửa hẹp.

const K := 4.6      # thân dài khoảng 13m, cao hơn nhà một tầng

var mover: CharacterBody3D
var legs: Array[MonsterLeg] = []
var hull: Node3D
var jaw: Node3D
var _mat: ShaderMaterial
var _state_t := 0.0
var _dest := Vector3.ZERO
var _bite_cd := 0.0
var _stun := 0.0
var _shots := 0
var _stuck_t := 0.0
var _growl_cd := 0.0
var _step_group := 0
var _group_t := 0.0
var _hurt_flash := 0.0
var _since_seen := 0.0      # đã bao lâu không còn nhìn thấy con mồi
var _path: Array[Vector3] = []
var _path_t := 0.0
var _path_goal := Vector3.ZERO
var _idle_t := 0.0        # đã đứng im bao lâu dù đang muốn đi
var _force_t := 0.0       # đang cố lách ra khỏi chỗ kẹt (tạm bỏ qua việc tránh quẹt đầu vào tường)
const REACH := 11.5        # từ tâm thân tới chóp mũi


func build() -> void:
	mname = "Săn Mồi"
	state = "patrol"
	var start := city.node_pos(city.nearest_node(city.road_point(rng)))
	while start.distance_to(city.start_pos) < 150.0:
		start = city.node_pos(city.nearest_node(city.road_point(rng)))
	global_position = start + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
	_dest = city.road_point(rng)
	yaw = (rng.randi() % 4) * PI * 0.5       # quay dọc theo một trong bốn ngả đường: đầu dài 11m, quay chéo thì mũi chọc vào góc nhà
	mover = CharacterBody3D.new()
	mover.top_level = true
	mover.collision_layer = 8
	mover.collision_mask = 1
	mover.floor_snap_length = 0.4
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 2.4
	cap.height = 6.6
	cs.shape = cap
	cs.position.y = 5.5          # thân ở trên cao: bước qua được xe, rào chắn, đống đổ nát
	mover.add_child(cs)
	add_child(mover)
	mover.global_position = global_position

	# Màu như bản cũ: thân xám đen, gai và hàm xám nhạt, mắt cam.
	MonsterMesh.rough = 0.3
	_mat = MonsterMesh.flesh(Color("3c3f44"), Color("2c2e32"), Color("202226"), {"bump": 0.25, "wetness": 0.2, "vein_amount": 0.0, "scale": 0.5, "pulse": 0.01})
	var tooth := MonsterMesh.bone(Color("9a968c"))
	hull = Node3D.new()
	hull.position.y = 1.35 * K
	hull.scale = Vector3.ONE * K
	add_child(hull)
	MonsterMesh.add(hull, MonsterMesh.blob(Vector3(0.62, 0.6, 1.25), 50, 0.28, 0.7), _mat)
	MonsterMesh.add(hull, MonsterMesh.blob(Vector3(0.7, 0.72, 0.8), 51, 0.3, 0.9), _mat, Vector3(0, 0.18, 0.75))
	MonsterMesh.add(hull, MonsterMesh.blob(Vector3(0.45, 0.42, 0.6), 52, 0.25, 0.5), _mat, Vector3(0, -0.05, -1.25))
	# Đầu dài, không mắt, hàm mở rộng
	var head := Node3D.new()
	head.position = Vector3(0, 0.25, 1.55)
	hull.add_child(head)
	MonsterMesh.add(head, MonsterMesh.blob(Vector3(0.36, 0.3, 0.62), 53, 0.22, 0.5), _mat, Vector3(0, 0.08, 0.2))
	var eye := StandardMaterial3D.new()
	eye.albedo_color = Color("ffb347")
	eye.emission_enabled = true
	eye.emission = Color("ffb347")
	eye.emission_energy_multiplier = 2.5
	for ex: float in [-1.0, 1.0]:
		MonsterMesh.add(head, SphereMesh.new(), eye, Vector3(ex * 0.22, 0.22, 0.52), Vector3.ZERO, Vector3.ONE * 0.11)
	jaw = Node3D.new()
	jaw.position = Vector3(0, -0.12, 0.05)
	head.add_child(jaw)
	MonsterMesh.add(jaw, MonsterMesh.blob(Vector3(0.3, 0.12, 0.55), 54, 0.2, 0.3, 0.7), _mat, Vector3(0, 0, 0.3))
	for i in 10:
		var tx := -0.24 + (i % 5) * 0.12
		var up := i < 5
		MonsterMesh.add(jaw if not up else head, MonsterMesh.spike(0.035, 0.24), tooth, Vector3(tx, 0.1 if not up else -0.08, 0.72 - absf(tx) * 0.5), Vector3(0.0 if not up else PI, 0, 0))
	# Gai sống lưng + đuôi
	for i in 9:
		MonsterMesh.add(hull, MonsterMesh.spike(0.07, 0.35 + 0.3 * sin(i * 0.4)), tooth, Vector3(0, 0.62 - absf(i - 4) * 0.02, 0.9 - i * 0.27), Vector3(-0.5, 0, 0))
	var tail := MonsterMesh.add(hull, MonsterMesh.limb(1.8, 0.2, 0.03, 55, 0.3), _mat, Vector3(0, 0.0, -1.6), Vector3(-1.25, 0, 0))
	tail.name = "Tail"
	var leg_mat := MonsterMesh.flesh(Color("3c3f44"), Color("2c2e32"), Color("202226"), {"bump": 0.25, "wetness": 0.2, "vein_amount": 0.0, "scale": 0.12})
	var upper := MonsterMesh.limb(0.95 * K, 0.2 * K, 0.11 * K, 56, 0.3)
	var lower := MonsterMesh.limb(1.05 * K, 0.12 * K, 0.06 * K, 57, 0.3)
	var claw := MonsterMesh.blob(Vector3(0.13, 0.06, 0.2) * K, 58, 0.2, 0.3, 0.5)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var leg := MonsterLeg.new()
			add_child(leg)
			leg.l1 = 0.95 * K
			leg.l2 = 1.05 * K
			leg.hip_local = Vector3(sx * 0.5, 1.3, sz * 0.9) * K
			leg.rest_local = Vector3(sx * 0.85, 0.0, sz * 1.05) * K
			leg.stride = 0.9 * K
			leg.step_time = 0.2
			leg.lift = 0.45 * K
			leg.group = 0 if sx * sz > 0.0 else 1
			leg.knee_dir = Vector3(sx * 0.4, 1.0, -sz * 0.8)
			leg.build(upper, lower, leg_mat, claw, tooth)
			leg.planted.connect(func(p: Vector3) -> void: mgr.shake_from(p, 0.22, 34.0, 1.6))
			legs.append(leg)
	MonsterMesh.rough = 1.0


func hunting() -> bool:
	return state in ["hunt", "search"]


## Xoay về một hướng, nhưng không xoay nếu làm vậy khiến đầu quét vào tường nhà.
func _safe_turn(dir: Vector3, rate: float, delta: float) -> void:
	var want := atan2(dir.x, dir.z)
	var d := wrapf(want - yaw, -PI, PI)
	var step := clampf(d, -rate * delta, rate * delta)
	if absf(step) < 0.0005:
		return
	var nf := Vector3(sin(yaw + step * 6.0), 0.0, cos(yaw + step * 6.0))
	var ahead := _clear_ahead(nf)
	if ahead >= REACH + 0.4 or ahead >= _clear_ahead(forward()) - 0.01:
		yaw += step


## Khoảng trống phía trước (tính tới tường gần nhất) để đầu và cổ không thò xuyên tường.
func _clear_ahead(dir: Vector3) -> float:
	var best := 999.0
	for h: float in [3.4, 5.6]:
		for side: float in [-2.2, 0.0, 2.2]:
			var from := global_position + Vector3(0, h, 0) + Vector3(dir.z, 0, -dir.x) * side
			var q := PhysicsRayQueryParameters3D.create(from, from + dir * (REACH + 3.0), 1)
			var hit := get_world_3d().direct_space_state.intersect_ray(q)
			if not hit.is_empty():
				best = minf(best, from.distance_to(hit.position))
	return best


func hit_spheres() -> Array:
	return [[global_position + Vector3(0, 6.0, 0) + forward() * 3.0, 4.8], [global_position + Vector3(0, 6.0, 0) - forward() * 3.3, 4.5], [global_position + Vector3(0, 2.2, 0), 3.0]]


func on_melee(attacker: int, stun: float, power: float) -> void:
	if state == "flee":
		return
	_stun = stun * power
	state = "stun"
	_state_t = 0.0
	target_id = attacker
	mgr.fire(self, "hurt")


func on_shot(attacker: int) -> void:
	_shots += 1
	mgr.fire(self, "hurt")
	if _shots >= 4:
		state = "flee"
		_state_t = 0.0
		_shots = 0
		forget()
		_dest = _far_point()
	else:
		_stun = 1.4
		state = "stun"
		_state_t = 0.0
		target_id = attacker


func _far_point() -> Vector3:
	var best := city.road_point(rng)
	for i in 6:
		var p := city.road_point(rng)
		if p.distance_to(global_position) > best.distance_to(global_position):
			best = p
	return best


func heard(pos: Vector3, loud: float, _source: String) -> void:
	if state in ["patrol"] and loud >= 0.5 and global_position.distance_to(pos) < (90.0 if loud >= 0.75 else 55.0):
		last_seen = pos
		state = "search"
		_state_t = 0.0
		_dest = pos


func server_tick(delta: float) -> void:
	_state_t += delta
	_bite_cd -= delta
	_growl_cd -= delta
	var eye := global_position + Vector3(0, 7.0, 0) + forward() * 6.8
	var seen: Node3D = null
	if state != "flee" and state != "stun" and state != "leave":
		seen = look_for_players(delta, eye, 48.0, forward(), 0.15, 1.0)
		# Ở sát bên thì không cần đứng trước mặt nó mới bị phát hiện: nó ngửi, cảm thấy hơi người.
		for np: Node3D in mgr.players():
			if global_position.distance_to(np.global_position) < 17.0:
				var s2: float = mgr.sees(global_position + Vector3(0, 5.0, 0), np, 17.0, Vector3.ZERO, -1.0)
				if s2 > 0.0:
					var npid := np.get_multiplayer_authority()
					aw[npid] = minf(1.0, float(aw.get(npid, 0.0)) + delta * 0.8)
					if aw[npid] >= 1.0 and seen == null:
						seen = np
		# Tai: tiếng bước chân gần
		for p: Node3D in mgr.players():
			var d := global_position.distance_to(p.global_position)
			if p.net_noise > 0.3 and d < 24.0 * p.net_noise:
				var pid := p.get_multiplayer_authority()
				aw[pid] = maxf(float(aw.get(pid, 0.0)), minf(0.6, float(aw.get(pid, 0.0)) + delta * 0.4))     # nghe thì chỉ nghi ngờ, phải thấy mới săn
				sense = "hear"
				if state == "patrol" and aw[pid] > 0.5:
					state = "search"
					_dest = p.global_position
					_state_t = 0.0
	if seen:
		target_id = seen.get_multiplayer_authority()
		last_seen = seen.global_position
		lost_t = 0.0
		if state in ["patrol", "search"]:
			state = "hunt"
			if _growl_cd <= 0.0:
				_growl_cd = 6.0
				mgr.fire(self, "screech")
	else:
		lost_t += delta
	# Mất dấu quá 20 giây thì bỏ cuộc và đi hẳn chỗ khác.
	if seen:
		_since_seen = 0.0
	elif state in ["hunt", "search"]:
		_since_seen += delta
		if _since_seen > 20.0:
			state = "leave"
			_state_t = 0.0
			_since_seen = 0.0
			target_id = 0
			forget()
			_dest = _far_point()
	var speed := 0.0
	var goal := global_position
	match state:
		"patrol":
			speed = 3.6
			goal = _dest
			if _flat_dist(_dest) < 3.0 or _stuck_t > 2.0:
				_dest = city.road_point(rng)
				_stuck_t = 0.0
		"search":
			speed = 5.2
			goal = _dest
			if _flat_dist(_dest) < 2.0 or _stuck_t > 1.5:
				_dest = last_seen + Vector3(rng.randf_range(-9, 9), 0, rng.randf_range(-9, 9))
				_stuck_t = 0.0
			if _state_t > 9.0:
				state = "patrol"
				target_id = 0
				_dest = city.road_point(rng)
		"hunt":
			speed = 8.6
			var rider: Node3D = mgr.player_by_id(target_id)
			if rider and (rider.net_flags & 64) != 0:
				speed = 14.2        # con mồi đi xe máy: nó bứt tốc, nhanh hơn xe
			goal = last_seen
			var tp: Node3D = mgr.player_by_id(target_id)
			if tp and seen == tp and global_position.distance_to(tp.global_position) < 10.0:
				speed = 0.0
				_safe_turn(tp.global_position - global_position, 2.0, delta)
				if _bite_cd <= 0.0:
					_bite_cd = 1.3
					mgr.fire(self, "bite")
					mgr.hurt(tp, 26.0, "slash")
			elif lost_t > 5.0 or (lost_t > 1.0 and _flat_dist(last_seen) < 1.5):
				state = "search"
				_state_t = 0.0
				_dest = last_seen
		"stun":
			speed = 3.0
			var tp2: Node3D = mgr.player_by_id(target_id)
			goal = global_position + (global_position - (tp2.global_position if tp2 else last_seen)).normalized() * 6.0
			if _state_t >= _stun:
				state = "hunt" if tp2 else "patrol"
				lost_t = 0.0
				if tp2:
					last_seen = tp2.global_position
		"leave":
			speed = 5.0
			goal = _dest
			if _state_t > 25.0 or _flat_dist(_dest) < 6.0:
				state = "patrol"
				_dest = city.road_point(rng)
		"flee":
			speed = 9.5
			goal = _dest
			if _state_t > 45.0 or _flat_dist(_dest) < 4.0 and _state_t > 20.0:
				state = "patrol"
				_dest = city.road_point(rng)
	speed *= pace()
	# Thân dài hơn 20m nên nó chỉ đi dọc tim đường và rẽ ở ngã tư: không đi chéo qua khối nhà.
	_path_t -= delta
	if _path_t <= 0.0 or _path.is_empty() or _path_goal.distance_to(goal) > 6.0:
		_path_t = 1.5
		_path_goal = goal
		var here := city.road_project(global_position)
		var there := city.road_project(goal)
		if (absf(here.z - there.z) < 3.0 or absf(here.x - there.x) < 3.0) and not city.crosses_lake(here, there):
			_path = [there]
		else:
			_path = city.road_route(here, there)
			# bỏ ngã tư đầu nếu nó nằm ngược hướng với ngã tư kế tiếp
			if _path.size() >= 2 and (_path[0] - here).dot(_path[1] - here) < 0.0 and here.distance_to(_path[0]) > 6.0:
				pass
	if _path.size() > 1 and _flat_dist(_path[0]) < 4.5:
		_path.remove_at(0)
	var waypoint: Vector3 = _path[0] if not _path.is_empty() else goal
	# còn lệch khỏi tim đường thì về tim đường trước
	var centre := city.road_project(global_position)
	if _flat_dist(centre) > 2.5 and state != "stun":
		waypoint = centre
	var to := waypoint - global_position
	to.y = 0.0
	var before := mover.global_position
	var wanted := speed
	_force_t -= delta
	if speed > 0.0 and to.length() > 0.3:
		if _force_t > 0.0:
			# đang lách ra khỏi chỗ kẹt: được xoay tự do, nhưng đầu sắp thò vào tường thì lùi lại thay vì húc tới
			turn_to(to, 2.6, delta)
			var gap_f := _clear_ahead(forward())
			if gap_f < REACH - 0.5:
				speed = -3.0
			elif gap_f < REACH + 0.5:
				speed = minf(speed, 1.0)
		else:
			_safe_turn(to, 2.6, delta)
			# đừng tiến sát tường tới mức đầu thò vào trong nhà
			var gap := _clear_ahead(forward())
			if gap < REACH + 0.5:
				speed = 0.0 if gap > REACH - 1.0 else -3.0
		var v := forward() * speed
		mover.velocity = Vector3(v.x, 0.0, v.z)
	else:
		mover.velocity = Vector3.ZERO
	mover.move_and_slide()
	mover.global_position.y = 0.0
	# Tránh nước: lùi lại nếu sắp xuống hồ
	if city.water_depth(mover.global_position + Vector3(0, 0.4, 0)) > 0.0:
		mover.global_position = before
		_stuck_t += 1.0
	global_position = mover.global_position
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length() / maxf(delta, 0.001)
	speed_now = lerpf(speed_now, moved, 0.3)
	# Đứng im quá lâu dù đang muốn đi (kẹt giữa tường và chướng ngại): lách ra, chấp nhận quẹt nhẹ, và đổi đích.
	if wanted > 1.0 and moved < 0.6:
		_idle_t += delta
		if _idle_t > 2.5:
			_idle_t = 0.0
			_force_t = 3.0
			_path_t = 0.0
			if state == "patrol" or state == "leave":
				_dest = city.road_point(rng)
	else:
		_idle_t = 0.0
	if speed > 1.0 and moved < speed * 0.25:
		_stuck_t += delta
		# kẹt: tính lại đường đi
		_path_t = 0.0
	else:
		_stuck_t = maxf(0.0, _stuck_t - delta)


func _flat_dist(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func event(ev: String, _arg: Variant) -> void:
	match ev:
		"screech":
			Sfx.play_at("stalker_screech", global_position + Vector3(0, 4.0, 0), 4.0, 26.0, 0.8)
		"bite":
			Sfx.play_at("stalker_bite", global_position + Vector3(0, 3.0, 0), 4.0, 16.0, 0.8)
			jaw.rotation.x = 0.9
		"hurt":
			_hurt_flash = 1.0
			Sfx.play_at("stalker_growl", global_position + Vector3(0, 3.0, 0), 4.0, 18.0, 1.0)


func visual_tick(delta: float) -> void:
	rotation.y = yaw
	if not multiplayer.is_server():
		mover.global_position = global_position
	var tt := Time.get_ticks_msec() * 0.001
	var run := clampf(speed_now / 8.0, 0.0, 1.0)
	hull.position.y = (1.3 + sin(tt * (3.0 + run * 9.0)) * (0.03 + run * 0.08) - (0.25 if state == "search" else 0.0)) * K
	hull.rotation.x = sin(tt * (4.0 + run * 14.0) + 1.0) * 0.05 * run
	jaw.rotation.x = move_toward(jaw.rotation.x, 0.55 if state == "hunt" else 0.12, delta * 3.0)
	_hurt_flash = maxf(0.0, _hurt_flash - delta * 2.0)
	_mat.set_shader_parameter("hurt", _hurt_flash)
	var tail := hull.get_node_or_null("Tail") as Node3D
	if tail:
		tail.rotation.y = sin(tt * 3.0) * 0.4
	_group_t += delta
	var any := false
	for l in legs:
		if l.stepping():
			any = true
	if not any and _group_t > 0.03:
		_step_group = 1 - _step_group
		_group_t = 0.0
	var xf := Transform3D(Basis(Vector3.UP, yaw), global_position)
	var vel := forward() * speed_now
	for l in legs:
		l.ground_y = global_position.y
		l.step_time = lerpf(0.36, 0.17, run)
		l.stride = lerpf(0.5, 1.3, run) * K
		l.update(delta, xf, vel, l.group == _step_group)
