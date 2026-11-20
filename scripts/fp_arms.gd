class_name FPArms
extends Node3D
## Hai cánh tay ở góc nhìn thứ nhất dùng model người thật (Quaternius, CC0) có khung xương.
## Cả thân người gắn sau camera (đầu nằm sau ống kính nên không thấy); mỗi khung hình giải IK hai khớp
## (vai → khuỷu → cổ tay) để bàn tay tới đúng điểm cầm "Grip" do player.gd tính (vung tay, nhún bước, cầm đèn...),
## xoay bàn tay theo trục cán đang cầm rồi gập từng đốt ngón quanh cán.

const MODEL := "res://assets/models/hero/Superhero_Male_FullBody.gltf"
const EYE := Vector3(0.0, 1.69, 0.06)      # vị trí mắt trên model (đơn vị model)
const BACK := 0.14                          # đẩy thân ra sau camera một chút
## Dời khớp vai lên trước / lên trên (toạ độ khung xương) cho tay vươn tới chỗ cầm như các game FPS; thân vẫn nằm sau camera.
var shoulder_shift := Vector3(0.0, 0.02, 0.3)          # đã duyệt (phương án A)
## model cơ bắp có tay ngắn hơn người thường: kéo dài xương cẳng tay / bàn tay để khuỷu gập tự nhiên khi cầm đồ
var arm_scale := 1.0
## góc nhìn riêng của lớp tay (hẹp hơn góc nhìn chính như các game FPS: tay ở gần mà vẫn đủ to)
var view_fov := 50.0

var skel: Skeleton3D
var body_mesh: MeshInstance3D
var _model: Node3D
var _b := {}                 # tên xương -> chỉ số
var _rest_g := {}            # chỉ số -> Transform3D (tư thế nghỉ, toạ độ khung xương)
var _sides := {}             # "r"/"l" -> {upper, lower, hand, clav, l1, l2, fingers: [[idx, sign, k]], thumb: [...]}
## tay nào đang hiện và đang nắm (0 = xoè, 1 = nắm chặt)
var show := {"r": true, "l": false}
var grip_amt := {"r": 0.85, "l": 0.85}
var thumb_fold_sign := -1.0
## Vẽ tay ở lớp riêng (camera riêng, đè lên màn hình) như "viewmodel" của các game FPS: không bị bộ lọc vẽ tay
## làm nhoè / viền mực / đậm màu, không chui vào tường. Tắt đi khi cần nhìn tay từ camera khác (cảnh thử).
var use_overlay := true
const LAYER := 1 << 19
var _vp: SubViewport
var _vcam: Camera3D
var _venv: Environment
var _main_cam: Camera3D
var _fill: DirectionalLight3D
var flash_light: SpotLight3D
## Tay đơn giản (đã duyệt: 4 ngón dính liền + ngón cái, tay trần) thay cho model có khung xương.
var simple := true
var _sh := {}               # "r"/"l" -> MeshInstance3D
var _sh_mesh := {}          # "r_hold" / "r_fist" / ... -> ArrayMesh
var _sleeve := Color(0.29, 0.32, 0.21)


func _setup_simple() -> void:
	for s: String in ["r", "l"]:
		var mi := MeshInstance3D.new()
		mi.layers = LAYER
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 0.3
		mi.visible = false
		add_child(mi)
		_sh[s] = mi
	set_shirt(Color("e9e4d8"))
	if use_overlay:
		_setup_overlay.call_deferred()


func _simple_mesh(s: String, g: String) -> ArrayMesh:
	var key := s + "_" + g
	if not _sh_mesh.has(key):
		_sh_mesh[key] = SimpleHand.make_mesh("mitt", g, 1.0 if s == "r" else -1.0, _sleeve)
	return _sh_mesh[key]


