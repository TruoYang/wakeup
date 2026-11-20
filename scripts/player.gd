extends CharacterBody3D
## Nhân vật: đi, chạy, ngồi, nhảy, bơi/lặn, tương tác, đánh, ném; góc nhìn thứ nhất / thứ ba.
## Mỗi người chơi điều khiển nhân vật mang id của mình; các máy khác chỉ nhận trạng thái đồng bộ.

const WALK_SPEED := 4.0
const RUN_SPEED := 7.2
const CROUCH_SPEED := 1.8
const SWIM_SPEED := 2.5
const JUMP_SPEED := 5.4
const ACCEL := 28.0
const AIR_ACCEL := 6.0
const MOUSE_SENS := 0.0024
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.1
const THIRD_PERSON_DIST := 3.8
const STAMINA_DRAIN := 13.0
const STAMINA_REGEN := 9.0
const STEP_HEIGHT := 0.5
const SWIM_DEPTH := 1.25      # nước ngập tới đây (tính từ chân) thì nổi lên bơi
const FLOAT_DEPTH := 1.48     # khi thả lỏng, chân chìm chừng này (đầu vừa nhô khỏi mặt nước)
const BREATH_TIME := 28.0
const REACH := 2.7

enum { F_CROUCH = 1, F_SWIM = 2, F_DEAD = 4, F_LIGHT = 8, F_HIDDEN = 16, F_ATTACK = 32, F_RIDE = 64 }
const BIKE_SPEED := 13.0

# --- trạng thái đồng bộ qua mạng
@export var net_pitch := 0.0
@export var net_flags := 0
@export var net_noise := 0.0
@export var net_stealth := 0.0
@export var net_speed := 0.0
@export var net_shirt := Color("e9e4d8")
@export var net_name := ""

var third_person := false
var crouching := false
var swimming := false
var sprinting := false
var pitch := 0.0
var surface := "concrete"
var target: Dictionary = {}
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var world: Node = null

var head: Node3D
var arm: SpringArm3D
var camera: Camera3D
var body: Humanoid
var shape: CollisionShape3D
var light: SpotLight3D
var name_tag: Label3D

var _step_acc := 0.0
var _shake := 0.0
var _shake_freq := 1.0
var _attack_cd := 0.0
var _fall_speed := 0.0
var _was_in_water := false
var _last_pos := Vector3.ZERO
var _prev_attack_flag := false
var _dead_shown := false
var riding := -1
var bike_fuel := 0.0
var bike_model: Node3D
var cockpit: Node3D          # đầu xe nhìn từ chỗ ngồi lái (góc nhìn thứ nhất)
var _engine_t := 0.0
var hands: Node3D
var hand_r: Node3D
var hand_l: Node3D
var fp_arms: FPArms
var weapon_node: Node3D
var off_node: Node3D
var _held_off := ""
var _swing := 0.0
var _bob := 0.0
var _held := "?"


func _enter_tree() -> void:
	_build_nodes()
	# Đặt quyền điều khiển SAU khi đã tạo các nút con (kể cả nút đồng bộ) để chúng cùng thuộc về người chơi này.
	if name.is_valid_int():
		set_multiplayer_authority(name.to_int())


func _build_nodes() -> void:
	if head != null:
		return
	shape = CollisionShape3D.new()
	shape.name = "Shape"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = STAND_HEIGHT
	shape.shape = cap
	shape.position.y = STAND_HEIGHT * 0.5
	add_child(shape)

	# hình người chơi (người khác trong co-op nhìn thấy, và góc nhìn thứ ba): model low-poly góc cạnh cùng kiểu gia đình
	var lp := LowPolyHumanoid.new()
	lp.sleeves = "long"
	lp.shoe_color = Color("34302e")
	lp.sole_color = Color("d8d2c8")
	lp.roll_cuffs = false
	body = lp
	body.name = "Body"
	body.rotation.y = PI      # hình người nhìn về -Z (hướng đi tới)
	add_child(body)
	body.setup(net_shirt, Color("3a4350"))

	head = Node3D.new()
	head.name = "Head"
	head.position.y = STAND_HEIGHT - 0.2
	add_child(head)
	arm = SpringArm3D.new()
	arm.name = "Arm"
	arm.spring_length = 0.0
	arm.margin = 0.2
	arm.collision_mask = 1
	var probe := SphereShape3D.new()
	probe.radius = 0.2
	arm.shape = probe
	head.add_child(arm)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.near = 0.06
	camera.far = 700.0
	arm.add_child(camera)

	# Hai tay nhìn thấy ở góc nhìn thứ nhất, tay phải cầm vũ khí.
	hands = Node3D.new()
	hands.name = "Hands"
	camera.add_child(hands)
	hand_r = _make_arm(1.0)
	hand_l = _make_arm(-1.0)

	weapon_node = Node3D.new()
	weapon_node.position = Vector3(0.0, 0.03, 0.0)
	hand_r.get_node("Grip").add_child(weapon_node)

	light = SpotLight3D.new()
	light.name = "Flashlight"
	light.spot_range = 26.0
	light.spot_angle = 34.0
	light.light_energy = 0.0
	light.light_color = Color("fff1d6")
	light.shadow_enabled = true
	light.position = Vector3(0.15, -0.1, 0.0)
	head.add_child(light)

	bike_model = load("res://scripts/world/bikes.gd").make_model()
	bike_model.rotation.y = PI
	bike_model.visible = false
	add_child(bike_model)
	cockpit = _make_cockpit()
	cockpit.visible = false
	add_child(cockpit)

	name_tag = Label3D.new()
	name_tag.name = "NameTag"
	name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_tag.position.y = 2.1
	name_tag.pixel_size = 0.004
	name_tag.font_size = 48
	name_tag.outline_size = 10
	name_tag.modulate = Color(0.95, 0.92, 0.85)
	name_tag.no_depth_test = false
	add_child(name_tag)

	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for prop: String in [".:position", ".:rotation", ".:net_pitch", ".:net_flags", ".:net_noise", ".:net_stealth", ".:net_speed", ".:net_shirt", ".:net_name"]:
		cfg.add_property(NodePath(prop))
		cfg.property_set_replication_mode(NodePath(prop), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = cfg
	add_child(sync)


## Đầu xe máy nhìn từ yên: tay lái, hai gương, đồng hồ, đèn pha, chắn bùn trước.
func _make_cockpit() -> Node3D:
	var n := Node3D.new()
	n.name = "Cockpit"
	n.position = Vector3(0, STAND_HEIGHT - 0.2, 0)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.75, 0.12, 0.1)
	red.roughness = 0.5
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.09, 0.09, 0.1)
	dark.roughness = 0.7
	var chrome := StandardMaterial3D.new()
	chrome.albedo_color = Color(0.74, 0.76, 0.8)
	chrome.metallic = 0.7
	chrome.roughness = 0.3
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.55, 0.68, 0.78)
	glass.roughness = 0.15
	var parts := [
		[Vector3(0.74, 0.04, 0.04), Vector3(0, -0.4, -0.62), chrome, Vector3.ZERO],            # tay lái
		[Vector3(0.13, 0.055, 0.055), Vector3(-0.39, -0.4, -0.62), dark, Vector3.ZERO],        # tay nắm trái
		[Vector3(0.13, 0.055, 0.055), Vector3(0.39, -0.4, -0.62), dark, Vector3.ZERO],         # tay nắm phải
		[Vector3(0.3, 0.12, 0.2), Vector3(0, -0.4, -0.76), red, Vector3(0.5, 0, 0)],           # mặt nạ
		[Vector3(0.2, 0.02, 0.12), Vector3(0, -0.33, -0.72), dark, Vector3(0.5, 0, 0)],        # đồng hồ
		[Vector3(0.2, 0.16, 0.1), Vector3(0, -0.5, -0.9), chrome, Vector3.ZERO],               # đèn pha
		[Vector3(0.2, 0.3, 0.34), Vector3(0, -0.72, -0.72), red, Vector3.ZERO],                # cổ xe
		[Vector3(0.14, 0.06, 0.5), Vector3(0, -0.95, -1.05), red, Vector3(0.25, 0, 0)],        # chắn bùn trước
		[Vector3(0.02, 0.2, 0.02), Vector3(-0.3, -0.3, -0.64), chrome, Vector3(0, 0, 0.35)],   # cần gương trái
		[Vector3(0.02, 0.2, 0.02), Vector3(0.3, -0.3, -0.64), chrome, Vector3(0, 0, -0.35)],   # cần gương phải
		[Vector3(0.15, 0.09, 0.02), Vector3(-0.36, -0.19, -0.64), dark, Vector3.ZERO],         # gương trái
		[Vector3(0.15, 0.09, 0.02), Vector3(0.36, -0.19, -0.64), dark, Vector3.ZERO],          # gương phải
		[Vector3(0.13, 0.07, 0.005), Vector3(-0.36, -0.19, -0.628), glass, Vector3.ZERO],
		[Vector3(0.13, 0.07, 0.005), Vector3(0.36, -0.19, -0.628), glass, Vector3.ZERO],
		[Vector3(0.3, 0.1, 0.5), Vector3(0, -0.86, -0.3), dark, Vector3.ZERO],                 # yên, bình xăng trước bụng
	]
	for part: Array in parts:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = part[0]
		bm.material = part[2]
		mi.mesh = bm
		mi.position = part[1]
		mi.rotation = part[3]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(mi)
	return n


