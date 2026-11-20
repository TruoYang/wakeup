extends Monster
## Cua Quỷ: khối thịt hồng nhợt phình tròn rộng chừng 2,6m, miệng hốc đầy răng trên lưng, mười chân nhện dài, bò ngang như cua.
## Chúng trồi lên từ khe nứt và từ hồ theo từng đợt (mỗi đợt có hạn), nhìn xa tới 70m.
## Thân quá rộng để đi thẳng qua cửa, nên muốn vào nhà nó dựng nghiêng người, bám vào tường mà lách qua.
## Giết được từng con nhưng không bao giờ diệt sạch: đợt sau lại có con khác trồi lên.

const SPEED_ROAM := 1.8
const SPEED_CHASE := 5.6
const MAX_HP := 5.0
const SIGHT := 70.0
const HALF_W := 1.5

var hp := MAX_HP
var _body: Node3D
var _tilt: Node3D
var _wall := 0.0             # 0 = bò phẳng trên mặt đất, 1 = dựng nghiêng bám tường (trong nhà)
var wall_mode := false      # máy chủ quyết định, gửi cho các máy khác
var _jaw: Node3D
var _mouth: Node3D
var _legs: Array[Node3D] = []
var _mat: ShaderMaterial
var _state_t := 0.0
var _dest := Vector3.ZERO
var _bite_cd := 0.0
var _stun := 0.0
var _ti := -1               # đang lần tới mẩu dấu vết thứ mấy của con mồi
var _lost := 0.0
var _side_t := 0.0
var _side := 1.0
var _hurt_flash := 0.0
var _dead_t := 0.0
var _warned := false
var _exit := Vector3.ZERO     # chỗ leo lên mặt đất khi trồi từ khe nứt / hồ
var _far_t := 0.0
## Người chơi mà con này được "gọi" tới (đợt phục kích lúc vác máy phát): trồi lên xong là mò thẳng tới chỗ người đó.
var lure := 0