func _ready() -> void:
	if simple:
		_setup_simple()
		return
	_model = (load(MODEL) as PackedScene).instantiate()
	add_child(_model)
	# quay mặt model về -Z (hướng camera nhìn), mắt ngay sau ống kính
	_model.rotation.y = PI
	_model.position = Vector3(0.0, -EYE.y, EYE.z + BACK)
	skel = _model.find_children("*", "Skeleton3D", true, false)[0]
	for mi: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 0.5
		if mi.name == "SuperHero_Male":
			body_mesh = mi
		else:
			mi.visible = false             # mắt, lông mày: không cần
	# tay áo dài tới cổ tay, vải bám theo hình cánh tay (cùng cách tô vùng quần áo với HeroHumanoid)
	var prep := HeroHumanoid._prepare(MODEL, "mid")
	body_mesh.mesh = prep.mesh
	body_mesh.material_override = prep.mat
	# phong cách như các game FPS cách điệu: da trơn mịn, găng hở ngón tối màu có miếng đệm mu bàn tay
	body_mesh.set_instance_shader_parameter("smooth_skin", 1.0)
	body_mesh.set_instance_shader_parameter("skin_flat", Color(0.8, 0.56, 0.4))
	body_mesh.set_instance_shader_parameter("glove_on", 0.0)       # tay trần (đã duyệt)
	body_mesh.set_instance_shader_parameter("pants_color", Color(0.2, 0.22, 0.26))
	body_mesh.layers = LAYER
	for i in skel.get_bone_count():
		_b[skel.get_bone_name(i)] = i
		_rest_g[i] = skel.get_bone_global_rest(i)
	# thu nhỏ đầu, cổ, chân về 0 để không bao giờ lọt vào khung hình
	for n: String in ["Head", "neck_01", "thigh_l", "thigh_r"]:
		skel.set_bone_pose_scale(_b[n], Vector3.ONE * 0.001)
	for s2: String in ["r", "l"]:
		var cl: int = _b["clavicle_" + s2]
		var parent_g: Basis = (_rest_g[skel.get_bone_parent(cl)] as Transform3D).basis
		skel.set_bone_pose_position(cl, skel.get_bone_rest(cl).origin + parent_g.inverse() * shoulder_shift)
	for s: String in ["r", "l"]:
		var up: int = _b["upperarm_" + s]
		var lo: int = _b["lowerarm_" + s]
		var ha: int = _b["hand_" + s]
		var d := {"clav": _b["clavicle_" + s], "upper": up, "lower": lo, "hand": ha,
			"l1": (_rest_g[lo] as Transform3D).origin.distance_to((_rest_g[up] as Transform3D).origin) * arm_scale,
			"l2": (_rest_g[ha] as Transform3D).origin.distance_to((_rest_g[lo] as Transform3D).origin) * arm_scale,
			"fingers": [], "thumb": []}
		for f: String in ["index", "middle", "ring", "pinky"]:
			for j in 3:
				var bi: int = _b["%s_0%d_%s" % [f, j + 1, s]]
				d.fingers.append([bi, _curl_sign(bi), [1.0, 1.15, 0.85][j] * (1.0 + 0.06 * ["index", "middle", "ring", "pinky"].find(f))])
		for j2 in 3:
			var ti: int = _b["thumb_0%d_%s" % [j2 + 1, s]]
			d.thumb.append([ti, _curl_sign(ti), [0.25, 0.55, 0.6][j2]])
		_sides[s] = d
		skel.set_bone_pose_position(lo, skel.get_bone_rest(lo).origin * arm_scale)
		skel.set_bone_pose_position(ha, skel.get_bone_rest(ha).origin * arm_scale)
	# ống tay áo khoác tạm bỏ (chưa duyệt kiểu tay áo)
	set_shirt(Color("e9e4d8"))
	if use_overlay:
		_setup_overlay.call_deferred()


