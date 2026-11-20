class_name HeroHumanoid
extends Humanoid
## Hình người dùng model thật có khung xương (Quaternius, CC0) cho các nhân vật ở gần: gia đình, kẻ cướp,
## đồng nghiệp, người bị thương, người chơi khác. Dùng lại toàn bộ hoạt ảnh của Humanoid (đi, chạy, ngồi, bơi, đánh,
## ngã): các khớp "giả" của Humanoid vẫn được tính như cũ nhưng ẩn đi, rồi chép góc xoay sang xương của model.
## Quần áo được tô theo vùng trên cơ thể (áo / quần / giày) và nhuộm màu riêng cho từng người (instance uniform).

const MALE := "res://assets/models/hero/Superhero_Male_FullBody.gltf"
const FEMALE := "res://assets/models/hero/Superhero_Female_FullBody.gltf"
const HAIR := {"long": "res://assets/models/hero/Hair_Long.gltf", "short": "res://assets/models/hero/Hair_SimpleParted.gltf",
	"side": "res://assets/models/hero/Hair_SimpleParted.gltf", "buzz": "res://assets/models/hero/Hair_Buzzed.gltf"}

var female := false
## trẻ con (bé Na): đầu to so với người, vai hẹp, tay chân ngắn — đặt `scale` nhỏ ở bên ngoài
var child := false
var sleeves := "short"          # "short" (áo cộc) / "long" (áo dài tay)
var face: Node3D                # điểm gắn trên đầu (khăn bịt mặt, mũ...)
var hand_att: Node3D            # điểm gắn ở bàn tay vung đánh (gậy, dao...)

static var _cache: Dictionary = {}       # khoá giới tính + tay áo -> {mesh, mat}
var _model: Node3D
var _skel: Skeleton3D
var _body: MeshInstance3D
var _bi := {}
var _rest := {}                 # chỉ số xương -> Transform3D tư thế nghỉ (toạ độ model)
var _hip_rest := 0.95
static var palm_twist := PI * 0.5


static func arrays_norm(mi: MeshInstance3D) -> PackedVector3Array:
	return mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]


static func _prepare(path: String, sleeve_kind: String) -> Dictionary:
	var key := path + sleeve_kind
	if _cache.has(key):
		return _cache[key]
	var sc: Node = (load(path) as PackedScene).instantiate()
	var sk: Skeleton3D = sc.find_children("*", "Skeleton3D", true, false)[0]
	var mi: MeshInstance3D = null
	for m: MeshInstance3D in sc.find_children("*", "MeshInstance3D", true, false):
		if m.name.begins_with("Super"):
			mi = m
	var y_pelvis := sk.get_bone_global_rest(sk.find_bone("pelvis")).origin.y
	var y_neck := sk.get_bone_global_rest(sk.find_bone("neck_01")).origin.y
	var y_foot := sk.get_bone_global_rest(sk.find_bone("foot_r")).origin.y
	var x_sh := absf(sk.get_bone_global_rest(sk.find_bone("upperarm_r")).origin.x)
	var x_el := absf(sk.get_bone_global_rest(sk.find_bone("lowerarm_r")).origin.x)
	var x_wr := absf(sk.get_bone_global_rest(sk.find_bone("hand_r")).origin.x)
	var sleeve_end := (x_sh + x_el) * 0.5 + 0.06 if sleeve_kind == "short" else x_wr - 0.03
	if sleeve_kind == "mid":
		sleeve_end = x_el + (x_wr - x_el) * 0.6
	# găng tay hở ngón: từ cổ tay tới hết đốt ngón thứ nhất
	var x_k2 := absf(sk.get_bone_global_rest(sk.find_bone("middle_02_r")).origin.x) + 0.006
	var x_t2 := absf(sk.get_bone_global_rest(sk.find_bone("thumb_02_r")).origin.x) + 0.006
	var y_hand := sk.get_bone_global_rest(sk.find_bone("hand_r")).origin.y
	var norms: PackedVector3Array = arrays_norm(mi)
	var arrays := mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var cols := PackedColorArray()
	cols.resize(verts.size())
	for i in verts.size():
		var v := verts[i]
		var ax := absf(v.x)
		var shirt := 0.0
		var pants := 0.0
		var shoe := 0.0
		if v.y < y_foot + 0.085:
			shoe = 1.0
		elif v.y < y_pelvis + 0.07:
			pants = smoothstep(y_foot + 0.085, y_foot + 0.11, v.y)
			shoe = 1.0 - pants
		elif v.y < y_neck - 0.015:
			if ax < x_sh + 0.02:
				shirt = 1.0
			else:
				shirt = 1.0 - smoothstep(sleeve_end - 0.01, sleeve_end + 0.01, ax)
			# chỗ giao áo / quần
			var t := smoothstep(y_pelvis + 0.05, y_pelvis + 0.09, v.y)
			shirt *= t
			pants = (1.0 - t) if ax < x_sh else 0.0
		# kênh a: 0 = không găng, 0.5 = găng (lòng bàn tay), 1 = găng (mu bàn tay)
		var glove := 0.0
		if ax > x_wr - 0.035 and absf(v.y - y_hand) < 0.09:
			var thumb_zone := v.y < y_hand - 0.022 and v.z > -0.06
			var limit := x_t2 if thumb_zone else x_k2
			if ax < limit:
				glove = 1.0 if norms[i].y > 0.15 else 0.5
		cols[i] = Color(shirt, pants, shoe, glove)
	arrays[Mesh.ARRAY_COLOR] = cols
	for ci in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
		arrays[ci] = null
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, mi.mesh.surface_get_format(0) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
	var src := mi.mesh.surface_get_material(0) as StandardMaterial3D
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/hero_body.gdshader")
	mat.set_shader_parameter("albedo_tex", src.albedo_texture)
	mat.set_shader_parameter("normal_tex", src.normal_texture)
	mat.set_shader_parameter("rough_tex", src.roughness_texture)
	sc.free()
	_cache[key] = {"mesh": am, "mat": mat}
	return _cache[key]


