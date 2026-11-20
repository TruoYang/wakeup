extends Node
## Dựng các cảnh khởi đầu (nhân vật, HUD, nhà mẫu, khu phố).
## Chạy MỘT LẦN:  godot --headless --path . res://tools/build_scenes.tscn
## Sau đó cảnh được chỉnh bằng editor; chạy lại sẽ GHI ĐÈ các cảnh này.

const BLOCK_W := 56.0   # chiều dài khối nhà (trục X)
const BLOCK_D := 48.0   # chiều sâu khối nhà (trục Z)
const ROAD := 14.0
const COLS := 5
const ROWS := 3
const HOUSE_W := 5.0
const HOUSE_D := 14.0

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 20261111
	for dir: String in ["scenes", "props", "levels"]:
		DirAccess.make_dir_recursive_absolute("res://" + dir)
	build_player()
	build_hud()
	var houses := build_house_prefabs()
	var office := build_box_prefab("office", Vector3(26, 18, 22), Color("8c96a0"), true)
	var tree := build_tree()
	build_district(houses, office, tree)
	build_main()
	print("Đã dựng xong các cảnh.")
	get_tree().quit()


# ---------------------------------------------------------------- helpers
func mat(color: Color, rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


func box_mesh(size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat(color)
	mi.mesh = bm
	return mi


func box_shape(size: Vector3) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	return cs


func own(root: Node, node: Node) -> void:
	for child in node.get_children():
		# Không đụng vào bên trong các cảnh con đã được gắn vào.
		if child.scene_file_path == "" or child == root:
			child.owner = root
			own(root, child)
		else:
			child.owner = root


func save(root: Node, path: String) -> PackedScene:
	own(root, root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	assert(err == OK, "pack failed: " + path)
	err = ResourceSaver.save(packed, path)
	assert(err == OK, "save failed: " + path)
	root.free()
	return load(path)


func static_box(node_name: String, size: Vector3, color: Color, pos: Vector3) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.name = node_name
	sb.position = pos
	var mi := box_mesh(size, color)
	mi.name = "Mesh"
	sb.add_child(mi)
	var cs := box_shape(size)
	cs.name = "Shape"
	sb.add_child(cs)
	return sb


# ---------------------------------------------------------------- player
func build_player() -> void:
	var p := CharacterBody3D.new()
	p.name = "Player"
	p.set_script(load("res://scripts/player.gd"))
	p.floor_snap_length = 0.3
	p.floor_max_angle = deg_to_rad(50)

	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	p.add_child(cs)

	# Thân tạm (thay bằng mô hình nhân vật của bạn: kéo file .glb vào làm con của Body).
	var body := Node3D.new()
	body.name = "Body"
	p.add_child(body)
	var torso := MeshInstance3D.new()
	torso.name = "Torso"
	var cm := CapsuleMesh.new()
	cm.radius = 0.28
	cm.height = 1.25
	cm.material = mat(Color("e9e4d8"))
	torso.mesh = cm
	torso.position.y = 0.72
	body.add_child(torso)
	var skull := MeshInstance3D.new()
	skull.name = "HeadMesh"
	var sm := SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.4
	sm.material = mat(Color("d9a679"))
	skull.mesh = sm
	skull.position.y = 1.58
	body.add_child(skull)

	var head := Node3D.new()
	head.name = "Head"
	head.position.y = 1.6
	p.add_child(head)
	var arm := SpringArm3D.new()
	arm.name = "Arm"
	arm.spring_length = 0.0
	arm.margin = 0.2
	var probe := SphereShape3D.new()
	probe.radius = 0.2
	arm.shape = probe
	head.add_child(arm)
	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.fov = 75.0
	cam.near = 0.08
	cam.far = 600.0
	cam.current = true
	arm.add_child(cam)
	save(p, "res://scenes/player.tscn")


# ---------------------------------------------------------------- HUD
func stat_row(parent: Control, label: String, unique: String, color: Color) -> void:
	var row := HBoxContainer.new()
	row.name = unique + "Row"
	row.add_theme_constant_override("separation", 10)
	var l := Label.new()
	l.name = "Label"
	l.text = label
	l.custom_minimum_size = Vector2(70, 0)
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color("9a958b"))
	row.add_child(l)
	var bar := ProgressBar.new()
	bar.name = unique
	bar.unique_name_in_owner = true
	bar.custom_minimum_size = Vector2(160, 8)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.value = 100.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.07, 0.08, 0.7)
	bar.add_theme_stylebox_override("background", bg)
	row.add_child(bar)
	parent.add_child(row)


func build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.set_script(load("res://scripts/hud.gd"))

	var root := MarginContainer.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "top", "right", "bottom"]:
		root.add_theme_constant_override("margin_" + side, 18)
	hud.add_child(root)

	var objective := Label.new()
	objective.name = "Objective"
	objective.unique_name_in_owner = true
	objective.text = "MỤC TIÊU"
	objective.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	objective.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	objective.add_theme_font_size_override("font_size", 15)
	root.add_child(objective)

	var stats := VBoxContainer.new()
	stats.name = "Stats"
	stats.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	stats.size_flags_vertical = Control.SIZE_SHRINK_END
	stats.add_theme_constant_override("separation", 6)
	root.add_child(stats)
	stat_row(stats, "MÁU", "HpBar", Color("cf4a3b"))
	stat_row(stats, "ĐÓI", "FoodBar", Color("e4a03a"))
	stat_row(stats, "KHÁT", "WaterBar", Color("73a5c6"))
	stat_row(stats, "SỨC", "StaminaBar", Color("ebe5d8"))

	var noise := VBoxContainer.new()
	noise.name = "Noise"
	noise.size_flags_horizontal = Control.SIZE_SHRINK_END
	noise.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	root.add_child(noise)
	stat_row(noise, "TIẾNG ỒN", "NoiseBar", Color("e4a03a"))

	var hint := Label.new()
	hint.name = "Hint"
	hint.unique_name_in_owner = true
	hint.text = "Nhấp chuột để điều khiển · WASD đi · Shift chạy · C ngồi · Space nhảy · V đổi góc nhìn · Esc nhả chuột"
	hint.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hint.size_flags_vertical = Control.SIZE_SHRINK_END
	hint.add_theme_font_size_override("font_size", 14)
	root.add_child(hint)

	var cross := ColorRect.new()
	cross.name = "Crosshair"
	cross.color = Color(1, 1, 1, 0.7)
	cross.custom_minimum_size = Vector2(4, 4)
	cross.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cross.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cross)
	save(hud, "res://scenes/hud.tscn")


