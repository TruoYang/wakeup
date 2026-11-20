class_name Humanoid
extends Node3D
## Hình người dựng bằng code (dùng cho người chơi và dân thường), có hoạt ảnh đi / chạy / ngồi / bơi / đánh.

var shirt := Color("e9e4d8")
var pants := Color("3a4350")
var skin := Color("d9a679")
var hair := Color("1c1a18")

var _hips: Node3D
var _torso: Node3D
var _head: Node3D
var _arm: Array[Node3D] = []
var _fore: Array[Node3D] = []
var _leg: Array[Node3D] = []
var _shin: Array[Node3D] = []
var _phase := 0.0
var _crouch := 0.0
var _swim := 0.0
var _attack := 0.0
var _dead := 0.0
## chiều cao hông khi đứng (người lớn 0,95; trẻ con chân ngắn hơn)
var hip_h := 0.95


## Kiểu tóc: "" = tự chọn theo màu áo (ngắn / húi cua / mái lệch), "long" = tóc dài (Mai, bé Na).
var hair_style := ""

# Dùng chung mesh và vật liệu giữa mọi hình người (hàng trăm dân thường): đỡ tốn bộ nhớ và lệnh vẽ.
static var _meshes: Dictionary = {}
static var _mats: Dictionary = {}
const DETAIL_FAR := 22.0       # chi tiết nhỏ (mắt, mũi, ngón tay...) chỉ vẽ khi ở gần
const BODY_FAR := 240.0