## Gập quanh trục X của xương theo chiều nào thì đầu ngón đi về phía lòng bàn tay (lòng bàn tay úp xuống ở tư thế T).
func _curl_sign(bi: int) -> float:
	var rg: Transform3D = _rest_g[bi]
	var along := rg.basis.y * 0.03
	var axis := rg.basis.x.normalized()
	var plus := Basis(axis, 0.6) * along
	var minus := Basis(axis, -0.6) * along
	return 1.0 if plus.y < minus.y else -1.0


var _jacket_mat: StandardMaterial3D
var _jacket_in: StandardMaterial3D


## Ống tay áo khoác dày: một ống vải có nếp gấp (dựng bằng SurfaceTool), mép tay áo cuộn tròn, gắn theo xương cẳng tay.
func _make_jacket_sleeves() -> void:
	_jacket_mat = StandardMaterial3D.new()
	_jacket_mat.roughness = 0.92
	_jacket_mat.cull_mode = BaseMaterial3D.CULL_BACK
	_jacket_in = StandardMaterial3D.new()
	_jacket_in.roughness = 1.0
	_jacket_in.cull_mode = BaseMaterial3D.CULL_FRONT          # mặt trong ống tay áo, tối hơn
	for s: String in ["r", "l"]:
		var d: Dictionary = _sides[s]
		var att := BoneAttachment3D.new()
		att.bone_name = "lowerarm_" + s
		skel.add_child(att)
		var l2: float = d.l2
		var mesh := _sleeve_mesh(l2 * 0.62, 1.0 if s == "r" else -1.0)
		for pass_mat: Material in [_jacket_mat, _jacket_in]:
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.material_override = pass_mat
			mi.layers = LAYER
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.position = Vector3(0, -0.06, 0)
			att.add_child(mi)


## Ống vải dọc trục Y của xương (từ khuỷu tới gần giữa cẳng tay), mặt cắt hơi dẹt, có các nếp gấp lượn và mép cuộn.
func _sleeve_mesh(length: float, side: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 22
	var segs := 28
	var pts: Array = []
	for i in rings + 1:
		var t := float(i) / rings
		var y := t * length
		var base := lerpf(0.074, 0.066, t)
		if t > 0.88:
			base += (t - 0.88) / 0.12 * 0.008          # mép tay áo loe nhẹ
		var row: Array = []
		for j in segs + 1:
			var a := float(j) / segs * TAU
			var fold := 0.0
			fold += 0.07 * sin(a * 3.0 + t * 9.0 * side) * smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(0.85, 1.0, t))
			fold += 0.05 * sin(a * 5.0 - t * 14.0) * sin(t * PI)
			var r := base * (1.0 + fold)
			row.append(Vector3(cos(a) * r, y, sin(a) * r * 0.86))
		pts.append(row)
	for i in rings:
		for j in segs:
			var p00: Vector3 = pts[i][j]
			var p01: Vector3 = pts[i][j + 1]
			var p10: Vector3 = pts[i + 1][j]
			var p11: Vector3 = pts[i + 1][j + 1]
			for p: Vector3 in [p00, p10, p11, p00, p11, p01]:
				st.set_uv(Vector2(0, 0))
				st.add_vertex(p)
	# mép cuộn
	var cy := length
	for j in segs:
		var a0 := float(j) / segs * TAU
		var a1 := float(j + 1) / segs * TAU
		for k in 6:
			var b0 := float(k) / 6.0 * TAU
			var b1 := float(k + 1) / 6.0 * TAU
			var q := func(a: float, b: float) -> Vector3:
				var rr := 0.082 + cos(b) * 0.007
				return Vector3(cos(a) * rr, cy + sin(b) * 0.007, sin(a) * rr * 0.86)
			for p2: Vector3 in [q.call(a0, b0), q.call(a0, b1), q.call(a1, b1), q.call(a0, b0), q.call(a1, b1), q.call(a1, b0)]:
				st.add_vertex(p2)
	st.generate_normals()
	return st.commit()


