extends Node3D
## Ảnh duyệt tay góc nhìn thứ nhất (chưa áp vào game): dựng tay + đồ vật thật của game trên nền trung tính,
## chụp từng tư thế để người duyệt chốt trước. Thông số đúng như bản thử đã được khen (góc nhìn 50°, vai lùi sau
## camera 0,12m, không kéo dài tay, khuỷu tay hướng xuống).

var cam: Camera3D
var fp: FPArms
var grips := {}
var items := {}


func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.6, 0.66)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	floor_mi.mesh = pm
	floor_mi.position.y = -1.6
	add_child(floor_mi)
	cam = Camera3D.new()
	cam.near = 0.02
	cam.fov = 50.0
	add_child(cam)
	cam.current = true
	# cả cụm tay (vai, khuỷu, điểm nắm) ngẩng lên một góc so với camera để tay nằm trọn trong khung hình
	var rig := Node3D.new()
	rig.rotation.x = 0.24
	cam.add_child(rig)
	fp = FPArms.new()
	fp.use_overlay = false
	fp.arm_scale = 1.0
	fp.shoulder_shift = Vector3(0.0, 0.0, 0.12)
	rig.add_child(fp)
	for s: String in ["r", "l"]:
		var g := Node3D.new()
		rig.add_child(g)
		grips[s] = g
		# đồ vật thật của game, gắn theo điểm nắm giống player.gd (trục cán = trục Y của điểm nắm)
		var holder := Node3D.new()
		holder.position = Vector3(0, 0.03, 0)
		g.add_child(holder)
		var fl := ItemModels.make("denpin")
		fl.scale = Vector3.ONE * 1.0
		fl.rotation = Vector3(0, 0, PI * 0.5)
		fl.position = Vector3(0.044, 0.05, 0.0)
		holder.add_child(fl)
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.04, 0.9, 0.04)
		bar.mesh = bm
		var mm := StandardMaterial3D.new()
		mm.albedo_color = Color("8a8e94")
		mm.metallic = 0.8
		mm.roughness = 0.45
		bar.material_override = mm
		bar.position = Vector3(0, 0.3, -0.16)
		bar.rotation.x = -0.55          # gậy chúi về phía trước như khi cầm thật
		holder.add_child(bar)
		items[s] = {"flash": fl, "bar": bar}
	# kiểu đỡ đèn như ảnh tham khảo 4
	var a4 := Vector3(-0.75, 0.2, -0.62).normalized()
	var f4 := (Vector3.UP - a4 * a4.dot(Vector3.UP)).normalized()
	var n4 := a4.cross(f4)
	var b4 := Basis(-n4, a4, (-n4).cross(a4)).orthonormalized()
	var mirror := func(b: Basis) -> Basis:
		var m := Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))
		return m * b * m
	# [tay, vị trí, hướng, nắm úp?, độ nắm, hướng khuỷu, đồ cầm]
	var flash_over_l := ["l", Vector3(-0.19, -0.12, -0.29), Basis.from_euler(Vector3(-PI * 0.5 + 0.05, -0.3, 0.0)), true, 1.0, Vector3(-0.45, -1.0, 0.1), "flash"]
	var flash_hold_r := ["r", Vector3(0.17, -0.13, -0.29), b4, false, 0.95, Vector3(0.5, -1.0, 0.0), "flash"]
	var flash_hold_l := ["l", Vector3(-0.17, -0.13, -0.29), mirror.call(b4), false, 0.95, Vector3(-0.5, -1.0, 0.0), "flash"]
	var bar_r := ["r", Vector3(0.19, -0.19, -0.31), Basis.from_euler(Vector3(-0.15, 0.25, 0.0)), false, 0.95, Vector3(0.45, -1.0, 0.1), "bar"]
	var fist_r := ["r", Vector3(0.17, -0.15, -0.3), Basis.from_euler(Vector3(0.25, 0.12, 0.0)), false, 1.15, Vector3(0.45, -1.0, 0.1), ""]
	var fist_l := ["l", Vector3(-0.17, -0.15, -0.3), Basis.from_euler(Vector3(0.25, -0.12, 0.0)), false, 1.15, Vector3(-0.45, -1.0, 0.1), ""]
	var sets := {
		"A_den_up_tay_trai": [flash_over_l],
		"B_den_do_tay_phai": [flash_hold_r],
		"C_gay_sat_tay_phai": [bar_r],
		"D_nam_dam": [fist_r, fist_l],
		"E_den_trai_gay_phai": [flash_hold_l, bar_r],
	}
	var variant := "gang"
	for a in OS.get_cmdline_user_args():
		variant = a
	if variant == "tran":
		fp.body_mesh.set_instance_shader_parameter("glove_on", 0.0)
	for k: String in sets:
		fp.relax("l")
		fp.relax("r")
		for s2: String in ["r", "l"]:
			grips[s2].visible = false
		for pe: Array in sets[k]:
			var g2: Node3D = grips[pe[0]]
			g2.visible = true
			g2.transform = Transform3D(pe[2], pe[1])
			g2.set_meta("reverse", pe[3])
			g2.set_meta("thumb", 0.0 if pe[3] else 0.35)
			g2.set_meta("thumb_curl", 3.5 if pe[3] else 1.0)
			fp.grip_amt[pe[0]] = pe[4]
			(items[pe[0]].flash as Node3D).visible = pe[6] == "flash"
			(items[pe[0]].bar as Node3D).visible = pe[6] == "bar"
		for i in 3:
			for pe2: Array in sets[k]:
				fp.solve(pe2[0], grips[pe2[0]], pe2[5])
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://duyet_%s_%s.png" % [variant, k])
		print("shot ", k)
	get_tree().quit()
