extends Node3D
## Ảnh duyệt tay đơn giản (chưa áp vào game). Tham số dòng lệnh: danh sách "kiểu:nắm:xoay" (vd mitten:hold:0.6).

func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.86, 0.86, 0.86)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	e.ambient_light_energy = 0.55
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 25, 0)
	add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 50.0
	cam.near = 0.02
	add_child(cam)
	cam.current = true
	var n := 0
	for arg: String in OS.get_cmdline_user_args():
		var parts := arg.split(":")
		var fx := float(parts[3]) if parts.size() > 3 else -0.15
		var fwd := Vector3(fx, 0.12, -1.0).normalized()
		var z := (Vector3.UP - fwd * fwd.dot(Vector3.UP)).normalized()
		var x := fwd.cross(z)
		var h := SimpleHand.new()
		h.style = parts[0]
		h.grip = parts[1]
		if parts.size() > 5:
			h.glove = Color(parts[5])
		if parts.size() > 6:
			h.sleeve = Color(parts[6])
		var roll := float(parts[2])
		cam.add_child(h)
		var tilt := float(parts[4]) if parts.size() > 4 else 0.0
		h.transform = Transform3D(Basis(Vector3.BACK, tilt) * Basis(fwd, roll) * Basis(x, fwd, z), Vector3(0.07, -0.02, -0.55))
		if h.grip == "hold":
			var fl := ItemModels.make("denpin")
			fl.rotation = Vector3(0, 0, PI * 0.5)
			h.add_child(fl)
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://sh_%d.png" % n)
		print("shot ", n, " ", arg)
		n += 1
		h.queue_free()
		await get_tree().process_frame
	get_tree().quit()