func set_shirt(c: Color) -> void:
	# áo khoác: theo tông màu áo đang mặc nhưng trầm, tối (như áo khoác dã ngoại); phần ống tay bó bên trong cùng màu
	var j := c.lerp(Color(0.16, 0.17, 0.18), 0.6)
	if simple:
		# ống tay áo khoác (màu theo áo đang mặc, trầm xuống); dựng lại mesh khi đổi áo
		var nj := j.lerp(Color(0.29, 0.32, 0.21), 0.35)
		if nj != _sleeve or _sh_mesh.is_empty():
			_sleeve = nj
			_sh_mesh.clear()
			for s: String in _sh:
				(_sh[s] as MeshInstance3D).mesh = null
		return
	if body_mesh:
		body_mesh.set_instance_shader_parameter("shirt_color", j.darkened(0.1))
	if _jacket_mat:
		_jacket_mat.albedo_color = j
		_jacket_in.albedo_color = j.darkened(0.6)


## Lớp vẽ riêng cho tay: SubViewport dùng chung thế giới 3D (cùng ánh trăng, đèn pin, đèn trong hầm) nhưng
## camera chỉ thấy lớp của tay; nền trong suốt, đè lên khung hình chính (dưới HUD và kính nhìn đêm).
func _setup_overlay() -> void:
	_main_cam = get_parent() as Camera3D
	if _main_cam == null:
		return
	_main_cam.cull_mask &= ~LAYER
	var cl := CanvasLayer.new()
	cl.layer = -1
	add_child(cl)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(svc)
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.world_3d = get_viewport().world_3d
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.handle_input_locally = false
	svc.add_child(_vp)
	_vcam = Camera3D.new()
	_vcam.cull_mask = LAYER
	_vcam.near = 0.02
	_vcam.far = 20.0
	_venv = Environment.new()
	_venv.background_mode = Environment.BG_CLEAR_COLOR
	_venv.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_venv.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	_venv.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_vcam.environment = _venv
	_vp.add_child(_vcam)
	_vcam.current = true
	# nguồn sáng phụ chỉ chiếu lên lớp tay (ban đêm tay không bị đen kịt; đèn pin bật thì tay sáng hơn như ánh dội lại)
	_fill = DirectionalLight3D.new()
	_fill.light_cull_mask = LAYER
	_fill.layers = LAYER
	_fill.shadow_enabled = false
	_fill.light_color = Color(0.95, 0.9, 0.85)
	add_child(_fill)
	_fill.rotation = Vector3(-0.7, 0.35, 0.0)


var _light_scan := 0.0


## Camera của lớp tay chỉ "thấy" lớp tay, mà đèn cũng bị lọc theo lớp: gắn thêm lớp tay cho mọi nguồn sáng
## (trăng, đèn pin, đèn trong hầm...) để chúng vẫn chiếu lên tay. Quét lại định kỳ cho đèn mới tạo.
func _tag_lights() -> void:
	for l: Light3D in get_tree().root.find_children("*", "Light3D", true, false):
		l.layers |= LAYER


func _process(delta: float) -> void:
	if _vcam == null:
		return
	_light_scan -= delta
	if _light_scan <= 0.0:
		_light_scan = 1.5
		_tag_lights()
	var svc := _vp.get_parent() as SubViewportContainer
	svc.visible = visible and _main_cam.current           # cắt cảnh / camera khác: không vẽ tay
	var vs := get_viewport().get_visible_rect().size
	if svc.size != vs:
		svc.position = Vector2.ZERO
		svc.size = vs
		_vp.size = Vector2i(vs)
	_vcam.global_transform = _main_cam.global_transform
	_vcam.fov = view_fov
	var we: Environment = _main_cam.get_world_3d().environment
	if we:
		_venv.ambient_light_color = we.ambient_light_color
		_venv.ambient_light_energy = maxf(we.ambient_light_energy * 0.35, 0.08)     # ít ánh sáng đều hơn để thấy khối tay
		var dark := clampf(1.0 - we.ambient_light_energy * 2.0, 0.0, 1.0)
		var lit: bool = flash_light != null and flash_light.light_energy > 0.0
		_fill.light_energy = lerpf(0.0, 0.25, dark) + (0.35 * dark if lit else 0.0)
		_venv.tonemap_exposure = we.tonemap_exposure
		_venv.tonemap_mode = we.tonemap_mode
		_venv.tonemap_white = we.tonemap_white


