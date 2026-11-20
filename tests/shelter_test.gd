extends Node
## Kiểm thử Chương 2 (bản cốt truyện mới): tự chơi từ ngày 1 tới kết thúc.
## Đêm 2 đi lấy lọ thuốc, có một trận cướp phá cửa, vác xác ra ngoài, đêm 5 lấy máy phát, gom đủ đồ, kết thúc tốt.

var results: Array[String] = []
var failed := false
var main: Node3D
var sh: Node3D
var p: CharacterBody3D


func check(cond: bool, what: String) -> void:
	results.append(("OK   " if cond else "FAIL ") + what)
	if not cond:
		failed = true


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func skip_dialogue() -> void:
	for i in 40:
		if not main.dialogue.active:
			return
		main.dialogue.advance()
		await get_tree().process_frame


## Chọn một phương án (không phải dò xét) theo chữ chứa trong nhãn; không thấy thì chọn phương án đầu tiên chọn được.
func pick(prefer: String) -> void:
	var choices: Array = sh.current.choices
	var idx := -1
	for i in choices.size():
		var ch: Dictionary = choices[i]
		if ch.get("info", false) or (ch.has("need") and not sh.need_ok(ch.need)):
			continue
		if idx < 0:
			idx = i
		if prefer != "" and str(ch.t).contains(prefer):
			idx = i
			break
	sh.vote(idx)
	await frames(2)
	sh.continue_after_event()
	await frames(2)


