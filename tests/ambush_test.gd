extends Node
## Phục kích Cua Quỷ khi vác máy phát tín hiệu: chỉ có ở chế độ Khó hoặc co-op.

var results: Array[String] = []
var failed := false
var main: Node3D


func check(cond: bool, what: String) -> void:
	results.append(("OK   " if cond else "FAIL ") + what)
	if not cond:
		failed = true


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _crawlers_up(near: Vector3, r: float) -> Array:
	var out: Array = []
	for m: Monster in main.monsters.list:
		if m.kind == "crawler" and m.state != "dormant" and m.state != "dead" and m.global_position.distance_to(near) < r:
			out.append(m)
	return out


func _ready() -> void:
	main = (load("res://levels/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await frames(30)
	var p: CharacterBody3D = main.local_player()
	var city: City = main.city
	var sh: Node = main.shelter
	main.civs.set_physics_process(false)
	Game.god = true            # không bị cắn chết giữa bài thử
	# đứng ở sân trạm phát sóng, vác máy
	var at := city.radio_pos + Vector3(4.0, 0.3, 4.0)
	p.global_position = at
	for m: Monster in main.monsters.list:
		if m.kind == "crawler":
			m.state = "dormant"
			m.global_position = Vector3(0, -60, 0)
	main.monsters.set("_wave_t", 9999.0)        # tắt đợt thường cho khỏi lẫn
	# --- chế độ Thường, chơi một mình: không phục kích
	Game.difficulty = "normal"
	sh.machine = {"state": "carried", "pos": at, "carrier": p.get_multiplayer_authority()}
	await frames(120)
	check(_crawlers_up(at, 150.0).is_empty(), "chế độ Thường, một mình: vác máy không có Cua Quỷ phục kích")
	sh.machine = {"state": "tower", "pos": at, "carrier": 0}
	await frames(10)
	# --- chế độ Khó: phục kích ngay khi nhấc máy
	Game.difficulty = "hard"
	sh.machine = {"state": "carried", "pos": at, "carrier": p.get_multiplayer_authority()}
	await frames(10)
	var up := _crawlers_up(at, 120.0)
	check(up.size() >= 3, "chế độ Khó: nhấc máy lên là có %d Cua Quỷ trồi lên quanh trạm" % up.size())
	var d0 := 0.0
	for m: Monster in up:
		d0 += m.global_position.distance_to(p.global_position)
	await frames(60 * 12)
	p.global_position = at
	var d1 := 0.0
	for m2: Monster in up:
		d1 += m2.global_position.distance_to(p.global_position)
	check(up.size() > 0 and d1 < d0 - 10.0, "Cua Quỷ mò tới chỗ người vác máy (khoảng cách trung bình %.0fm -> %.0fm)" % [d0 / maxf(1, up.size()), d1 / maxf(1, up.size())])
	var inside := 0
	for m3: Monster in up:
		if not city.building_at(m3.global_position).is_empty() and m3.state != "chase":
			inside += 1
	check(inside == 0, "không con nào trồi lên giữa khối nhà")
	# --- vẫn vác máy: thêm đợt sau khoảng 40-55 giây
	var before := _crawlers_up(at, 200.0).size()
	for m4: Monster in main.monsters.list:
		if m4.kind == "crawler":
			m4.state = "dormant"
			m4.global_position = Vector3(0, -60, 0)
	main.monsters.set("_signal_t", 0.5)
	await frames(60)
	check(_crawlers_up(at, 150.0).size() >= 2, "vác máy lâu: có thêm đợt Cua Quỷ (trước %d con)" % before)
	# --- đặt máy xuống: hết phục kích
	sh.machine = {"state": "placed", "pos": at, "carrier": 0}
	for m5: Monster in main.monsters.list:
		if m5.kind == "crawler":
			m5.state = "dormant"
			m5.global_position = Vector3(0, -60, 0)
	main.monsters.set("_signal_t", 0.5)
	await frames(90)
	check(_crawlers_up(at, 150.0).is_empty(), "máy đã đặt xuống: không còn phục kích")
	Game.difficulty = "normal"
	for r in results:
		print(r)
	print("KẾT QUẢ: ", "CÓ LỖI" if failed else "TẤT CẢ ĐẠT")
	get_tree().quit(1 if failed else 0)
