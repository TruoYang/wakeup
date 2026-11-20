extends Node
## Kiểm thử quái vật: trồi lên, tầm nhìn bị mái/tường che, Thổ Trùng nghe bước chân, sát thương.

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


func place(pos: Vector3) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	await frames(15)


func mon(kind: String) -> Monster:
	for m: Monster in main.monsters.list:
		if m.kind == kind:
			return m
	return null


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	main = (load("res://levels/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await frames(20)
	p = main.local_player()
	var city: City = main.city
	var mgr: Node = main.monsters
	Game.difficulty = "normal"
	main.civs.set_physics_process(false)      # tiếng la của dân thường sẽ kéo quái vật đi chỗ khác, làm nhiễu bài thử
	check(mgr.list.filter(func(m: Monster) -> bool: return m.kind == "worm").size() == 3, "có 3 con Thổ Trùng")
	check(mgr.list.size() == 33 and mgr.list.filter(func(m: Monster) -> bool: return m.kind == "crawler").size() == 12, "có 33 quái vật (12 Cua Quỷ, 6 kẻ cướp, Quỷ Mắt): %s" % ", ".join(mgr.list.map(func(m: Monster) -> String: return m.mname)))

	# --- mái nhà và tường che tầm nhìn
	var house: Dictionary = {}
	var s := 1.0
	var o := Vector3.ZERO
	var street := Vector3.ZERO
	var inside := Vector3.ZERO
	var upstairs := Vector3.ZERO
	var sky_eye := Vector3.ZERO
	var titan_eye := Vector3.ZERO
	var street_eye := Vector3.ZERO
	# chọn một ngôi nhà mà đoạn đường phía trước không có xe hay đống đổ nát che
	for b in city.buildings:
		if b.kind != "house" or b.floors < 3 or b.has("yaw"):
			continue
		house = b
		s = house.s
		o = house.origin
		street = Vector3(o.x, 0.1, o.z + s * 6.0)
		inside = Vector3(o.x + s * 0.5, o.y + 0.05, o.z + s * -8.0)
		upstairs = Vector3(o.x + s * 0.2, o.y + City.FH + 0.05, o.z + s * -5.0)
		sky_eye = Vector3(o.x + 6.0, 34.0, o.z + s * 20.0)       # chỗ Dực Quái bay
		titan_eye = Vector3(o.x - 20.0, 13.5, o.z + s * 7.0)    # mắt Thủy Quái ngoài đường
		street_eye = Vector3(o.x + 25.0, 1.6, o.z + s * 6.0)    # mắt Săn Mồi ngoài đường
		var open := true
		for eye: Vector3 in [sky_eye, titan_eye, street_eye, street + Vector3(40.0, 1.6, 0)]:
			for h: float in [0.25, 0.9, 1.6]:
				if not mgr.clear_line(eye, street + Vector3(0, h, 0)):
					open = false
		if open:
			break
	await place(street)
	check(mgr.sees(sky_eye, p, 90.0) > 0.0, "đứng ngoài đường: Dực Quái trên trời THẤY")
	check(mgr.sees(titan_eye, p, 80.0) > 0.0, "đứng ngoài đường: Thủy Quái THẤY")
	check(mgr.sees(street_eye, p, 48.0) > 0.0, "đứng ngoài đường: Săn Mồi THẤY")
	await place(inside)
	check(mgr.sees(sky_eye, p, 90.0) == 0.0, "trong nhà tầng trệt: Dực Quái KHÔNG thấy (mái và sàn che)")
	check(mgr.sees(titan_eye, p, 80.0) == 0.0, "trong nhà tầng trệt: Thủy Quái KHÔNG thấy")
	check(mgr.sees(street_eye, p, 48.0) == 0.0, "trong nhà, khuất sau tường: Săn Mồi KHÔNG thấy")
	await place(upstairs)
	check(absf(p.global_position.y - (o.y + City.FH)) < 0.3, "đứng trên tầng 2")
	check(mgr.sees(sky_eye, p, 90.0) == 0.0, "tầng 2 dưới mái: Dực Quái KHÔNG thấy")
	# trên mái nhà (lộ thiên) thì lại bị thấy
	var roof := Vector3(o.x, o.y + house.floors * City.FH + 0.1, o.z + s * -7.0)
	await place(roof)
	check(p.global_position.y > o.y + house.floors * City.FH - 0.3, "đứng trên mái")
	check(mgr.sees(sky_eye, p, 90.0) > 0.0, "trên mái nhà lộ thiên: Dực Quái THẤY")
	# ngồi và áo tối màu làm giảm tầm bị thấy
	await place(street)
	var far_eye := street + Vector3(40.0, 1.6, 0)
	check(mgr.sees(far_eye, p, 48.0) > 0.0, "đứng cách 40m ngoài đường: bị thấy")
	p.set_crouching(true)
	await frames(5)
	check(mgr.sees(far_eye, p, 48.0) == 0.0, "ngồi xuống cách 40m: không bị thấy")
	p.set_crouching(false)
	# lặn dưới nước thì không bị thấy
	var lc := city.lake_rect.get_center()
	await place(Vector3(lc.x + 8.0, City.WATER_Y - 3.5, lc.y))
	check(mgr.sees(Vector3(lc.x, 30.0, lc.y), p, 90.0) == 0.0, "lặn dưới hồ: không bị thấy")

	# --- ban đêm: Thủy Quái và Dực Quái không thấy người; Săn Mồi vẫn thấy
	main.weather.hour = 23.0
	await frames(3)
	check(mon("titan").night_blind() and mon("flyer").night_blind(), "ban đêm: Thủy Quái và Dực Quái mù")
	check(absf(mon("titan").pace() - 0.8) < 0.02 and absf(mon("stalker").pace() - 0.8) < 0.02, "ban đêm mọi quái chậm lại khoảng 20%% (x%.2f)" % mon("stalker").pace())
	await place(street)
	var ref_p: Vector3 = p.global_position
	var eye_n := street + (street_eye - street).normalized() * 18.0
	var night_s: float = mgr.sees(eye_n, p, 60.0)
	check(night_s > 0.0, "ban đêm Săn Mồi vẫn thấy người đứng cách 18m (%.2f)" % night_s)
	p.set_crouching(true)
	await frames(10)
	var crouch_s: float = mgr.sees(eye_n, p, 60.0)
	p.set_crouching(false)
	await frames(10)
	check(crouch_s < night_s, "ban đêm ngồi xuống thì khó bị thấy hơn (%.2f < %.2f)" % [crouch_s, night_s])
	main.weather.hour = 14.0
	await frames(3)
	check(not mon("titan").night_blind() and mon("titan").pace() > 0.99, "ban ngày thì nhìn và đi bình thường")

	# --- Thổ Trùng: nghe bước chân chạy, không nghe khi ngồi đi
	var worm := mon("worm")
	await place(Vector3(City.road_x(1) + 2.0, 0.1, City.road_z(1)))
	worm.global_position = p.global_position + Vector3(22.0, 0, 0)
	worm.state = "roam"
	worm.forget()
	p.rotation.y = PI * 0.5
	p.set_crouching(true)
	Input.action_press("move_forward")
	await frames(240)
	var aw_crouch: float = worm.aw.get(1, 0.0)
	check(aw_crouch < 0.05, "ngồi đi 4 giây cách Thổ Trùng 22m: nó không nghe (%.2f)" % aw_crouch)
	p.set_crouching(false)
	Input.action_press("sprint")
	worm.global_position = p.global_position + Vector3(-14.0, 0, 0)
	worm._dest = worm.global_position
	await frames(80)
	Input.action_release("sprint")
	Input.action_release("move_forward")
	check(float(worm.aw.get(1, 0.0)) > 0.5 or worm.hunting(), "chạy hơn 1 giây gần Thổ Trùng: nó nghe thấy (%.2f, %s)" % [worm.aw.get(1, 0.0), worm.state])
	# đứng yên chờ nó tới và trồi lên
	var hp0 := Game.hp
	var erupted := false
	for i in 900:
		await get_tree().physics_frame
		if i % 30 == 0 and worm.state == "track":
			Game.noise = 0.5
			p.net_noise = 0.5
		if worm.state == "warn":
			p.global_position = worm._strike + Vector3(0.5, 0.1, 0)     # đứng đúng chỗ đất đang nứt
		if worm.state == "erupt":
			erupted = true
		if erupted and worm.state == "rest":
			break
	check(erupted, "Thổ Trùng tới nơi và trồi lên")
	check(Game.hp < hp0, "đứng ngay chỗ nó trồi lên thì bị thương (máu %.0f -> %.0f)" % [hp0, Game.hp])

	# --- Thủy Quái trồi lên từ hồ
	Game.reset()
	Game.god = true
	p.net_flags |= 16
	var titan := mon("titan")
	main.home_known = true      # bỏ qua đoạn nhân vật suy nghĩ (đã kiểm ở route_test)
	main.play_time = 30.0
	await frames(620)
	check(titan.state != "dormant" and titan.global_position.y > -1.0, "Thủy Quái đã trồi lên khỏi hồ (trạng thái %s)" % titan.state)
	var t0 := titan.global_position
	await frames(600)
	check(titan.global_position.distance_to(t0) > 8.0, "Thủy Quái đi lại (%.0fm trong 10 giây)" % titan.global_position.distance_to(t0))

	# --- Săn Mồi: thấy người ngoài đường thì đuổi và cắn
	Game.god = false
	p.net_flags &= ~16
	Game.reset()
	var st := mon("stalker")
	var lane := Vector3(City.road_x(3) + 1.0, 0.1, City.road_z(0))
	var found := false
	for j in City.ROWS + 1:
		for i in City.COLS:
			var c := Vector3(City.road_x(i) + 9.0, 0.1, City.road_z(j) + 2.0)
			var ok := true
			for h: float in [0.5, 1.2]:
				for side: float in [-1.2, 0.0, 1.2]:
					if not mgr.clear_line(c + Vector3(-1, h, side), c + Vector3(30, h, side)):
						ok = false
			if ok and not found:
				found = true
				lane = c
	await place(lane)
	for m: Monster in mgr.list:
		if m != st:
			m.set_physics_process(false)
			m.global_position = Vector3(500, m.global_position.y, 500)
	st.mover.global_position = p.global_position + Vector3(22.0, 0.3, 0)
	st.global_position = st.mover.global_position
	st.yaw = -PI * 0.5
	st.state = "patrol"
	st._dest = p.global_position
	var bitten := false
	var hunted := false
	for i in 600:
		await get_tree().physics_frame
		if st.state == "hunt":
			hunted = true
		if Game.hp < 100.0:
			bitten = true
			break
	check(hunted, "Săn Mồi phát hiện và chuyển sang săn")
	check(bitten, "Săn Mồi đuổi kịp và cắn (máu còn %.0f)" % Game.hp)
	check(Game.hunted or Game.awareness > 0.5, "HUD nhận tín hiệu đang bị săn")
	# đánh trả thì nó lùi lại
	st.on_melee(1, 3.0, 1.0)
	await frames(10)
	check(st.state == "stun", "đánh trúng thì Săn Mồi choáng và lùi lại")

	# --- Cua Quỷ: lần theo dấu chân vào tận trong nhà, đập 3 cú thì chết
	for other: Monster in mgr.list:
		if other.kind != "crawler":
			other.set_physics_process(false)
			other.global_position = Vector3(900, 0, 900)
	var chouse: Dictionary = {}
	for hb in city.buildings:
		if hb.kind == "house" and not hb.has("damage") and not hb.has("yaw") and float(hb.w) >= 5.0 and (hb.door as Vector3).distance_to(city.start_pos) > 120.0:
			chouse = hb
			break
	var chs: float = chouse.s
	var cdoor: Vector3 = chouse.door
	Game.hp = 100.0
	Game.injuries.clear()
	await place(cdoor + Vector3(0, 0.1, chs * 3.0))
	for step in 9:
		p.global_position = cdoor + Vector3(0, 0.1, chs * (3.0 - step * 1.0))
		await frames(4)
	var cr: Monster = mon("crawler")
	cr.global_position = cdoor + Vector3(9.0, 0.0, chs * 5.0)
	cr.hp = 5.0
	cr.visible = true
	cr.state = "chase"
	cr.target_id = 1
	cr._ti = -1
	cr._lost = 0.0
	var reached := false
	for i in 900:
		await get_tree().physics_frame
		if Game.hp < 100.0:
			reached = true
			break
	check(reached, "Cua Quỷ lần theo dấu chân, chui qua cửa vào nhà và cắn (còn cách %.1fm, máu %.0f)" % [cr.global_position.distance_to(p.global_position), Game.hp])
	check(city.building_at(cr.global_position).get("id", -1) == chouse.id, "Cua Quỷ đang ở trong nhà")
	for hit in 4:
		cr.on_melee(1, 1.0, 1.0)
	check(cr.state != "dead", "đập 4 cú Cua Quỷ chưa chết")
	cr.on_melee(1, 1.0, 1.0)
	check(cr.state == "dead" and cr.hit_spheres().is_empty(), "đập cú thứ 5 thì Cua Quỷ chết")
	# đợt trồi lên: ép hẹn giờ, phải có 2-3 con rời trạng thái ngủ và leo lên mặt đất
	for c2: Monster in mgr.list:
		if c2.kind == "crawler":
			c2.state = "dormant"
	mgr._wave_t = 0.0
	await frames(3)
	var woke: int = mgr.list.filter(func(m: Monster) -> bool: return m.kind == "crawler" and m.state == "emerge").size()
	check(woke >= 2 and woke <= 3, "một đợt có 2-3 Cua Quỷ trồi lên (%d)" % woke)
	await frames(360)
	var up: int = mgr.list.filter(func(m: Monster) -> bool: return m.kind == "crawler" and m.active() and m.state != "emerge" and m.global_position.y > -0.3).size()
	check(up >= 2, "sau 6 giây chúng đã leo lên mặt đất (%d con)" % up)

	# --- đập vỡ kính cửa sổ
	var gpane: Dictionary = {}
	for cell: Vector2i in city.panes:
		if not (city.panes[cell] as Array).is_empty():
			gpane = city.panes[cell][0]
			break
	var pc: Vector3 = (gpane.box as AABB).get_center()
	var smashed: bool = main.player_smash_glass(pc + Vector3(0, 0, 1.2), Vector3(0, 0, -1), 2.5)
	await frames(5)
	check(smashed and city.pane_at(pc).is_empty(), "đập dụng cụ vào ô kính thì kính vỡ, ô đó trống")

	# --- tiếng súng lục vang xa: Săn Mồi cách 180m cũng kéo về chỗ nổ súng
	var gst: Monster = null
	for gm: Monster in mgr.list:
		if gm.kind == "stalker":
			gst = gm
	gst.state = "patrol"
	gst.target_id = 0
	gst.forget()
	var shot_at: Vector3 = gst.global_position + Vector3(180.0, 0, 0)
	main.gun_noise(shot_at)
	check(gst.state == "search" and (gst.get("_dest") as Vector3).distance_to(shot_at) < 1.0, "tiếng súng cách 180m: Săn Mồi kéo về chỗ nổ súng (%s)" % gst.state)

	# --- Bạch Trùng bò dọc đường
	var grub := mon("grub")
	check(grub.segs.size() == 40, "Bạch Trùng có 40 đốt")

	for r in results:
		print(r)
	print("KẾT QUẢ: ", "THẤT BẠI" if failed else "TẤT CẢ ĐẠT")
	get_tree().quit(1 if failed else 0)