func setup(shirt_color: Color, pants_color: Color, skin_color := Color("d9a679")) -> void:
	super.setup(shirt_color, pants_color, skin_color)
	# các khối hình của Humanoid chỉ còn làm khung xương "giả" để tính hoạt ảnh: ẩn hết
	for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		mi.visible = false
	var path := FEMALE if female else MALE
	var prep := _prepare(path, sleeves)
	_model = (load(path) as PackedScene).instantiate()
	add_child(_model)
	_skel = _model.find_children("*", "Skeleton3D", true, false)[0]
	for m: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		if m.name.begins_with("Super"):
			_body = m
		elif m.name == "Eyebrows":
			var em := (m.mesh.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
			em.albedo_color = Color(0.22, 0.17, 0.14)
			m.material_override = em
	_body.mesh = prep.mesh
	_body.material_override = prep.mat
	_body.set_instance_shader_parameter("shirt_color", shirt_color)
	_body.set_instance_shader_parameter("pants_color", pants_color)
	_body.set_instance_shader_parameter("shoe_color", Color(0.08, 0.075, 0.075) if absi(hash(pants_color.to_html())) % 3 != 0 else Color(0.2, 0.13, 0.09))
	_body.set_instance_shader_parameter("skin_tint", Color(1.0, 0.93, 0.86).lerp(skin_color * 1.25, 0.25))
	_body.visibility_range_end = 260.0
	for i in _skel.get_bone_count():
		_bi[_skel.get_bone_name(i)] = i
		_rest[i] = _skel.get_bone_global_rest(i)
	_hip_rest = (_rest[_bi.pelvis] as Transform3D).origin.y
	# tóc
	var hs := hair_style
	if hs == "":
		hs = ["short", "buzz", "side"][absi(hash(shirt.to_html())) % 3]
	if female:
		hs = "long"
	var head_att := BoneAttachment3D.new()
	head_att.bone_name = "Head"
	_skel.add_child(head_att)
	var hair_sc: Node3D = (load(HAIR.get(hs, HAIR.short)) as PackedScene).instantiate()
	var holder := Node3D.new()
	holder.transform = (_rest[_bi.Head] as Transform3D).affine_inverse()
	if child:
		# BoneAttachment không theo tỉ lệ của xương: phóng tóc to theo đầu (quanh gốc xương đầu)
		var hs_t := Transform3D(Basis.IDENTITY.scaled(Vector3(1.32, 1.4, 1.32)), Vector3(0, 0.0, -0.01))
		holder.transform = hs_t * holder.transform
	head_att.add_child(holder)
	holder.add_child(hair_sc)
	for hm: MeshInstance3D in hair_sc.find_children("*", "MeshInstance3D", true, false):
		var hmat := (hm.mesh.surface_get_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
		hmat.albedo_color = Color(0.35, 0.3, 0.28)
		hm.material_override = hmat
	var ha := BoneAttachment3D.new()
	ha.bone_name = "hand_l"          # Humanoid vung tay _arm[1] khi đánh, tức tay trái của model
	_skel.add_child(ha)
	hand_att = Node3D.new()
	ha.add_child(hand_att)
	hand_att.position = Vector3(0.0, 0.085, 0.02)
	face = Node3D.new()
	head_att.add_child(face)
	face.position = Vector3(0, 0.06, 0.0)
	# ngón tay hơi co tự nhiên
	for s: String in ["l", "r"]:
		for f: String in ["index", "middle", "ring", "pinky"]:
			for j in 3:
				var b: int = _bi["%s_0%d_%s" % [f, j + 1, s]]
				_skel.set_bone_pose_rotation(b, _skel.get_bone_rest(b).basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, -0.35 * (1.0 + j * 0.2)))
	if child:
		# tỉ lệ trẻ em: đầu to so với người, vai và ngực hẹp, ngực phẳng, tay chân thon ngắn
		# (tỉ lệ xương nhân dồn xuống các xương con nên chỉnh rất ít: thân hẹp, đầu to bù lại)
		_skel.set_bone_pose_scale(_bi.spine_03, Vector3(0.82, 1.0, 0.6))          # ngực phẳng, vai hẹp
		_skel.set_bone_pose_scale(_bi.Head, Vector3(1.55 / 0.82, 1.55, 1.55 / 0.6))
		_body.set_instance_shader_parameter("cloth_flat", 0.85)          # áo rộng, không lộ khối cơ
		for s2: String in ["l", "r"]:
			_skel.set_bone_pose_scale(_bi["upperarm_" + s2], Vector3(0.75, 1.0, 0.75))
			_skel.set_bone_pose_scale(_bi["thigh_" + s2], Vector3(0.8, 1.0, 0.8))
	_apply_pose()


## Nắm chặt bàn tay (đang cầm vũ khí).
func grip(s: String) -> void:
	for f: String in ["index", "middle", "ring", "pinky"]:
		for j in 3:
			var b: int = _bi["%s_0%d_%s" % [f, j + 1, s]]
			_skel.set_bone_pose_rotation(b, _skel.get_bone_rest(b).basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, -1.25 * (1.0 + j * 0.15)))