func _make_arm(side: float) -> Node3D:
	var arm_n := Node3D.new()
	arm_n.position = Vector3(side * 0.3, -0.34, -0.3)
	arm_n.rotation = Vector3(0.42, side * 0.34, 0.0)
	hands.add_child(arm_n)
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color("d6a27a")
	skin.roughness = 0.62
	skin.rim_enabled = true
	skin.rim = 0.25
	var skin_dark := StandardMaterial3D.new()
	skin_dark.albedo_color = Color("c48e66")
	skin_dark.roughness = 0.65
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = net_shirt
	cloth.roughness = 0.95
	var cuff := StandardMaterial3D.new()
	cuff.albedo_color = net_shirt.darkened(0.25)
	cuff.roughness = 0.95
	# cẳng tay thon dần về cổ tay (trục cẳng tay dọc theo Z, cổ tay ở phía trước)
	_fp(arm_n, "cyl", Vector3(0.031, 0.3, 0.041), Vector3(0, -0.008, -0.19), Vector3(-PI * 0.5, 0, 0), skin)
	_fp(arm_n, "sphere", Vector3(0.07, 0.06, 0.07), Vector3(0, -0.006, -0.325), Vector3.ZERO, skin)          # cổ tay
	# tay áo xắn tới khuỷu, có mép gấp
	_fp(arm_n, "cyl", Vector3(0.05, 0.2, 0.054), Vector3(0, -0.012, -0.0), Vector3(-PI * 0.5, 0, 0), cloth).name = "Sleeve"
	_fp(arm_n, "cyl", Vector3(0.053, 0.035, 0.053), Vector3(0, -0.012, -0.1), Vector3(-PI * 0.5, 0, 0), cuff).name = "Cuff"
	# bàn tay nắm quanh trục đứng (trục cán dụng cụ); "Grip" xoay được để cầm đèn pin chĩa thẳng
	var grip := Node3D.new()
	grip.name = "Grip"
	grip.position = Vector3(0, 0, -0.36)
	arm_n.add_child(grip)
	_fp(grip, "sphere", Vector3(0.042, 0.092, 0.088), Vector3(side * 0.02, -0.002, 0.006), Vector3.ZERO, skin)    # mu bàn tay
	var rows := [[0.031, 0.056], [0.01, 0.058], [-0.011, 0.055], [-0.03, 0.046]]
	for r: Array in rows:
		var y: float = r[0]
		var ln: float = r[1]
		# đốt ngón vòng qua phía trước cán, rồi gập về phía lòng bàn tay
		_fp(grip, "capsule", Vector3(0.0125, ln, 0.0125), Vector3(side * 0.006, y, -0.04), Vector3(0, 0, PI * 0.5), skin)
		_fp(grip, "capsule", Vector3(0.0115, 0.026, 0.0115), Vector3(-side * 0.022, y, -0.022), Vector3(PI * 0.5, 0, 0), skin_dark)
		_fp(grip, "sphere", Vector3(0.024, 0.02, 0.022), Vector3(side * 0.032, y, -0.034), Vector3.ZERO, skin)   # khớp đốt ngón
	# ngón cái vắt qua phía trên
	_fp(grip, "capsule", Vector3(0.015, 0.045, 0.015), Vector3(-side * 0.016, 0.05, -0.012), Vector3(PI * 0.5, side * 0.35, 0), skin)
	_fp(grip, "sphere", Vector3(0.032, 0.04, 0.05), Vector3(-side * 0.02, 0.028, 0.02), Vector3.ZERO, skin)     # gò ngón cái
	return arm_n


