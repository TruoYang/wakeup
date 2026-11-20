class_name LowPolyHumanoid
extends Humanoid
## Hình người low-poly góc cạnh (mặt cắt phẳng như ảnh mẫu đã duyệt), dựng bằng code từ ít mặt rồi làm phẳng pháp tuyến.
## Giữ nguyên khung khớp của Humanoid (_hips, _torso, _head, _arm, _fore, _leg, _shin) nên dùng lại mọi hoạt ảnh:
## đi, chạy, ngồi, bơi, đánh, ngã.
## Dùng cho gia đình (Mai, bé Na), người chơi (cả người chơi khác trong co-op), kẻ cướp, đồng nghiệp, người bị thương.
## Tham số: child (đầu to, chân ngắn), female (vai hẹp, eo thon), hair_style ("long" / "short" / "hood"),
## sleeves ("short" / "long"), shoe_color, sole_color, roll_cuffs (xắn gấu quần), hem_color (viền áo; mặc định sẫm hơn áo).

var child := false
var female := false
var sleeves := "short"
var shoe_color := Color("c8323a")
var sole_color := Color("eeeae4")
var roll_cuffs := true
var hem_color := Color(0, 0, 0, 0)
var hair_color := Color("16151a")
var face: Node3D                # điểm gắn trên mặt (khăn bịt mặt...)
var hand_att: Node3D            # điểm gắn ở bàn tay phải (gậy, ống...)

static var _facets: Dictionary = {}


## Mesh góc cạnh, dùng chung giữa mọi bản sao.
static func _fmesh(shape: String, seg: int) -> Mesh:
	var key := "%s|%d" % [shape, seg]
	if _facets.has(key):
		return _facets[key]
	var m: PrimitiveMesh
	match shape:
		"sphere":
			var s := SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			s.radial_segments = seg
			s.rings = maxi(3, seg / 2)
			m = s
		"cyl":
			var c := CylinderMesh.new()
			c.top_radius = 0.5
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = seg
			c.rings = 1
			m = c
		"taper":                # trụ thon dần xuống dưới (bắp tay, đùi)
			var t := CylinderMesh.new()
			t.top_radius = 0.5
			t.bottom_radius = 0.38
			t.height = 1.0
			t.radial_segments = seg
			t.rings = 1
			m = t
		_:
			var b := BoxMesh.new()
			b.size = Vector3.ONE
			m = b
	var f := MonsterMesh.facet(m)
	_facets[key] = f
	return f


static func _flat(color: Color) -> StandardMaterial3D:
	var key := "lp" + color.to_html()
	if not _mats.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.9
		_mats[key] = mat
	return _mats[key]


