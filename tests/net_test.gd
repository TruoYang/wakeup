extends Node
## Kiểm thử co-op: chạy 2 tiến trình, một `-- host`, một `-- join`.
## Chủ phòng đi về phía trước; khách phải thấy nhân vật chủ phòng dịch chuyển, và ngược lại khi khách ngồi xuống.

func _ready() -> void:
	var role := "host"
	for a in OS.get_cmdline_user_args():
		role = a
	Net.my_name = "Chu" if role == "host" else "Khach"
	Net.mode = Net.Mode.HOST if role == "host" else Net.Mode.JOIN
	Net.address = "127.0.0.1"
	var main: Node3D = (load("res://levels/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var players: Node3D = main.get_node("Players")
	# đợi đủ 2 người
	var waited := 0
	while players.get_child_count() < 2 and waited < 3600:
		await get_tree().physics_frame
		waited += 1
	print("[%s] số người chơi: %d · danh sách: %s" % [role, players.get_child_count(), str(Net.players.values())])
	if players.get_child_count() < 2:
		print("[%s] FAIL không đủ 2 người" % role)
		get_tree().quit(1)
		return
	var me: CharacterBody3D = main.local_player()
	var other: CharacterBody3D = null
	for p in players.get_children():
		if p != me:
			other = p
	print("[%s] tôi=%s (điều khiển: %s) · người kia=%s (điều khiển: %s)" % [role, me.name, me.is_local(), other.name, other.is_local()])
	var other_start := other.global_position
	var my_start := me.global_position
	if role == "host":
		Input.action_press("move_forward")
	else:
		me.set_crouching(true)
		Input.action_press("move_back")
	for i in 150:
		await get_tree().physics_frame
	Input.action_release("move_forward")
	Input.action_release("move_back")
	var other_moved := other.global_position.distance_to(other_start)
	var i_moved := me.global_position.distance_to(my_start)
	print("[%s] cờ của người kia=%d, cờ của tôi=%d, tôi ngồi=%s" % [role, other.net_flags, me.net_flags, me.crouching])
	print("[%s] tôi đi %.1fm · thấy người kia đi %.1fm · người kia đang ngồi: %s · camera của tôi đang dùng: %s" % [role, i_moved, other_moved, other.crouching, me.get_node("Head/Arm/Camera").current])
	var ok := false
	if role == "host":
		ok = i_moved > 3.0 and other_moved > 2.0 and other.crouching
	else:
		ok = other_moved > 3.0 and i_moved > 2.0 and not other.crouching
	# --- đồ đạc, sát thương và quái vật qua mạng
	if role == "join":
		var hurt_total := [0.0]
		Game.hurt.connect(func(a: float, _k: String) -> void: hurt_total[0] += a)
		var got := []
		main.loot.opened.connect(func(_c: int, items: Array) -> void: got.append_array(items))
		main.loot.open(3)
		await get_tree().create_timer(0.6).timeout
		var item: String = got[0] if got.size() > 0 else ""
		var before := Game.count(item)
		if item != "":
			main.loot.take(3, item)
		await get_tree().create_timer(0.6).timeout
		var took: bool = item != "" and (Game.count(item) == before + 1 or Items.get_def(item).has("wallet") or Items.get_def(item).has("ammo"))
		print("[join] mở tủ qua mạng: %d món · lấy %s: %s" % [got.size(), Items.item_name(item), took])
		var w := 0.0
		while hurt_total[0] <= 0.0 and w < 6.0:
			await get_tree().create_timer(0.1).timeout
			w += 0.1
		print("[join] chờ sát thương %.1fs" % w)
		print("[join] máu sau khi chủ phòng gây sát thương: %.0f (nhận %.1f sát thương)" % [Game.hp, hurt_total[0]])
		var st: Monster = main.monsters.list[2]
		print("[join] Săn Mồi ở %s (đã nhận dữ liệu: %s)" % [st.global_position.round(), st._has_net])
		ok = ok and took and hurt_total[0] > 0.0 and st._has_net
	else:
		await get_tree().create_timer(1.4).timeout
		main.hurt_player(other.get_multiplayer_authority(), 20.0, "crush", "torso")
		await get_tree().create_timer(6.0).timeout
		print("[host] Săn Mồi ở %s" % main.monsters.list[2].global_position.round())
	print("[%s] %s" % [role, "ĐẠT" if ok else "FAIL"])
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(0 if ok else 1)
