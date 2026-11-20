extends Node3D
## Người dân có tên: chủ cửa hàng (phải trả tiền khi họ còn sống), ông Tư (cho mượn xà beng), đồng nghiệp ở văn phòng.
## Họ đi qua đi lại; quái vật tới gần thì hoảng loạn chạy quanh và la hét (tiếng la kéo quái vật săn mồi tới).

const COWORKERS := ["Anh Hùng", "Chị Lan", "Minh"]
const LINES := {
	"Anh Hùng": ["Anh Hùng: 'Mày thấy cái thứ ngoài hồ chưa?! Nó cao hơn cả toà nhà này!'", "Anh Hùng: 'Tao ở lại đây. Ra đường lúc này là chết.'", "Anh Hùng: 'Trong ngăn bàn có đồ ăn đấy, cứ lấy mà đi.'"],
	"Chị Lan": ["Chị Lan: 'Điện thoại mất sóng rồi… Con chị còn ở trường…'", "Chị Lan: 'Em về với vợ con đi. Đi nép vào nhà, đừng chạy giữa đường.'", "Chị Lan: 'Nghe nói dưới đường phía nam có hầm đi bộ, đi dưới đó an toàn hơn.'"],
	"Minh": ["Minh: 'Em thấy nó giẫm nát cả dãy xe… Nó không nhìn xuống đâu, nhưng mà nó nghe.'", "Minh: 'Ban đêm mấy con to không thấy đường. Nhưng thứ dưới đất thì vẫn nghe bước chân.'", "Minh: 'Anh cầm cái bàn phím kia mà phòng thân. Còn hơn tay không.'"],
}

var city: City
var world: Node
var list: Array[Dictionary] = []
var _last_shout := -99.0


func setup(c: City, w: Node) -> void:
	city = c
	world = w
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var cw := 0
	for spot in c.npc_spots:
		var kind: String = spot.kind
		var h: Humanoid
		if kind in ["wife", "child", "coworker", "hurt"]:
			# nhân vật ở gần: model low-poly góc cạnh (bé Na đã duyệt 19/11, Mai và mọi người cùng kiểu)
			var lp := LowPolyHumanoid.new()
			lp.female = kind in ["wife", "child"] or (kind == "coworker" and cw % 3 == 1)
			lp.child = kind == "child"
			if kind == "child":
				lp.hem_color = Color("e9a62a")
			elif kind == "wife":
				lp.shoe_color = Color("8a6a58")            # dép quai nâu
				lp.sole_color = Color("5a4438")
				lp.roll_cuffs = false
			else:
				lp.shoe_color = Color("2c2a2a")
				lp.sole_color = Color("cfcac2")
				lp.roll_cuffs = false
				lp.sleeves = "long" if kind == "coworker" else "short"
			h = lp
		else:
			h = Humanoid.new()
		add_child(h)
		var nm := "Chủ tiệm"
		var shirt := Color.from_hsv(rng.randf(), 0.35, 0.75)
		if kind == "wife":
			nm = "Mai (vợ bạn)"
			shirt = Color("c86a7a")
		elif kind == "child":
			nm = "Bé Na"
			shirt = Color("f0c850")
		elif kind == "hurt":
			nm = "Người bị thương"
			shirt = Color.from_hsv(rng.randf(), 0.3, 0.6)
		elif kind == "coworker":
			nm = COWORKERS[cw % COWORKERS.size()]
			cw += 1
			shirt = Color("dfe3ea") if cw != 2 else Color("b8c8e8")
		if kind == "wife" or kind == "child":
			h.hair_style = "long"
		if kind == "child":
			h.setup(Color("f2d23a"), Color("4f7fb8"), Color("e2b48c"))
		elif kind == "wife":
			h.setup(Color("d77a8c"), Color("34343e"), Color("e0b08a"))
		else:
			h.setup(shirt, Color("3a3a40"), Color("c99a70"))
		h.position = spot.pos
		h.rotation.y = spot.yaw
		if kind == "child":
			h.scale = Vector3.ONE * 0.72
		var tag := Label3D.new()
		tag.text = nm
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.position.y = 2.0
		tag.pixel_size = 0.0035
		tag.font_size = 48
		tag.outline_size = 10
		tag.visibility_range_end = 12.0
		h.add_child(tag)
		list.append({"kind": kind, "name": nm, "home": spot.pos, "pos": spot.pos, "building": spot.building, "node": h, "alive": true, "hp": 3,
			"tag": tag, "yaw": spot.yaw, "phase": rng.randf() * TAU, "panic": false, "shout": rng.randf_range(1.0, 5.0), "line": 0, "mode": "", "gone": false, "flee_roll": rng.randf(), "punch": 0.0, "need": ["bang", "nuocsuoi", "banhmi", "giamdau", "bang", "nuocsuoi"][list.size() % 6], "helped": false, "axis": Vector3(cos(spot.yaw), 0, -sin(spot.yaw))})