func setup(shirt_color: Color, pants_color: Color, skin_color := Color("d9a679")) -> void:
	shirt = shirt_color
	pants = pants_color
	skin = skin_color
	for c in get_children():
		c.queue_free()
	_arm.clear()
	_fore.clear()
	_leg.clear()
	_shin.clear()
	var hs := hair_style
	if hs == "":
		hs = ["short", "buzz", "side"][absi(hash(shirt.to_html())) % 3]
	var shirt_dark := shirt.darkened(0.18)
	var lip := skin.darkened(0.28)
	var shoe := Color(0.12, 0.11, 0.11) if absi(hash(pants.to_html())) % 3 != 0 else Color(0.32, 0.22, 0.16)
	# --- hông, thắt lưng
	_hips = _pivot(self, Vector3(0, 0.95, 0))
	_part(_hips, "capsule_x", Vector3(0.2, 0.14, 0.2), Vector3(0, -0.01, 0), pants)
	_part(_hips, "box", Vector3(0.345, 0.04, 0.205), Vector3(0, 0.085, 0), Color(0.16, 0.12, 0.1), true)
	_part(_hips, "box", Vector3(0.04, 0.035, 0.01), Vector3(0, 0.085, 0.104), Color(0.7, 0.62, 0.4), true)
	# --- thân: bụng nhỏ, ngực rộng, vai tròn, cổ áo
	_torso = _pivot(_hips, Vector3(0, 0.08, 0))
	_part(_torso, "box", Vector3(0.31, 0.26, 0.185), Vector3(0, 0.14, 0), shirt)
	_part(_torso, "sphere", Vector3(0.4, 0.34, 0.225), Vector3(0, 0.37, 0), shirt)
	_part(_torso, "box", Vector3(0.36, 0.1, 0.2), Vector3(0, 0.49, 0), shirt)
	_part(_torso, "cyl", Vector3(0.13, 0.035, 0.13), Vector3(0, 0.555, 0.0), shirt_dark, true)
	_part(_torso, "box", Vector3(0.012, 0.3, 0.008), Vector3(0, 0.33, 0.118), shirt_dark, true)    # nẹp áo
	# --- đầu
	_head = _pivot(_torso, Vector3(0, 0.57, 0))
	_part(_head, "cyl", Vector3(0.095, 0.12, 0.095), Vector3(0, 0.0, 0), skin)                       # cổ
	_part(_head, "sphere", Vector3(0.19, 0.225, 0.205), Vector3(0, 0.17, 0), skin)                   # sọ
	_part(_head, "sphere", Vector3(0.155, 0.13, 0.16), Vector3(0, 0.105, 0.018), skin)              # cằm, quai hàm
	_part(_head, "box", Vector3(0.028, 0.055, 0.04), Vector3(0, 0.155, 0.103), skin.darkened(0.06), true)   # mũi
	for sd: float in [-1.0, 1.0]:
		_part(_head, "sphere", Vector3(0.028, 0.058, 0.045), Vector3(sd * 0.096, 0.165, 0.0), skin.darkened(0.08), true)   # tai
		_part(_head, "sphere", Vector3(0.034, 0.024, 0.02), Vector3(sd * 0.04, 0.188, 0.091), Color(0.95, 0.94, 0.9), true)  # tròng trắng
		_part(_head, "sphere", Vector3(0.017, 0.017, 0.012), Vector3(sd * 0.04, 0.188, 0.1), Color(0.12, 0.08, 0.06), true)  # con ngươi
		var brow := _part(_head, "box", Vector3(0.045, 0.011, 0.014), Vector3(sd * 0.042, 0.218, 0.096), hair, true)
		brow.rotation.z = -sd * 0.12
	_part(_head, "box", Vector3(0.046, 0.009, 0.012), Vector3(0, 0.103, 0.096), lip, true)          # miệng
	# tóc
	match hs:
		"buzz":
			_part(_head, "sphere", Vector3(0.198, 0.17, 0.214), Vector3(0, 0.215, -0.006), hair)
		"side":
			_part(_head, "sphere", Vector3(0.206, 0.16, 0.222), Vector3(0, 0.235, -0.012), hair)
			var fr := _part(_head, "sphere", Vector3(0.15, 0.05, 0.07), Vector3(0.025, 0.272, 0.075), hair)
			fr.rotation.z = -0.25
		"long":
			_part(_head, "sphere", Vector3(0.212, 0.17, 0.226), Vector3(0, 0.235, -0.012), hair)
			_part(_head, "sphere", Vector3(0.2, 0.34, 0.1), Vector3(0, 0.12, -0.075), hair)
			for sd2: float in [-1.0, 1.0]:
				_part(_head, "sphere", Vector3(0.05, 0.24, 0.1), Vector3(sd2 * 0.09, 0.13, -0.025), hair)
			_part(_head, "sphere", Vector3(0.17, 0.05, 0.06), Vector3(0, 0.27, 0.078), hair)
		_:
			_part(_head, "sphere", Vector3(0.21, 0.16, 0.222), Vector3(0, 0.24, -0.014), hair)
			_part(_head, "sphere", Vector3(0.17, 0.045, 0.06), Vector3(0, 0.275, 0.075), hair)
	# --- tay: vai tròn, bắp tay trong tay áo, cẳng tay, bàn tay có ngón cái và các ngón khép
	for side: float in [-1.0, 1.0]:
		var a := _pivot(_torso, Vector3(side * 0.225, 0.5, 0))
		_part(a, "sphere", Vector3(0.13, 0.13, 0.13), Vector3(side * 0.01, -0.01, 0), shirt)
		_part(a, "capsule", Vector3(0.1, 0.24, 0.1), Vector3(0, -0.14, 0), shirt)
		_part(a, "cyl", Vector3(0.104, 0.03, 0.104), Vector3(0, -0.255, 0), shirt_dark, true)    # mép tay áo
		var f := _pivot(a, Vector3(0, -0.29, 0))
		_part(f, "capsule", Vector3(0.078, 0.22, 0.078), Vector3(0, -0.11, 0), skin)
		_part(f, "box", Vector3(0.042, 0.085, 0.078), Vector3(0, -0.285, 0.004), skin)              # lòng bàn tay
		var fing := _part(f, "box", Vector3(0.036, 0.06, 0.07), Vector3(0, -0.352, 0.012), skin.darkened(0.04), true)
		fing.rotation.x = 0.35
		var th := _part(f, "capsule", Vector3(0.022, 0.04, 0.022), Vector3(-side * 0.018, -0.275, 0.042), skin.darkened(0.04), true)
		th.rotation.x = 0.6
		_arm.append(a)
		_fore.append(f)
		# --- chân: đùi, gối, ống chân, giày có đế
		var l := _pivot(_hips, Vector3(side * 0.095, -0.06, 0))
		_part(l, "capsule", Vector3(0.15, 0.42, 0.15), Vector3(0, -0.2, 0), pants)
		var sh := _pivot(l, Vector3(0, -0.43, 0))
		_part(sh, "capsule", Vector3(0.115, 0.4, 0.115), Vector3(0, -0.2, 0), pants)
		_part(sh, "sphere", Vector3(0.105, 0.09, 0.25), Vector3(0, -0.405, 0.045), shoe)
		_part(sh, "box", Vector3(0.11, 0.025, 0.26), Vector3(0, -0.445, 0.045), Color(0.08, 0.08, 0.08))
		_leg.append(l)
		_shin.append(sh)


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