func _lp(parent: Node3D, shape: String, seg: int, size: Vector3, pos: Vector3, color: Color, rot := Vector3.ZERO, detail := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _fmesh(shape, seg)
	mi.scale = size
	mi.position = pos
	mi.rotation = rot
	mi.material_override = _flat(color)
	mi.visibility_range_end = DETAIL_FAR if detail else BODY_FAR
	if detail:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Giữ tương thích với HeroHumanoid (kẻ cướp gọi grip để nắm gậy): hình low-poly không có ngón rời nên không cần làm gì.
func grip(_s: String) -> void:
	pass


func setup(shirt_color: Color, pants_color: Color, skin_color := Color("e2b48c")) -> void:
	shirt = shirt_color
	pants = pants_color
	skin = skin_color
	for c in get_children():
		c.queue_free()
	_arm.clear()
	_fore.clear()
	_leg.clear()
	_shin.clear()
	var hem := hem_color if hem_color.a > 0.0 else shirt.darkened(0.2)
	var cuff := pants.lightened(0.12)
	var hair_c := hair_color
	var hs_kind := hair_style if hair_style != "" else ("long" if female else "short")
	# tỉ lệ: trẻ con đầu rất to, chân ngắn; người lớn đầu hơi to (stylized) cho đồng bộ với bé Na
	var hk := 1.8 if child else 1.22      # cỡ đầu
	var tk := 0.82 if child else 1.0      # chiều cao thân
	var wk := 1.0 if child else (0.9 if female else 1.08)    # bề ngang vai
	var lk := 0.66 if child else 1.0      # chiều dài chân
	hip_h = 0.95 * lk
	# --- hông
	_hips = _pivot(self, Vector3(0, hip_h, 0))
	_lp(_hips, "cyl", 7, Vector3(0.38 * wk * (1.06 if female else 1.0), 0.2, 0.24), Vector3(0, 0.0, 0), pants)
	# --- thân: áo, gấu áo, vai, cổ áo
	_torso = _pivot(_hips, Vector3(0, 0.08, 0))
	_lp(_torso, "cyl", 7, Vector3(0.36 * wk, 0.1, 0.23), Vector3(0, 0.0, 0), hem)                 # gấu áo
	if female and not child:
		_lp(_torso, "cyl", 7, Vector3(0.31 * wk, 0.22, 0.2), Vector3(0, 0.13, 0), shirt)             # eo thon
		_lp(_torso, "cyl", 7, Vector3(0.35 * wk, 0.2, 0.22), Vector3(0, 0.33, 0), shirt)
		_lp(_torso, "sphere", 6, Vector3(0.3 * wk, 0.13, 0.12), Vector3(0, 0.34, 0.07), shirt)     # ngực
	else:
		_lp(_torso, "cyl", 7, Vector3(0.35 * wk, 0.42 * tk, 0.22), Vector3(0, 0.23 * tk, 0), shirt)
	_lp(_torso, "sphere", 7, Vector3(0.4 * wk, 0.2, 0.24), Vector3(0, 0.44 * tk, 0), shirt)       # vai
	_lp(_torso, "cyl", 7, Vector3(0.13, 0.04, 0.13), Vector3(0, 0.53 * tk, 0.0), hem)              # cổ áo
	# --- đầu
	_head = _pivot(_torso, Vector3(0, 0.54 * tk, 0))
	_lp(_head, "cyl", 6, Vector3(0.09, 0.1, 0.09), Vector3(0, 0.02, 0), skin)                       # cổ
	var hs := Vector3(0.36, 0.38, 0.34) * hk * 0.62
	if not child:
		hs.y *= 1.06              # mặt người lớn dài hơn chút
	var hc := Vector3(0, 0.07 + hs.y * 0.5, 0)
	_lp(_head, "sphere", 8, hs, hc, skin)                                                           # sọ
	_lp(_head, "sphere", 7, Vector3(hs.x * 0.82, hs.y * 0.5, hs.z * 0.82), hc + Vector3(0, -hs.y * 0.2, hs.z * 0.06), skin)   # má, cằm
	var fz := hs.z * 0.47
	var ek := hk if child else hk * 0.9
	var brow_h := 0.01 if female or child else 0.014
	for sd: float in [-1.0, 1.0]:
		_lp(_head, "sphere", 5, Vector3(0.04, 0.07, 0.04) * hk, hc + Vector3(sd * hs.x * 0.5, -0.01, 0.0), skin.darkened(0.06))                      # tai
		_lp(_head, "box", 0, Vector3(0.026, 0.02, 0.02) * ek, hc + Vector3(sd * hs.x * 0.2, -0.005, fz), Color("1a1412"), Vector3.ZERO, true)        # mắt
		_lp(_head, "box", 0, Vector3(0.045, brow_h, 0.02) * ek, hc + Vector3(sd * hs.x * 0.21, hs.y * 0.11, fz - 0.004), hair_c, Vector3(0, 0, -sd * 0.12), true)  # lông mày
	_lp(_head, "box", 0, Vector3(0.026, 0.04, 0.03) * ek, hc + Vector3(0, -hs.y * 0.08, fz + 0.01), skin.darkened(0.05), Vector3.ZERO, true)  # mũi
	var lip := Color("b4565a") if female and not child else skin.darkened(0.3)
	_lp(_head, "box", 0, Vector3(0.05, 0.012, 0.02) * ek, hc + Vector3(0, -hs.y * 0.24, fz - 0.01), lip, Vector3.ZERO, true)    # miệng
	face = _pivot(_head, hc + Vector3(0, -hs.y * 0.18, fz * 0.55))
	match hs_kind:
		"long":
			# tóc dài: chỏm, mái rẽ giữa, hai mảng ôm má, mảng dài sau lưng
			_lp(_head, "sphere", 10, hs * Vector3(1.12, 0.78, 1.12), hc + Vector3(0, hs.y * 0.16, -hs.z * 0.06), hair_c)
			for sd2: float in [-1.0, 1.0]:
				_lp(_head, "box", 0, Vector3(hs.x * 0.5, hs.y * 0.16, 0.06), hc + Vector3(sd2 * hs.x * 0.24, hs.y * 0.3, fz * 0.86), hair_c, Vector3(0.15, 0, sd2 * 0.12))   # mái
				_lp(_head, "box", 0, Vector3(0.07, hs.y * 1.2, hs.z * 0.75), hc + Vector3(sd2 * hs.x * 0.52, -hs.y * 0.25, -hs.z * 0.08), hair_c, Vector3(0, 0, sd2 * 0.05))  # ôm hai bên má
			_lp(_head, "box", 0, Vector3(hs.x * 1.12, hs.y * (1.9 if child else 1.6), 0.09), hc + Vector3(0, -hs.y * 0.5, -hs.z * 0.42), hair_c, Vector3(-0.1, 0, 0))     # tóc dài sau lưng
		"hood":
			# mũ trùm của áo hoodie (kẻ cướp)
			_lp(_head, "sphere", 8, hs * Vector3(1.24, 1.1, 1.22), hc + Vector3(0, hs.y * 0.08, -hs.z * 0.12), shirt.darkened(0.08))
			_lp(_head, "box", 0, Vector3(hs.x * 1.2, hs.y * 0.9, 0.12), hc + Vector3(0, -hs.y * 0.45, -hs.z * 0.5), shirt.darkened(0.08))   # phần mũ rủ sau gáy
		_:
			# tóc ngắn: chỏm gọn, mái hất, gáy và tóc mai cắt ngắn
			_lp(_head, "sphere", 9, hs * Vector3(1.08, 0.7, 1.1), hc + Vector3(0, hs.y * 0.2, -hs.z * 0.05), hair_c)
			_lp(_head, "box", 0, Vector3(hs.x * 0.85, hs.y * 0.14, 0.07), hc + Vector3(hs.x * 0.06, hs.y * 0.36, fz * 0.8), hair_c, Vector3(0.35, 0, -0.12))   # mái
			_lp(_head, "box", 0, Vector3(hs.x * 0.95, hs.y * 0.45, 0.07), hc + Vector3(0, -hs.y * 0.02, -hs.z * 0.46), hair_c)     # gáy
			for sd3: float in [-1.0, 1.0]:
				_lp(_head, "box", 0, Vector3(0.05, hs.y * 0.3, hs.z * 0.35), hc + Vector3(sd3 * hs.x * 0.51, hs.y * 0.08, -hs.z * 0.05), hair_c)   # tóc mai
	# --- tay
	for side: float in [-1.0, 1.0]:
		var a := _pivot(_torso, Vector3(side * 0.19 * wk, 0.46 * tk, 0))
		var f := _pivot(a, Vector3(0, -0.29, 0))
		if sleeves == "long":
			_lp(a, "taper", 6, Vector3(0.14, 0.32, 0.14), Vector3(0, -0.13, 0), shirt)
			_lp(f, "taper", 6, Vector3(0.11, 0.22, 0.11), Vector3(0, -0.1, 0), shirt)
			_lp(f, "cyl", 6, Vector3(0.105, 0.035, 0.105), Vector3(0, -0.21, 0), hem)               # cổ tay áo
		else:
			_lp(a, "taper", 6, Vector3(0.15, 0.17, 0.15), Vector3(0, -0.07, 0), shirt)              # tay áo
			_lp(a, "cyl", 6, Vector3(0.155, 0.03, 0.155), Vector3(0, -0.16, 0), hem)                # viền tay áo
			_lp(a, "taper", 6, Vector3(0.09, 0.14, 0.09), Vector3(0, -0.22, 0), skin)               # bắp tay trần
			_lp(f, "taper", 6, Vector3(0.085, 0.22, 0.085), Vector3(0, -0.11, 0), skin)
		_lp(f, "box", 0, Vector3(0.05, 0.09, 0.075), Vector3(0, -0.27, 0.0), skin)                   # bàn tay
		_lp(f, "box", 0, Vector3(0.022, 0.05, 0.026), Vector3(-side * 0.025, -0.25, 0.03), skin.darkened(0.04), Vector3(0.5, 0, 0), true)  # ngón cái
		if side > 0.0:
			hand_att = _pivot(f, Vector3(0, -0.28, 0.0))
		_arm.append(a)
		_fore.append(f)
		# --- chân: quần ống đứng, gấu (xắn hoặc không), giày có đế
		var l := _pivot(_hips, Vector3(side * 0.1 * wk, -0.06, 0))
		_lp(l, "taper", 7, Vector3(0.2, 0.44 * lk, 0.2), Vector3(0, -0.2 * lk, 0), pants)
		var sh := _pivot(l, Vector3(0, -0.43 * lk, 0))
		var fy := -(0.52 * lk - 0.06)          # mặt đất, tính từ khớp gối
		_lp(sh, "taper", 7, Vector3(0.18, 0.36 * lk, 0.18), Vector3(0, -0.17 * lk, 0), pants)
		if roll_cuffs:
			_lp(sh, "cyl", 7, Vector3(0.19, 0.07, 0.19), Vector3(0, fy + 0.11, 0), cuff)                # gấu xắn
		_lp(sh, "box", 0, Vector3(0.13, 0.08, 0.24), Vector3(0, fy + 0.055, 0.04), shoe_color)            # thân giày
		_lp(sh, "box", 0, Vector3(0.135, 0.03, 0.25), Vector3(0, fy + 0.015, 0.04), sole_color)           # đế
		_lp(sh, "box", 0, Vector3(0.08, 0.03, 0.05), Vector3(0, fy + 0.07, 0.135), sole_color, Vector3.ZERO, true)   # mũi giày
		_leg.append(l)
		_shin.append(sh)