func build() -> void:
	mname = "Cua Quỷ"
	state = "dormant"
	global_position = Vector3(0, -60, 0)
	visible = false
	MonsterMesh.rough = 0.3
	# mai nâu ô-liu loang lổ, bụng và chân nâu sẫm, gai ngà
	# Kiểu "Chomper": một khối thịt hồng nhợt phình tròn, mặt cắt góc cạnh, miệng hốc khổng lồ trên lưng
	# (môi đỏ, hai vòng răng), chùm mắt đen nhỏ phía trước, mười chân nhện dài gấp khúc.
	# Mọi mảng đều dựng ít mặt rồi làm phẳng pháp tuyến (MonsterMesh.facet) cho hợp nét vẽ tay của game.
	_mat = MonsterMesh.flesh(Color("d7a199"), Color("b9786f"), Color("6e1622"), {"bump": 0.08, "wetness": 0.25, "vein_amount": 0.55, "scale": 1.6, "pulse": 0.0, "glow": 0.05})
	var dark := MonsterMesh.flesh(Color("9c6a64"), Color("7a4c48"), Color("3a1418"), {"bump": 0.05, "wetness": 0.2, "vein_amount": 0.15, "scale": 1.8, "pulse": 0.0})
	var wart := MonsterMesh.flesh(Color("e6b8ae"), Color("c99088"), Color("7a2028"), {"bump": 0.05, "wetness": 0.3, "vein_amount": 0.2, "scale": 2.4, "pulse": 0.0})
	var lip_mat := MonsterMesh.flesh(Color("a3242c"), Color("7a141c"), Color("3a0408"), {"bump": 0.05, "wetness": 0.8, "vein_amount": 0.3, "scale": 2.0, "pulse": 0.0})
	var gum := MonsterMesh.flesh(Color("5a0a12"), Color("3a050a"), Color("1a0204"), {"bump": 0.05, "wetness": 0.9, "vein_amount": 0.2, "scale": 2.0, "pulse": 0.0})
	var tooth := MonsterMesh.bone(Color("e9dcb2"))
	var F := MonsterMesh.facet
	# _tilt: dựng nghiêng cả thân khi bám tường; _body: thân quay ngang 90 độ so với hướng đi (cua bò ngang)
	_tilt = Node3D.new()
	add_child(_tilt)
	_body = Node3D.new()
	_tilt.add_child(_body)
	# Thân: khối tròn phình, rộng 2,6m, cao 1,7m; ít mặt nên thấy rõ từng mảng cắt
	MonsterMesh.add(_body, F.call(MonsterMesh.blob(Vector3(1.3, 0.85, 1.2), 91, 0.6, 0.9, 0.42)), _mat, Vector3(0, 1.15, 0))
	MonsterMesh.add(_body, F.call(MonsterMesh.blob(Vector3(1.05, 0.45, 0.95), 92, 0.3, 0.4, 0.4)), dark, Vector3(0, 0.62, 0))     # bụng
	# mụn bướu rải trên thân (tránh vùng miệng trên lưng và chùm mắt phía trước)
	var wr := RandomNumberGenerator.new()
	wr.seed = 31
	for i in 18:
		var a := wr.randf() * TAU
		var e := wr.randf_range(-0.35, 0.55)
		var dirv := Vector3(cos(a) * cos(e), sin(e), sin(a) * cos(e))
		if dirv.z > 0.55 and dirv.y < 0.3:
			continue
		var sz := wr.randf_range(0.07, 0.16)
		MonsterMesh.add(_body, F.call(MonsterMesh.blob(Vector3.ONE * sz, 200 + i, 0.4, 0.2, 0.3)), wart, Vector3(0, 1.15, 0) + dirv * Vector3(1.3, 0.85, 1.2) * 0.97)
	# chùm mắt đen bóng phía trước, dưới mép miệng
	var eye := StandardMaterial3D.new()
	eye.albedo_color = Color("0c0808")
	eye.roughness = 0.08
	eye.metallic_specular = 1.0
	eye.emission_enabled = true
	eye.emission = Color("401010")
	eye.emission_energy_multiplier = 0.08
	var eye_m := SphereMesh.new()
	eye_m.radial_segments = 8
	eye_m.rings = 4
	var eye_f: Mesh = F.call(eye_m)
	var eyes := [[0.0, 0.0, 0.15], [-0.22, 0.04, 0.11], [0.22, 0.04, 0.11], [-0.12, -0.17, 0.1], [0.12, -0.17, 0.1],
		[-0.38, -0.08, 0.08], [0.38, -0.08, 0.08], [0.0, 0.2, 0.08], [-0.3, 0.18, 0.06], [0.3, 0.18, 0.06], [0.0, -0.3, 0.07]]
	for ev: Array in eyes:
		var ep := Vector3(float(ev[0]), 0.98 + float(ev[1]), 1.18)
		MonsterMesh.add(_body, eye_f, eye, ep, Vector3.ZERO, Vector3.ONE * float(ev[2]) * 2.0)
	# hàm kẹp nhỏ dưới chùm mắt (đớp khi cắn)
	_jaw = Node3D.new()
	_jaw.position = Vector3(0, 0.55, 1.05)
	_body.add_child(_jaw)
	for tx: float in [-0.18, 0.18]:
		MonsterMesh.add(_jaw, MonsterMesh.spike(0.07, 0.42), tooth, Vector3(tx, -0.1, 0.1), Vector3(PI * 0.5 + 0.9, 0, -tx * 2.0))
	# MIỆNG HỐC trên lưng, ngả về phía trước: cổ họng đỏ thẫm, môi dày đỏ, hai vòng răng nhọn chĩa vào trong
	var mouth_base := Node3D.new()
	mouth_base.position = Vector3(0, 1.62, 0.42)
	mouth_base.rotation.x = 0.62
	_body.add_child(mouth_base)
	_mouth = Node3D.new()
	_mouth.scale = Vector3.ONE * 1.3
	mouth_base.add_child(_mouth)
	var throat := CylinderMesh.new()
	throat.top_radius = 0.62
	throat.bottom_radius = 0.15
	throat.height = 0.75
	throat.radial_segments = 10
	throat.cap_top = false
	MonsterMesh.add(_mouth, F.call(throat), gum, Vector3(0, -0.36, 0))
	var hole := StandardMaterial3D.new()
	hole.albedo_color = Color(0.03, 0.0, 0.0)
	hole.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var deep := CylinderMesh.new()
	deep.top_radius = 0.2
	deep.bottom_radius = 0.2
	deep.height = 0.02
	MonsterMesh.add(_mouth, deep, hole, Vector3(0, -0.7, 0))
	var lip := TorusMesh.new()
	lip.inner_radius = 0.56
	lip.outer_radius = 0.84
	lip.rings = 12
	lip.ring_segments = 6
	MonsterMesh.add(_mouth, F.call(lip), lip_mat, Vector3(0, 0.02, 0), Vector3.ZERO, Vector3(1.0, 0.62, 1.0))
	for t in 18:
		var ta := t * TAU / 18.0
		var tooth_n := MonsterMesh.add(_mouth, MonsterMesh.spike(0.075, 0.34 + 0.1 * (t % 3)), tooth, Vector3(cos(ta) * 0.6, 0.06, sin(ta) * 0.6))
		tooth_n.rotation = Vector3(0, -ta, 0)
		tooth_n.rotate_object_local(Vector3.BACK, 0.8)
	for t2 in 12:
		var tb := t2 * TAU / 12.0 + 0.26
		var tn2 := MonsterMesh.add(_mouth, MonsterMesh.spike(0.05, 0.24), tooth, Vector3(cos(tb) * 0.36, -0.22, sin(tb) * 0.36))
		tn2.rotation = Vector3(0, -tb, 0)
		tn2.rotate_object_local(Vector3.BACK, 1.05)
	# mười chân nhện dài gấp khúc, toả quanh thân, gối nhô cao hơn lưng; mỗi chân khua theo nhịp riêng
	MonsterMesh.rough = 0.15
	var upper: Mesh = F.call(MonsterMesh.limb(1.9, 0.12, 0.08, 110, 0.12))
	var lower: Mesh = F.call(MonsterMesh.limb(2.5, 0.085, 0.015, 111, 0.12))
	var lr := RandomNumberGenerator.new()
	lr.seed = 77
	for i in 10:
		var ang := (i + 0.5) / 10.0 * TAU
		var pivot := Node3D.new()
		pivot.position = Vector3(sin(ang) * 1.05, 0.95, cos(ang) * 0.95)
		pivot.set_meta("side", 1.0)
		pivot.set_meta("ang", ang)
		pivot.set_meta("phase", lr.randf() * TAU)
		pivot.set_meta("f1", lr.randf_range(0.8, 1.6))
		pivot.set_meta("f2", lr.randf_range(1.1, 2.3))
		pivot.set_meta("base", 0.0)
		_body.add_child(pivot)
		var arm := Node3D.new()                 # quay theo hướng toả ra của chân
		arm.name = "Arm"
		pivot.add_child(arm)
		MonsterMesh.add(arm, upper, dark, Vector3.ZERO, Vector3(0, 0, 2.35))                    # đốt trong: vươn ra, ngóc cao hơn lưng
		var knee := Node3D.new()
		knee.name = "Knee"
		knee.position = Vector3(1.9 * sin(2.35), -1.9 * cos(2.35), 0)
		arm.add_child(knee)
		MonsterMesh.add(knee, lower, dark, Vector3.ZERO, Vector3(0, 0, 0.36))                   # đốt ngoài: cắm chéo xuống đất
		_legs.append(pivot)
	MonsterMesh.rough = 1.0


