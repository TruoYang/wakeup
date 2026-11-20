extends Node
## Kiểm thử co-op Chương 2 (2 tiến trình: `-- host` và `-- join`): sổ khẩu phần cả phòng cùng thấy, bỏ phiếu (hoà thì tung xúc xắc),
## cả nhóm cùng ngủ hoặc cùng ra ngoài rồi chui về hầm, sang ngày mới.

var role := "host"
var ok := true


func say(cond: bool, what: String) -> void:
	print("[%s2] %s %s" % [role, "OK  " if cond else "FAIL", what])
	if not cond:
		ok = false


func until(cond: Callable, max_frames: int) -> bool:
	var n := 0
	while not cond.call() and n < max_frames:
		await get_tree().process_frame
		n += 1
	return cond.call()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		role = a
	Net.my_name = "Chu" if role == "host" else "Khach"
	Net.mode = Net.Mode.HOST if role == "host" else Net.Mode.JOIN
	Net.address = "127.0.0.1"
	Game.chapter = 2 if role == "host" else 1
	Game.carry = {}
	var main: Node3D = (load("res://levels/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var players: Node3D = main.get_node("Players")
	if not await until(func() -> bool: return players.get_child_count() >= 2, 6000):
		say(false, "không đủ 2 người")
		get_tree().quit(1)
		return
	var sh: Node3D = main.shelter
	say(await until(func() -> bool: return sh.active and sh.family.size() == 4, 900), "chương 2 bật ở máy này, gia đình có 4 người (%d)" % sh.family.size())
	await frames(60)
	var p: CharacterBody3D = main.local_player()
	say(sh.in_bunker(p.global_position), "người chơi ở trong hầm")
	say(sh.food == 7 and sh.water == 8, "kho tăng theo số người: %d đồ ăn, %d nước" % [sh.food, sh.water])
	say(sh.panel == "journal" and sh.ui.is_open(), "cả phòng thấy sổ ghi ngày 1")
	if role == "host":
		await frames(300)
		sh.ack_journal()
		await frames(30)
		sh.open_rations()
		await frames(30)
		sh.set_plan("me", "eat", true)
		sh.set_plan("p%d" % sh._peers()[1], "drink", true)
		await frames(90)
		sh.confirm_rations(sh.plan)
		say(await until(func() -> bool: return sh.current_id != "" and sh.panel == "event", 600), "đêm 1: có sự kiện ở cửa hầm (%s)" % sh.current_id)
		# thay sự kiện ngẫu nhiên bằng "Đêm nay" cho bài kiểm thử ổn định
		sh.open_event("dem_nay", "night")
		sh._push()
		sh.vote(0)
		say(await until(func() -> bool: return sh.current_done, 900), "hai phiếu khác nhau: tung xúc xắc rồi chốt")
		var went_out: bool = sh._pending_out != ""
		print("[host2] xúc xắc chọn: ", "ra ngoài" if went_out else "ngủ")
		await frames(40)
		sh.continue_after_event()
		if went_out:
			say(await until(func() -> bool: return sh.outside and sh.phase == "out", 300), "cả nhóm cùng ra ngoài")
			await frames(200)
			sh.return_home()
		say(await until(func() -> bool: return sh.day == 2, 2400), "mọi người đã về: sang ngày 2")
	else:
		say(await until(func() -> bool: return sh.panel == "rations" and sh.plan.get("me", {}).get("eat", false), 2400), "khách thấy cuốn sổ chủ phòng đang ghi: %s" % str(sh.plan))
		say(await until(func() -> bool: return sh.current_id == "dem_nay" and sh.panel == "event", 1800), "khách thấy sự kiện ở cửa hầm")
		var me: Dictionary = sh.my_member()
		say(int(me.get("thirst", 9)) == 0 and int(me.get("hunger", 0)) == 1, "khẩu phần chủ phòng chia đã áp vào khách (đói %s, khát %s)" % [me.get("hunger"), me.get("thirst")])
		sh.vote(1)
		say(await until(func() -> bool: return sh.current_done, 900), "khách thấy kết quả bỏ phiếu")
		say(await until(func() -> bool: return sh.outside or sh.day == 2, 1200), "khách đi theo quyết định chung")
		if sh.outside:
			say(p.global_position.y > -1.0, "khách ra ngoài phố cùng cả nhóm")
			say(await until(func() -> bool: return sh.sites.size() >= 1, 600), "khách thấy %d điểm chạm trán do máy chủ đặt" % sh.sites.size())
			await frames(120)
			sh.return_home()
			say(await until(func() -> bool: return not sh.outside and sh.in_bunker(p.global_position), 2400), "khách chui xuống hầm")
		say(await until(func() -> bool: return sh.day == 2, 2400), "khách cũng sang ngày 2")
	print("[%s2] %s" % [role, "ĐẠT" if ok else "THẤT BẠI"])
	await frames(120)
	get_tree().quit(0 if ok else 1)
