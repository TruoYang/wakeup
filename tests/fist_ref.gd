extends Node3D
## Bản duyệt tư thế cầm đèn theo ảnh mẫu: cẳng tay gần như dựng đứng từ góc dưới phải, cổ tay gập,
## bàn tay ôm thân đèn từ bên phải (ngón vắt qua mặt trên), đèn chĩa thẳng ra trước.

var cam: Camera3D


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
	cam = Camera3D.new()
	cam.near = 0.02
	cam.fov = 50.0
	add_child(cam)
	cam.current = true
	# [tên, vị trí nắm, xoay đèn (lệch trái / ngẩng), dời vai, hướng khuỷu]
	# [tên, vị trí nắm, hướng đèn (lệch trái, ngẩng), dời vai, hướng khuỷu, gập ngón cái, cuộn ngón cái, xoay quanh thân đèn]
	var vs := []
	var n := 0
	# nắm đấm: [độ nắm ngón, gập ngón cái, cuộn ngón cái, xoay tay, nắm ngược]
	for th: Array in [[1.4, 0.5, -1.4, -0.3, true], [1.4, 0.9, -1.4, -0.3, true], [1.4, 1.3, -1.8, -0.3, true], [1.4, 0.9, -2.2, -0.3, true], [1.6, 1.2, -1.4, -0.3, true], [1.4, 0.0, -2.2, -0.3, true]]:
		n += 1
		vs.append(["f%d" % n, Vector3(0.12, -0.1, -0.5), Vector2(0.15, 0.1), Vector3(0, 0.02, 0.3), Vector3(0.15, -1.0, 0.0), th[1], th[2], th[3], Vector3(0.04, 0, 0), th[0], th[4]])
	for v: Array in vs:
		var fp := FPArms.new()
		fp.use_overlay = false
		fp.arm_scale = 1.0
		fp.shoulder_shift = v[3]
		cam.add_child(fp)
		fp.body_mesh.set_instance_shader_parameter("glove_on", 0.0)
		for att: Node in fp.skel.get_children():
			if att is BoneAttachment3D:
				att.visible = false          # chưa duyệt kiểu tay áo: tạm ẩn ống tay áo khoác
		var g := Node3D.new()
		cam.add_child(g)
		# trục Y của điểm nắm = hướng đèn chĩa: ra trước (-Z), hơi lệch trái và ngẩng lên
		var fwd := Vector3(-(v[2] as Vector2).x, (v[2] as Vector2).y, -1.0).normalized()
		var x := Vector3.UP.cross(fwd).normalized() * -1.0
		if x.x < 0.0:
			x = -x
		var b := Basis(x, fwd, x.cross(fwd)).orthonormalized()
		g.transform = Transform3D(b, v[1])
		g.set_meta("reverse", v[10])       # ngón tay chĩa lên rồi vắt qua mặt trên thân đèn, cổ tay ở dưới
		g.set_meta("fist_thumb", v[5])
		g.set_meta("thumb_curl", v[6])
		g.set_meta("roll", v[7])
		fp.grip_amt["r"] = v[9]
		var holder := Node3D.new()
		holder.position = v[8]
		g.add_child(holder)
		var fl := ItemModels.make("denpin")
		fl.rotation = Vector3(0, 0, PI * 0.5)
		fl.position = Vector3(0.0, 0.0, 0.0)
		holder.add_child(fl)
		fl.visible = false
		for i in 3:
			fp.relax("l")
			fp.solve("r", g, v[4])
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://fist_%s.png" % v[0])
		print("shot ", v[0])
		fp.queue_free()
		g.queue_free()
		await get_tree().process_frame
	get_tree().quit()