func _fp(parent: Node3D, shape: String, size: Vector3, pos: Vector3, rot: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	match shape:
		"cyl":
			var c := CylinderMesh.new()
			c.bottom_radius = size.x
			c.top_radius = size.z
			c.height = size.y
			c.radial_segments = 16
			c.rings = 1
			mi.mesh = c
		"capsule":
			var cp := CapsuleMesh.new()
			cp.radius = size.x
			cp.height = size.y + size.x * 2.0
			cp.radial_segments = 10
			cp.rings = 3
			mi.mesh = cp
		"sphere":
			var sp := SphereMesh.new()
			sp.radius = 0.5
			sp.height = 1.0
			sp.radial_segments = 14
			sp.rings = 8
			mi.mesh = sp
			mi.scale = size
		_:
			var bx := BoxMesh.new()
			bx.size = size
			mi.mesh = bx
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _box_part(parent: Node3D, size: Vector3, pos: Vector3, color: Color, metal := 0.0) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = 0.5 if metal > 0.0 else 0.85
	b.material = m
	mi.mesh = b
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.layers = FPArms.LAYER if fp_arms else 1
	parent.add_child(mi)


## Dựng hình vũ khí đang cầm trong tay phải.
func _update_held() -> void:
	var id: String = Game.equip.weapon
	if id == _held:
		if Game.offhand != _held_off:
			_update_off()
		return
	_held = id
	for c in weapon_node.get_children():
		c.queue_free()
	weapon_node.rotation = Vector3(-0.5, 0, 0)
	weapon_node.position = Vector3(0.0, 0.03, 0.0)
	if fp_arms and Items.get_def(id).has("weapon") and not Items.get_def(id).has("gun"):
		# cán nằm dọc trục nắm, xuyên qua lòng nắm tay (lệch 4cm về phía các ngón như đèn pin), thò xuống dưới một đoạn
		weapon_node.rotation = Vector3.ZERO
		weapon_node.position = Vector3(0.04, -0.22, 0.0)
	match id:
		"canhcay":
			_box_part(weapon_node, Vector3(0.045, 0.75, 0.045), Vector3(0, 0.3, 0), Color("6a4a2e"))
			_box_part(weapon_node, Vector3(0.03, 0.25, 0.03), Vector3(0.06, 0.55, 0), Color("5a3e26"))
		"banphim":
			_box_part(weapon_node, Vector3(0.42, 0.03, 0.15), Vector3(0, 0.12, 0), Color("1c1d20"))
			_box_part(weapon_node, Vector3(0.38, 0.012, 0.12), Vector3(0, 0.14, 0), Color("3a3c40"))
		"chao":
			_box_part(weapon_node, Vector3(0.035, 0.3, 0.035), Vector3(0, 0.12, 0), Color("2a2a2c"))
			_box_part(weapon_node, Vector3(0.3, 0.3, 0.05), Vector3(0, 0.4, 0), Color("18181a"), 0.6)
		"ongtuyp", "gaysat":
			_box_part(weapon_node, Vector3(0.04, 0.9, 0.04), Vector3(0, 0.36, 0), Color("8a8e94"), 0.8)
		"xabeng":
			_box_part(weapon_node, Vector3(0.035, 0.85, 0.035), Vector3(0, 0.34, 0), Color("7a2a22"), 0.6)
			_box_part(weapon_node, Vector3(0.035, 0.035, 0.14), Vector3(0, 0.76, -0.06), Color("7a2a22"), 0.6)
		"sungluc":
			weapon_node.rotation = Vector3(0, 0, 0)
			_box_part(weapon_node, Vector3(0.035, 0.05, 0.2), Vector3(0, 0.07, -0.12), Color("2a2c2e"), 0.5)       # nòng + khoá nòng
			_box_part(weapon_node, Vector3(0.032, 0.11, 0.045), Vector3(0, 0.0, -0.03), Color("3a2e26"))             # báng
			_box_part(weapon_node, Vector3(0.012, 0.03, 0.04), Vector3(0, 0.035, -0.07), Color("1c1d1c"))            # vòng cò
		"phao":
			_box_part(weapon_node, Vector3(0.05, 0.14, 0.05), Vector3(0, 0.05, 0), Color("c8302a"))
		"chai":
			_box_part(weapon_node, Vector3(0.07, 0.22, 0.07), Vector3(0, 0.08, 0), Color(0.3, 0.6, 0.4))
		"":
			pass
		_:
			_held_model(weapon_node, id)
	_update_off()


## Món không có hình cầm tay riêng: dùng hình 3D của món đó, thu nhỏ vừa lòng bàn tay.
func _held_model(parent: Node3D, id: String) -> void:
	parent.rotation = Vector3(-0.2, 0.3, 0)
	var m := ItemModels.make(id)
	m.scale = Vector3.ONE * (1.1 if Items.get_def(id).get("cat", "") != "gear" else 0.8)
	m.rotation = Vector3.ZERO
	m.position = Vector3(0, 0.02, -0.04)
	if id == "denpin":
		# đèn pin nằm dọc trục nắm tay (mặt kính hướng lên theo trục, tức chĩa thẳng ra trước khi cổ tay gập)
		# đúng như bản duyệt A: thân đèn nằm trong lòng nắm tay (lệch 4cm về phía các ngón), dọc trục nắm
		parent.rotation = Vector3.ZERO
		m.scale = Vector3.ONE
		m.rotation = Vector3(0, 0, PI * 0.5)
		m.position = Vector3(0.04, 0.0, 0.0) - parent.position
	for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
		mi.layers = FPArms.LAYER if fp_arms else 1
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)


## Món cầm ở tay trái.
func _update_off() -> void:
	if off_node == null:
		off_node = Node3D.new()
		off_node.position = Vector3(0.0, 0.03, 0.0)
		hand_l.get_node("Grip").add_child(off_node)
	for c in off_node.get_children():
		c.queue_free()
	_held_off = Game.offhand
	if Game.offhand != "":
		_held_model(off_node, Game.offhand)


func is_local() -> bool:
	return is_multiplayer_authority()


## Tay thật (model có khung xương) chỉ dựng cho người chơi trên máy này; các khối hình cũ ẩn đi, chỉ giữ làm điểm nắm.
func _make_fp_arms() -> void:
	if not ResourceLoader.exists(FPArms.MODEL):
		return
	fp_arms = FPArms.new()
	fp_arms.flash_light = light
	camera.add_child(fp_arms)
	for arm_n: Node3D in [hand_r, hand_l]:
		for mi: MeshInstance3D in arm_n.find_children("*", "MeshInstance3D", true, false):
			if not weapon_node.is_ancestor_of(mi) and (off_node == null or not off_node.is_ancestor_of(mi)):
				mi.visible = false
	fp_arms.set_shirt(net_shirt)


func _ready() -> void:
	if is_local():
		_make_fp_arms()
	add_to_group("players")
	world = get_tree().get_first_node_in_group("world")
	arm.add_excluded_object(get_rid())
	_last_pos = global_position
	if is_local():
		camera.current = true
		camera.fov = float(Game.settings.fov)
		net_name = Net.my_name
		set_third_person(false)
		name_tag.visible = false
		Game.shake.connect(add_shake)
		Game.inventory_changed.connect(_on_inventory_changed)
		_on_inventory_changed()
	else:
		camera.current = false
		body.visible = true
		hands.visible = false