func animate(delta: float, speed: float, crouching: bool, swimming: bool, pitch := 0.0) -> void:
	super.animate(delta, speed, crouching, swimming, pitch)
	_apply_pose()


func _set_global(bone: String, g: Basis, globals: Dictionary) -> void:
	var b: int = _bi[bone]
	var p := _skel.get_bone_parent(b)
	var pg: Basis = globals[p] if globals.has(p) else (_rest[p] as Transform3D).basis
	globals[b] = g
	_skel.set_bone_pose_rotation(b, Quaternion((pg.inverse() * g).orthonormalized()))


## Chép tư thế của các khớp Humanoid (toạ độ thân người, mặt hướng +Z giống model) sang xương model.
func _apply_pose() -> void:
	if _skel == null or _hips == null:
		return
	var hips_b := _hips.transform.basis
	var torso_b := hips_b * _torso.transform.basis
	var head_b := torso_b * _head.transform.basis
	var g := {}
	var r := func(n: String) -> Basis: return (_rest[_bi[n]] as Transform3D).basis
	_set_global("pelvis", hips_b * r.call("pelvis"), g)
	_set_global("spine_01", hips_b * r.call("spine_01"), g)
	_set_global("spine_02", hips_b.slerp(torso_b, 0.5) * r.call("spine_02"), g)
	_set_global("spine_03", torso_b * r.call("spine_03"), g)
	_set_global("neck_01", torso_b.slerp(head_b, 0.5) * r.call("neck_01"), g)
	_set_global("Head", head_b * r.call("Head"), g)
	for clav: String in ["clavicle_r", "clavicle_l"]:
		_set_global(clav, torso_b * r.call(clav), g)
	# tay: _arm[0] là bên -X (tay phải của model), _arm[1] bên +X; tư thế nghỉ của model là chữ T nên hạ tay xuống trước
	for i in 2:
		var s := "r" if i == 0 else "l"
		var down := Basis(Vector3.BACK, (PI * 0.5 - 0.08) * (1.0 if i == 0 else -1.0))
		var arm_b := torso_b * _arm[i].transform.basis
		var fore_b := arm_b * _fore[i].transform.basis
		_set_global("upperarm_" + s, arm_b * down * r.call("upperarm_" + s), g)
		# xoắn cẳng tay cho lòng bàn tay úp vào đùi
		var twist := Basis(Vector3.UP, palm_twist * (1.0 if i == 0 else -1.0))
		_set_global("lowerarm_" + s, fore_b * twist * down * r.call("lowerarm_" + s), g)
		_set_global("hand_" + s, fore_b * twist * down * r.call("hand_" + s), g)
		var leg_b := hips_b * _leg[i].transform.basis
		var shin_b := leg_b * _shin[i].transform.basis
		_set_global("thigh_" + s, leg_b * r.call("thigh_" + s), g)
		_set_global("calf_" + s, shin_b * r.call("calf_" + s), g)
		_set_global("foot_" + s, shin_b * r.call("foot_" + s), g)
	# hông lên xuống (ngồi, nhún bước)
	var pb: int = _bi.pelvis
	var root_b: Basis = (_rest[_skel.get_bone_parent(pb)] as Transform3D).basis
	_skel.set_bone_pose_position(pb, _skel.get_bone_rest(pb).origin + root_b.inverse() * Vector3(0, _hips.position.y - 0.95, 0))