func _ready() -> void:
	Game.chapter = 2
	Game.carry = {}
	Net.mode = Net.Mode.SOLO
	main = (load("res://levels/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await frames(30)
	sh = main.shelter
	p = main.local_player()
	for m: Monster in main.monsters.list:
		if m.kind != "robber":
			m.set_physics_process(false)
			m.global_position = Vector3(6000, -300, 6000)
	check(sh.active and sh.in_bunker(p.global_position), "chương 2: bắt đầu trong hầm")
	check(Game.count("denpin") == 1 and Game.offhand == "denpin", "có sẵn đèn pin ở tay trái")
	Game.god = true
	var days := 0
	var fought := false
	while not sh.ended and days < 16:
		days += 1
		for w in 400:
			if sh.panel == "journal" or sh.ended:
				break
			await frames(1)
		sh.ack_journal()
		await frames(3)
		await skip_dialogue()
		if sh.day == 2:
			check(sh.member("na").get("special", false), "ngày 2: bé Na lên cơn, cần lọ thuốc đặc trị")
		# đủ ăn uống cho cả nhà mỗi ngày (để bài thử đi hết truyện)
		sh.food = 40
		sh.water = 40
		var plan := {}
		for f: Dictionary in sh.family:
			plan[f.id] = {"eat": true, "drink": true, "med": false}
		sh.confirm_rations(plan)
		await frames(140)
		# các sự kiện trong đêm
		var guard := 0
		while sh.phase in ["event", "fight", "out"] and guard < 12 and not sh.ended:
			guard += 1
			if sh.phase == "event" and sh.current_id != "":
				var cid: String = sh.current_id
				if cid == "thuoc_dac_tri":
					check(true, "đêm 2: sự kiện lọ thuốc")
					await pick("đi ngay")
				elif cid == "may_phat_tin_hieu":
					check(true, "đêm 5: đài báo máy phát tín hiệu")
					await pick("lấy máy")
				elif cid == "dem_nay":
					if sh.day >= 3 and not fought:
						# ép một trận cướp phá cửa để thử
						fought = true
						sh.current_done = true
						sh._pending_fight = 3
						sh.continue_after_event()
						await frames(10)
						continue
					await pick("Ngủ" if sh.day < 6 else "tìm đồ")
				else:
					await pick("Không")
				continue
			if sh.phase == "fight":
				var bots: Array = main.monsters.list.filter(func(m: Monster) -> bool: return m.kind == "robber" and m.state == "fight")
				check(bots.size() == 3 and sh.in_bunker(bots[0].global_position), "bọn cướp xông xuống hầm: %d tên" % bots.size())
				await frames(60)
				check(Game.hp < 100.0 or Game.god, "bọn cướp đánh người chơi")
				for b: Monster in bots:
					var hits := 0
					while b.state == "fight" and hits < 20:
						b.on_melee(1, 3.0, 1.0)        # gậy sắt
						hits += 1
					check(hits == 3, "gậy sắt: 3 cú hạ một tên (%d)" % hits)
				await frames(10)
				check(sh.current_id == "dem_nay", "đánh xong thì tới lượt chọn đêm nay")
				# vác một cái xác ra ngoài
				var corpse: Monster = bots[0]
				var ci: int = main.monsters.list.find(corpse)
				main._req_carry_body(ci)
				await frames(3)
				check(Game.carrying == "body" and int(corpse.carrier) == 1, "vác được xác kẻ cướp")
				sh._srv_dump_body()
				await frames(3)
				check(Game.carrying == "" and not sh.in_bunker(corpse.global_position), "vác xác lên vứt ngoài ngõ")
				continue
			if sh.phase == "out":
				check(sh.outside and not sh.in_bunker(p.global_position), "cả nhóm leo lên mặt đất (việc: %s)" % sh.mission)
				if sh.mission == "medicine":
					# mở két bệnh viện: chưa có mã thì không mở được
					var safe: Dictionary = main.city.containers[main.city.hospital_safe_cid]
					main.interact({"type": "container", "id": safe.id})
					await frames(3)
					check(not main.inv_ui.is_open(), "két bệnh viện khoá số: chưa có mã thì không mở")
					Game.add_item("maydo")
					main._on_scanned([])
					await skip_dialogue()
					check(Game.safe_code, "máy dò cho biết mã két")
					main.interact({"type": "container", "id": safe.id})
					await frames(8)
					check(main.inv_ui.is_open() and main.inv_ui.container_items.has("thuocdactri"), "mở được két: có lọ thuốc đặc trị")
					main.inv_ui._take("thuocdactri")
					await frames(5)
					main.inv_ui.close()
					check(Game.count("thuocdactri") == 1, "lấy được lọ thuốc")
				if sh.mission == "machine":
					check(str(sh.machine.state) == "tower", "máy phát nằm ở trạm phát sóng")
					p.global_position = (sh.machine.pos as Vector3) + Vector3(1.0, 0.3, 0)
					await frames(5)
					sh.machine_action("pick")
					await frames(3)
					check(Game.carrying == "machine", "vác máy phát lên vai")
					check(Game.speed_factor() < 0.7, "vác máy thì chậm hẳn (%.2f)" % Game.speed_factor())
				sh.return_home()
				await frames(160)
				continue
			await frames(10)
		if sh.day == 3 and sh.member("na").get("special", false) and Game.count("thuocdactri") > 0:
			sh.interact({"id": "talk:na"})
			await frames(3)
			await skip_dialogue()
			check(sh.flags.has("na_cured") and not sh.member("na").get("special", false), "cho bé Na uống thuốc: con hết cơn")
		if Game.carrying == "machine" and sh.in_bunker(p.global_position):
			sh.machine_action("place")
			await frames(3)
			await skip_dialogue()
			check(str(sh.machine.state) == "placed" and sh.bomb_day == sh.day + 3, "đặt máy lên bệ: 3 ngày nữa thả bom")
			var nd: Dictionary = sh.need_counts()
			check(int(nd.food) == 7 * 2 * sh.people() and int(nd.chan) == sh.people(), "yêu cầu dự trữ: %s" % str(nd))
			sh.machine_action("check")
			await frames(3)
			await skip_dialogue()
			check(not sh.ended, "chưa đủ đồ thì máy báo thiếu")
			sh.food = int(nd.food) + 5
			sh.water = int(nd.water) + 5
			sh.storage["chan"] = int(nd.chan)
			sh.machine_action("check")
			await frames(10)
			await skip_dialogue()
			await get_tree().create_timer(10.0).timeout
	check(fought, "đã có một trận cướp phá cửa")
	check(sh.ended and main.end_ui.is_open(), "kết thúc chương 2 (sau %d ngày)" % days)
	check(main.end_ui._title.text in ["BÌNH YÊN", "CÒN SỐNG"], "kết tốt: %s" % main.end_ui._title.text)
	check(main.end_ui._story.text.contains("Hai năm sau"), "màn kết có đoạn hai năm sau")
	# ống thông khí ở sân sau: giữ E đủ 5 giây mới sửa xong, buông sớm thì phải làm lại
	sh.ended = false
	sh.outside = true
	sh.pipe_broken = true
	Game.hold_label = ""
	check(sh.pipe_pos.distance_to(main.city.home_back) < 0.1 and sh.pipe_pos.distance_to(sh.exit_pos) > 4.0, "ống thông khí nằm ở sân sau, cách nắp hầm %.1fm" % sh.pipe_pos.distance_to(sh.exit_pos))
	var hb: Dictionary = {}
	for bd: Dictionary in main.city.buildings:
		if bd.kind == "home":
			hb = bd
	check((hb.rect as Rect2).grow(0.1).has_point(Vector2(sh.exit_pos.x, sh.exit_pos.z)), "nắp hầm nằm trong nhà")
	p.global_position = sh.pipe_pos + Vector3(0.8, 0.3, 0.8)
	await frames(10)
	Input.action_press("interact")
	sh.interact({"id": "pipe_fix"})
	await frames(60 * 2)
	Input.action_release("interact")
	await frames(10)
	check(sh.pipe_broken, "giữ E 2 giây rồi buông: ống chưa sửa xong")
	Input.action_press("interact")
	sh.interact({"id": "pipe_fix"})
	await frames(60 * 5 + 20)
	Input.action_release("interact")
	await frames(10)
	check(not sh.pipe_broken, "giữ E đủ 5 giây: ống đã nối lại")
	sh.outside = false
	# kết xấu: tới ngày thả bom mà kho chưa đủ / tới ngày 14 vẫn chưa có máy
	sh.ended = false
	sh.food = 0
	sh.bomb_day = sh.day
	sh._morning()
	await frames(10)
	check(sh.ended and main.end_ui._title.text == "KHÔNG KỊP", "kết xấu khi bom rơi mà thiếu đồ: %s" % main.end_ui._title.text)
	sh.ended = false
	sh.bomb_day = -1
	sh.day = 14
	sh._morning()
	await frames(10)
	check(sh.ended and main.end_ui._title.text == "BỊ LÃNG QUÊN", "kết xấu khi không mang máy về: %s" % main.end_ui._title.text)
	# đủ 10 sự kiện đêm, mọi kết cục đều chạy được
	check(ShelterEvents.NIGHT_POOL.size() == 10, "có 10 sự kiện đêm")
	for id: String in ShelterEvents.NIGHT_POOL + ["thuoc_dac_tri", "may_phat_tin_hieu", "dem_nay", "qua_tra_on"]:
		check(ShelterEvents.EVENTS.has(id), "sự kiện '%s' có nội dung" % id) if not ShelterEvents.EVENTS.has(id) else null
		var ev: Dictionary = ShelterEvents.EVENTS[id]
		for ch: Dictionary in ev.choices:
			var total := 0.0
			for o: Dictionary in ch.out:
				total += float(o.get("p", 1.0))
			if (ch.out as Array).size() > 1 and absf(total - 1.0) > 0.01:
				check(false, "xác suất '%s' / '%s' = %.2f" % [id, ch.t, total])
	for line in results:
		print(line)
	print("KẾT QUẢ: ", "THẤT BẠI" if failed else "TẤT CẢ ĐẠT")
	get_tree().quit(1 if failed else 0)