## Trồi lên ở `from` (dưới khe nứt hoặc dưới nước) rồi leo ra `exit_pos`.
func spawn_at(from: Vector3, exit_pos: Vector3) -> void:
	global_position = from
	_exit = exit_pos
	hp = MAX_HP
	_ti = -1
	_far_t = 0.0
	_state_t = 0.0
	target_id = 0
	forget()
	yaw = atan2(exit_pos.x - from.x, exit_pos.z - from.z)
	state = "emerge"
	mgr.fire(self, "emerge")


func active() -> bool:
	return state != "dormant" and state != "dead"


func hunting() -> bool:
	return state == "chase"


func hit_spheres() -> Array:
	if state == "dead" or state == "dormant":
		return []
	return [[global_position + Vector3(0, 1.1, 0), 1.6]]


func on_melee(attacker: int, _stun_s: float, power: float) -> void:
	if state == "dead" or state == "dormant":
		return
	hp -= power
	mgr.fire(self, "hurt")
	if hp <= 0.01:
		_die()
		return
	_stun = 0.55
	target_id = attacker
	if state != "chase":
		state = "chase"
		_state_t = 0.0
		_lost = 0.0
	# bật lùi
	var p: Node3D = mgr.player_by_id(attacker)
	if p:
		var away := global_position - p.global_position
		away.y = 0.0
		_try_move(away.normalized() * 0.9)