# ---------------------------------------------------------------- prefabs
## Khối nhà tạm: gốc toạ độ ở giữa mặt tiền, sát đất; mặt tiền quay về +Z.
func build_box_prefab(file: String, size: Vector3, color: Color, windows: bool) -> PackedScene:
	var sb := StaticBody3D.new()
	sb.name = file.capitalize().replace(" ", "")
	var center := Vector3(0, size.y * 0.5, -size.z * 0.5)
	var mi := box_mesh(size, color)
	mi.name = "Mesh"
	mi.position = center
	sb.add_child(mi)
	var cs := box_shape(size)
	cs.name = "Shape"
	cs.position = center
	sb.add_child(cs)
	if windows:
		# Băng cửa sổ + cửa ra vào chỉ để dễ nhìn hướng nhà (thay bằng mô hình thật sau).
		var floors := int(size.y / 3.6)
		for f in range(1, floors):
			var w := box_mesh(Vector3(size.x * 0.78, 1.3, 0.12), Color("2c3a46"))
			w.name = "Windows%d" % f
			w.position = Vector3(0, f * 3.6 + 1.6, 0.02)
			sb.add_child(w)
		var door := box_mesh(Vector3(minf(2.4, size.x * 0.5), 2.6, 0.12), Color("4a3b2e"))
		door.name = "Door"
		door.position = Vector3(0, 1.3, 0.02)
		sb.add_child(door)
	return save(sb, "res://props/%s.tscn" % file)


