extends Node
## Kiểm thử tự động chơi đơn: thế giới, di chuyển, va chạm, cầu thang, bơi, đồ đạc, nhiệm vụ.

var results: Array[String] = []
var failed := false
var main: Node3D
var p: CharacterBody3D


func check(cond: bool, what: String) -> void:
	results.append(("OK   " if cond else "FAIL ") + what)
	if not cond:
		failed = true


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func place(pos: Vector3, yaw := 0.0) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.rotation.y = yaw
	await frames(20)


func walk(n: int, action := "move_forward") -> void:
	Input.action_press(action)
	await frames(n)
	Input.action_release(action)


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	main = (load("res://levels/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await frames(30)
	p = main.local_player()
	var city: City = main.city
	main.monsters.set_physics_process(false)     # bài này chỉ thử cơ chế; quái vật có bài riêng
	main.civs.set_physics_process(false)
	check(p != null, "có nhân vật")
	check(p.is_on_floor(), "đứng trên sàn văn phòng (y=%.2f)" % p.global_position.y)
	check(main.is_indoors(p.global_position), "bắt đầu trong nhà")

	# --- đi bộ ngoài đường
	# tìm một đoạn đường trống 40m về phía đông (không có xe, đống đổ nát)
	var clear_start := Vector3(City.road_x(1), 0.3, City.road_z(1) + 2.0)
	for j in City.ROWS + 1:
		for off: float in [2.0, -2.0, 4.5, -4.5]:
			for i in City.COLS:
				var c := Vector3(City.road_x(i) + 9.0, 0.3, City.road_z(j) + off)
				var ok := true
				for h: float in [0.4, 1.0]:
					for side: float in [-0.5, 0.0, 0.5]:
						var q := PhysicsRayQueryParameters3D.create(c + Vector3(-1, h, side), c + Vector3(42, h, side), 3)
						if not get_viewport().world_3d.direct_space_state.intersect_ray(q).is_empty():
							ok = false
				if ok and clear_start.x == City.road_x(1):
					clear_start = c
	await place(clear_start, -PI * 0.5)
	var a := p.global_position
	await walk(120)
	var d := p.global_position.distance_to(a)
	check(d > 6.0 and d < 9.5 and p.global_position.x > a.x + 5.0, "đi bộ 2 giây được %.1fm về phía đông" % d)
	check(p.surface == "asphalt", "bề mặt dưới chân: %s (đường nhựa)" % p.surface)
	Input.action_press("sprint")
	a = p.global_position
	await walk(120)
	Input.action_release("sprint")
	check(p.global_position.distance_to(a) > 12.0, "chạy 2 giây được %.1fm" % p.global_position.distance_to(a))
	check(Game.noise > 0.6, "chạy thì ồn (%.2f)" % Game.noise)
	p.set_crouching(true)
	await walk(90)
	check(Game.noise < 0.12, "ngồi đi gần như không ồn (%.2f)" % Game.noise)
	p.set_crouching(false)

	# --- đi chéo lên vỉa hè (lệch 25 độ so với mép vỉa hè)
	var bcd := City.block_center(3, 0)
	var curb_z := bcd.z + City.BD * 0.5
	await place(Vector3(bcd.x - 20.0, 0.3, curb_z + 3.0), 0.0)
	p.rotation.y = -deg_to_rad(65.0)      # gần như đi dọc theo mép, chỉ chếch vào 25 độ
	await frames(5)
	await walk(150)
	check(p.global_position.y > 0.15 and p.global_position.z < curb_z - 0.2, "đi chéo vẫn bước lên được vỉa hè (y=%.2f)" % p.global_position.y)

	# --- hầm đi bộ: đi xuống cầu thang, đi dưới hầm
	var tz: float = city.tunnel.z
	var ex: float = city.tunnel.entrances[0]
	await place(Vector3(ex - 1.5, 0.3, tz), -PI * 0.5)
	await walk(220)
	check(p.global_position.y < City.TUNNEL_FLOOR + 0.4, "đi xuống hầm đi bộ (y=%.2f)" % p.global_position.y)
	check(main.is_indoors(p.global_position), "dưới hầm được tính là có mái che")
	check(not main.monsters.clear_line(Vector3(p.global_position.x + 12.0, 60.0, tz + 20.0), p.global_position + Vector3(0, 1.5, 0)), "dưới hầm: quái vật trên trời không nhìn thấy")

	# --- xe máy
	var bidx := 0
	var wrecks := 0
	for i in main.bikes.list.size():
		if main.bikes.list[i].broken:
			wrecks += 1
	while main.bikes.list[bidx].broken:
		bidx += 1
	check(wrecks > 3 and main.bikes.index_near(main.bikes.list[0].pos if main.bikes.list[0].broken else Vector3(999, 0, 999), 3.0) != 0, "có %d xe hỏng (cháy đen), không lên được" % wrecks)
	var bike0: Dictionary = main.bikes.list[bidx]
	main.bikes.mount(bidx)
	await frames(3)
	check(p.riding_bike(), "lên được xe máy")
	await place(clear_start, -PI * 0.5)
	a = p.global_position
	await walk(120)
	check(p.global_position.distance_to(a) > 14.0, "đi xe 2 giây được %.1fm (nhanh hơn chạy bộ)" % p.global_position.distance_to(a))
	check(Game.noise > 0.8, "đi xe rất ồn (%.2f)" % Game.noise)
	p.stop_riding()
	await frames(3)
	check(not p.riding_bike() and bike0.rider == 0 and (bike0.pos as Vector3).distance_to(p.global_position) < 3.0, "xuống xe: xe nằm lại chỗ vừa dừng")
	check(main.civs.alive_count() > 8, "có dân thường trên phố (%d người)" % main.civs.alive_count())

	# --- Thủy Quái phá nhà: mất tầng trên / sập hẳn, khối nhà dựng lại không lỗi
	var victim: Dictionary = {}
	for bb in city.buildings:
		if bb.kind == "house" and bb.floors >= 4 and not bb.has("yaw"):
			victim = bb
			break
	var vc := (victim.rect as Rect2).get_center()
	var top_before: bool = not main.line_clear(Vector3(vc.x, 80.0, vc.y), Vector3(vc.x, victim.floors * City.FH - 1.0, vc.y))
	main._cl_building_damage(victim.id, "top", 2, false)
	await frames(5)
	var top_after: bool = not main.line_clear(Vector3(vc.x, 80.0, vc.y), Vector3(vc.x, victim.floors * City.FH - 1.0, vc.y))
	check(top_before and not top_after, "nhà bị giật mất 2 tầng trên: phần trên không còn mái/sàn")
	check(not main.line_clear(Vector3(vc.x, 80.0, vc.y), Vector3(vc.x, 0.5, vc.y)), "các tầng dưới của nhà đó vẫn còn")
	main._cl_building_damage(victim.id + 1, "collapse", 1, false)
	await frames(5)
	check(city.buildings[victim.id + 1].get("ruined", false) and city.building_at(Vector3((city.buildings[victim.id + 1].rect as Rect2).get_center().x, 1.0, (city.buildings[victim.id + 1].rect as Rect2).get_center().y)).is_empty(), "nhà sập hẳn thành đống đổ nát")
	check(city.containers.size() == main.loot.info.size() - main.loot.drops.size() - main.loot.bodies.size(), "dựng lại khối nhà không sinh trùng chỗ lục đồ")

	# --- ngủ qua đêm
	main.weather.hour = 22.0
	await frames(3)
	check(main.darkness() > 0.9, "22 giờ: trời tối")
	main.hud.start_sleep()
	check(main.ui_open(), "đang ngủ: có cảnh chuyển, không điều khiển được")
	await frames(480)
	check(not main.hud.sleeping(), "cảnh ngủ kết thúc sau khoảng 8 giây")
	check(absf(main.weather.hour - 6.0) < 0.2, "ngủ trên giường: tua tới 6 giờ sáng (%.1f)" % main.weather.hour)
	check(city.beds.size() > 100, "có %d chiếc giường ngủ được" % city.beds.size())
	check(Game.has_clock() == false and main.weather.part_of_day() == "Rạng sáng", "chưa có đồng hồ thì chỉ biết buổi: %s" % main.weather.part_of_day())
	main.weather.hour = 16.8

	# --- tường nhà chặn lại: đi thẳng vào hông dãy nhà
	var block := City.block_center(1, 0)
	await place(Vector3(block.x, 0.3, block.z - City.BD * 0.5 - 3.0), PI)
	await walk(200)
	check(p.global_position.z < block.z - City.BD * 0.5 + 2.3, "tường mặt tiền chặn lại (z=%.1f)" % (p.global_position.z - (block.z - City.BD * 0.5)))

	# --- vào nhà qua cửa, leo cầu thang lên tầng 2
	var house: Dictionary = {}
	for b in city.buildings:
		if b.kind == "house" and b.floors >= 3 and b.s > 0.0 and not b.has("yaw"):
			house = b
			break
	var s: float = house.s
	var o: Vector3 = house.origin
	await place(Vector3(o.x + s * -1.15, o.y + 0.1, o.z + s * 1.5), 0.0 if s > 0 else PI)
	await walk(70)
	check(main.is_indoors(p.global_position), "đi qua cửa vào nhà")
	check(p.surface in ["tile", "concrete", "wood"], "bề mặt trong nhà: %s" % p.surface)
	# tới chân cầu thang (ô bên phải, phía sau nhà) rồi đi lên
	var hw: float = house.w * 0.5
	var stair_x := hw - City.T - 0.575
	await place(Vector3(o.x + s * stair_x, o.y + 0.1, o.z + s * (-house.d + 6.0)), 0.0 if s > 0 else PI)
	await walk(150)
	check(p.global_position.y > o.y + City.FH - 0.3, "leo cầu thang lên tầng 2 (cao %.2fm)" % (p.global_position.y - o.y))
	# bước sang sàn tầng 2 và đứng yên được
	await walk(40, "move_left")
	await frames(30)
	check(absf(p.global_position.y - (o.y + City.FH)) < 0.25 and p.is_on_floor(), "đứng vững trên sàn tầng 2 (y=%.2f)" % (p.global_position.y - o.y))

	# --- hồ: lội xuống, bơi, lặn, nín thở
	var lake := city.lake_rect
	var lc := lake.get_center()
	await place(Vector3(lc.x, City.WATER_Y - 1.5, lc.y), 0.0)
	await frames(60)
	check(p.swimming, "ở giữa hồ thì bơi")
	var float_depth := City.WATER_Y - p.global_position.y
	check(float_depth > 1.2 and float_depth < 1.8, "thả lỏng thì nổi, đầu nhô khỏi mặt nước (chân sâu %.2fm)" % float_depth)
	check(Game.breath > 99.0, "nổi trên mặt nước thì thở bình thường")
	Input.action_press("crouch")
	await frames(120)
	Input.action_release("crouch")
	var dive := City.WATER_Y - p.global_position.y
	check(dive > 3.0, "bấm C thì lặn xuống (sâu %.1fm)" % dive)
	check(Game.breath < 95.0, "lặn thì hơi thở giảm (%.0f)" % Game.breath)
	check(Game.submerged, "camera dưới mặt nước")
	check(p.global_position.y > -City.LAKE_DEPTH - 0.6, "không xuyên đáy hồ (y=%.2f)" % p.global_position.y)
	Input.action_press("jump")
	await frames(150)
	Input.action_release("jump")
	check(City.WATER_Y - p.global_position.y < 1.8, "bấm Space thì nổi lên")
	# bơi về bờ tây (bờ thoải) rồi đi lên bờ
	await place(Vector3(lake.position.x + 14.0, City.WATER_Y - 1.5, lc.y), 0.0)
	p.rotation.y = PI * 0.5
	p.pitch = 0.0
	p.head.rotation.x = 0.0
	await walk(700)
	check(not p.swimming and p.global_position.y > 0.0, "bơi vào bờ thoải và đi lên được (y=%.2f, x=%.1f)" % [p.global_position.y, p.global_position.x - lake.position.x])

	# --- đồ đạc: lục một chỗ, lấy đồ
	var con: Dictionary = city.containers[0]
	var got := []
	main.loot.opened.connect(func(_cid: int, items: Array) -> void: got.append_array(items))
	main.loot.open(con.id)
	await frames(5)
	check(got.size() > 0, "mở %s có %d món" % [con.name, got.size()])
	var before := Game.count(got[0])
	main.loot.take(con.id, got[0])
	await frames(5)
	check(Game.count(got[0]) == before + 1 or Items.get_def(got[0]).has("wallet") or Items.get_def(got[0]).has("ammo"), "lấy được %s vào túi" % Items.item_name(got[0]))
	Game.food = 40.0
	Game.add_item("banhmi", 1, true)
	Game.use_item("banhmi")
	check(Game.food > 60.0, "ăn bánh mì thì bớt đói (%.0f)" % Game.food)
	Game.damage(30.0, "slash", "arm_l")
	check(Game.has_injury("bleed", "arm_l"), "bị cào thì chảy máu ở tay")
	Game.add_item("bang", 1, true)
	Game.use_item("bang")
	check(not Game.has_injury("bleed"), "băng gạc cầm được máu")

	# --- nhiệm vụ: về nhà gặp vợ con -> lục nhà ông Tư lấy xà beng -> về cạy hầm
	await place(city.home_pos + Vector3(0, 0.2, 0))
	await frames(10)
	check(main.stage == 0, "về tới nhà chưa đổi nhiệm vụ: phải nói chuyện với vợ con trước")
	var wife := -1
	for i in main.npcs.list.size():
		if main.npcs.list[i].kind == "wife":
			wife = i
	check(wife >= 0 and (main.npcs.list[wife].pos as Vector3).distance_to(p.global_position) < 6.0, "vợ đang ở trong nhà, gần chỗ bạn đứng")
	main._talk_family(wife)
	check(main.dialogue.active and Game.talking, "nói chuyện với vợ: hiện hội thoại phụ đề, khoá điều khiển")
	for k in 30:
		if not main.dialogue.active:
			break
		main.dialogue.advance()
		await get_tree().process_frame
	await frames(5)
	check(main.stage == 1 and Game.objective.contains("ông Tư"), "nói chuyện với vợ: nhiệm vụ mới là sang nhà ông Tư")
	var box := -1
	for con2 in city.containers:
		if con2.table == "tu_box":
			box = con2.id
	var tu_items := []
	main.loot.opened.connect(func(cid: int, items: Array) -> void:
		if cid == box:
			tu_items.assign(items))
	main.loot.open(box)
	await frames(5)
	check(tu_items.has("xabeng"), "hòm đồ nghề trong nhà ông Tư có xà beng")
	main.loot.take(box, "xabeng")
	await frames(10)
	check(Game.count("xabeng") == 1 and main.stage == 2, "lấy được xà beng: nhiệm vụ chuyển sang về cạy hầm")
	main.interact({"type": "hatch", "id": 0})
	await frames(5)
	check(main.stage == 3 and Game.won, "cạy cửa hầm: thắng")

	for r in results:
		print(r)
	print("KẾT QUẢ: ", "THẤT BẠI" if failed else "TẤT CẢ ĐẠT")
	get_tree().quit(1 if failed else 0)