func on_shot(_attacker: int) -> void:
	if state != "dead" and state != "dormant":
		_die()


func _die() -> void:
	state = "dead"
	_dead_t = 0.0
	target_id = 0
	forget()
	mgr.fire(self, "die")


func heard(pos: Vector3, loud: float, source: String) -> void:
	if state == "roam" and source != "monster" and loud >= 0.35 and global_position.distance_to(pos) < 30.0 * loud:
		_dest = pos
		_state_t = 0.0


func _space() -> PhysicsDirectSpaceState3D:
	return get_world_3d().direct_space_state


func _clear(from: Vector3, to: Vector3) -> bool:
	return _space().intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 3)).is_empty()


## Tiến một bước trên mặt đất; trả về false nếu bị tường, đồ đạc chặn.
func _try_move(step: Vector3) -> bool:
	if step.length() < 0.0001:
		return true
	var dir := step.normalized()
	var from := global_position + Vector3(0, 0.45, 0)
	if not _clear(from, from + dir * (step.length() + 0.75)):
		return false
	var np := global_position + step
	var hit := _space().intersect_ray(PhysicsRayQueryParameters3D.create(np + Vector3(0, 0.9, 0), np + Vector3(0, -3.0, 0), 3))
	if hit.is_empty():
		np.y -= 0.25           # hẫng chân: rơi dần
	else:
		var gy: float = (hit.position as Vector3).y
		if gy - global_position.y > 0.75:
			return false
		np.y = gy
	if city.water_depth(np + Vector3(0, 0.3, 0)) > 0.0:
		return false
	global_position = np
	return true


func server_tick(delta: float) -> void:
	_state_t += delta
	_bite_cd -= delta
	if state == "dormant":
		return
	if state == "dead":
		_dead_t += delta
		speed_now = 0.0
		if _dead_t > 25.0:        # xác tan; đợt sau sẽ có con khác trồi lên thay
			state = "dormant"
			global_position = Vector3(0, -60, 0)
		return
	if state == "emerge":
		# leo từ dưới sâu lên mặt đất
		var to := _exit - global_position
		if to.length() < 0.25:
			global_position = _exit
			state = "roam"
			_state_t = 0.0
			_dest = _exit
			var lp: Node3D = mgr.player_by_id(lure) if lure != 0 else null
			lure = 0
			if lp:
				_dest = lp.global_position          # bị tiếng bíp của máy phát dẫn tới: đi thẳng tới người vác
				return
			# mò về phía có người
			var best := 1e9
			for pl: Node3D in mgr.players():
				var d := pl.global_position.distance_to(global_position)
				if d < best:
					best = d
					_dest = pl.global_position + Vector3(rng.randf_range(-22.0, 22.0), 0.0, rng.randf_range(-22.0, 22.0))
		else:
			global_position += to.normalized() * minf(2.4 * delta, to.length())
		speed_now = 2.0
		return
	# đi lạc quá xa người chơi thì chui xuống lại (không rải đầy bản đồ)
	var nearest := 1e9
	for pl2: Node3D in mgr.players():
		nearest = minf(nearest, pl2.global_position.distance_to(global_position))
	_far_t = _far_t + delta if nearest > 230.0 else 0.0
	if _far_t > 15.0 and state == "roam":
		state = "dormant"
		global_position = Vector3(0, -60, 0)
		return
	if _stun > 0.0:
		_stun -= delta
		speed_now = 0.0
		return
	var eye := global_position + Vector3(0, 1.1, 0)
	var seen: Node3D = look_for_players(delta, eye, SIGHT, Vector3.ZERO, -1.0, 1.5, 0.3)
	# Tai thính: tiếng bước chân, tiếng lục đồ ở gần
	if state == "roam":
		for p: Node3D in mgr.players():
			if p.net_noise > 0.2 and global_position.distance_to(p.global_position) < 15.0 * p.net_noise:
				var pid := p.get_multiplayer_authority()
				aw[pid] = minf(1.0, float(aw.get(pid, 0.0)) + delta * 0.9)
				sense = "hear"
				if aw[pid] >= 1.0:
					seen = p
	if seen and state == "roam":
		state = "chase"
		_state_t = 0.0
		_lost = 0.0
		_ti = -1
		target_id = seen.get_multiplayer_authority()
		mgr.fire(self, "spot")
	# Trong nhà (hoặc sắp chui qua cửa): dựng nghiêng bám tường, bò chậm hơn.
	wall_mode = not city.building_at(global_position).is_empty() or not city.building_at(global_position + forward() * 1.6).is_empty()
	match state:
		"roam":
			_roam(delta)
		"chase":
			_chase(delta)


