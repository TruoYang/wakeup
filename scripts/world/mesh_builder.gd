class_name MeshBuilder
## Gom nhiều khối hộp thành một lưới duy nhất cho mỗi vật liệu + tạo vùng va chạm khớp từng khối.

const FACES := [
	[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)],
	[Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
	[Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(1, 0, 0)],
	[Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)],
	[Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(1, 0, 0)],
	[Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(-1, 0, 0)],
]

var root: Node3D
var groups: Dictionary = {}      # "vật liệu|lớp" -> {v, n, c, i}
var bodies: Dictionary = {}      # "bề mặt|tầng va chạm" -> StaticBody3D
var shape_cache: Dictionary = {}
var boxes := 0


func _init(parent: Node3D) -> void:
	root = parent


## layer: "ext" (luôn hiện) hoặc "int" (nội thất, ẩn khi ở xa).
## solid: 0 không va chạm, 1 chặn đi + chặn nhìn, 2 chỉ chặn đi (kính, lan can thưa).
func box(mat: String, center: Vector3, size: Vector3, color := Color.WHITE, solid := 1, layer := "ext", rot := Basis.IDENTITY, surface := "") -> void:
	boxes += 1
	var key := mat + "|" + layer
	var g: Dictionary = groups.get(key, {})
	if g.is_empty():
		g = {"v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray(), "i": PackedInt32Array()}
		groups[key] = g
	var v: PackedVector3Array = g.v
	var n: PackedVector3Array = g.n
	var c: PackedColorArray = g.c
	var idx: PackedInt32Array = g.i
	# 8 đỉnh tính một lần, ghép thành 6 mặt (nhanh hơn nhiều so với tính lại từng góc từng mặt)
	var ax := rot.x * (size.x * 0.5)
	var ay := rot.y * (size.y * 0.5)
	var az := rot.z * (size.z * 0.5)
	var nx := rot.x.normalized()
	var ny := rot.y.normalized()
	var nz := rot.z.normalized()
	var p000 := center - ax - ay - az
	var p100 := center + ax - ay - az
	var p010 := center - ax + ay - az
	var p110 := center + ax + ay - az
	var p001 := center - ax - ay + az
	var p101 := center + ax - ay + az
	var p011 := center - ax + ay + az
	var p111 := center + ax + ay + az
	var base := v.size()
	# thứ tự góc giống bản cũ: (o - r - u, o + r - u, o + r + u, o - r + u) cho từng mặt
	v.append_array(PackedVector3Array([p101, p100, p110, p111,  p000, p001, p011, p010,  p011, p111, p110, p010,  p000, p100, p101, p001,  p001, p101, p111, p011,  p100, p000, p010, p110]))
	n.append_array(PackedVector3Array([nx, nx, nx, nx, -nx, -nx, -nx, -nx, ny, ny, ny, ny, -ny, -ny, -ny, -ny, nz, nz, nz, nz, -nz, -nz, -nz, -nz]))
	var cols := PackedColorArray()
	cols.resize(24)
	cols.fill(color)
	c.append_array(cols)
	for f in 6:
		var b0 := base + f * 4
		idx.append_array(PackedInt32Array([b0, b0 + 2, b0 + 1, b0, b0 + 3, b0 + 2]))
	if solid > 0:
		collider(center, size, surface if surface != "" else Mats.SURFACE.get(mat, "concrete"), solid, rot)


var _body_by: Dictionary = {}     # tầng va chạm -> bề mặt -> StaticBody3D


func collider(center: Vector3, size: Vector3, surface: String, solid := 1, rot := Basis.IDENTITY) -> void:
	var per: Dictionary = _body_by.get(solid, {})
	if per.is_empty():
		_body_by[solid] = per
	var body: StaticBody3D = per.get(surface)
	if body == null:
		body = StaticBody3D.new()
		body.name = "Col_%s_%d" % [surface, solid]
		body.collision_layer = 1 if solid == 1 else 2
		body.collision_mask = 0
		body.set_meta("surface", surface)
		body.set_meta("shapes", [])
		root.add_child(body)
		per[surface] = body
		bodies["%s|%d" % [surface, solid]] = body
	var skey := size.snapped(Vector3.ONE * 0.01)
	var shape: BoxShape3D = shape_cache.get(skey)
	if shape == null:
		shape = BoxShape3D.new()
		shape.size = size
		shape_cache[skey] = shape
	# thêm hình va chạm thẳng vào máy vật lý (không tạo nút CollisionShape3D cho từng khối); giữ tham chiếu shape
	PhysicsServer3D.body_add_shape(body.get_rid(), shape.get_rid(), Transform3D(rot, center))
	(body.get_meta("shapes") as Array).append(shape)


## Tạo các MeshInstance3D. Lớp "int" chỉ hiện trong bán kính `interior_range`.
func commit(interior_range := 80.0) -> void:
	for key: String in groups:
		var parts := key.split("|")
		var g: Dictionary = groups[key]
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = g.v
		arr[Mesh.ARRAY_NORMAL] = g.n
		arr[Mesh.ARRAY_COLOR] = g.c
		arr[Mesh.ARRAY_INDEX] = g.i
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(0, Mats.get_mat(parts[0]))
		var mi := MeshInstance3D.new()
		mi.name = "Mesh_" + key.replace("|", "_")
		mi.mesh = mesh
		if parts[1] == "int":
			mi.visibility_range_end = interior_range
			mi.visibility_range_end_margin = 10.0
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		if parts[0] == "glass" or parts[0] == "emit":
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	groups.clear()