func _on_inventory_changed() -> void:
	var col := Color("e9e4d8")
	match Game.equip.body:
		"aokhoac": col = Color("2c3238")
		"aophao": col = Color("4a5a6a")
		"aobaoho": col = Color("d08a2f")
		"aogiap": col = Color("4a5a3a")
	net_shirt = col
	body.set_shirt(col)
	if fp_arms:
		fp_arms.set_shirt(col)
	for arm_n: Node3D in [hand_r, hand_l]:
		((arm_n.get_node("Sleeve") as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = col
		((arm_n.get_node("Cuff") as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = col.darkened(0.25)
	_update_held()
	net_stealth = Game.stat("stealth")


# ------------------------------------------------------------------ xe máy
func riding_bike() -> bool:
	return riding >= 0


func start_riding(idx: int, fuel: float) -> void:
	riding = idx
	bike_fuel = fuel
	if crouching:
		set_crouching(false)
	_set_flag(F_RIDE, true)
	Game.say("Đã lên xe (xăng %d%%). F để xuống. Xe rất ồn: quái vật nghe thấy từ xa." % int(fuel))
	Sfx.play("door", -6.0)


func stop_riding() -> void:
	if riding < 0:
		return
	var side := global_transform.basis.x * 0.9
	if world:
		world.bikes.dismount(riding, global_position, rotation.y + PI, bike_fuel)
	riding = -1
	_set_flag(F_RIDE, false)
	Sfx.loop("engine_loop", 0.0)
	if not test_move(global_transform, side):
		global_position += side


func _on_refuel(amount: float) -> bool:
	if riding < 0:
		return false
	bike_fuel = minf(100.0, bike_fuel + amount)
	Game.say("Đã đổ xăng: %d%%" % int(bike_fuel), "good")
	return true


# ------------------------------------------------------------------ điều khiển
func _unhandled_input(event: InputEvent) -> void:
	if not is_local() or (world and world.ui_open()):
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(event.relative)
	elif Game.dead:
		return
	elif event.is_action_pressed("toggle_view"):
		set_third_person(not third_person)
	elif event.is_action_pressed("swap_hand"):
		Game.swap_hand()
		Sfx.play("ui_click", -10.0)
	elif event.is_action_pressed("hot_1") or event.is_action_pressed("hot_2") or event.is_action_pressed("hot_3") or event.is_action_pressed("hot_4"):
		for k in 4:
			if event.is_action_pressed("hot_%d" % (k + 1)):
				Game.select_hot(k)
	elif event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Game.select_hot(Game.hot_sel + (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1))
	elif event.is_action_pressed("use_off") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		use_offhand()
	elif event.is_action_pressed("crouch") and not swimming and not Game.fly and riding < 0:
		set_crouching(not crouching)
	elif event.is_action_pressed("nightvision"):
		if Items.get_def(str(Game.equip.get("eyes", ""))).has("nightvision"):
			Game.nv_on = not Game.nv_on
			Sfx.play("ui_click", -4.0, 1.4)
			Game.say("Kính nhìn đêm: BẬT" if Game.nv_on else "Kính nhìn đêm: TẮT")
		else:
			Game.say("Chưa đeo kính nhìn đêm (tìm ở biệt phủ, đeo vào ô mắt trong túi đồ).")
	elif event.is_action_pressed("flashlight"):
		_set_flag(F_LIGHT, not (net_flags & F_LIGHT))
		Sfx.play("ui_click", -6.0)
	elif event.is_action_pressed("fly") and Game.god:
		Game.fly = not Game.fly
		Game.say("Bay: BẬT (Space lên · C xuống · Shift nhanh)" if Game.fly else "Bay: TẮT")
	elif event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if riding >= 0 and (target.is_empty() or target.get("type", "") == "bike"):
			stop_riding()
		elif world and Game.carrying != "" and target.get("type", "") != "shelter":
			world.drop_carry()
		elif world and not target.is_empty():
			world.interact(target)
	elif event.is_action_pressed("attack") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		attack()
	elif event.is_action_pressed("throw"):
		throw_item()


func look(relative: Vector2) -> void:
	var sens := MOUSE_SENS * float(Game.settings.sens)
	rotate_y(-relative.x * sens)
	pitch = clampf(pitch - relative.y * sens, -1.45, 1.45)
	head.rotation.x = pitch
	net_pitch = pitch


func set_third_person(on: bool) -> void:
	third_person = on
	arm.spring_length = THIRD_PERSON_DIST if on else 0.0
	arm.position = Vector3(0.45, 0.25, 0.0) if on else Vector3.ZERO
	body.visible = on or not is_local()


func set_crouching(on: bool) -> void:
	if on == crouching:
		return
	if not on and test_move(global_transform, Vector3.UP * (STAND_HEIGHT - CROUCH_HEIGHT)):
		return   # trần quá thấp, không đứng dậy được
	_apply_crouch(on)
	_set_flag(F_CROUCH, on)


func _apply_crouch(on: bool) -> void:
	crouching = on
	var height := CROUCH_HEIGHT if on else STAND_HEIGHT
	(shape.shape as CapsuleShape3D).height = height
	shape.position.y = height * 0.5


func _set_flag(flag: int, on: bool) -> void:
	net_flags = (net_flags | flag) if on else (net_flags & ~flag)


func add_shake(amount: float) -> void:
	_shake = minf(1.0, maxf(_shake, amount) + amount * 0.25)
	_shake_freq = Game.shake_freq
	Game.shake_freq = 1.0


func eye_position() -> Vector3:
	return global_position + Vector3(0, (CROUCH_HEIGHT if crouching else STAND_HEIGHT) - 0.2, 0)


# ------------------------------------------------------------------ vòng lặp
func _physics_process(delta: float) -> void:
	if not is_local():
		_remote_update(delta)
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_update_camera(delta)
	_set_flag(F_DEAD, Game.dead)
	_set_flag(F_HIDDEN, Game.god)
	if Game.dead:
		if riding >= 0:
			stop_riding()
		if not _dead_shown:
			_dead_shown = true
			set_third_person(true)
			body.play_dead(true)
		velocity = Vector3.ZERO
		net_speed = 0.0
		net_noise = 0.0
		return
	if _dead_shown:
		_dead_shown = false
		body.play_dead(false)
	if Game.grabbed and not Game.fly:
		# bị xúc tu quấn: treo lơ lửng tại chỗ, giãy giụa
		if riding >= 0:
			stop_riding()
		global_position = global_position.lerp(Game.grab_pos, minf(1.0, delta * 8.0))
		velocity = Vector3.ZERO
		_fall_speed = 0.0
		net_speed = 0.0
		target = {}
		add_shake(0.04)
		return
	if world and world.ui_open():
		_idle_physics(delta)
		return
	if Game.fly:
		_fly(delta)
	else:
		_move(delta)
	_update_state(delta)
	target = world.find_interactable(camera.global_position, -camera.global_transform.basis.z, self) if world else {}


func _idle_physics(delta: float) -> void:
	if not is_on_floor() and not swimming and not Game.fly:
		velocity.y -= gravity * delta
	velocity.x = move_toward(velocity.x, 0.0, ACCEL * delta)
	velocity.z = move_toward(velocity.z, 0.0, ACCEL * delta)
	if swimming:
		velocity.y = move_toward(velocity.y, 0.0, 4.0 * delta)
	move_and_slide()
	net_speed = 0.0
	Game.noise = move_toward(Game.noise, 0.0, 2.5 * delta)
	net_noise = Game.noise
	body.animate(delta, 0.0, crouching, swimming, pitch)


func _fly(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := camera.global_transform.basis * Vector3(input.x, 0.0, input.y)
	dir.y += Input.get_axis("crouch", "jump")
	var speed := 40.0 if Input.is_action_pressed("sprint") else 15.0
	global_position += dir.limit_length(1.0) * speed * delta
	velocity = Vector3.ZERO
	swimming = false
	_set_flag(F_SWIM, false)


func _move(delta: float) -> void:
	var feet_depth := 0.0
	if world:
		feet_depth = world.water_depth(global_position)
	var was_swimming := swimming
	swimming = feet_depth >= SWIM_DEPTH or (was_swimming and feet_depth >= SWIM_DEPTH - 0.25)
	_set_flag(F_SWIM, swimming)
	if swimming and crouching:
		set_crouching(false)
	if feet_depth > 0.5 and not _was_in_water:
		Sfx.play("splash", linear_to_db(clampf(absf(velocity.y) / 9.0, 0.15, 1.0)))
		if world:
			world.emit_noise(global_position, 0.5 if absf(velocity.y) > 4.0 else 0.25)
	_was_in_water = feet_depth > 0.5

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if riding >= 0 and feet_depth > 0.7:
		stop_riding()
		Game.say("Xe chết máy vì ngập nước.", "bad")
	if swimming:
		_swim(delta, input, feet_depth)
	else:
		_walk(delta, input, feet_depth)


func _walk(delta: float, input: Vector2, feet_depth: float) -> void:
	var on_floor := is_on_floor()
	if not on_floor:
		velocity.y -= gravity * delta
		_fall_speed = minf(_fall_speed, velocity.y)
	else:
		if _fall_speed < -12.5 and feet_depth < 0.6:
			Game.damage((-_fall_speed - 12.5) * 7.0, "fall")
			Game.say("Bạn ngã đau!", "bad")
		_fall_speed = 0.0
		if Input.is_action_just_pressed("jump"):
			if crouching:
				set_crouching(false)
			elif Game.carrying != "":
				pass                     # đang vác vật nặng: không nhảy được
			elif Game.stamina > 4.0 and riding < 0:
				velocity.y = JUMP_SPEED
				Game.stamina -= 4.0
	var dir := (global_transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	sprinting = Input.is_action_pressed("sprint") and not crouching and input.y < 0.0 and Game.can_sprint() and riding < 0
	var speed := CROUCH_SPEED if crouching else (RUN_SPEED if sprinting else WALK_SPEED)
	speed *= Game.speed_factor()
	if riding >= 0:
		speed = BIKE_SPEED if bike_fuel > 0.0 else 2.2
		if input.y > 0.0:
			speed *= 0.35           # lùi xe thì chậm
		input.x *= 0.3
	if feet_depth > 0.3:
		speed *= lerpf(0.8, 0.45, clampf((feet_depth - 0.3) / 0.9, 0.0, 1.0))   # lội nước thì chậm
	var accel := ACCEL if on_floor else AIR_ACCEL
	if riding >= 0:
		accel = 9.0
	velocity.x = move_toward(velocity.x, dir.x * speed, accel * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, accel * delta)
	# Xe máy không leo được vỉa hè, bậc thềm; riêng tấm ván bắc qua khe nứt thì chạy lên được.
	var on_plank := false
	if riding >= 0 and world:
		for ch in world.city.chasms:
			if (ch.rect as Rect2).grow(2.6).has_point(Vector2(global_position.x, global_position.z)):
				if ch.kind == "plank":
					on_plank = true
				elif (ch.rect as Rect2).grow(0.6).has_point(Vector2(global_position.x, global_position.z)):
					stop_riding()
					Game.say("Xe máy không qua được chỗ này. Tìm khe nứt có ván bắc qua, hoặc bỏ xe lại.", "bad")
				break
	if on_floor and (riding < 0 or on_plank):
		_step_up(delta)
	move_and_slide()


func _swim(delta: float, input: Vector2, feet_depth: float) -> void:
	sprinting = Input.is_action_pressed("sprint") and Game.stamina > 1.0 and input.length() > 0.1
	var speed := SWIM_SPEED * (1.45 if sprinting else 1.0) * clampf(Game.speed_factor(), 0.6, 1.2)
	# Bơi theo hướng nhìn: nhìn xuống + tiến = lặn.
	var wish := camera.global_transform.basis * Vector3(input.x, 0.0, input.y)
	var vertical := Input.get_axis("crouch", "jump")
	wish.y += vertical
	wish = wish.limit_length(1.0) * speed
	if absf(wish.y) < 0.05:
		# Thả lỏng: nổi lên tới khi đầu nhô khỏi mặt nước; mang quá nặng thì chìm dần.
		var heavy := Game.weight() > Game.capacity() * 0.9
		wish.y = -0.45 if heavy else clampf((feet_depth - FLOAT_DEPTH) * 1.6, -0.5, 0.9)
	# Không bơi cao hơn mặt nước
	if feet_depth < FLOAT_DEPTH - 0.12 and wish.y > 0.0:
		wish.y = 0.0
	velocity = velocity.move_toward(wish, 9.0 * delta)
	# Vịn bờ leo lên: sát mặt nước, đang áp vào thành hồ, bấm Space.
	if is_on_wall() and feet_depth < FLOAT_DEPTH + 0.3 and Input.is_action_pressed("jump") and Game.stamina > 6.0:
		velocity.y = 7.2
		Game.stamina -= 6.0
		swimming = false
	move_and_slide()


func _update_state(delta: float) -> void:
	var hv := Vector2(velocity.x, velocity.z).length()
	var moving := hv > 0.5
	var on_floor := is_on_floor()
	Game.distance += global_position.distance_to(_last_pos)
	_last_pos = global_position
	# sức bền
	if sprinting and moving:
		Game.stamina = maxf(0.0, Game.stamina - STAMINA_DRAIN * (0.8 if swimming else 1.0) * (0.5 if Game.coffee > 0.0 else 1.0) * delta)
	else:
		var regen := STAMINA_REGEN * (0.5 if swimming else 1.0)
		if Game.has_injury("pain") and Game.painkiller <= 0.0:
			regen *= 0.6
		Game.stamina = minf(100.0, Game.stamina + regen * delta)
	# hơi thở
	var head_y := global_position.y + (CROUCH_HEIGHT if crouching else STAND_HEIGHT) - 0.25
	var head_under: bool = world != null and world.water_depth(Vector3(global_position.x, head_y, global_position.z)) > 0.02
	if head_under and not Game.god:
		Game.breath = maxf(0.0, Game.breath - 100.0 / BREATH_TIME * delta)
		if Game.breath <= 0.0:
			Game.damage(11.0 * delta, "drown")
	else:
		if Game.breath < 25.0 and not head_under:
			Sfx.play("gasp", -6.0)
			Game.breath = 25.0
		Game.breath = minf(100.0, Game.breath + 35.0 * delta)
	Game.submerged = world != null and world.water_depth(camera.global_position) > 0.0
	# bề mặt + bước chân + tiếng ồn
	var wading: bool = world != null and world.water_depth(global_position) > 0.25
	if on_floor:
		surface = "water" if wading else _floor_surface()
	var loud := 0.0
	if swimming:
		loud = 0.45 if sprinting else (0.22 if moving or absf(velocity.y) > 0.6 else 0.0)
		if head_under:
			loud *= 0.3
	elif moving and on_floor:
		loud = 0.06 if crouching else (1.0 if sprinting else 0.42)
		loud *= {"metal": 1.3, "wood": 1.1, "grass": 0.7, "dirt": 0.8, "water": 1.25}.get(surface, 1.0)
		loud *= 1.0 - clampf(Game.stat("quiet"), 0.0, 0.8)
	if riding >= 0:
		# xe máy: ồn, tốn xăng, tiếng máy vang xa
		loud = 0.95 if hv > 1.0 else 0.35
		if hv > 1.0:
			bike_fuel = maxf(0.0, bike_fuel - 0.95 * delta)
			if bike_fuel <= 0.0 and bike_fuel + 0.95 * delta > 0.0:
				Game.say("Hết xăng. Cần can xăng (mở túi, dùng khi đang ngồi trên xe).", "bad")
		_engine_t -= delta
		if _engine_t <= 0.0 and hv > 1.0 and world:
			_engine_t = 1.2
			world.emit_noise(global_position, 0.9)
		Sfx.loop("engine_loop", clampf(0.25 + hv / BIKE_SPEED * 0.6, 0.0, 0.85))
	Game.noise = move_toward(Game.noise, loud, 2.5 * delta)
	net_noise = Game.noise
	net_speed = hv
	bike_model.visible = riding >= 0 and (third_person or not is_local())
	cockpit.visible = riding >= 0 and is_local() and not third_person
	if cockpit.visible:
		# đầu xe nghiêng nhẹ khi vào cua, rung theo máy
		cockpit.rotation.z = lerpf(cockpit.rotation.z, clampf(-Input.get_axis("move_left", "move_right") * 0.12 * hv / BIKE_SPEED, -0.12, 0.12), 0.1)
		cockpit.position.y = STAND_HEIGHT - 0.2 + sin(Time.get_ticks_msec() * 0.045) * 0.003 * (1.0 if hv > 1.0 else 0.4)
	if riding < 0:
		_footsteps(delta, hv, on_floor, loud, true)
	Game.indoors = world != null and world.is_indoors(global_position)
	body.animate(delta, hv, crouching, swimming, pitch)
	light.light_energy = 4.5 * (Game.flash_boost if is_local() else 1.0) if (net_flags & F_LIGHT) else 0.0
	light.spot_range = 26.0 * (1.35 if Game.flash_boost > 1.0 else 1.0)


func _footsteps(delta: float, hv: float, on_floor: bool, loud: float, local: bool) -> void:
	if swimming:
		_step_acc += (hv + absf(velocity.y)) * delta
		if _step_acc > 2.2:
			_step_acc = 0.0
			if local:
				Sfx.play("swim_%d" % (1 + randi() % 3), -8.0)
			else:
				Sfx.play_at("swim_%d" % (1 + randi() % 3), global_position, -3.0, 4.0)
		return
	if not on_floor or hv < 0.5:
		return
	_step_acc += hv * delta
	var stride := 1.2 if crouching else (2.5 if hv > 5.5 else 1.9)
	if _step_acc >= stride:
		_step_acc = 0.0
		Sfx.step(surface, global_position, loud, local)


func _floor_surface() -> String:
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		if col.get_normal().y > 0.6:
			var c := col.get_collider()
			if c and c.has_meta("surface"):
				return c.get_meta("surface")
	return surface


func _update_hands(delta: float) -> void:
	hands.visible = not third_person and not Game.dead
	if not hands.visible:
		return
	var hv := Vector2(velocity.x, velocity.z).length()
	_bob += delta * (5.0 + hv * 1.4) * (1.0 if hv > 0.5 else 0.0)
	_swing = maxf(0.0, _swing - delta * 2.3)
	var k := sin((1.0 - _swing) * PI) if _swing > 0.0 else 0.0
	# cú đánh 3 pha: lấy đà (wind) -> vụt (hit) -> thu tay; u chạy 0..1 trong 0,43 giây
	var u := 1.0 - _swing if _swing > 0.0 else 1.0
	var wind := smoothstep(0.0, 0.28, u) * (1.0 - smoothstep(0.28, 0.42, u))
	var hit := smoothstep(0.28, 0.42, u) * (1.0 - smoothstep(0.55, 1.0, u))
	hands.rotation = Vector3(-0.04 * hit + 0.03 * wind, 0.06 * wind - 0.08 * hit, 0.0)
	hands.position = Vector3(sin(_bob * 0.5) * 0.012, absf(sin(_bob)) * -0.014 * minf(hv / 4.0, 1.5) + (-0.05 if swimming else 0.0), 0.0)
	# vung tay phải khi đánh; khi bơi hai tay quạt nước
	hand_r.rotation = Vector3(0.42 + k * 1.0, 0.34 - k * 0.5, 0.0)
	hand_r.position = Vector3(0.3, -0.34 + k * 0.1, -0.3 - k * 0.14)
	var stroke := sin(_bob * 0.7) * 0.5 if swimming else 0.0
	hand_l.rotation = Vector3(0.42 + stroke, -0.34, 0.0)
	hand_l.visible = swimming or riding >= 0 or hv > 5.5 or Game.offhand != ""
	if riding >= 0:
		# hai tay đặt lên tay lái (tay theo thân xe chứ không theo hướng ngẩng/cúi của đầu)
		var inv := Basis(Vector3.RIGHT, -pitch)
		hand_r.position = inv * Vector3(0.36, -0.42, -0.42)
		hand_l.position = inv * Vector3(-0.36, -0.42, -0.42)
		hand_r.rotation = Vector3(0.25 - pitch, 0.06, 0.0)
		hand_l.rotation = Vector3(0.25 - pitch, -0.06, 0.0)
		hands.position = Vector3.ZERO
	else:
		hand_l.position = Vector3(-0.3, -0.34, -0.3)
	# cầm đèn pin: tay đưa ra trước, đèn chĩa thẳng theo hướng nhìn (góc dưới màn hình), không vung vẩy
	var g_r: Node3D = hand_r.get_node("Grip")
	var g_l: Node3D = hand_l.get_node("Grip")
	g_r.rotation = Vector3.ZERO
	g_l.rotation = Vector3.ZERO
	for gg: Node3D in [g_r, g_l]:
		gg.set_meta("reverse", false)
		gg.set_meta("tilt", 0.0)
		gg.set_meta("roll", 0.0)
		gg.set_meta("thumb", 0.35)
		gg.set_meta("thumb_curl", 1.0)
	# đèn pin (bản duyệt A): nắm ngược (ngón vòng lên qua thân đèn), xoay tay -0,3, ngón cái gập vào đè lên thân đèn
	for gg2: Node3D in [g_r, g_l]:
		var fl: bool = (gg2 == g_r and Game.equip.weapon == "denpin") or (gg2 == g_l and Game.offhand == "denpin")
		var fist: bool = (gg2 == g_r and Game.equip.weapon == "") or (gg2 == g_l and Game.offhand == "")
		var held: String = Game.equip.weapon if gg2 == g_r else Game.offhand
		if held != "" and held != "denpin" and Items.get_def(held).has("weapon") and not Items.get_def(held).has("gun"):
			fl = true            # gậy, ống tuýp, xà beng...: cùng kiểu nắm đã duyệt
		gg2.remove_meta("fist_thumb") if gg2.has_meta("fist_thumb") else null
		if fist and fp_arms and riding < 0 and not swimming:
			# nắm đấm tay không: nắm gọn, ngón cái gập hẳn vào trong (không vểnh ra)
			gg2.set_meta("reverse", true)
			gg2.set_meta("roll", -0.3)
			gg2.set_meta("fist_thumb", 0.0)
			gg2.set_meta("thumb_curl", -2.2)
			gg2.set_meta("pole", Vector3(0.15 * (1.0 if gg2 == g_r else -1.0), -1.0, 0.0))
			gg2.set_meta("amt", 1.4)
		elif fl and fp_arms and riding < 0 and not swimming:
			gg2.set_meta("reverse", true)
			gg2.set_meta("roll", -0.3)
			gg2.set_meta("thumb", -1.5)
			gg2.set_meta("thumb_curl", -1.4)
			gg2.set_meta("pole", Vector3(0.15 * (1.0 if gg2 == g_r else -1.0), -1.0, 0.0))
			gg2.set_meta("amt", 1.0)
		else:
			gg2.remove_meta("pole") if gg2.has_meta("pole") else null
			gg2.remove_meta("amt") if gg2.has_meta("amt") else null
	if fp_arms and riding < 0 and not swimming:
		# Tư thế như các game FPS: tay ở một phần ba dưới, cẳng tay đi chéo từ góc dưới vào giữa, khuỷu tay chĩa ra
		# ngoài và nằm ngoài khung hình (lớp tay vẽ với góc nhìn hẹp riêng). Điểm nắm đặt thẳng trong toạ độ camera.
		var w: String = Game.equip.weapon
		if w == "denpin":
			_pose_hand(hand_r, _view_basis(1.0), Vector3(0.07, -0.02, -0.55) - _view_basis(1.0).x * 0.04)
		elif w == "":
			# đấm: rụt tay về sát người, hạ thấp, rồi thúc thẳng ra giữa màn hình
			var fb := _view_basis(1.0).rotated(Vector3.UP, hit * 0.35 - wind * 0.25).rotated(Vector3.RIGHT, wind * 0.3)
			_pose_hand(hand_r, fb, Vector3(0.12, -0.1, -0.5) + Vector3(0.05, -0.05, 0.14) * wind + Vector3(-0.09, 0.05, -0.3) * hit)
		else:
			# vũ khí cán dài: nắm như cầm đèn (cùng kiểu đã duyệt), cán dựng chếch lên trước; vung thì quật xuống
			# vụt: giơ cao ra sau về bên phải lấy đà, rồi quật chéo xuống trước sang trái, thu về
			var wdir := Vector3(-0.25, 1.0, -0.55).lerp(Vector3(-0.85, -0.45, -1.0), hit)
			# lấy đà: ngả đầu gậy sang phải và ra sau vai (xoay quanh trục nhìn và trục ngang của camera)
			var wb := Basis(Vector3.BACK, -0.75 * wind) * Basis(Vector3.RIGHT, 0.5 * wind) * _flash_basis(1.0, wdir)
			_pose_hand(hand_r, wb, Vector3(0.12, -0.1, -0.48) + Vector3(0.12, 0.2, 0.02) * wind + Vector3(-0.22, -0.12, -0.14) * hit)
		var o: String = Game.offhand
		if o == "denpin":
			_pose_hand(hand_l, _view_basis(-1.0), Vector3(-0.07, -0.02, -0.55) - _view_basis(-1.0).x * 0.04)
		elif o == "":
			_pose_hand(hand_l, _view_basis(-1.0), Vector3(-0.12, -0.1, -0.5))
		else:
			_pose_hand(hand_l, _flash_basis(-1.0, Vector3(-0.25, 1.0, -0.55)), Vector3(-0.12, -0.1, -0.48))
		g_r.rotation = Vector3.ZERO
		g_l.rotation = Vector3.ZERO
	elif riding < 0 and not swimming:
		if Game.equip.weapon == "":
			hand_r.position = Vector3(0.2, -0.3 + k * 0.06, -0.06 - k * 0.22)
			hand_r.rotation = Vector3(0.25 + k * 0.2, 0.12, 0.0)
		if Game.equip.weapon == "denpin":
			g_r.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
		if Game.offhand == "denpin":
			g_l.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	_aim_flashlight()
	if fp_arms:
		fp_arms.visible = hands.visible
		for sd: Array in [["r", hand_r, 1.0, Game.equip.weapon], ["l", hand_l, -1.0, Game.offhand]]:
			var hn: Node3D = sd[1]
			# Chỉ vẽ tay khi tay không hoặc cầm đèn pin; cầm món khác thì chỉ hiện món đồ.
			var held := str(sd[3])
			if hn.visible and (held == "" or held == "denpin"):
				fp_arms.grip_amt[sd[0]] = float((hn.get_node("Grip") as Node3D).get_meta("amt", 0.95 if str(sd[3]) != "" else 1.15))
				var gnode: Node3D = hn.get_node("Grip")
				var pole: Vector3 = gnode.get_meta("pole", Vector3(float(sd[2]) * 1.0, -0.45, 0.1))        # khuỷu tay chĩa ra ngoài, hơi xuống
				fp_arms.solve(sd[0], gnode, pole)
			else:
				fp_arms.relax(sd[0])


## Đặt bàn tay sao cho điểm nắm (Grip, cách gốc tay 0,36m) nằm đúng `pos` với hướng `basis` trong toạ độ camera.
func _pose_hand(hn: Node3D, basis: Basis, pos: Vector3) -> void:
	hn.basis = basis
	hn.position = pos - basis * Vector3(0, 0, -0.36)


## Cầm đèn pin như ảnh tham khảo: bàn tay đỡ thân đèn từ phía dưới-ngoài, cẳng tay đi lên từ góc dưới,
## thân đèn nằm ngang chĩa chéo vào giữa và ra trước (trục nắm = trục đèn). side: 1 tay phải, -1 tay trái.
func _flash_basis(side: float, dir := Vector3(-0.15, 0.1, -1.0)) -> Basis:
	# bản duyệt A (tay phải): đèn chĩa ra trước, lệch vào trong 0,15 và ngẩng 0,1; tay trái lấy đối xứng
	var fwd := dir.normalized()
	var x := Vector3.UP.cross(fwd).normalized() * -1.0
	if x.x < 0.0:
		x = -x
	var b := Basis(x, fwd, x.cross(fwd)).orthonormalized()
	if side < 0.0:
		var m := Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))
		b = m * b * m
	return b


## Hướng bàn tay đúng như ảnh mẫu đã duyệt (tay 4 ngón dính, bản 5): thân đèn nằm chéo vào giữa màn hình,
## bàn tay dựng đứng, nghiêng 0,3. Ánh đèn vẫn chiếu theo hướng nhìn (xem _aim_flashlight).
func _view_basis(side: float) -> Basis:
	var fwd := Vector3(-1.6, 0.12, -1.0).normalized()
	var z := (Vector3.UP - fwd * fwd.dot(Vector3.UP)).normalized()
	var b := Basis(Vector3.BACK, 0.3) * Basis(fwd.cross(z), fwd, z)
	if side < 0.0:
		var m := Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))
		b = m * b * m
	return b


## Ánh đèn phát ra từ mặt kính của chiếc đèn pin đang cầm (góc nhìn thứ nhất), chĩa theo hướng nhìn.
func _aim_flashlight() -> void:
	var grip: Node3D = null
	if Game.equip.weapon == "denpin":
		grip = hand_r.get_node("Grip")
	elif Game.offhand == "denpin":
		grip = hand_l.get_node("Grip")
	if grip == null or third_person or not hands.visible:
		light.position = Vector3(0.15, -0.1, 0.0)
		light.rotation = Vector3.ZERO
		return
	var lens: Vector3 = grip.global_transform * Vector3(0.04, 0.13, 0.0)
	light.global_transform = Transform3D(camera.global_transform.basis, lens)


func _update_camera(delta: float) -> void:
	_update_hands(delta)
	var head_y := (CROUCH_HEIGHT if crouching else STAND_HEIGHT) - 0.2
	if swimming:
		head_y = STAND_HEIGHT - 0.3
	head.position.y = lerpf(head.position.y, head_y, minf(1.0, 12.0 * delta))
	# Rung màn hình: biên độ nhỏ, tắt dần nhanh, nhân với mức người chơi chọn trong cài đặt.
	_shake = maxf(0.0, _shake - delta * (1.1 + _shake_freq * 0.8))
	var k := _shake * float(Game.settings.shake) * 2.0
	var t := Time.get_ticks_msec() * 0.001 * _shake_freq
	camera.h_offset = sin(t * 31.0) * 0.045 * k
	camera.v_offset = sin(t * 37.0 + 1.3) * 0.06 * k
	camera.rotation.z = sin(t * 23.0 + 0.7) * 0.014 * k


func _remote_update(delta: float) -> void:
	var crouch := (net_flags & F_CROUCH) != 0
	if crouch != crouching:
		_apply_crouch(crouch)
	swimming = (net_flags & F_SWIM) != 0
	head.rotation.x = net_pitch
	head.position.y = lerpf(head.position.y, (CROUCH_HEIGHT if crouching else STAND_HEIGHT) - 0.2, minf(1.0, 12.0 * delta))
	var dead := (net_flags & F_DEAD) != 0
	if dead != _dead_shown:
		_dead_shown = dead
		body.play_dead(dead)
	var attacking := (net_flags & F_ATTACK) != 0
	if attacking and not _prev_attack_flag:
		body.play_attack()
	_prev_attack_flag = attacking
	body.set_shirt(net_shirt)
	var on_bike := (net_flags & F_RIDE) != 0
	bike_model.visible = on_bike
	body.animate(delta, 0.0 if on_bike else net_speed, crouching, swimming, net_pitch)
	light.light_energy = 4.5 if (net_flags & F_LIGHT) else 0.0
	name_tag.text = net_name
	name_tag.visible = not dead
	# tiếng bước chân của người khác
	if net_speed > 0.5 and not swimming and not on_bike:
		var space := get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.4, 0), global_position + Vector3(0, -0.6, 0), 3)
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and hit.collider.has_meta("surface"):
			surface = hit.collider.get_meta("surface")
	velocity.y = 0.0
	if not on_bike:
		_footsteps(delta, net_speed, net_speed > 0.5, net_noise, false)


## Nếu bị một bậc thấp chặn lại (vỉa hè, bậc thềm) thì nhấc người lên bậc đó, kể cả khi đi chéo.
func _step_up(delta: float) -> void:
	var motion := Vector3(velocity.x, 0.0, velocity.z) * delta
	if motion.length() < 0.0005:
		return
	var block := KinematicCollision3D.new()
	if not test_move(global_transform, motion, block):
		return
	if test_move(global_transform, Vector3.UP * STEP_HEIGHT):
		return
	# Thăm dò theo hướng vuông góc với mép bậc (không phải hướng đi), để đi chéo vẫn bước lên được.
	var n := block.get_normal()
	var into := Vector3(-n.x, 0.0, -n.z)
	if into.length() < 0.2:
		into = motion.normalized()
	into = into.normalized()
	if into.dot(motion.normalized()) < 0.12:
		return                                   # gần như đi song song với mép: không tính là bước lên
	var raised := global_transform.translated(Vector3.UP * STEP_HEIGHT)
	var probe := into * 0.4
	if test_move(raised, probe):
		return                                   # phía trên là tường chứ không phải bậc
	var hit := KinematicCollision3D.new()
	var over := raised.translated(probe)
	if not test_move(over, Vector3.DOWN * STEP_HEIGHT, hit):
		return
	if hit.get_normal().y < 0.7:
		return
	var rise := STEP_HEIGHT + hit.get_travel().y
	if rise > 0.01:
		global_position += Vector3(0.0, rise + 0.01, 0.0) + into * 0.06