func _roam(delta: float) -> void:
	var to := _dest - global_position
	to.y = 0.0
	if to.length() < 1.0 or _state_t > 14.0:
		_state_t = 0.0
		_dest = global_position + Vector3(rng.randf_range(-28.0, 28.0), 0.0, rng.randf_range(-28.0, 28.0))
		return
	turn_to(to, 3.0, delta)
	var before := global_position
	if not _try_move(forward() * SPEED_ROAM * pace() * delta):
		_dest = global_position + Vector3(rng.randf_range(-20.0, 20.0), 0.0, rng.randf_range(-20.0, 20.0))
	speed_now = before.distance_to(global_position) / maxf(delta, 0.001)


func _chase(delta: float) -> void:
	var p: Node3D = mgr.player_by_id(target_id)
	if p == null or (p.net_flags & (4 | 16)) != 0:
		state = "roam"
		target_id = 0
		return
	var ppos: Vector3 = p.global_position
	var dist := global_position.distance_to(ppos)
	var chest := ppos + Vector3(0, 0.9, 0)
	var los := _clear(global_position + Vector3(0, 0.6, 0), chest)
	if los:
		_lost = 0.0
		last_seen = ppos
	else:
		_lost += delta
	if _lost > 16.0 or dist > 110.0:
		state = "roam"
		target_id = 0
		_ti = -1
		forget()
		_dest = global_position
		return
	# Cắn
	if dist < 2.5 and los:
		speed_now = 0.0
		turn_to(ppos - global_position, 8.0, delta)
		if _bite_cd <= 0.0:
			_bite_cd = 1.15
			mgr.fire(self, "bite")
			mgr.hurt(p, 16.0, "slash", "leg_l" if rng.randf() < 0.5 else "leg_r")
		return
	var speed := SPEED_CHASE * (0.62 if wall_mode else 1.0) * delta
	var before := global_position
	var moved := false
	_side_t -= delta
	# 1. Thấy thẳng và cùng tầng: lao thẳng tới.
	if los and absf(ppos.y - global_position.y) < 1.2 and _side_t <= 0.0:
		var to := ppos - global_position
		to.y = 0.0
		turn_to(to, 7.0, delta)
		moved = _try_move(forward() * speed)
		if moved:
			_ti = -1
	# 2. Không thì lần theo đúng dấu chân con mồi (qua cửa, lên cầu thang).
	if not moved:
		var trail: PackedVector3Array = mgr.trail_of(target_id)
		if _ti < 0 or _ti >= trail.size():
			_ti = -1
			var from := global_position + Vector3(0, 0.5, 0)
			for i in range(trail.size() - 1, -1, -1):
				var c := trail[i]
				if c.distance_to(global_position) < 34.0 and _clear(from, c + Vector3(0, 0.5, 0)):
					_ti = i
					break
		if _ti >= 0 and _ti < trail.size():
			var c2 := trail[_ti]
			var to2 := c2 - global_position
			if to2.length() < 0.45:
				_ti += 1
			else:
				turn_to(Vector3(to2.x, 0.0, to2.z), 9.0, delta)
				global_position += to2.normalized() * minf(speed, to2.length())
			moved = true
	# 3. Chưa có dấu vết nào trong tầm mắt: lách sang bên rồi thử lại.
	if not moved:
		if _side_t <= 0.0:
			_side_t = 0.7
			_side = -_side
		var to3 := last_seen - global_position
		to3.y = 0.0
		var dir := to3.normalized().rotated(Vector3.UP, _side * 1.2)
		turn_to(dir, 7.0, delta)
		_try_move(forward() * speed)
	speed_now = before.distance_to(global_position) / maxf(delta, 0.001)


