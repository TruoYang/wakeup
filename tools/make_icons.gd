extends Node
## Chụp mô hình 3D của món đồ thành biểu tượng 128x128 nền trong suốt (dùng cho các món chưa có biểu tượng).
## Chạy: xvfb-run godot --path . --rendering-driver vulkan res://tools/make_icons.tscn [-- tất_cả]

func _ready() -> void:
	var all := OS.get_cmdline_user_args().has("all")
	var vp := SubViewport.new()
	vp.size = Vector2i(128, 128)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	e.ambient_light_energy = 0.75
	env.environment = e
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.3
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)
	var holder := Node3D.new()
	vp.add_child(holder)
	var made := 0
	for id: String in Items.defs:
		var path := Items.icon_path(id)
		if FileAccess.file_exists(path) and not all:
			continue
		for c in holder.get_children():
			c.queue_free()
		await get_tree().process_frame
		var m := ItemModels.make(id)
		holder.add_child(m)
		# khung bao của mô hình để đặt máy quay vừa khít
		var box := AABB()
		var first := true
		for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
			var b := mi.transform * mi.get_aabb()
			box = b if first else box.merge(b)
			first = false
		var center := box.get_center()
		var radius := maxf(box.size.length() * 0.5, 0.05)
		cam.size = radius * 2.15
		cam.position = center + Vector3(0.9, 0.85, 1.2).normalized() * 3.0
		cam.look_at(center, Vector3.UP)
		for i in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(path)
		made += 1
		print("icon ", id)
	print("đã tạo %d biểu tượng" % made)
	get_tree().quit()