## Giúp người bị thương: đưa món họ cần. Trả về true nếu đã giúp.
func help(idx: int) -> void:
	var n: Dictionary = list[idx]
	if n.helped:
		Game.say("Người đó gật đầu cảm ơn bạn lần nữa.")
		return
	var need: String = n.need
	if Game.count(need) <= 0:
		Game.say("Người bị thương thều thào: 'Làm ơn… tôi cần %s…'" % Items.item_name(need).to_lower())
		return
	Game.remove_item(need)
	Game.helped += 1
	Game.cruelty = maxf(0.0, Game.cruelty - 8.0)
	var gift := 30000 + (idx % 5) * 20000
	Game.money += gift
	Sfx.play("pickup", -6.0)
	Game.say("Bạn đưa %s. Người đó dúi vào tay bạn %s đ: 'Cảm ơn… Đừng đi đường lớn, chỗ nào cũng bị chặn. Đi hầm hoặc luồn qua nhà.'" % [Items.item_name(need).to_lower(), Game.format_money(gift)], "good")
	if multiplayer.is_server():
		_srv_helped(idx)
	else:
		_srv_helped.rpc_id(1, idx)


@rpc("any_peer", "reliable")
func _srv_helped(idx: int) -> void:
	if multiplayer.is_server() and idx >= 0 and idx < list.size():
		_cl_helped.rpc(idx)


@rpc("authority", "reliable", "call_local")
func _cl_helped(idx: int) -> void:
	list[idx].helped = true
	(list[idx].tag as Label3D).text = "Người bạn đã giúp"


func talk(idx: int) -> String:
	var n: Dictionary = list[idx]
	var lines: Array = LINES.get(n.name, ["…"])
	if n.panic:
		return "%s: 'Nó tới rồi! Đừng đứng đó nữa!'" % n.name
	n.line = (int(n.line) + 1) % lines.size()
	return lines[n.line]


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or world.monsters == null:
		return
	var t := Time.get_ticks_msec() * 0.001
	for n in list:
		var h: Humanoid = n.node
		var home: Vector3 = n.home
		var near := cam.global_position.distance_to(home) < 70.0
		h.visible = near and not n.get("hidden", false)
		if not n.alive or not near:
			continue
		# quái vật gần nhất
		var threat_d := 999.0
		var threat := Vector3.ZERO
		for m: Monster in world.monsters.list:
			if m.state == "dormant" or (m.kind == "worm" and m.state != "erupt") or m.kind == "flyer":
				continue
			var d := Vector2(m.global_position.x - home.x, m.global_position.z - home.z).length()
			if d < threat_d:
				threat_d = d
				threat = m.global_position
		n.panic = threat_d < (70.0 if n.kind == "coworker" else 42.0)
		var target := home
		var speed := 0.0
		if n.gone:
			h.visible = false
			continue
		# vợ con nấp yên trong nhà; người bị thương ngồi tại chỗ
		if n.kind in ["wife", "child", "hurt"]:
			h.position = n.pos
			h.animate(delta, 0.0, n.kind != "wife" or n.panic, false)
			continue
		# Quái vật tới gần: một nửa số chủ tiệm bỏ chạy khỏi cửa hàng (hàng trong tiệm khi đó lấy không mất tiền).
		if n.panic and n.kind == "owner" and n.mode == "" and float(n.flee_roll) < 0.5:
			n.mode = "fled"
			if cam.global_position.distance_to(home) < 22.0:
				Game.say("Chủ tiệm bỏ chạy khỏi cửa hàng!")
		if n.mode == "fled":
			var door: Vector3 = city.buildings[int(n.building)].door
			target = door
			speed = 5.5
			if Vector2(n.pos.x - door.x, n.pos.z - door.z).length() < 1.2:
				n.gone = true
		elif n.mode == "fight":
			# đánh trả: đuổi theo người chơi trong tiệm và vung gậy
			var me: CharacterBody3D = world.local_player()
			n.punch = float(n.punch) - delta
			if me and me.global_position.distance_to(home) < 10.0 and not Game.dead:
				target = me.global_position
				speed = 3.6
				if me.global_position.distance_to(n.pos) < 1.7 and float(n.punch) <= 0.0:
					n.punch = 1.3
					h.play_attack()
					Sfx.play_at("hit", n.pos + Vector3(0, 1, 0), 0.0, 6.0)
					Game.damage(9.0, "crush", "torso")
		elif n.mode == "yield":
			speed = 0.0
			target = n.pos
		elif n.panic:
			# chạy cuống cuồng quanh chỗ mình, tránh xa hướng quái vật
			var away := home - threat
			away.y = 0.0
			away = away.normalized() if away.length() > 0.1 else Vector3.FORWARD
			var side := Vector3(-away.z, 0, away.x)
			target = home + away * 1.2 + side * sin(t * 2.3 + float(n.phase)) * 1.6
			speed = 4.5
			n.shout = float(n.shout) - delta
			if float(n.shout) <= 0.0:
				n.shout = randf_range(9.0, 16.0)
				if cam.global_position.distance_to(home) < 16.0 and t - _last_shout > 9.0:
					_last_shout = t
					Game.say("%s hét lên: '%s'" % [n.name, ["Nó tới rồi! Chạy đi!", "Trời ơi cứu với!", "Đừng ra đường!", "Nó kia kìa!"][randi() % 4]], "bad")
				if multiplayer.is_server():
					world.monsters.hear(home, 0.6, "civ")
		else:
			# đi qua đi lại sau quầy / quanh bàn
			var ax: Vector3 = n.axis
			target = home + ax * sin(t * 0.45 + float(n.phase)) * 1.3
			speed = 0.9
		var pos: Vector3 = n.pos
		var to := target - pos
		to.y = 0.0
		var moving := 0.0
		if to.length() > 0.08:
			var step := minf(to.length(), speed * delta)
			pos += to.normalized() * step
			moving = speed if to.length() > 0.25 else 0.0
			n.yaw = lerp_angle(float(n.yaw), atan2(to.x, to.z), minf(1.0, delta * 6.0))
		n.pos = pos
		h.position = pos
		h.rotation.y = n.yaw
		h.animate(delta, moving, n.mode == "yield", false)


