class_name MonsterMesh
## Tạo hình quái vật bằng code: các khối thịt méo mó, u bướu; chi thuôn có khớp; gai, răng.

static var _noise: FastNoiseLite
static var _cache: Dictionary = {}
## Hệ số độ gồ ghề của hình khối (1 = sần sùi, 0.25 = trơn nhẵn, đồ sộ).
static var rough := 1.0


static func noise() -> FastNoiseLite:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		_noise.frequency = 1.0
	return _noise


static func _displace(mesh: PrimitiveMesh, stretch: Vector3, seed_v: int, bump: float, lumps: float) -> ArrayMesh:
	var arr := mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n := noise()
	var off := Vector3(seed_v * 13.7, seed_v * 7.3, seed_v * 3.1)
	for i in verts.size():
		var p := verts[i]
		var dir := p.normalized() if p.length() > 0.001 else Vector3.UP
		var q := p * 1.3 + off
		var d := n.get_noise_3dv(q) * 0.6 + n.get_noise_3dv(q * 2.7) * 0.28 + n.get_noise_3dv(q * 6.1) * 0.12
		# u bướu: những chỗ phồng hẳn lên
		var lump := maxf(0.0, n.get_noise_3dv(q * 1.9 + Vector3(40, 0, 0)) - 0.25) * lumps
		verts[i] = (p + dir * (d * bump + lump)) * stretch
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = null
	arr[Mesh.ARRAY_TANGENT] = null
	var st := SurfaceTool.new()
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	st.create_from(am, 0)
	st.generate_normals()
	return st.commit()


## Khối thịt méo (bán kính theo 3 trục).
static func blob(radius: Vector3, seed_v := 0, bump := 0.22, lumps := 0.5, detail := 1.0) -> ArrayMesh:
	bump *= rough
	lumps *= rough
	var key := "b%s|%d|%.2f|%.2f|%.1f" % [radius, seed_v, bump, lumps, detail]
	if _cache.has(key):
		return _cache[key]
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = int(28 * detail)
	s.rings = int(16 * detail)
	var m := _displace(s, radius, seed_v, bump, lumps)
	_cache[key] = m
	return m


## Chi thuôn dọc theo -Y (gốc ở đầu trên), dài `length`, bán kính r0 -> r1.
static func limb(length: float, r0: float, r1: float, seed_v := 0, bump := 0.25) -> ArrayMesh:
	bump *= rough
	var key := "l%.2f|%.2f|%.2f|%d|%.2f" % [length, r0, r1, seed_v, bump]
	if _cache.has(key):
		return _cache[key]
	var c := CylinderMesh.new()
	c.top_radius = 1.0
	c.bottom_radius = 1.0
	c.height = 1.0
	c.radial_segments = 12
	c.rings = 8
	var arr := c.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n := noise()
	var off := Vector3(seed_v * 5.1, seed_v * 9.7, 0.0)
	for i in verts.size():
		var p := verts[i]
		var t := 0.5 - p.y                       # 0 ở gốc, 1 ở ngọn
		var r := lerpf(r0, r1, t)
		# khớp phồng ở hai đầu, bắp thịt ở giữa
		r *= 1.0 + 0.28 * exp(-pow((t - 0.0) * 6.0, 2.0)) + 0.22 * exp(-pow((t - 1.0) * 6.0, 2.0)) + 0.12 * sin(t * PI)
		var ring := Vector3(p.x, 0.0, p.z)
		var q := Vector3(p.x * 1.5, t * length * 0.8, p.z * 1.5) + off
		var d := 1.0 + (n.get_noise_3dv(q) * 0.6 + n.get_noise_3dv(q * 3.0) * 0.4) * bump
		var radial := ring.length()
		verts[i] = Vector3(p.x * r * d, -t * length, p.z * r * d) if radial > 0.01 else Vector3(0, -t * length, 0)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = null
	arr[Mesh.ARRAY_TANGENT] = null
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var st := SurfaceTool.new()
	st.create_from(am, 0)
	st.generate_normals()
	var m := st.commit()
	_cache[key] = m
	return m


## Bản góc cạnh của một mesh: tách đỉnh theo từng mặt rồi tính pháp tuyến phẳng (mặt cắt rõ như low-poly).
static func facet(mesh: Mesh) -> ArrayMesh:
	var key := "f%d" % mesh.get_instance_id()
	if _cache.has(key) and (_cache[key] as Array)[0] == mesh:
		return (_cache[key] as Array)[1]
	var arr := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if idx.is_empty():
		idx.resize(v.size())
		for i in v.size():
			idx[i] = i
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	out_v.resize(idx.size())
	out_n.resize(idx.size())
	for t in range(0, idx.size() - 2, 3):
		var a := v[idx[t]]
		var b := v[idx[t + 1]]
		var c := v[idx[t + 2]]
		var n := (c - a).cross(b - a)
		n = n.normalized() if n.length() > 1e-9 else Vector3.UP
		for j in 3:
			out_v[t + j] = [a, b, c][j]
			out_n[t + j] = n
	var na := []
	na.resize(Mesh.ARRAY_MAX)
	na[Mesh.ARRAY_VERTEX] = out_v
	na[Mesh.ARRAY_NORMAL] = out_n
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, na)
	_cache[key] = [mesh, m]        # giữ cả mesh gốc để id không bị dùng lại cho mesh khác
	return m


static func spike(radius: float, length: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = radius
	c.height = length
	c.radial_segments = 6
	c.rings = 1
	return c


static func flesh(base: Color, mottle: Color, vein: Color, opts: Dictionary = {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/flesh.gdshader")
	m.set_shader_parameter("base_color", base)
	m.set_shader_parameter("mottle_color", mottle)
	m.set_shader_parameter("vein_color", vein)
	for k: String in opts:
		m.set_shader_parameter(k, opts[k])
	return m


static func bone(color := Color("d8ccb0")) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.45
	return m


static func add(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi
