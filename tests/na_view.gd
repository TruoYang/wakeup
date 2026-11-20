extends Node3D
## Ảnh duyệt nhân vật: Mai và bé Na đứng cạnh nhau, nhìn chính diện.

func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.82, 0.83, 0.85)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 20, 0)
	add_child(sun)
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(10, 10)
	fl.mesh = pm
	add_child(fl)
	var mai := HeroHumanoid.new()
	mai.female = true
	mai.hair_style = "long"
	add_child(mai)
	mai.setup(Color("b0607a"), Color("3a3a48"), Color("d9a679"))
	mai.position = Vector3(-0.5, 0, 0)
	var na := HeroHumanoid.new()
	na.female = true
	na.child = true
	na.hair_style = "long"
	add_child(na)
	na.setup(Color("f0c040"), Color("5a6a9a"), Color("d9a679"))
	na.scale = Vector3.ONE * 0.6
	na.position = Vector3(0.45, 0, 0)
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 40
	cam.position = Vector3(0, 1.0, 4.2)
	cam.look_at(Vector3(0, 0.85, 0))
	cam.current = true
	for i in 5:
		mai.animate(0.016, 0.0, false, false)
		na.animate(0.016, 0.0, false, false)
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://na_view.png")
	cam.position = Vector3(0.45, 0.7, 1.4)
	cam.look_at(Vector3(0.45, 0.62, 0))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://na_close.png")
	print("shot na")
	get_tree().quit()
