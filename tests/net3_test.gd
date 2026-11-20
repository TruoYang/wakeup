extends Node
## Kiểm thử co-op Quỷ Mắt (2 tiến trình: `-- host` và `-- join`): khách đi lại trong vệt sáng → bị quấn, nhấc lên
## trên chính máy khách; chủ phòng đập xúc tu → nó nhả, khách rơi xuống và đi lại được.

var role := "host"
var ok := true


func say(cond: bool, what: String) -> void:
	print("[%s3] %s %s" % [role, "OK  " if cond else "FAIL", what])
	if not cond:
		ok = false


func until(cond: Callable, max_frames: int) -> bool:
	var n := 0
	while not cond.call() and n < max_frames:
		await get_tree().physics_frame
		n += 1
	return cond.call()


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


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
	await until(func() -> bool: return sh.active, 900)
	var te: Monster = null
	for m: Monster in main.monsters.list:
		if m.kind == "towereye":
			te = m
		elif role == "host" and m.kind != "robber":
			m.set_physics_process(false)
			m.global_position = Vector3(5000, -300, 5000)
			m.state = "dormant"
	say(await until(func() -> bool: return te.awake, 600), "Quỷ Mắt thức trên máy này")
	say(te.n_tents() == 7, "co-op: %d xúc tu" % te.n_tents())
	for i in 80:
		if main.dialogue.active:
			main.dialogue.advance()
		await frames(2)
	sh.ui.close_all()
	var p: CharacterBody3D = main.local_player()
	Game.hp = 100.0
	if role == "join":
		Input.action_press("move_forward")
		var n := 0
		while not Game.grabbed and n < 60 * 20:
			var g: Vector3 = te.tents[0].g
			p.global_position = Vector3(g.x, City.BASE + 0.3, g.z)
			await frames(1)
			n += 1
		Input.action_release("move_forward")
		say(Game.grabbed, "khách đi lại trong vệt sáng: bị quấn (%.1f giây)" % (n / 60.0))
		await frames(120)
		say(p.global_position.y > City.BASE + 1.5, "khách bị nhấc lên trên máy mình (cao %.1fm)" % (p.global_position.y - City.BASE))
		say(await until(func() -> bool: return not Game.grabbed, 60 * 20), "chủ phòng đập xúc tu: khách được thả")
		await frames(90)
		say(p.global_position.y < City.BASE + 0.8, "khách rơi xuống đất")
		say(Game.hp < 100.0, "khách bị siết mất máu (%.0f)" % Game.hp)
	else:
		var cid := 0
		for q in players.get_children():
			if q != p:
				cid = q.get_multiplayer_authority()
		var gi := [-1]
		var find_grab := func() -> bool:
			for i2 in te.n_tents():
				if int(te.tents[i2].st) == 2 and int(te.tents[i2].holder) == cid:
					gi[0] = i2
					return true
			return false
		say(await until(find_grab, 60 * 25), "máy chủ: một xúc tu đang quấn khách")
		await frames(150)
		var hits := 0
		while gi[0] >= 0 and int(te.tents[gi[0]].st) == 2 and hits < 10:
			te.on_melee(1, 1.0, 1.0)
			hits += 1
			await frames(40)
		say(gi[0] >= 0 and int(te.tents[gi[0]].st) == 3, "chủ phòng đập %d cú: xúc tu nhả khách" % hits)
		await frames(200)
	print("[%s3] %s" % [role, "ĐẠT" if ok else "THẤT BẠI"])
	await frames(60)
	get_tree().quit(0 if ok else 1)
