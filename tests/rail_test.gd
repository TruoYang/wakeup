extends Node
## Kiểm thử đường sắt trên cao: leo cầu thang lên ga, tầm nhìn của quái, rào sân ga, nhảy xuống chỗ gãy.

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


func face(dir: Vector3) -> void:
	p.rotation.y = atan2(-dir.x, -dir.z)
	p.pitch = 0.0
	p.head.rotation.x = 0.0


func walk(n: int, jump_at := -1) -> void:
	Input.action_press("move_forward")
	for i in n:
		if i == jump_at:
			Input.action_press("jump")
		if i == jump_at + 6:
			Input.action_release("jump")
		await get_tree().physics_frame
	Input.action_release("move_forward")
	Input.action_release("jump")


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	main = (load("res://levels/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await frames(20)
	p = main.local_player()
	for m: Monster in main.monsters.list:
		m.set_physics_process(false)
		m.global_position = Vector3(5000, -100, 5000)
	main.monsters.set_physics_process(false)
	var rl: Rail = main.city.rail
	check(rl.stations.size() == 6 and rl.gaps.size() == 2 and rl.trains.size() == 2, "tuyến có 6 ga, 2 đoạn gãy, 2 đoàn tàu (dài %dm)" % int(rl.length))
	# --- có khúc cua: hướng tuyến đổi ít nhất 4 lần
	var turns := 0
	var prev_t := (rl.frame(0.0).t as Vector3)
	var s := 10.0
	while s < rl.length:
		var tt := (rl.frame(s).t as Vector3)
		if prev_t.angle_to(tt) > 1.2:
			turns += 1
			prev_t = tt
		s += 10.0
	check(turns >= 4, "tuyến rẽ %d lần (có khúc cua)" % turns)
	# --- leo cầu thang lên ga
	var st: Dictionary = rl.stations[2]
	var f0: Dictionary = rl.frame(st.s)
	var base: Vector3 = st.stair_base
	var top: Vector3 = st.stair_top
	Game.god = false
	Game.hp = 100.0
	p.global_position = base - (top - base).normalized() * 1.5 + Vector3(0, 0.4, 0)
	p.velocity = Vector3.ZERO
	await frames(10)
	face(top - base)
	await walk(330)
	check(p.global_position.y > Rail.DECK_Y - 0.6, "leo cầu thang lên tới chiếu nghỉ (y=%.1f)" % p.global_position.y)
	# rẽ vào sân ga qua ô cửa
	face(-(f0.n as Vector3) * float(st.side))
	await walk(90)
	var lat := absf((p.global_position - (f0.p as Vector3)).dot(f0.n as Vector3))
	check(p.global_position.y > Rail.DECK_Y - 0.6 and lat < Rail.STATION_HALF and lat > Rail.HALF, "đi qua ô cửa vào sân ga, dừng ở rào chắn (y=%.1f, cách tim %.1fm)" % [p.global_position.y, lat])
	# đi vào giữa sân ga
	var f: Dictionary = rl.frame(st.s)
	var plat: Vector3 = (f.p as Vector3) + (f.n as Vector3) * float(st.side) * 6.0 + Vector3(0, Rail.DECK_Y + 0.7, 0)
	p.global_position = plat
	p.velocity = Vector3.ZERO
	await frames(30)
	check(p.is_on_floor() and absf(p.global_position.y - (Rail.DECK_Y + 0.6)) < 0.3, "đứng vững trên sân ga (y=%.2f)" % p.global_position.y)
	# --- tầm nhìn: quái dưới đất không thấy, Thủy Quái trên cao thấy
	var mgr: Node = main.monsters
	var ground_eye := Vector3(p.global_position.x, 7.0, p.global_position.z) + (f.t as Vector3) * 20.0
	var high_eye := ground_eye + Vector3(0, 40.0, 0)
	check(mgr.sees(ground_eye, p, 60.0) == 0.0, "Săn Mồi dưới đường không nhìn thấy người trên sân ga")
	check(mgr.sees(high_eye, p, 120.0) == 0.0 and rl.under_canopy(p.global_position), "đứng dưới mái vòm ga: Thủy Quái trên cao cũng không thấy")
	var deck_out: Vector3 = (rl.frame(st.s + Rail.STATION_LEN * 0.5 + 25.0).p as Vector3) + Vector3(0, Rail.DECK_Y + 0.3, 0)
	p.global_position = deck_out
	await frames(15)
	var high2 := p.global_position + Vector3(20.0, 40.0, 0.0)
	check(not rl.under_canopy(p.global_position) and mgr.sees(high2, p, 120.0) > 0.0, "ra khỏi mái vòm, trên cầu trống: Thủy Quái trên cao thấy")
	p.global_position = plat
	await frames(15)
	# --- lối lên thứ hai ở bên kia đường
	var base2: Vector3 = st.stair_base2
	var top2: Vector3 = st.stair_top2
	p.global_position = base2 - (top2 - base2).normalized() * 1.5 + Vector3(0, 0.4, 0)
	p.velocity = Vector3.ZERO
	await frames(10)
	face(top2 - base2)
	await walk(330)
	check(p.global_position.y > Rail.DECK_Y - 0.6, "leo lối lên thứ hai (bên kia đường) tới chiếu nghỉ (y=%.1f)" % p.global_position.y)
	face((f0.n as Vector3) * float(st.side))
	await walk(90)
	var lat2 := absf((p.global_position - (f0.p as Vector3)).dot(f0.n as Vector3))
	check(p.global_position.y > Rail.DECK_Y - 0.6 and lat2 < Rail.STATION_HALF, "lối thứ hai vào được sân ga (cách tim %.1fm)" % lat2)
	p.global_position = plat
	p.velocity = Vector3.ZERO
	await frames(20)
	# --- rào sân ga: đi thẳng vào thì bị chặn, nhảy thì qua được
	face(-(f.n as Vector3) * float(st.side))
	await walk(70)
	var d_side := ((p.global_position - (f.p as Vector3)) * Vector3(1, 0, 1)).length()
	check(d_side > Rail.HALF, "rào sân ga chặn lại khi đi thẳng vào (cách tim %.1fm)" % d_side)
	await walk(90, 5)
	d_side = ((p.global_position - (f.p as Vector3)) * Vector3(1, 0, 1)).length()
	check(d_side < Rail.HALF, "nhảy qua rào xuống đường ray (cách tim %.1fm)" % d_side)
	# --- chỗ gãy: đi tới mép rồi rơi xuống đống đổ nát, không bị thương nặng
	var g: Vector2 = rl.gaps[0]
	var fg: Dictionary = rl.frame(g.x - 6.0)
	p.global_position = (fg.p as Vector3) + Vector3(0, Rail.DECK_Y + 0.5, 0)
	p.velocity = Vector3.ZERO
	await frames(20)
	Game.hp = 100.0
	face(fg.t as Vector3)
	await walk(150)
	await frames(60)
	check(p.global_position.y < Rail.DECK_Y - 2.0, "đi quá mép chỗ gãy thì rơi xuống (y=%.1f)" % p.global_position.y)
	check(Game.hp > 85.0, "rơi xuống đống đổ nát chỉ xây xước (máu %.0f)" % Game.hp)
	for r in results:
		print(r)
	print("KẾT QUẢ: ", "THẤT BẠI" if failed else "TẤT CẢ ĐẠT")
	get_tree().quit(1 if failed else 0)
