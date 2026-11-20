extends Monster
## Kẻ cướp: người, cầm gậy hoặc dao. Phá cửa xông vào hầm, hoặc phục kích ngoài phố. Đánh thời gian thực:
## người chơi đập trả bằng dụng cụ (dụng cụ càng nặng càng đau), súng thì hai phát là gục.
## Gục xuống thì rơi lại đồ đang mang và nằm thành cái xác: vác được (E), để trong hầm qua đêm thì cả nhà mất tinh thần.

const MAX_HP := 7.0
const SPEED := 4.4
const REACH := 1.6

var hp := MAX_HP
var body: Humanoid
var mover: CharacterBody3D
var carrier := 0             # mã máy người đang vác cái xác (0 = nằm dưới đất)
var _hit_cd := 0.0
var _stun := 0.0
var _flash := 0.0
var _weapon: Node3D
var _loot: Array = []
var _shirt := Color.BLACK


func build() -> void:
	mname = "Kẻ cướp"
	state = "dormant"
	_shirt = [Color("2a2c30"), Color("3a3028"), Color("2c3a30"), Color("402826")][rng.randi() % 4]
	# model low-poly góc cạnh cùng kiểu gia đình: áo hoodie trùm đầu, khăn bịt mũi miệng, gậy cầm tay phải
	var lp := LowPolyHumanoid.new()
	lp.hair_style = "hood"
	lp.sleeves = "long"
	lp.shoe_color = Color("2a2624")
	lp.sole_color = Color("4a4440")
	lp.roll_cuffs = false
	body = lp
	add_child(body)
	body.setup(_shirt, Color(0.15, 0.15, 0.17), Color("c9956a"))
	var mask := MeshInstance3D.new()
	mask.mesh = LowPolyHumanoid._fmesh("sphere", 7)
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.1, 0.1, 0.11)
	mm.roughness = 0.95
	mask.material_override = mm
	mask.scale = Vector3(0.3, 0.17, 0.2)
	mask.position = Vector3(0, -0.01, -0.02)
	lp.face.add_child(mask)
	_weapon = ItemModels.make(["gaysat", "ongtuyp", "canhcay"][rng.randi() % 3])
	_weapon.scale = Vector3.ONE * 1.2
	# trục dài của món đồ là X: xoay cho cán chĩa ra trước, hếch lên (như cầm gậy sẵn sàng vụt)
	_weapon.quaternion = Quaternion(Vector3.RIGHT, Vector3(0, 0.55, 0.85).normalized())
	lp.hand_att.add_child(_weapon)
	mover = CharacterBody3D.new()
	mover.top_level = true
	mover.collision_layer = 8
	mover.collision_mask = 3
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	mover.add_child(cs)
	add_child(mover)
	global_position = Vector3(0, -200, 0)
	mover.global_position = global_position
	visible = false


## Xuất hiện ở `pos` và lao vào đánh. loot: những món nó đang mang (rơi ra khi gục).
func spawn_at(pos: Vector3, loot: Array) -> void:
	hp = MAX_HP
	carrier = 0
	_stun = 0.0
	_loot = loot
	global_position = pos
	mover.global_position = pos
	mover.velocity = Vector3.ZERO
	state = "fight"
	target_id = 0
	mgr.fire(self, "spawn")


func active() -> bool:
	return state == "fight"


func hunting() -> bool:
	return state == "fight"


func hit_spheres() -> Array:
	if state != "fight":
		return []
	return [[global_position + Vector3(0, 1.1, 0), 0.55], [global_position + Vector3(0, 0.5, 0), 0.45]]


func on_melee(attacker: int, stun: float, power: float) -> void:
	if state != "fight":
		return
	# dụng cụ càng nặng (chỉ số choáng càng cao) càng đau; tay không thì gần như chỉ đẩy được nó ra
	hp -= maxf(0.6, stun * power)
	_stun = 0.45
	target_id = attacker
	mgr.fire(self, "hurt")
	if hp <= 0.0:
		_die()


func on_shot(attacker: int) -> void:
	if state != "fight":
		return
	hp -= 4.0
	target_id = attacker
	mgr.fire(self, "hurt")
	if hp <= 0.0:
		_die()