func build_house_prefabs() -> Array[PackedScene]:
	var out: Array[PackedScene] = []
	var colors := ["d8c9a3", "c9b38a", "b9c4c9", "d6b5a0", "a9b79c", "cfcfc4", "e0c070", "9fb0c0"]
	var heights := [7.6, 11.2, 14.8, 11.2, 7.6, 14.8, 11.2, 18.4]
	for i in colors.size():
		out.append(build_box_prefab("house_%d" % (i + 1), Vector3(HOUSE_W - 0.1, heights[i], HOUSE_D), Color(colors[i]), true))
	return out


func build_tree() -> PackedScene:
	var t := StaticBody3D.new()
	t.name = "Tree"
	var trunk := MeshInstance3D.new()
	trunk.name = "Trunk"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.16
	cyl.bottom_radius = 0.22
	cyl.height = 3.0
	cyl.material = mat(Color("5b4634"))
	trunk.mesh = cyl
	trunk.position.y = 1.5
	t.add_child(trunk)
	var crown := MeshInstance3D.new()
	crown.name = "Crown"
	var sp := SphereMesh.new()
	sp.radius = 1.7
	sp.height = 3.0
	sp.radial_segments = 8
	sp.rings = 4
	sp.material = mat(Color("3f6b3a"))
	crown.mesh = sp
	crown.position.y = 4.0
	t.add_child(crown)
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var cshape := CylinderShape3D.new()
	cshape.radius = 0.25
	cshape.height = 3.0
	cs.shape = cshape
	cs.position.y = 1.5
	t.add_child(cs)
	return save(t, "res://props/tree.tscn")


# ---------------------------------------------------------------- district
func block_center(col: int, row: int) -> Vector3:
	var x := (col - (COLS - 1) * 0.5) * (BLOCK_W + ROAD)
	var z := (row - (ROWS - 1) * 0.5) * (BLOCK_D + ROAD)
	return Vector3(x, 0, z)


func marker(node_name: String, pos: Vector3) -> Marker3D:
	var m := Marker3D.new()
	m.name = node_name
	m.position = pos
	return m