# ------------------------------------------------------------------ đánh / bắn / ném
## Chuột phải: dùng món ở tay trái (đèn pin: bật/tắt; đồ ăn, thuốc: dùng).
func use_offhand() -> void:
	var id: String = Game.offhand
	if id == "":
		return
	_use_held(id)


## Dùng một món đang cầm mà không phải để đánh. Trả về true nếu đã dùng.
func _use_held(id: String) -> bool:
	var def := Items.get_def(id)
	if def.has("light"):
		_set_flag(F_LIGHT, not (net_flags & F_LIGHT))
		Sfx.play("ui_click", -6.0)
		return true
	if def.get("cat", "") in ["food", "drink", "med"]:
		Game.use_item(id)
		return true
	if def.has("scan") and world:
		world.call("scan_supplies", global_position)
		return true
	return false


func attack() -> void:
	if _attack_cd > 0.0 or Game.dead or swimming:
		return
	if Game.carrying != "":
		Game.say("Đang vác bằng hai tay. Bấm E để đặt xuống rồi mới đánh được.")
		return
	var weapon: String = Game.equip.weapon
	var def := Items.get_def(weapon)
	if def.has("throwable"):
		throw_item()
		return
	if weapon != "" and not def.has("weapon") and not def.has("gun"):
		if _use_held(weapon):
			_attack_cd = 0.25
			return
	_attack_cd = 0.65
	_swing = 1.0
	body.play_attack()
	_set_flag(F_ATTACK, true)
	get_tree().create_timer(0.3).timeout.connect(func() -> void: _set_flag(F_ATTACK, false))
	var origin := camera.global_position if not third_person else eye_position()
	var dir := -camera.global_transform.basis.z
	if def.has("gun"):
		if Game.ammo <= 0:
			Sfx.play("empty")
			Game.say("Hết đạn.")
			return
		Game.ammo -= 1
		Sfx.play("gunshot", -2.0)
		add_shake(0.35)
		if world:
			world.player_shoot(origin, dir)
		Game.inventory_changed.emit()
		return
	Sfx.play("swing", -6.0)
	Game.stamina = maxf(0.0, Game.stamina - 5.0)
	if world:
		var power := 1.0 if weapon != "" else 0.35
		if Game.has_injury("fracture", "arm"):
			power *= 0.5
		if weapon != "" and world.player_smash_glass(origin, dir, REACH + 0.4):
			return
		if world.player_melee(origin, dir, REACH, float(def.get("stun", 0.6)), power):
			Sfx.play("hit", -3.0)
			if weapon != "" and def.has("dur"):       # chỉ bàn phím và gậy gỗ mới hỏng
				Game.weapon_uses -= 1
				Game.wear[weapon] = Game.weapon_uses
				if Game.weapon_uses <= 0:
					Game.say("%s đã gãy." % def.n, "bad")
					Game.equip.weapon = ""
					Game.wear.erase(weapon)
					Game.remove_item(weapon)


func throw_item() -> void:
	if _attack_cd > 0.0 or Game.dead or Game.carrying != "":
		return
	var id := ""
	if Items.get_def(Game.equip.weapon).has("throwable"):
		id = Game.equip.weapon
	elif Game.count("phao") > 0:
		id = "phao"
	elif Game.count("chai") > 0:
		id = "chai"
	if id == "" or Game.count(id) <= 0:
		Game.say("Không có gì để ném (pháo, chai).")
		return
	_attack_cd = 0.7
	_swing = 1.0
	body.play_attack()
	Game.remove_item(id)
	if Game.count(id) <= 0 and Game.equip.weapon == id:
		Game.equip.weapon = ""
	Sfx.play("swing", -6.0)
	if world:
		var dir := -camera.global_transform.basis.z
		world.player_throw(id, eye_position() + dir * 0.6, dir * 15.0 + Vector3(0, 4.0, 0))
