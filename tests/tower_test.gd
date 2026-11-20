extends Node
## Kiểm thử Quỷ Mắt trên tháp phát sóng (Chương 2, chơi một mình): đứng im trong vệt sáng thì không bị thấy,
## đi lại thì bị thấy, bị đuổi, bị quấn và nhấc lên, rơi máy đang vác, mất máu; đập đủ thì nó nhả; trong nhà thì an toàn.

var results: Array[String] = []
var failed := false
var main: Node3D
var p: CharacterBody3D
var te: Monster


func check(cond: bool, what: String) -> void:
	results.append(("OK   " if cond else "FAIL ") + what)
	if not cond:
		failed = true


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func skip_dialogue() -> void:
	for i in 60:
		if not main.dialogue.active:
			return
		main.dialogue.advance()
		await get_tree().process_frame


## Đứng (hoặc đi tại chỗ) đúng giữa vệt sáng của xúc tu 0 trong n khung hình.
func stay_in_beam(n: int, walk: bool, at := Vector3.INF) -> void:
	if walk:
		Input.action_press("move_forward")
	for i in n:
		var g: Vector3 = te.tents[0].g if at == Vector3.INF else at
		if not Game.grabbed:
			p.global_position = Vector3(g.x, p.global_position.y if at == Vector3.INF else at.y, g.z)
		await get_tree().physics_frame
		if int(te.tents[0].st) != 0 and at == Vector3.INF:
			break
	Input.action_release("move_forward")


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Game.chapter = 2
	Game.carry = {}
	Net.mode = Net.Mode.SOLO
	main = (load("res://levels/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await frames(30)
	await skip_dialogue()
	p = main.local_player()
	var sh: Node3D = main.shelter
	sh.ui.close_all()
	sh.ack_journal()
	await skip_dialogue()
	for m: Monster in main.monsters.list:
		if m.kind == "towereye":
			te = m
		elif m.kind != "robber":
			m.set_physics_process(false)
			m.global_position = Vector3(5000, -300, 5000)
			m.state = "dormant"
	check(te != null, "có Quỷ Mắt trong danh sách quái")
	await frames(10)
	check(te.awake, "Chương 2: Quỷ Mắt thức trên tháp")
	check(te.n_tents() == 4, "chơi một mình: %d xúc tu" % te.n_tents())
	Game.hp = 100.0
	# --- đứng im trong vệt sáng
	p.global_position = Vector3(te.tents[0].g.x, City.BASE + 0.3, te.tents[0].g.z)
	await frames(20)
	await stay_in_beam(60 * 4, false)
	check(te.visible, "lại gần tháp: thấy Quỷ Mắt")
	check(int(te.tents[0].st) == 0, "đứng im trong vệt sáng 4 giây: không bị thấy (cảnh giác %.2f)" % float(te.tents[0].a))
	# --- vác máy rồi đi lại trong vệt sáng
	sh.machine = {"state": "carried", "pos": p.global_position, "carrier": 1}
	main._cl_carry("machine")
	await stay_in_beam(60 * 5, true)
	check(int(te.tents[0].st) >= 1, "vác máy đi lại trong vệt sáng: bị thấy (trạng thái %d)" % int(te.tents[0].st))
	var hp0 := Game.hp
	var n := 0
	Input.action_press("move_forward")
	while int(te.tents[0].st) != 2 and n < 60 * 12:
		await frames(1)
		n += 1
	Input.action_release("move_forward")
	check(int(te.tents[0].st) == 2, "xúc tu đuổi tới và quấn lấy (%.1f giây)" % (n / 60.0))
	await frames(100)
	check(Game.grabbed, "người chơi bị giữ lại")
	check(p.global_position.y > City.BASE + 1.5, "bị nhấc lên khỏi mặt đất (cao %.1fm)" % (p.global_position.y - City.BASE))
	check(Game.carrying == "" and str(sh.machine.state) == "ground", "bị quấn thì rơi máy (%s)" % str(sh.machine.state))
	var mp: Vector3 = sh.machine.pos
	check(mp.y < City.BASE + 0.6, "máy rơi xuống đất (cao %.1f)" % mp.y)
	Input.action_press("move_forward")
	var y0 := p.global_position
	await frames(60)
	Input.action_release("move_forward")
	check(p.global_position.distance_to(y0) < 0.3, "bị quấn thì không đi được")
	await frames(120)
	check(Game.hp < hp0, "bị siết mất máu (%.0f → %.0f)" % [hp0, Game.hp])
	# --- đập để thoát
	Game.add_item("gaysat", 1, true)
	Game.equip.weapon = "gaysat"
	var hits := 0
	while Game.grabbed and hits < 12:
		p.attack()
		hits += 1
		await frames(45)
	await frames(10)
	check(not Game.grabbed and int(te.tents[0].st) == 3, "đập %d cú: xúc tu nhả ra và rụt lên tháp" % hits)
	await frames(90)
	check(p.global_position.y < City.BASE + 0.6 and Game.hp > 0.0, "rơi xuống đất an toàn (máu %.0f)" % Game.hp)
	# --- trong phòng máy (có mái) thì vệt sáng không thấy
	te.tents[1].st = 0
	var inside: Vector3 = main.city.radio_pos + Vector3(0, 0.3, 1.5)
	te.tents[1].g = Vector3(inside.x, 0, inside.z)
	te.set("_t_all", 0.0)
	var seen := false
	Input.action_press("move_forward")
	for i in 60 * 4:
		p.global_position = inside
		te.tents[1].g = Vector3(inside.x, 0, inside.z)
		await frames(1)
		if int(te.tents[1].st) != 0:
			seen = true
	Input.action_release("move_forward")
	check(not seen, "đi lại trong phòng máy có mái: không bị thấy")
	# --- máy bị rơi nhặt lại được
	p.global_position = mp + Vector3(0, 0.3, 0.8)
	await frames(5)
	sh.machine_action("pick")
	await frames(5)
	await skip_dialogue()
	check(Game.carrying == "machine", "nhặt lại máy bị rơi")
	for line in results:
		print(line)
	print("KẾT QUẢ: ", "THẤT BẠI" if failed else "TẤT CẢ ĐẠT")
	get_tree().quit(1 if failed else 0)