## Xoay ngắn nhất đưa vector a về vector b.
static func _arc(a: Vector3, b: Vector3) -> Quaternion:
	var an := a.normalized()
	var bn := b.normalized()
	var d := an.dot(bn)
	if d > 0.99999:
		return Quaternion.IDENTITY
	if d < -0.99999:
		var ax := an.cross(Vector3.UP)
		if ax.length() < 0.01:
			ax = an.cross(Vector3.RIGHT)
		return Quaternion(ax.normalized(), PI)
	return Quaternion(an.cross(bn).normalized(), acos(clampf(d, -1.0, 1.0)))


## Đặt bàn tay `s` ("r"/"l") theo điểm nắm `grip` (Node3D): gốc = tâm nắm tay, trục Y = trục cán đang cầm,
## trục -X (tay phải) / +X (tay trái) = hướng lòng bàn tay áp vào cán.
func solve(s: String, grip: Node3D, pole_cam: Vector3) -> void:
	if simple:
		# bàn tay dựng sẵn: gốc = tâm vật cầm (lệch 4cm khỏi điểm nắm như đèn pin), trục Y = trục cán
		var mi: MeshInstance3D = _sh[s]
		var g := "fist" if grip.has_meta("fist_thumb") else "hold"
		var m := _simple_mesh(s, g)
		if mi.mesh != m:
			mi.mesh = m
		var gt := grip.global_transform.orthonormalized()
		mi.global_transform = Transform3D(gt.basis, gt * Vector3(0.04, 0.0, 0.0))
		mi.visible = true
		return
	var d: Dictionary = _sides[s]
	var to_sk := skel.global_transform.affine_inverse()
	var g := grip.global_transform
	var axis := (to_sk.basis * g.basis.y).normalized()                     # trục cán
	var n := (to_sk.basis * (g.basis.x * (-1.0 if s == "r" else 1.0))).normalized()   # pháp tuyến lòng bàn tay → cán
	# nắm "úp" kiểu Phasmophobia / cảnh sát: ngón cái quay về đuôi đèn, các ngón vắt qua mặt trên thân đèn,
	# cẳng tay đi lên từ phía dưới; cổ tay gần như thẳng nên da cẳng tay không bị xoắn
	if grip.get_meta("reverse", false):
		axis = -axis
	# xoay bàn tay quanh cán (roll) và nắm chéo cán như tay thật (tilt: xương bàn tay ngả về phía đầu cán)
	var roll: float = grip.get_meta("roll", 0.0)
	var tilt: float = grip.get_meta("tilt", 0.0)
	if roll != 0.0:
		n = n.rotated(axis, roll * (1.0 if s == "r" else -1.0))
	# hướng duỗi của các ngón (trước khi gập): vuông góc với cán và pháp tuyến
	var f := (n.cross(axis) if s == "r" else axis.cross(n)).normalized()
	if tilt != 0.0:
		f = (f + axis * tilt).normalized()
		n = (n - f * n.dot(f)).normalized()
	var center := to_sk * g.origin
	# cổ tay: lùi khỏi tâm nắm tay theo chiều ngón, lệch ra phía mu bàn tay
	var wrist := center - f * 0.082 - n * 0.032 - axis * (0.012 if tilt == 0.0 else 0.0)
	var a: Vector3 = (_rest_g[d.upper] as Transform3D).origin + shoulder_shift
	var l1: float = d.l1
	var l2: float = d.l2
	var dv := wrist - a
	var dist := clampf(dv.length(), 0.05, (l1 + l2) * 0.999)
	var dn := dv.normalized()
	var pole := to_sk * (global_transform * pole_cam) - a
	var pp := (pole - dn * pole.dot(dn)).normalized()
	var ca := (l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist)
	var e := a + dn * (l1 * ca) + pp * (l1 * sqrt(maxf(0.0, 1.0 - ca * ca)))
	var w := a + dn * dist
	var rg_up: Transform3D = _rest_g[d.upper]
	var rg_lo: Transform3D = _rest_g[d.lower]
	var rg_ha: Transform3D = _rest_g[d.hand]
	var q1 := _arc(rg_lo.origin - rg_up.origin, e - a)
	var b_up := Basis(q1) * rg_up.basis
	var dir_lo := Basis(q1) * (rg_ha.origin - rg_lo.origin)
	var q2 := _arc(dir_lo, w - e)
	var b_lo := Basis(q2 * q1) * rg_lo.basis
	# bàn tay: Y xương = chiều ngón, X = ngược pháp tuyến lòng tay (tay phải) / cùng chiều (tay trái)
	var hx := -n if s == "r" else n
	var b_ha := Basis(hx, f, hx.cross(f)).orthonormalized()
	# cẳng tay xoắn theo bàn tay cho cổ tay khỏi bị vặn
	var twist_axis := (w - e).normalized()
	var want := b_ha.x - twist_axis * b_ha.x.dot(twist_axis)
	var have := b_lo.x - twist_axis * b_lo.x.dot(twist_axis)
	if want.length() > 0.01 and have.length() > 0.01:
		b_lo = Basis(_arc(have, want) ) * b_lo
	var clav_g: Basis = (_rest_g[d.clav] as Transform3D).basis
	skel.set_bone_pose_rotation(d.upper, Quaternion((clav_g.inverse() * b_up).orthonormalized()))
	skel.set_bone_pose_rotation(d.lower, Quaternion((b_up.inverse() * b_lo).orthonormalized()))
	skel.set_bone_pose_rotation(d.hand, Quaternion((b_lo.inverse() * b_ha).orthonormalized()))
	# ngón tay gập quanh cán
	var amt: float = grip_amt[s]
	for fd: Array in d.fingers:
		var bi: int = fd[0]
		skel.set_bone_pose_rotation(bi, skel.get_bone_rest(bi).basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, float(fd[1]) * amt * 1.25 * float(fd[2])))
	# ngón cái: cầm đồ thì duỗi dọc theo cán; tay không (amt > 1) thì gập ngang qua các ngón thành nắm đấm
	# cầm đồ: ngón cái ép dọc theo thân đồ vật (gập nhẹ); tay không: gập hẳn ngang qua các ngón
	var fold := clampf((amt - 1.0) * 6.0, 0.0, 1.0) if amt > 1.0 else float(grip.get_meta("thumb", 0.35))
	if grip.has_meta("fist_thumb"):
		fold = float(grip.get_meta("fist_thumb"))
	for td: Array in d.thumb:
		var ti: int = td[0]
		var q := Quaternion(Vector3.RIGHT, float(td[1]) * minf(amt, 1.0) * float(td[2]) * float(grip.get_meta("thumb_curl", 1.0)))
		if fold > 0.0:
			q = q * Quaternion(Vector3.BACK, thumb_fold_sign * fold * [0.9, 0.5, 0.5][d.thumb.find(td)] * (1.0 if s == "r" else -1.0))
		skel.set_bone_pose_rotation(ti, skel.get_bone_rest(ti).basis.get_rotation_quaternion() * q)


## Thả tay về tư thế nghỉ (tư thế T: cánh tay dang ngang sau mặt phẳng camera, không lọt vào khung hình).
func relax(s: String) -> void:
	if simple:
		(_sh[s] as MeshInstance3D).visible = false
		return
	var d: Dictionary = _sides[s]
	for bi: int in [d.upper, d.lower, d.hand]:
		skel.set_bone_pose_rotation(bi, skel.get_bone_rest(bi).basis.get_rotation_quaternion())