func event(ev: String, _arg: Variant) -> void:
	match ev:
		"spot":
			Sfx.play_at("stalker_screech", global_position + Vector3(0, 1.0, 0), 1.0, 20.0, 1.6)
			if not _warned:
				var cam := get_viewport().get_camera_3d()
				if cam and cam.global_position.distance_to(global_position) < 30.0:
					_warned = true
					Game.say("Cua Quỷ! Chúng trồi lên từ khe nứt và hồ, nhìn rất xa. Vào nhà nó phải dựng nghiêng người bám tường mà lách, nên chậm hẳn. Cầm dụng cụ mà đập: năm cú là chết.", "bad")
		"bite":
			Sfx.play_at("stalker_bite", global_position + Vector3(0, 0.8, 0), 2.0, 12.0, 1.5)
			_jaw.rotation.x = -0.9
		"hurt":
			_hurt_flash = 1.0
			Sfx.play_at("stalker_growl", global_position + Vector3(0, 0.8, 0), 1.0, 14.0, 1.5)
		"emerge":
			visible = true
			Sfx.play_at("stalker_growl", global_position + Vector3(0, 1.0, 0), 2.0, 22.0, 1.5)
		"die":
			Sfx.play_at("grub_bite", global_position + Vector3(0, 0.4, 0), 0.0, 10.0, 1.4)


func extra() -> Variant:
	return wall_mode


func set_extra(v: Variant) -> void:
	wall_mode = bool(v)


func visual_tick(delta: float) -> void:
	visible = state != "dormant"
	if not visible:
		return
	rotation.y = yaw
	var tt := Time.get_ticks_msec() * 0.001
	_hurt_flash = maxf(0.0, _hurt_flash - delta * 2.5)
	_mat.set_shader_parameter("hurt", _hurt_flash)
	if state == "dead":
		# lật ngửa, chân co quắp
		_tilt.rotation.z = move_toward(_tilt.rotation.z, PI, delta * 5.0)
		_tilt.position = _tilt.position.move_toward(Vector3(0, 1.1, 0), delta * 3.0)
		for l in _legs:
			var arm2: Node3D = l.get_node("Arm")
			arm2.rotation.z = move_toward(arm2.rotation.z, -0.9, delta * 3.0)
		return
	# bám tường: dựng thân lên gần thẳng đứng, áp sát về một bên, tâm thân nâng lên nửa bề rộng
	_wall = move_toward(_wall, 1.0 if wall_mode else 0.0, delta * 2.2)
	var k := smoothstep(0.0, 1.0, _wall)
	_tilt.rotation.z = k * 1.42
	_tilt.position = Vector3(k * 0.32, k * 1.05, 0)
	var run := clampf(speed_now / SPEED_CHASE, 0.0, 1.0)
	_body.position.y = sin(tt * (4.0 + run * 10.0)) * (0.015 + run * 0.03)
	_jaw.rotation.x = move_toward(_jaw.rotation.x, 0.0, delta * 4.0)
	# miệng trên lưng: phập phồng chậm, há to khi đuổi / khi cắn
	var open := 0.85 + 0.15 * sin(tt * 2.3) + run * 0.25 + (0.4 if _jaw.rotation.x > 0.2 else 0.0)
	_mouth.scale = Vector3(open, 1.0, open) * 1.3
	_mouth.rotation.y = sin(tt * 0.7) * 0.2
	for l in _legs:
		var ph: float = l.get_meta("phase")
		var ang: float = l.get_meta("ang")
		var f1: float = l.get_meta("f1")
		var f2: float = l.get_meta("f2")
		var sp := 2.0 + run * 9.0
		# khua tới khua lui, ngóc lên quờ xuống, xoắn nhẹ: mỗi chân một nhịp lệch nhau nên trông giật cục, ghê
		var sweep := sin(tt * sp * f1 + ph) * (0.35 + run * 0.45) + sin(tt * 7.1 * f2 + ph * 2.0) * 0.08
		var lift := maxf(0.0, sin(tt * sp * f2 + ph * 1.7)) * (0.25 + run * 0.5) + sin(tt * 1.3 + ph) * 0.12
		var arm: Node3D = l.get_node("Arm")
		# bám tường: co chân sát vào thân cho khỏi xuyên trần, chỉ ngọ nguậy nhẹ
		var tuck := 1.0 - k * 0.75
		arm.rotation = Vector3(sin(tt * 3.7 * f1 + ph) * 0.15, -ang + PI * 0.5 + sweep * tuck, lift * tuck + k * (0.7))
		(arm.get_node("Knee") as Node3D).rotation.z = (-lift * 0.9 + sin(tt * sp * f1 * 1.3 + ph) * 0.2) * tuck + k * (-1.2)

