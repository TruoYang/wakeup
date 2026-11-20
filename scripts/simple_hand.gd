class_name SimpleHand
extends Node3D
## Bàn tay góc nhìn thứ nhất kiểu hoạt hình, dựng bằng khối tròn, tư thế nắm cố định (không có khung xương):
## dễ đặt, không bao giờ vặn vẹo. Toạ độ: gốc = tâm vật đang cầm, trục Y = trục cán / thân đèn,
## trục Z = hướng từ cổ tay lên khớp ngón (mu bàn tay hướng +X). Cẳng tay chạy từ cổ tay xuống dưới theo -Z.
## style: "mitten" = găng liền ngón (4 ngón là một khối), "cartoon" = 4 ngón mập riêng từng ngón.
## grip: "hold" = nắm quanh cán (chừa lỗ cho cán), "fist" = nắm đấm chặt.

var style := "mitten"
var grip := "hold"
var side := 1.0                 # 1 = tay phải, -1 = tay trái (lật theo trục X)
var skin := Color(0.86, 0.64, 0.48)
var glove := Color(0.18, 0.18, 0.2)
var sleeve := Color(0.3, 0.33, 0.36)

var _mats := {}


func _ready() -> void:
	build()


func _mat(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.75
		_mats[key] = m
	return _mats[key]


func _blob(pos: Vector3, size: Vector3, c: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 18
	s.rings = 10
	mi.mesh = s
	mi.material_override = _mat(c)
	mi.position = Vector3(pos.x * side, pos.y, pos.z)
	mi.rotation = Vector3(rot.x, rot.y * side, rot.z * side)
	mi.scale = size
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _cap(a: Vector3, b: Vector3, r: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	var aa := Vector3(a.x * side, a.y, a.z)
	var bb := Vector3(b.x * side, b.y, b.z)
	cm.radius = r
	cm.height = aa.distance_to(bb) + r * 2.0
	cm.radial_segments = 14
	cm.rings = 4
	mi.mesh = cm
	mi.material_override = _mat(c)
	add_child(mi)
	mi.position = (aa + bb) * 0.5
	var up := (bb - aa).normalized()
	var ref := Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := up.cross(ref).normalized()
	mi.basis = Basis(x, up, x.cross(up))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func build() -> void:
	if style == "tactical":
		build_tactical()
		return
	if style == "mitt" or style == "mittg":
		glove_on = style == "mittg"
		build_mitt()
		return
	for ch in get_children():
		ch.queue_free()
	# "cartoon" = tay trần; "glove" = găng kín; "fingerless" = găng hở ngón (lòng bàn tay găng, ngón trần)
	var hand := glove if style in ["mitten", "glove", "fingerless"] else skin
	var fing := skin if style == "fingerless" else hand
	var hole := 0.026 if grip == "hold" else 0.0       # bán kính chỗ trống cho cán
	# lòng / mu bàn tay: khối dẹt dựng đứng phía +X của cán, từ cổ tay lên tới khớp ngón
	_blob(Vector3(hole + 0.024, 0.0, -0.038), Vector3(0.05, 0.105, 0.115), hand)
	# cổ tay + ống tay áo + cẳng tay (chạy xuống dưới, hơi chéo ra phía +X)
	_cap(Vector3(hole + 0.02, 0.0, -0.085), Vector3(hole + 0.07, 0.0, -0.36), 0.036, skin if style in ["cartoon", "fingerless"] else glove)
	_cap(Vector3(hole + 0.045, 0.0, -0.2), Vector3(hole + 0.11, 0.0, -0.6), 0.05, sleeve)
	_blob(Vector3(hole + 0.044, 0.0, -0.205), Vector3(0.115, 0.115, 0.04), sleeve.darkened(0.2), Vector3(PI * 0.5 - 0.15, 0, 0))   # mép tay áo
	# các ngón: vòng từ khớp ngón (phía +X, trên) qua đỉnh cán, xuống phía -X (bên kia cán), mũi ngón quặp về dưới
	var r_wrap := hole + 0.018
	if style == "mitten":
		# găng liền ngón: một khối dày uốn cong (nhiều khối tròn chồng khít lên nhau thành một dải mượt)
		for k in 12:
			var a := lerpf(-0.25, PI * 1.05, k / 11.0)        # góc quanh trục Y, 0 = phía +X
			var p := Vector3(cos(a) * r_wrap, 0.0, sin(a) * r_wrap + 0.006)
			_blob(p, Vector3(0.046, 0.1, 0.046), hand)
		# rãnh giữa các ngón (vạch nhạt) để đọc được là bàn tay
		for g in 3:
			var gy := lerpf(0.025, -0.025, g / 2.0)
			_blob(Vector3(r_wrap * 0.6, gy, r_wrap + 0.012), Vector3(0.036, 0.004, 0.02), hand.lightened(0.25))
	else:
		for f in 4:
			var y := lerpf(0.032, -0.034, f / 3.0)
			var r_f := 0.0145 - f * 0.001
			var pts: Array[Vector3] = []
			for k2 in 4:
				var a2 := lerpf(-0.15, PI * (0.95 if f < 3 else 0.85), k2 / 3.0)
				pts.append(Vector3(cos(a2) * r_wrap, y, sin(a2) * r_wrap + 0.008))
			for k3 in 3:
				_cap(pts[k3], pts[k3 + 1], r_f, hand if (style == "fingerless" and k3 == 0) else fing)
			_blob(pts[3] + Vector3(0.002, 0, -0.004), Vector3.ONE * r_f * 2.2, fing)
	# ngón cái: từ gò ngón cái (phía +X, dưới, gần đầu cán +Y) vòng qua phía trước, đè lên các ngón
	# ngón cái: mọc từ gò ngón cái phía dưới cán, vòng ra phía trước rồi gập đè chéo lên mặt các ngón (thấy được)
	var rw2 := hole + 0.018
	var t0 := Vector3(hole * 0.5 + 0.01, 0.036, -0.042)
	var t1 := Vector3(-rw2 - 0.012, 0.03, -0.018)
	var t2 := Vector3(-rw2 - 0.014, 0.006, 0.008)
	var tr := 0.016 if style == "mitten" else 0.013
	_cap(t0, t1, tr, hand)
	_cap(t1, t2, tr * 0.9, fing)
	_blob(t2, Vector3.ONE * tr * 1.9, fing)
	if style == "mitten":
		# đường may găng và mép găng ở cổ tay
		_blob(Vector3(hole + 0.022, 0.0, -0.085), Vector3(0.06, 0.1, 0.03), glove.lightened(0.15))


## Găng tay quân đội dày (style "tactical"): ngón mập, đường may từng đốt, miếng đệm cứng trên khớp ngón và mu bàn tay,
## cổ găng cao có quai dán, ống tay áo khoác dày có nếp gấp. Gọi thay cho build() khi style == "tactical".
func build_tactical() -> void:
	for ch in get_children():
		ch.queue_free()
	var g := glove
	var pad := glove.darkened(0.35)
	var seam := glove.lightened(0.18)
	var hole := 0.026 if grip == "hold" else 0.0
	var r_wrap := hole + 0.021
	# lòng + mu bàn tay dày hơn tay trần
	_blob(Vector3(hole + 0.027, 0.0, -0.04), Vector3(0.062, 0.118, 0.125), g)
	# miếng đệm mu bàn tay (cứng, sẫm) + đệm khớp ngón (dải nổi chạy ngang các khớp)
	_blob(Vector3(hole + 0.056, 0.0, -0.045), Vector3(0.02, 0.085, 0.07), pad)
	for kk in 4:
		var ky := lerpf(0.034, -0.034, kk / 3.0)
		_blob(Vector3(r_wrap * cos(-0.1), ky, r_wrap * sin(-0.1) + 0.012), Vector3(0.026, 0.022, 0.03), pad)
	# 4 ngón dày, mỗi đốt có đường may
	for f in 4:
		var y := lerpf(0.035, -0.037, f / 3.0)
		var r_f := 0.0175 - f * 0.0011
		var pts: Array[Vector3] = []
		for k2 in 4:
			var a2 := lerpf(-0.1, PI * (0.97 if f < 3 else 0.88), k2 / 3.0)
			pts.append(Vector3(cos(a2) * r_wrap, y, sin(a2) * r_wrap + 0.008))
		for k3 in 3:
			_cap(pts[k3], pts[k3 + 1], r_f, g)
			_blob(pts[k3 + 1], Vector3(r_f * 2.15, r_f * 0.5, r_f * 2.15), seam)        # đường may ở khớp
		_blob(pts[3] + Vector3(0.003, 0, -0.004), Vector3.ONE * r_f * 2.3, g)
	# ngón cái dày, có miếng đệm
	var t0 := Vector3(hole * 0.5 + 0.012, 0.04, -0.046)
	var t1 := Vector3(-r_wrap - 0.013, 0.033, -0.02)
	var t2 := Vector3(-r_wrap - 0.016, 0.008, 0.008)
	_cap(t0, t1, 0.018, g)
	_cap(t1, t2, 0.016, g)
	_blob(t2, Vector3.ONE * 0.034, g)
	_blob((t1 + t2) * 0.5 + Vector3(-0.012, 0, 0), Vector3(0.012, 0.024, 0.024), pad)
	# cổ găng cao, loe, có quai dán ngang
	_cap(Vector3(hole + 0.024, 0.0, -0.09), Vector3(hole + 0.05, 0.0, -0.2), 0.043, g)
	_blob(Vector3(hole + 0.04, 0.0, -0.15), Vector3(0.098, 0.098, 0.03), pad, Vector3(PI * 0.5 - 0.2, 0, 0))
	_blob(Vector3(hole + 0.072, 0.0, -0.15), Vector3(0.012, 0.06, 0.03), seam)              # khoá dán
	# ống tay áo khoác dày, có hai nếp gấp và bo tay
	_cap(Vector3(hole + 0.05, 0.0, -0.2), Vector3(hole + 0.13, 0.0, -0.62), 0.058, sleeve)
	_blob(Vector3(hole + 0.052, 0.0, -0.205), Vector3(0.13, 0.13, 0.045), sleeve.darkened(0.25), Vector3(PI * 0.5 - 0.18, 0, 0))
	for fo in 2:
		_blob(Vector3(hole + 0.07 + fo * 0.02, 0.0, -0.28 - fo * 0.09), Vector3(0.124, 0.124, 0.02), sleeve.darkened(0.12), Vector3(PI * 0.5 - 0.18, 0, 0.3 * fo))


## Tay 4 ngón dính liền + 1 ngón cái (style "mitt"): bốn ngón là một dải dày uốn cong quanh cán (như găng liền ngón),
## mũi ngón có ba rãnh nhẹ; ngón cái tách riêng gập đè lên. `glove_on` = đeo găng (màu glove) hay tay trần (màu skin).
var glove_on := false


func build_mitt() -> void:
	for ch in get_children():
		ch.queue_free()
	var h := glove if glove_on else skin
	var dark := h.darkened(0.22)
	var hole := 0.026 if grip == "hold" else 0.0
	var r_wrap := hole + 0.02
	# bàn tay
	_blob(Vector3(hole + 0.019, 0.0, -0.04), Vector3(0.036, 0.104, 0.12), h)
	# 4 ngón dính liền: mỗi ngón là một vòng cung quấn quanh cán, 4 vòng xếp sát nhau dọc theo cán
	# (khe giữa các ngón chạy vòng quanh cán), dính vào nhau thành một khối
	var fr := 0.0122
	for i in 4:
		var fy := lerpf(-0.0285, 0.0285, i / 3.0)
		var end_a := PI * (1.04 - 0.05 * absf(i - 1.0))   # ngón giữa dài nhất, ngón út ngắn nhất
		var seg := 9
		var prev := Vector3.ZERO
		for k in seg + 1:
			var aa := lerpf(-0.2, end_a, float(k) / seg)
			var rr := r_wrap * (1.0 - 0.05 * float(k) / seg)
			var p := Vector3(cos(aa) * rr, fy, sin(aa) * rr + 0.006)
			if k > 0:
				_cap(prev, p, fr * (1.0 - 0.08 * float(k) / seg), h)
			prev = p
		_blob(prev, Vector3.ONE * fr * 2.0, h)
	# ngón cái tách riêng: từ gò ngón cái dưới cán, vòng ra trước, đè chéo lên dải ngón
	var t0 := Vector3(hole * 0.5 + 0.012, -0.038, -0.046)
	var t1 := Vector3(-r_wrap * 0.55 - 0.006, -0.035, -0.032)
	var t2 := Vector3(-r_wrap - 0.01, -0.022, -0.016)
	_cap(t0, t1, 0.0165, h)
	_cap(t1, t2, 0.015, h)
	_blob(t2, Vector3.ONE * 0.03, h)
	# cổ tay, ống tay áo
	_cap(Vector3(hole + 0.02, 0.0, -0.09), Vector3(hole + 0.055, 0.0, -0.3), 0.032, h)
	_cap(Vector3(hole + 0.05, 0.0, -0.2), Vector3(hole + 0.13, 0.0, -0.62), 0.056, sleeve)
	_blob(Vector3(hole + 0.052, 0.0, -0.205), Vector3(0.128, 0.128, 0.045), sleeve.darkened(0.25), Vector3(PI * 0.5 - 0.18, 0, 0))


## Gộp mọi khối của bàn tay thành MỘT mesh (mỗi màu một surface): vài lần vẽ thay vì vài chục.
## Pháp tuyến biến đổi theo ma trận nghịch đảo chuyển vị để khối tròn bị co giãn vẫn đổ bóng đúng.
func baked_mesh() -> ArrayMesh:
	var groups := {}
	for mi in get_children():
		if not (mi is MeshInstance3D) or (mi as Node).is_queued_for_deletion():
			continue
		var m3 := mi as MeshInstance3D
		var arr := m3.mesh.surface_get_arrays(0)
		var t := m3.transform
		var nb := t.basis.inverse().transposed()
		var key: Material = m3.material_override
		if not groups.has(key):
			groups[key] = [PackedVector3Array(), PackedVector3Array(), PackedInt32Array()]
		var g: Array = groups[key]
		var base: int = (g[0] as PackedVector3Array).size()
		for v: Vector3 in arr[Mesh.ARRAY_VERTEX]:
			g[0].append(t * v)
		for n: Vector3 in arr[Mesh.ARRAY_NORMAL]:
			g[1].append((nb * n).normalized())
		for i: int in arr[Mesh.ARRAY_INDEX]:
			g[2].append(base + i)
	var am := ArrayMesh.new()
	for key: Material in groups:
		var g2: Array = groups[key]
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = g2[0]
		a[Mesh.ARRAY_NORMAL] = g2[1]
		a[Mesh.ARRAY_INDEX] = g2[2]
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		am.surface_set_material(am.get_surface_count() - 1, key)
	return am


## Dựng sẵn một bàn tay (không cần đưa vào cây cảnh) rồi trả về mesh đã gộp.
static func make_mesh(p_style: String, p_grip: String, p_side: float, p_sleeve: Color) -> ArrayMesh:
	var h := SimpleHand.new()
	h.style = p_style
	h.grip = p_grip
	h.side = p_side
	h.sleeve = p_sleeve
	h.build()
	var m := h.baked_mesh()
	h.free()
	return m
