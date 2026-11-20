class_name Monster
extends Node3D
## Lớp gốc của quái vật. Máy chủ phòng chạy trí khôn (server_tick); mọi máy chạy phần hình ảnh (visual_tick).

var kind := ""
var mname := ""
var mgr: Node
var city: City
var rng := RandomNumberGenerator.new()
var state := "idle"
var yaw := 0.0
var speed_now := 0.0
## Mức cảnh giác với từng người chơi (id -> 0..1). Chỉ máy chủ dùng.
var aw: Dictionary = {}
var sense := ""
var target_id := 0
var last_seen := Vector3.ZERO
var lost_t := 0.0

var _net_pos := Vector3.ZERO
var _net_yaw := 0.0
var _has_net := false


func setup(manager: Node, c: City, seed_v: int) -> void:
	mgr = manager
	city = c
	rng.seed = seed_v
	build()


func build() -> void:
	pass


func server_tick(_delta: float) -> void:
	pass


func visual_tick(_delta: float) -> void:
	pass


func extra() -> Variant:
	return null


func set_extra(_v: Variant) -> void:
	pass


func event(_name: String, _arg: Variant) -> void:
	pass


func heard(_pos: Vector3, _loud: float, _source: String) -> void:
	pass


func hit_spheres() -> Array:
	return []


func on_melee(_attacker: int, _stun: float, _power: float) -> void:
	pass


func on_shot(_attacker: int) -> void:
	pass


func hunting() -> bool:
	return false


func pack() -> Array:
	return [global_position, yaw, state, extra()]


func unpack(a: Array) -> void:
	_net_pos = a[0]
	_net_yaw = a[1]
	state = a[2]
	set_extra(a[3])
	if not _has_net:
		_has_net = true
		global_position = _net_pos
		yaw = _net_yaw


func client_interp(delta: float) -> void:
	if not _has_net:
		return
	var before := global_position
	global_position = global_position.lerp(_net_pos, minf(1.0, delta * 10.0))
	speed_now = lerpf(speed_now, before.distance_to(global_position) / maxf(delta, 0.001), 0.2)
	yaw = lerp_angle(yaw, _net_yaw, minf(1.0, delta * 8.0))


## Tia trúng một trong các khối cầu của quái?
func ray_hit(origin: Vector3, dir: Vector3, reach: float) -> bool:
	for s: Array in hit_spheres():
		var c: Vector3 = s[0]
		var r: float = s[1]
		var oc := c - origin
		var t := clampf(oc.dot(dir), 0.0, reach)
		if (origin + dir * t).distance_to(c) <= r:
			return true
	return false


## Cập nhật cảnh giác bằng mắt. Trả về người chơi bị phát hiện hoàn toàn (hoặc null).
func look_for_players(delta: float, eye: Vector3, sight: float, facing := Vector3.ZERO, fov_cos := -1.0, gain := 1.0, decay := 0.22) -> Node3D:
	var found: Node3D = null
	var best := 0.0
	for p: Node3D in mgr.players():
		var pid := p.get_multiplayer_authority()
		var s: float = mgr.sees(eye, p, sight, facing, fov_cos)
		var a: float = aw.get(pid, 0.0)
		if s > 0.0:
			a = minf(1.0, a + s * gain * delta)
			sense = "see"
		else:
			a = maxf(0.0, a - decay * delta)
		aw[pid] = a
		if a >= 1.0 and s > best:
			best = s
			found = p
	return found


func forget(pid := 0) -> void:
	if pid == 0:
		aw.clear()
	else:
		aw.erase(pid)


## Xoay dần về một hướng; trả về góc còn lệch.
func turn_to(dir: Vector3, rate: float, delta: float) -> float:
	var want := atan2(dir.x, dir.z)
	var d := wrapf(want - yaw, -PI, PI)
	yaw += clampf(d, -rate * delta, rate * delta)
	return absf(d)


## Ban đêm quái vật di chuyển chậm lại.
func pace() -> float:
	return lerpf(1.0, 0.8, mgr.world.darkness())       # ban đêm chậm lại khoảng 20%


## Ban đêm những con săn bằng mắt từ trên cao (Thủy Quái, Dực Quái) không nhìn thấy người.
func night_blind() -> bool:
	return mgr.world.darkness() > 0.6


func cool_down(delta: float, rate := 0.25) -> void:
	for pid: int in aw:
		aw[pid] = maxf(0.0, float(aw[pid]) - rate * delta)


func forward() -> Vector3:
	return Vector3(sin(yaw), 0.0, cos(yaw))
