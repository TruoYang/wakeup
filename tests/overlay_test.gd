extends Node3D
## Thử lớp vẽ tay riêng: so ảnh có và không có lớp phủ trong cùng một cảnh sáng.

func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.86, 0.86, 0.86)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	e.ambient_light_energy = 0.7
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 25, 0)
	add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 50.0
	add_child(cam)
	cam.current = true
	var mode := "msaa"
	for a in OS.get_cmdline_user_args():
		mode = a
	var fp := FPArms.new()
	fp.use_overlay = true
	cam.add_child(fp)
	await get_tree().process_frame
	await get_tree().process_frame
	if mode == "nomsaa":
		fp._vp.msaa_3d = Viewport.MSAA_DISABLED
	if mode == "notrans":
		fp._vp.transparent_bg = false
	var g := Node3D.new()
	cam.add_child(g)
	g.transform = Transform3D(Basis.from_euler(Vector3(-0.15, 0.25, 0)), Vector3(0.12, -0.12, -0.45))
	for i in 10:
		fp.solve("r", g, Vector3(0.5, -1, 0))
		fp.relax("l")
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://ov_%s.png" % mode)
	print("shot ", mode)
	get_tree().quit()