func _die() -> void:
	state = "dead"
	mgr.fire(self, "die")
	# đồ nó mang rơi ra quanh xác
	var k := 0
	for id: String in _loot:
		mgr.world.loot.drop(id, global_position + Vector3(cos(k * 1.7) * 0.8, 0.3, sin(k * 1.7) * 0.8))
		k += 1
	_loot = []
	if mgr.world.shelter and mgr.world.shelter.active:
		mgr.world.shelter.on_robber_down(self)


func heard(_pos: Vector3, _loud: float, _source: String) -> void:
	pass


func server_tick(delta: float) -> void:
	_hit_cd -= delta
	if state == "dead":
		# xác đang bị vác: đi theo người vác, vắt trên vai
		if carrier != 0:
			var p: Node3D = mgr.player_by_id(carrier)
			if p == null:
				carrier = 0
			else:
				global_position = p.global_position + (-p.global_transform.basis.z) * 0.3 + Vector3(0, 0.0, 0)
				yaw = p.rotation.y
		return
	if state != "fight":
		return
	if _stun > 0.0:
		_stun -= delta
		mover.velocity = Vector3(0, mover.velocity.y - 18.0 * delta, 0)
		mover.move_and_slide()
		global_position = mover.global_position
		speed_now = 0.0
		return
	# chọn người gần nhất
	var best: Node3D = null
	var best_d := 1e9
	for p2: Node3D in mgr.players():
		var d := p2.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = p2
	if best == null or best_d > 70.0:
		mover.velocity = Vector3(0, mover.velocity.y - 18.0 * delta, 0)
		mover.move_and_slide()
		global_position = mover.global_position
		speed_now = 0.0
		return
	target_id = best.get_multiplayer_authority()
	var to := best.global_position - global_position
	to.y = 0.0
	turn_to(to, 8.0, delta)
	var v := Vector3.ZERO
	if to.length() > REACH:
		v = to.normalized() * SPEED
	elif _hit_cd <= 0.0:
		_hit_cd = 1.25
		mgr.fire(self, "swing")
		mgr.hurt(best, rng.randf_range(9.0, 14.0), "crush" if rng.randf() < 0.6 else "slash")
	mover.velocity = Vector3(v.x, mover.velocity.y - 18.0 * delta, v.z)
	if mover.is_on_floor():
		mover.velocity.y = maxf(mover.velocity.y, -1.0)
	var before := mover.global_position
	mover.move_and_slide()
	global_position = mover.global_position
	speed_now = before.distance_to(global_position) / maxf(delta, 0.001)


func extra() -> Variant:
	return [carrier, hp]


func set_extra(v: Variant) -> void:
	carrier = int(v[0])
	hp = float(v[1])


func event(ev: String, _arg: Variant) -> void:
	match ev:
		"spawn":
			visible = true
			body.play_dead(false)
		"swing":
			body.play_attack()
			Sfx.play_at("swing", global_position + Vector3(0, 1.2, 0), 0.0, 8.0)
		"hurt":
			_flash = 1.0
			Sfx.play_at("hit", global_position + Vector3(0, 1.2, 0), 0.0, 10.0, 0.9)
		"die":
			body.play_dead(true)
			_weapon.visible = false
			Sfx.play_at("hit", global_position + Vector3(0, 1.0, 0), 2.0, 12.0, 0.6)
		"hide":
			visible = false


func visual_tick(delta: float) -> void:
	visible = state != "dormant"
	if not visible:
		return
	rotation.y = yaw
	if not multiplayer.is_server():
		mover.global_position = global_position
	if state == "dead":
		if carrier != 0:
			# vắt ngang trên vai người vác
			body.rotation = Vector3(0, PI * 0.5, PI * 0.5)
			body.position = Vector3(0.25, 1.45, 0)
		else:
			body.rotation = Vector3.ZERO
			body.position = Vector3.ZERO
		return
	body.play_dead(false)
	body.animate(delta, speed_now, false, false)
	_flash = maxf(0.0, _flash - delta * 3.0)