## Có chủ tiệm đang trông hàng ở gần `pos` không? (Còn sống, chưa bỏ chạy, chưa đầu hàng.) Có thì lấy hàng phải trả tiền.
func owner_present(building: int, pos: Vector3) -> bool:
	for n in list:
		if n.building == building and n.kind == "owner" and n.alive and not n.gone and n.mode != "yield" and n.mode != "fled":
			if (n.pos as Vector3).distance_to(pos) < 22.0:
				return true
	return false


func owner_alive(building: int) -> bool:
	for n in list:
		if n.building == building and n.kind == "owner" and n.alive:
			return true
	return false


func index_near(pos: Vector3, reach: float) -> int:
	for i in list.size():
		if list[i].alive and not list[i].gone and (list[i].pos as Vector3).distance_to(pos) < reach:
			return i
	return -1


## Tia đánh có trúng người dân nào không?
func ray_hit(origin: Vector3, dir: Vector3, reach: float) -> int:
	for i in list.size():
		if not list[i].alive or list[i].gone:
			continue
		var c: Vector3 = (list[i].pos as Vector3) + Vector3(0, 1.0, 0)
		var t := clampf((c - origin).dot(dir), 0.0, reach)
		if (origin + dir * t).distance_to(c) < 0.7:
			return i
	return -1


func hit(idx: int) -> void:
	if multiplayer.is_server():
		_srv_hit(idx)
	else:
		_srv_hit.rpc_id(1, idx)


@rpc("any_peer", "reliable")
func _srv_hit(idx: int) -> void:
	if not multiplayer.is_server() or idx < 0 or idx >= list.size() or not list[idx].alive:
		return
	list[idx].hp -= 1
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	# Bị đánh lần đầu: chủ tiệm hoặc đầu hàng (cho hết hàng), hoặc đánh trả.
	var mode: String = list[idx].mode
	if list[idx].kind == "owner" and mode in ["", "fled"]:
		mode = "yield" if randf() < 0.5 else "fight"
	_cl_hit.rpc(idx, list[idx].hp <= 0, sender, mode)


@rpc("authority", "reliable", "call_local")
func _cl_hit(idx: int, killed: bool, attacker: int, mode: String) -> void:
	var n: Dictionary = list[idx]
	var first: bool = n.mode != mode
	n.mode = mode
	n.gone = false
	Sfx.play_at("hit", n.pos + Vector3(0, 1, 0), 0.0, 6.0)
	var mine := attacker == multiplayer.get_unique_id()
	if killed:
		n.alive = false
		(n.node as Humanoid).play_dead(true)
		(n.node as Humanoid).animate(1.0, 0.0, false, false)
		(n.tag as Label3D).visible = false
		if mine:
			Game.add_cruelty(35.0, "Bạn đã giết %s." % ("một người vô tội" if n.kind == "owner" else n.name))
	elif mine:
		if mode == "yield":
			Game.add_cruelty(8.0, "Chủ tiệm quỳ xuống: 'Lấy hết đi! Tôi không lấy tiền nữa, tha cho tôi!'" if first else "Người đó van xin bạn dừng tay.")
		elif mode == "fight":
			Game.add_cruelty(6.0, "Chủ tiệm vớ lấy cây gậy: 'Mày muốn cướp à?!' và lao vào đánh trả!" if first else "")
		else:
			Game.add_cruelty(8.0, "Người đó van xin bạn dừng tay.")


func sync_to(pid: int) -> void:
	var dead := []
	var modes := {}
	for i in list.size():
		if not list[i].alive:
			dead.append(i)
		if list[i].mode in ["yield", "fight"]:
			modes[i] = list[i].mode
	_cl_state.rpc_id(pid, dead, modes)


@rpc("authority", "reliable")
func _cl_state(dead: Array, modes: Dictionary) -> void:
	for i: int in modes:
		list[i].mode = modes[i]
	for i: int in dead:
		list[i].alive = false
		(list[i].node as Humanoid).play_dead(true)
		(list[i].tag as Label3D).visible = false