static func _mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _mats.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.85
		_mats[key] = mat
	return _mats[key]


static func _mesh(shape: String, size: Vector3) -> Mesh:
	var key := "%s|%.3f|%.3f|%.3f" % [shape, size.x, size.y, size.z]
	if _meshes.has(key):
		return _meshes[key]
	var m: PrimitiveMesh
	match shape:
		"capsule", "capsule_x":
			var c := CapsuleMesh.new()
			c.radius = size.x * 0.5
			c.height = size.y + size.x
			c.radial_segments = 12
			c.rings = 4
			m = c
		"cyl":
			var cy := CylinderMesh.new()
			cy.top_radius = size.x * 0.5
			cy.bottom_radius = size.z * 0.5
			cy.height = size.y
			cy.radial_segments = 12
			cy.rings = 1
			m = cy
		"sphere":
			var s := SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			s.radial_segments = 14
			s.rings = 8
			m = s
		_:
			var b := BoxMesh.new()
			b.size = size
			m = b
	_meshes[key] = m
	return m


func _part(parent: Node3D, shape: String, size: Vector3, pos: Vector3, color: Color, detail := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh(shape, Vector3.ONE if shape == "sphere" else size)
	if shape == "sphere":
		mi.scale = size
	elif shape == "capsule_x":
		mi.rotation.z = PI * 0.5
	mi.material_override = _mat(color)
	mi.position = pos
	mi.visibility_range_end = DETAIL_FAR if detail else BODY_FAR
	if detail:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func set_shirt(color: Color) -> void:
	if shirt.is_equal_approx(color) or _torso == null:
		return
	setup(color, pants, skin)


## speed: tốc độ ngang (m/s). Gọi mỗi khung hình.
func animate(delta: float, speed: float, crouching: bool, swimming: bool, pitch := 0.0) -> void:
	if _hips == null:
		return
	_crouch = move_toward(_crouch, 1.0 if crouching else 0.0, delta * 6.0)
	_swim = move_toward(_swim, 1.0 if swimming else 0.0, delta * 3.0)
	_attack = maxf(0.0, _attack - delta * 3.2)
	var moving := clampf(speed / 3.5, 0.0, 1.6)
	_phase += delta * (4.0 + speed * 1.55) * (1.0 if moving > 0.05 or swimming else 0.0)
	var sw := sin(_phase)
	var amp := 0.55 * minf(moving, 1.3)
	# thân
	_hips.position.y = lerpf(hip_h, hip_h * 0.65, _crouch) + absf(cos(_phase)) * 0.03 * moving
	_hips.rotation.x = lerpf(0.0, 1.35, _swim)
	_torso.rotation.x = lerpf(0.06 * moving, 0.55, _crouch) * (1.0 - _swim)
	_head.rotation.x = lerpf(-pitch * 0.5, -0.5 - pitch * 0.3, _crouch) - 0.9 * _swim
	for i in 2:
		var sg := -1.0 if i == 0 else 1.0
		var leg_swing := sw * sg * amp
		var kick := sin(_phase * 2.0 + i * PI) * 0.35 * _swim
		_leg[i].rotation.x = lerpf(leg_swing, -1.0 + leg_swing * 0.5, _crouch) * (1.0 - _swim) + kick
		_shin[i].rotation.x = (maxf(0.0, -sw * sg) * amp * 1.4 + _crouch * 1.5) * (1.0 - _swim) + absf(kick) * 0.5
		var arm_swing := -sw * sg * amp * 0.9
		var stroke := sin(_phase + i * PI) * 1.2
		_arm[i].rotation.x = arm_swing * (1.0 - _swim) + (-2.6 + stroke) * _swim
		_arm[i].rotation.z = sg * (0.06 + 0.25 * _swim)
		_fore[i].rotation.x = -(0.25 + absf(arm_swing) * 0.6) * (1.0 - _swim)
	if _attack > 0.0:
		var k := sin((1.0 - _attack) * PI)
		_arm[1].rotation.x = -1.9 * k - 0.4
		_fore[1].rotation.x = -0.9 * k
		_torso.rotation.y = -0.5 * k
	else:
		_torso.rotation.y = 0.0
	if _dead > 0.0:
		_dead = minf(1.0, _dead + delta * 2.5)
		rotation.x = -PI * 0.5 * _dead
		position.y = 0.18 * _dead


func play_attack() -> void:
	_attack = 1.0


func play_dead(on: bool) -> void:
	_dead = 0.001 if on else 0.0
	if not on:
		rotation.x = 0.0
		position.y = 0.0
