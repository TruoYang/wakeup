class_name ItemModels
## Hình khối 3D đơn giản của từng món đồ khi nằm ngoài thế giới (đồ rơi, đồ bày trong hầm).
## Không cầu kỳ, chỉ đủ để nhìn là biết đó là cái gì và nhặt được.

static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}


static func _mat(col: Color) -> StandardMaterial3D:
	var k := col.to_html()
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = 0.8
		if col.a < 0.99:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mats[k] = m
	return _mats[k]


## Một phần của mô hình: kind = box | cyl | sph; size: box (x,y,z) · cyl (bán kính, cao, -) · sph (rx, ry, rz).
static func _part(n: Node3D, kind: String, size: Vector3, pos: Vector3, col: String, rot := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	var key := "%s|%.3f|%.3f|%.3f" % [kind, size.x, size.y, size.z] if kind != "sph" else "sph"
	var mesh: Mesh = _meshes.get(key)
	if mesh == null:
		match kind:
			"box":
				var b := BoxMesh.new()
				b.size = size
				mesh = b
			"cyl":
				var c := CylinderMesh.new()
				c.top_radius = size.x
				c.bottom_radius = size.x if size.z <= 0.0 else size.z
				c.height = size.y
				c.radial_segments = 10
				c.rings = 1
				mesh = c
			"sph":
				var s := SphereMesh.new()
				s.radius = 0.5
				s.height = 1.0
				s.radial_segments = 10
				s.rings = 5
				mesh = s
		_meshes[key] = mesh
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if kind == "sph":
		mi.scale = size * 2.0
	mi.material_override = _mat(Color(col))
	mi.position = pos
	mi.rotation = rot
	n.add_child(mi)


static func _bottle(n: Node3D, body: String, cap: String, r := 0.035, h := 0.2) -> void:
	_part(n, "cyl", Vector3(r, h, 0), Vector3(0, h * 0.5, 0), body)
	_part(n, "cyl", Vector3(r * 0.45, h * 0.18, r * 0.8), Vector3(0, h * 1.09, 0), body)
	_part(n, "cyl", Vector3(r * 0.5, 0.02, 0), Vector3(0, h * 1.19, 0), cap)


static func _long(n: Node3D, r: float, length: float, col: String) -> void:
	_part(n, "cyl", Vector3(r, length, 0), Vector3(0, r, 0), col, Vector3(0, 0, PI * 0.5))


static func _folded(n: Node3D, col: String, trim: String) -> void:
	_part(n, "box", Vector3(0.34, 0.07, 0.26), Vector3(0, 0.035, 0), col)
	_part(n, "box", Vector3(0.3, 0.05, 0.22), Vector3(0.01, 0.095, 0.01), col)
	_part(n, "box", Vector3(0.1, 0.012, 0.22), Vector3(0, 0.125, 0.01), trim)


static func _pack(n: Node3D, col: String, s: float) -> void:
	_part(n, "box", Vector3(0.3, 0.4, 0.18) * s, Vector3(0, 0.2 * s, 0), col)
	_part(n, "box", Vector3(0.22, 0.16, 0.06) * s, Vector3(0, 0.13 * s, 0.11 * s), Color(col).darkened(0.25).to_html())
	_part(n, "box", Vector3(0.05, 0.3, 0.03) * s, Vector3(-0.09 * s, 0.22 * s, -0.1 * s), "2a2a2e")
	_part(n, "box", Vector3(0.05, 0.3, 0.03) * s, Vector3(0.09 * s, 0.22 * s, -0.1 * s), "2a2a2e")


static func _helmet(n: Node3D, col: String) -> void:
	_part(n, "sph", Vector3(0.13, 0.1, 0.15), Vector3(0, 0.08, 0), col)
	_part(n, "box", Vector3(0.2, 0.012, 0.08), Vector3(0, 0.035, 0.14), Color(col).darkened(0.3).to_html())


static func _shoes(n: Node3D, col: String, sole: String) -> void:
	for sx: float in [-0.07, 0.07]:
		_part(n, "box", Vector3(0.09, 0.03, 0.26), Vector3(sx, 0.015, 0), sole)
		_part(n, "box", Vector3(0.085, 0.07, 0.16), Vector3(sx, 0.065, -0.04), col)
		_part(n, "box", Vector3(0.085, 0.04, 0.1), Vector3(sx, 0.05, 0.08), col)


static func _pillbox(n: Node3D, stripe: String) -> void:
	_part(n, "box", Vector3(0.13, 0.05, 0.08), Vector3(0, 0.025, 0), "f2f0ea")
	_part(n, "box", Vector3(0.132, 0.018, 0.082), Vector3(0, 0.03, 0), stripe)


static func make(id: String) -> Node3D:
	var n := Node3D.new()
	match id:
		# ---- đồ ăn
		"banhmi":
			_part(n, "sph", Vector3(0.12, 0.04, 0.045), Vector3(0, 0.04, 0), "d9a25a")
			_part(n, "box", Vector3(0.16, 0.012, 0.02), Vector3(0, 0.075, 0), "f2d9a0")
		"mitom":
			_part(n, "box", Vector3(0.16, 0.035, 0.12), Vector3(0, 0.018, 0), "e0452a")
			_part(n, "box", Vector3(0.1, 0.037, 0.06), Vector3(0, 0.019, 0), "f2c94a")
		"xoi":
			_part(n, "sph", Vector3(0.08, 0.05, 0.08), Vector3(0, 0.05, 0), "4f8a3a")
			_part(n, "box", Vector3(0.17, 0.008, 0.012), Vector3(0, 0.1, 0), "d9c58a")
		"banhchung":
			_part(n, "box", Vector3(0.16, 0.06, 0.16), Vector3(0, 0.03, 0), "3f7a34")
			_part(n, "box", Vector3(0.165, 0.062, 0.012), Vector3(0, 0.03, 0), "d9c58a")
			_part(n, "box", Vector3(0.012, 0.062, 0.165), Vector3(0, 0.03, 0), "d9c58a")
		"cahop":
			_part(n, "cyl", Vector3(0.055, 0.045, 0), Vector3(0, 0.0225, 0), "c8ccd0")
			_part(n, "cyl", Vector3(0.056, 0.028, 0), Vector3(0, 0.0225, 0), "2f6fb0")
		"luongkho":
			_part(n, "box", Vector3(0.15, 0.04, 0.09), Vector3(0, 0.02, 0), "6a7a4a")
			_part(n, "box", Vector3(0.152, 0.012, 0.05), Vector3(0, 0.03, 0), "d8d2b0")
		"chuoi":
			for i in 4:
				_part(n, "box", Vector3(0.035, 0.035, 0.16), Vector3(-0.05 + i * 0.035, 0.03, 0), "f2cf3a", Vector3(0.25, (i - 1.5) * 0.14, 0))
			_part(n, "box", Vector3(0.1, 0.03, 0.03), Vector3(0, 0.055, -0.085), "6a5a2a")
		"banhquy":
			_part(n, "box", Vector3(0.18, 0.06, 0.12), Vector3(0, 0.03, 0), "2f5fa8")
			_part(n, "box", Vector3(0.1, 0.062, 0.07), Vector3(0, 0.03, 0), "f2e0b0")
		# ---- đồ uống
		"nuocsuoi":
			_bottle(n, "9fd0f0cc", "2f7fd0")
		"binhnuoc":
			_bottle(n, "7fbfe6cc", "2f5fa8", 0.1, 0.28)
			_part(n, "box", Vector3(0.03, 0.1, 0.1), Vector3(0.11, 0.22, 0), "2f5fa8")
		"trada":
			_part(n, "box", Vector3(0.1, 0.16, 0.04), Vector3(0, 0.08, 0), "c88a3acc")
			_part(n, "cyl", Vector3(0.005, 0.1, 0), Vector3(0.02, 0.2, 0), "f2f0ea")
		"tangluc":
			_part(n, "cyl", Vector3(0.033, 0.13, 0), Vector3(0, 0.065, 0), "d92a2a")
			_part(n, "cyl", Vector3(0.034, 0.03, 0), Vector3(0, 0.07, 0), "f2c94a")
		"suahop":
			_part(n, "box", Vector3(0.07, 0.12, 0.05), Vector3(0, 0.06, 0), "f2f0ea")
			_part(n, "box", Vector3(0.072, 0.04, 0.052), Vector3(0, 0.06, 0), "3f8fd0")
		"nuocdua":
			_part(n, "sph", Vector3(0.09, 0.1, 0.09), Vector3(0, 0.1, 0), "5f9a4a")
			_part(n, "cyl", Vector3(0.03, 0.02, 0), Vector3(0, 0.2, 0), "f2e8c8")
		# ---- thuốc men
		"bang":
			_part(n, "cyl", Vector3(0.045, 0.07, 0), Vector3(0, 0.045, 0), "f4f2ec", Vector3(0, 0, PI * 0.5))
			_part(n, "cyl", Vector3(0.015, 0.072, 0), Vector3(0, 0.045, 0), "d8d2c0", Vector3(0, 0, PI * 0.5))
		"nep":
			_part(n, "box", Vector3(0.36, 0.015, 0.05), Vector3(0, 0.008, -0.035), "c9a26a")
			_part(n, "box", Vector3(0.36, 0.015, 0.05), Vector3(0, 0.008, 0.035), "c9a26a")
			_part(n, "box", Vector3(0.05, 0.02, 0.13), Vector3(-0.1, 0.012, 0), "f4f2ec")
			_part(n, "box", Vector3(0.05, 0.02, 0.13), Vector3(0.1, 0.012, 0), "f4f2ec")
		"giamdau":
			_pillbox(n, "3f8fd0")
		"khangsinh":
			_pillbox(n, "d9452f")
		"con":
			_bottle(n, "8a5a2acc", "f2f0ea", 0.03, 0.13)
		"socuu":
			_part(n, "box", Vector3(0.26, 0.1, 0.18), Vector3(0, 0.05, 0), "d92a2a")
			_part(n, "box", Vector3(0.1, 0.102, 0.03), Vector3(0, 0.05, 0), "f4f2ec")
			_part(n, "box", Vector3(0.03, 0.102, 0.1), Vector3(0, 0.05, 0), "f4f2ec")
			_part(n, "box", Vector3(0.08, 0.02, 0.02), Vector3(0, 0.11, 0), "2a2a2e")
		# ---- dụng cụ, vũ khí
		"canhcay":
			_long(n, 0.028, 0.95, "7a5a3a")
			_part(n, "cyl", Vector3(0.018, 0.2, 0), Vector3(0.25, 0.06, 0.05), "7a5a3a", Vector3(0.9, 0, PI * 0.5))
		"banphim":
			_part(n, "box", Vector3(0.46, 0.028, 0.16), Vector3(0, 0.014, 0), "2a2c30")
			for r in 4:
				_part(n, "box", Vector3(0.42, 0.014, 0.027), Vector3(0, 0.034, -0.055 + r * 0.035), "e8e6e0" if r > 0 else "9aa0a8")
			_part(n, "box", Vector3(0.2, 0.014, 0.027), Vector3(-0.02, 0.034, 0.056), "e8e6e0")       # hàng phím cách
			_part(n, "cyl", Vector3(0.006, 0.18, 0), Vector3(0.12, 0.012, -0.16), "1a1a1e", Vector3(PI * 0.5, 0, 0))   # dây
		"chao":
			_part(n, "cyl", Vector3(0.15, 0.04, 0.12), Vector3(0, 0.02, 0), "2a2a2e")
			_part(n, "cyl", Vector3(0.13, 0.01, 0), Vector3(0, 0.041, 0), "3a3a40")
			_part(n, "box", Vector3(0.22, 0.025, 0.035), Vector3(0.25, 0.03, 0), "2a2a2e")
		"ongtuyp":
			_long(n, 0.025, 1.0, "9aa0a8")
			_part(n, "cyl", Vector3(0.032, 0.05, 0), Vector3(0.48, 0.025, 0), "7a8088", Vector3(0, 0, PI * 0.5))
		"gaysat":
			_long(n, 0.018, 0.9, "5a5e66")
		"xabeng":
			_long(n, 0.02, 0.8, "3a3d44")
			_part(n, "box", Vector3(0.03, 0.03, 0.12), Vector3(0.4, 0.02, 0.05), "3a3d44", Vector3(0, 0.5, 0))
			_part(n, "box", Vector3(0.05, 0.012, 0.035), Vector3(-0.41, 0.02, 0), "c8302a")
		"sungluc":
			_part(n, "box", Vector3(0.22, 0.045, 0.035), Vector3(0.02, 0.02, 0), "2a2c30")
			_part(n, "box", Vector3(0.05, 0.035, 0.11), Vector3(-0.07, 0.02, 0.06), "3a2e26", Vector3(0, 0.25, 0))
			_part(n, "box", Vector3(0.05, 0.012, 0.03), Vector3(-0.02, 0.02, 0.035), "1a1a1e")
		"bangdan":
			_part(n, "box", Vector3(0.05, 0.14, 0.03), Vector3(0, 0.015, 0), "2a2c30", Vector3(PI * 0.5, 0.3, 0))
			_part(n, "box", Vector3(0.04, 0.02, 0.025), Vector3(0.0, 0.03, -0.07), "c9a23a")
		"phao":
			_part(n, "cyl", Vector3(0.022, 0.12, 0), Vector3(0, 0.022, 0), "d92a2a", Vector3(0, 0, PI * 0.5))
			_part(n, "cyl", Vector3(0.004, 0.06, 0), Vector3(0.085, 0.03, 0), "e8e0c0", Vector3(0, 0, 1.1))
		"chai":
			_bottle(n, "5f9a6acc", "c9a23a", 0.032, 0.18)
		"canxang":
			_part(n, "box", Vector3(0.26, 0.32, 0.14), Vector3(0, 0.16, 0), "c8302a")
			_part(n, "box", Vector3(0.14, 0.03, 0.04), Vector3(-0.02, 0.345, 0), "c8302a")
			_part(n, "cyl", Vector3(0.025, 0.05, 0), Vector3(0.1, 0.345, 0), "f2c94a")
		"dongho", "donghotay":
			_part(n, "cyl", Vector3(0.035, 0.014, 0), Vector3(0, 0.012, 0), "2a2c30" if id == "dongho" else "c8ccd0")
			_part(n, "cyl", Vector3(0.027, 0.004, 0), Vector3(0, 0.02, 0), "7fe0b0" if id == "dongho" else "f4f2ec")
			_part(n, "box", Vector3(0.035, 0.006, 0.2), Vector3(0, 0.006, 0), "3a2a22")
		"vi":
			_part(n, "box", Vector3(0.13, 0.025, 0.1), Vector3(0, 0.013, 0), "6a4228")
			_part(n, "box", Vector3(0.1, 0.006, 0.05), Vector3(0.02, 0.028, 0), "7fbf7a")
		"dtla", "dienthoai":
			_part(n, "box", Vector3(0.08, 0.012, 0.16), Vector3(0, 0.006, 0), "1a1a1e")
			_part(n, "box", Vector3(0.07, 0.004, 0.14), Vector3(0, 0.013, 0), "3f6a9a")
		"maydo":
			_part(n, "box", Vector3(0.2, 0.06, 0.13), Vector3(0, 0.03, 0), "2f3a34")
			_part(n, "box", Vector3(0.12, 0.008, 0.08), Vector3(-0.02, 0.064, 0), "6fe0a0")
			_part(n, "cyl", Vector3(0.006, 0.16, 0), Vector3(0.08, 0.13, -0.04), "8a9098")
			_part(n, "sph", Vector3(0.012, 0.012, 0.012), Vector3(0.08, 0.21, -0.04), "e0453a")
		"kinhdem":
			_part(n, "box", Vector3(0.18, 0.06, 0.08), Vector3(0, 0.04, 0), "2a2e2a")
			for sx: float in [-0.045, 0.045]:
				_part(n, "cyl", Vector3(0.028, 0.07, 0), Vector3(sx, 0.04, 0.07), "1a1c1a", Vector3(PI * 0.5, 0, 0))
				_part(n, "cyl", Vector3(0.022, 0.005, 0), Vector3(sx, 0.04, 0.107), "4fe07a", Vector3(PI * 0.5, 0, 0))
			_part(n, "box", Vector3(0.2, 0.02, 0.012), Vector3(0, 0.04, -0.045), "3a3a3a")
		"caphe":
			_part(n, "cyl", Vector3(0.033, 0.11, 0), Vector3(0, 0.055, 0), "5a3a22")
			_part(n, "cyl", Vector3(0.034, 0.03, 0), Vector3(0, 0.06, 0), "e8dcc0")
		"nuocngot":
			_part(n, "cyl", Vector3(0.033, 0.12, 0), Vector3(0, 0.06, 0), "d92a2a")
			_part(n, "cyl", Vector3(0.034, 0.02, 0), Vector3(0, 0.08, 0), "f4f2ec")
		"chan":
			_part(n, "box", Vector3(0.4, 0.09, 0.3), Vector3(0, 0.045, 0), "8a6a8a")
			_part(n, "box", Vector3(0.38, 0.07, 0.28), Vector3(0.01, 0.12, 0.01), "9a7a9a")
			_part(n, "box", Vector3(0.41, 0.03, 0.05), Vector3(0, 0.1, 0.1), "d8c8a0")
		"thuocdactri":
			_part(n, "cyl", Vector3(0.03, 0.08, 0), Vector3(0, 0.04, 0), "e08a2acc")
			_part(n, "cyl", Vector3(0.032, 0.025, 0), Vector3(0, 0.09, 0), "f4f2ec")
			_part(n, "box", Vector3(0.045, 0.04, 0.062), Vector3(0, 0.04, 0), "f4f2ec")
		"denpin":
			# đèn pin nhôm: nắp đuôi, thân có các vòng khía chống trượt, nút bấm cao su, đầu loe, viền kim loại, mặt kính
			var ax := Vector3(0, 0, PI * 0.5)
			_part(n, "cyl", Vector3(0.024, 0.02, 0), Vector3(-0.088, 0.035, 0), "1c1d20", ax)
			_part(n, "cyl", Vector3(0.021, 0.15, 0), Vector3(-0.005, 0.035, 0), "2a2c30", ax)
			for k in 5:
				_part(n, "cyl", Vector3(0.0225, 0.005, 0), Vector3(-0.07 + k * 0.014, 0.035, 0), "4a4e56", ax)
			_part(n, "box", Vector3(0.016, 0.008, 0.014), Vector3(0.035, 0.058, 0), "151515")
			_part(n, "cyl", Vector3(0.035, 0.045, 0.022), Vector3(0.093, 0.035, 0), "33363c", Vector3(0, 0, -PI * 0.5))
			_part(n, "cyl", Vector3(0.037, 0.008, 0), Vector3(0.118, 0.035, 0), "8a8e96", ax)
			_part(n, "cyl", Vector3(0.031, 0.004, 0), Vector3(0.122, 0.035, 0), "fff0b0", ax)
		"bimbim":
			_part(n, "box", Vector3(0.13, 0.04, 0.18), Vector3(0, 0.025, 0), "f2a02a")
			_part(n, "box", Vector3(0.09, 0.042, 0.08), Vector3(0, 0.025, 0), "d92a2a")
		"ngocay":
			_part(n, "box", Vector3(0.1, 0.03, 0.15), Vector3(0, 0.02, 0), "c8302a")
			_part(n, "box", Vector3(0.07, 0.032, 0.06), Vector3(0, 0.02, 0.02), "f2c94a")
		"sachvo":
			_part(n, "box", Vector3(0.2, 0.03, 0.27), Vector3(0, 0.015, 0), "2f6fb0")
			_part(n, "box", Vector3(0.19, 0.025, 0.26), Vector3(0.01, 0.043, 0.01), "5f9a4a", Vector3(0, 0.15, 0))
			_part(n, "box", Vector3(0.18, 0.012, 0.25), Vector3(0, 0.062, 0), "f4f2ec", Vector3(0, -0.1, 0))
		"baloxin":
			_pack(n, "4a5236", 1.45)
		# ---- đồ mặc
		"giaythethao":
			_shoes(n, "e8e6e0", "2f7fd0")
		"giaybaoho":
			_shoes(n, "6a4a30", "2a2a2e")
		"aokhoac":
			_folded(n, "2f3440", "5a6070")
		"aophao":
			_folded(n, "6a7a4a", "c8302a")
		"aobaoho":
			_folded(n, "e08a2a", "d8d8d0")
		"aogiap":
			_part(n, "box", Vector3(0.36, 0.1, 0.3), Vector3(0, 0.05, 0), "4a5a3a")
			_part(n, "box", Vector3(0.12, 0.05, 0.1), Vector3(-0.09, 0.12, 0.05), "3a4a2e")
			_part(n, "box", Vector3(0.12, 0.05, 0.1), Vector3(0.09, 0.12, 0.05), "3a4a2e")
		"mubaohiem":
			_helmet(n, "d92a2a")
		"musat":
			_helmet(n, "4a5a3a")
		"balonho":
			_pack(n, "2f6fb0", 0.85)
		"balophuot":
			_pack(n, "5a6a3a", 1.2)
		_:
			# món chưa có hình riêng: một cái hộp màu theo loại
			var cat: String = Items.get_def(id).get("cat", "tool")
			var col: String = {"food": "d9a25a", "drink": "7fbfe6", "med": "f2f0ea", "gear": "6a7a8a"}.get(cat, "8a7a5a")
			_part(n, "box", Vector3(0.2, 0.12, 0.16), Vector3(0, 0.06, 0), col)
	return n