func build_district(houses: Array[PackedScene], office: PackedScene, tree: PackedScene) -> void:
	var d := Node3D.new()
	d.name = "District"
	var total_w := COLS * (BLOCK_W + ROAD) + ROAD + 40.0
	var total_d := ROWS * (BLOCK_D + ROAD) + ROAD + 40.0
	d.add_child(static_box("Ground", Vector3(total_w, 1.0, total_d), Color("3a3d40"), Vector3(0, -0.5, 0)))

	# Tường bao quanh bản đồ (vô hình) để không rơi ra ngoài.
	var bounds := Node3D.new()
	bounds.name = "Bounds"
	d.add_child(bounds)
	for side in 4:
		var horizontal := side < 2
		var size := Vector3(total_w, 30, 1) if horizontal else Vector3(1, 30, total_d)
		var sign_v := -1.0 if side % 2 == 0 else 1.0
		var pos := Vector3(0, 15, sign_v * total_d * 0.5) if horizontal else Vector3(sign_v * total_w * 0.5, 15, 0)
		var wall := StaticBody3D.new()
		wall.name = "Wall%d" % side
		wall.position = pos
		var cs := box_shape(size)
		cs.name = "Shape"
		wall.add_child(cs)
		bounds.add_child(wall)

	var lake_col := 2
	var lake_row := 1
	for row in ROWS:
		for col in COLS:
			var c := block_center(col, row)
			var block := Node3D.new()
			block.name = "Block_%d_%d" % [col, row]
			block.position = c
			d.add_child(block)
			if col == lake_col and row == lake_row:
				# Hồ trung tâm: nơi Thủy Quái trồi lên.
				block.name = "Lake"
				block.add_child(static_box("Bank", Vector3(BLOCK_W, 0.2, BLOCK_D), Color("6f8a5a"), Vector3(0, 0.1, 0)))
				var water := box_mesh(Vector3(BLOCK_W - 10, 0.06, BLOCK_D - 10), Color("3f6f8a"))
				water.name = "Water"
				water.position.y = 0.24
				block.add_child(water)
				continue
			block.add_child(static_box("Sidewalk", Vector3(BLOCK_W, 0.2, BLOCK_D), Color("8d8a83"), Vector3(0, 0.1, 0)))
			if col == 0 and row == 1:
				# Văn phòng nơi bắt đầu (mặt tiền quay ra đường phía đông).
				var o: Node3D = office.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
				o.name = "Office"
				o.position = Vector3(BLOCK_W * 0.5 - 2.0, 0.2, 0)
				o.rotation.y = PI * 0.5
				block.add_child(o)
			else:
				place_house_row(block, houses, 1.0, col, row)    # dãy quay mặt ra đường phía nam
				place_house_row(block, houses, -1.0, col, row)   # dãy quay mặt ra đường phía bắc
			# Cây dọc vỉa hè
			for i in 4:
				for s in [-1.0, 1.0]:
					if rng.randf() < 0.3:
						continue
					var t: Node3D = tree.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
					t.name = "Tree_%d_%s" % [i, "S" if s > 0 else "N"]
					t.position = Vector3(-BLOCK_W * 0.5 + 7.0 + i * 14.0 + rng.randf_range(-1.5, 1.5), 0.2, s * (BLOCK_D * 0.5 - 0.9))
					t.rotation.y = rng.randf() * TAU
					block.add_child(t)

	# Điểm xuất phát và nhà
	var start_block := block_center(0, 1)
	d.add_child(marker("PlayerStart", Vector3(start_block.x + BLOCK_W * 0.5 + 3.0, 0.3, start_block.z)))
	var home_block := block_center(COLS - 1, 1)
	var home := marker("Home", Vector3(home_block.x, 0.3, home_block.z + BLOCK_D * 0.5 + 2.0))
	d.add_child(home)
	var beacon := box_mesh(Vector3(0.6, 40, 0.6), Color(0.52, 0.71, 0.5, 1))
	beacon.name = "Beacon"
	beacon.position.y = 20.0
	(beacon.mesh as BoxMesh).material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	home.add_child(beacon)
	save(d, "res://levels/district.tscn")


func place_house_row(block: Node3D, houses: Array[PackedScene], side: float, col: int, row: int) -> void:
	var count := int(BLOCK_W / HOUSE_W)
	var x0 := -count * HOUSE_W * 0.5 + HOUSE_W * 0.5
	for i in count:
		# Chừa vài lô trống làm hẻm.
		if rng.randf() < 0.1:
			continue
		var h: Node3D = houses[rng.randi() % houses.size()].instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		h.name = "House_%s%d" % ["S" if side > 0 else "N", i]
		h.position = Vector3(x0 + i * HOUSE_W, 0.2, side * (BLOCK_D * 0.5 - 1.6))
		h.rotation.y = 0.0 if side > 0 else PI
		block.add_child(h)


# ---------------------------------------------------------------- main level
func build_main() -> void:
	var m := Node3D.new()
	m.name = "Main"
	m.set_script(load("res://scripts/main.gd"))

	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("5a6470")
	sky_mat.sky_horizon_color = Color("b9a58c")
	sky_mat.ground_bottom_color = Color("3a3d40")
	sky_mat.ground_horizon_color = Color("b9a58c")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8f9aa6")
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_light_color = Color("a89a86")
	env.fog_density = 0.004
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	m.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-38, -50, 0)
	sun.light_color = Color("ffd9a8")
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	m.add_child(sun)

	var district: Node3D = (load("res://levels/district.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	m.add_child(district)
	var player: Node3D = (load("res://scenes/player.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	m.add_child(player)
	var hud: Node = (load("res://scenes/hud.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	m.add_child(hud)
	save(m, "res://levels/main.tscn")
