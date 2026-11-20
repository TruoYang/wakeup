extends Node3D
## Thế giới: dựng thành phố, sinh người chơi, điều phối đồ đạc, quái vật, thời tiết, nhiệm vụ và giao diện.

const PLAYER := preload("res://scenes/player.tscn")
const MENU := "res://scenes/menu.tscn"
const WORLD_SEED := 20261111

var city: City
var weather: Node3D
var loot: Node3D
var npcs: Node3D
var monsters: Node
var fx: Node3D
var civs: Node3D
var bikes: Node3D
var players: Node3D
var spawner: MultiplayerSpawner
var hud: CanvasLayer
var inv_ui: CanvasLayer
var map_ui: CanvasLayer
var pause_ui: CanvasLayer
var end_ui: CanvasLayer

var play_time := 0.0
var stage := 0
var home_known := false     # chương 1: chỉ khi Thủy Quái trồi lên mới nghĩ tới chuyện về nhà (lúc đó mới có chỉ dẫn)
var _thrown: Array[Dictionary] = []
var _ray := PhysicsRayQueryParameters3D.new()
var _respawn_t := -1.0
var _marker: MeshInstance3D
var dialogue: CanvasLayer          # hội thoại phụ đề
var shelter: Node3D                # chương 2: hầm trú ẩn
var _broken_glass: Array = []
var _hold_cid := -1            # đang giữ E trên một chỗ chứa: đủ lâu thì lấy hết
var _hold_t := 0.0
var _hl: Node3D                 # món đang được viền sáng
var _outline: ShaderMaterial    # [id nhà, số ô kính] đã bị đập vỡ
var _damaged: Array = []         # [id, mode, cut] các nhà đã bị phá (để gửi cho người vào sau)
var _wreck_rng := RandomNumberGenerator.new()
var _last_wreck := -99.0
var _last_brush := -99.0
var _tu_seen := false


func _ready() -> void:
	add_to_group("world")
	_ray.collision_mask = 1
	Game.reset()
	city = City.new()
	city.name = "City"
	add_child(city)
	city.build(WORLD_SEED)

	weather = _module("Weather", "res://scripts/world/weather.gd")
	fx = _module("Fx", "res://scripts/world/fx.gd")
	loot = _module("Loot", "res://scripts/world/loot.gd")
	npcs = _module("Npcs", "res://scripts/world/npcs.gd")
	monsters = _module("Monsters", "res://scripts/monsters/manager.gd", false)
	weather.setup(city, WORLD_SEED)
	weather.water_mat = _find_water_material()
	loot.setup(city, self, WORLD_SEED)
	npcs.setup(city, self)
	civs = _module("Civs", "res://scripts/world/civs.gd")
	bikes = _module("Bikes", "res://scripts/world/bikes.gd")
	civs.setup(city, self, WORLD_SEED)
	bikes.setup(city, self)
	monsters.setup(city, self, WORLD_SEED)

	players = Node3D.new()
	players.name = "Players"
	add_child(players)
	spawner = MultiplayerSpawner.new()
	spawner.name = "PlayerSpawner"
	add_child(spawner)
	spawner.spawn_path = NodePath("../Players")
	spawner.spawn_limit = Net.MAX_PLAYERS
	spawner.spawn_function = _spawn_player

	hud = _ui("Hud", "res://scripts/ui/hud.gd", 1)
	inv_ui = _ui("InventoryUI", "res://scripts/ui/inventory.gd", 2)
	map_ui = _ui("MapUI", "res://scripts/ui/map.gd", 3)
	pause_ui = _ui("PauseUI", "res://scripts/ui/pause.gd", 4)
	end_ui = _ui("EndUI", "res://scripts/ui/end.gd", 5)
	_ui("NightVision", "res://scripts/ui/nightvision.gd", 0)
	dialogue = (load("res://scripts/ui/dialogue.gd") as GDScript).new()
	dialogue.name = "Dialogue"
	add_child(dialogue)
	_build_marker()

	Net.player_joined.connect(_on_player_joined)
	Net.player_left.connect(_on_player_left)
	Net.server_closed.connect(back_to_menu)
	Net.connection_failed.connect(back_to_menu)
	Game.player_died.connect(_on_local_death)
	match Net.mode:
		Net.Mode.JOIN:
			if Net.join(Net.address) != OK:
				back_to_menu.call_deferred()
		Net.Mode.HOST:
			if Net.host() != OK:
				back_to_menu.call_deferred()
				return
			_on_player_joined(1)
		_:
			Net.solo()
			_on_player_joined(1)
	# Hầm trú ẩn (chương 2) có mặt ở mọi máy; chỉ bật khi chủ phòng bắt đầu chương 2.
	shelter = (load("res://scripts/shelter.gd") as GDScript).new()
	shelter.name = "Shelter"
	add_child(shelter)
	shelter.setup(self)
	if Game.chapter == 2 and Net.mode != Net.Mode.JOIN:
		shelter.start.call_deferred()
	else:
		Game.chapter = 1
		_scatter_start_items.call_deferred()
		_intro.call_deferred()


func _module(node_name: String, path: String, spatial := true) -> Node:
	var n: Node = Node3D.new() if spatial else Node.new()
	n.name = node_name
	n.set_script(load(path))
	add_child(n)
	return n


func _ui(node_name: String, path: String, layer: int) -> CanvasLayer:
	var n := CanvasLayer.new()
	n.name = node_name
	n.layer = layer
	n.set_script(load(path))
	add_child(n)
	return n


func _find_water_material() -> ShaderMaterial:
	var w := city.find_child("Water", true, false) as MeshInstance3D
	return w.material_override as ShaderMaterial if w else null


## Vũ khí thô sơ rải sẵn: bàn phím trong văn phòng, cành cây gãy dưới gốc cây, ống tuýp ở hẻm. Vài đám cháy trên phố.
func _scatter_start_items() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = WORLD_SEED + 77
	var k := 0
	for car in city.cars:
		k += 1
		if k % 5 == 0:
			fx.burning(car.pos + Vector3(0, 1.0, 0))
	if not multiplayer.is_server():
		return
	loot.drop("banphim", city.start_pos + Vector3(2.4, 0.75, 1.2))
	loot.drop("canhcay", city.start_pos + Vector3(-1.0, 0.3, 8.5))
	for i in 14:
		var xf: Transform3D = city._tree_xf[r.randi() % city._tree_xf.size()]
		loot.drop("canhcay" if i % 3 != 0 else "ongtuyp", xf.origin + Vector3(r.randf_range(-1.5, 1.5), 0.3, r.randf_range(-1.5, 1.5)))


func _intro() -> void:
	Game.say("Bạn tỉnh dậy trong văn phòng, gục mặt trên bàn phím. Mặt đất rung lên từng đợt. Ngoài kia có tiếng gì đó gầm rất lớn.")
	get_tree().create_timer(5.0).timeout.connect(func() -> void: Game.say("E: nhặt đồ, lục tủ. Tab: túi đồ. 1-4 / lăn chuột: đổi món trên tay, F: chuyển sang tay trái. M: bản đồ."))


func local_player() -> CharacterBody3D:
	return players.get_node_or_null(str(multiplayer.get_unique_id())) as CharacterBody3D


func online_peers() -> int:
	return multiplayer.get_peers().size()


func ui_open() -> bool:
	return Game.talking or inv_ui.is_open() or map_ui.is_open() or pause_ui.is_open() or end_ui.is_open() or hud.sleeping() or (shelter != null and shelter.active and shelter.ui.is_open())


func back_to_menu() -> void:
	Sfx.stop_all_loops()
	Net.leave()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MENU)


func restart() -> void:
	Sfx.stop_all_loops()
	get_tree().paused = false
	get_tree().reload_current_scene()


# ------------------------------------------------------------------ người chơi vào / rời phòng
func _on_player_joined(id: int) -> void:
	if not multiplayer.is_server():
		return
	spawner.spawn({"id": id, "slot": players.get_child_count()})
	if id != 1:
		loot.sync_to(id)
		npcs.sync_to(id)
		bikes.sync_to(id)
		for d: Array in _damaged:
			_cl_building_damage.rpc_id(id, d[0], d[1], d[2], false)
		for g: Array in _broken_glass:
			_cl_glass.rpc_id(id, g[0], g[1], false)
		_cl_state.rpc_id(id, stage, play_time, weather.hour, weather.kind)
		shelter.on_player_joined(id)
		_cl_say.rpc("%s đã vào phòng." % str(Net.players.get(id, "Ai đó")))


func _on_player_left(id: int) -> void:
	var p := players.get_node_or_null(str(id))
	if p and multiplayer.is_server():
		bikes.release_rider(id)
		shelter.on_player_left(id)
		p.queue_free()
		_cl_say.rpc("Một người đã rời phòng.")


func _spawn_player(data: Dictionary) -> Node:
	var p: CharacterBody3D = PLAYER.instantiate()
	p.name = str(data.id)
	p.position = city.start_pos + Vector3((int(data.slot) % 2) * 1.6, 0.0, (int(data.slot) / 2) * 1.6)
	p.rotation.y = PI      # nhìn về phía nam: qua cửa kính xuống hồ
	return p


@rpc("authority", "reliable")
func _cl_state(s: int, t: float, hour: float, kind: String) -> void:
	play_time = t
	weather.hour = hour
	weather.kind = kind
	_apply_stage(s, false)


@rpc("authority", "reliable", "call_local")
func _cl_say(text: String) -> void:
	Game.say(text)


# ------------------------------------------------------------------ vòng lặp
func _process(delta: float) -> void:
	play_time += delta
	_update_quest()
	_update_marker()
	_update_pick(delta)
	if _respawn_t > 0.0:
		_respawn_t -= delta
		if _respawn_t <= 0.0:
			_respawn()
	if multiplayer.is_server():
		_update_thrown(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if inv_ui.is_open():
			inv_ui.close()
		elif map_ui.is_open():
			map_ui.close()
		elif not end_ui.is_open():
			pause_ui.toggle()
		get_viewport().set_input_as_handled()
	elif end_ui.is_open() or pause_ui.is_open():
		return
	elif event.is_action_pressed("interact") and inv_ui.is_open():
		# E mở thì E cũng đóng
		if inv_ui.opened_frame != Engine.get_process_frames():
			inv_ui.close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory"):
		if inv_ui.is_open():
			inv_ui.close()
		elif not map_ui.is_open():
			inv_ui.open_bag()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("map"):
		if map_ui.is_open():
			map_ui.close()
		elif not inv_ui.is_open():
			map_ui.open()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ vác vật nặng (xác, máy phát)
func _req_carry_body(idx: int) -> void:
	if multiplayer.is_server():
		_srv_carry_body(idx)
	else:
		_srv_carry_body.rpc_id(1, idx)


@rpc("any_peer", "reliable")
func _srv_carry_body(idx: int) -> void:
	if not multiplayer.is_server() or idx < 0 or idx >= monsters.list.size():
		return
	var rb: Monster = monsters.list[idx]
	if rb.kind != "robber" or rb.state != "dead" or int(rb.get("carrier")) != 0:
		return
	var pid := multiplayer.get_remote_sender_id()
	if pid == 0:
		pid = 1
	rb.set("carrier", pid)
	if pid == multiplayer.get_unique_id():
		_cl_carry("body")
	else:
		_cl_carry.rpc_id(pid, "body")


@rpc("authority", "reliable")
func _cl_carry(what: String) -> void:
	Game.carrying = what
	if what != "":
		Sfx.play("rummage", -4.0, 0.7)
		Game.say("Đang vác. Chậm hơn, không nhảy, không đánh được. Bấm E để đặt xuống.")


## Đặt vật đang vác xuống ngay chỗ đứng.
func drop_carry() -> void:
	var what := Game.carrying
	Game.carrying = ""
	if what == "machine" and shelter:
		shelter.drop_machine()
		return
	if multiplayer.is_server():
		_srv_drop_body()
	else:
		_srv_drop_body.rpc_id(1)


@rpc("any_peer", "reliable")
func _srv_drop_body() -> void:
	if not multiplayer.is_server():
		return
	var pid := multiplayer.get_remote_sender_id()
	if pid == 0:
		pid = 1
	for rb: Monster in monsters.list:
		if rb.kind == "robber" and int(rb.get("carrier")) == pid:
			rb.set("carrier", 0)
			var p := rb.global_position
			var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.0, 0), p + Vector3(0, -4.0, 0), 1))
			rb.global_position = (hit.position as Vector3) if not hit.is_empty() else p


## Máy dò nhu yếu phẩm: quét 40m quanh người, đánh dấu chỗ có đồ ăn, nước, thuốc trong 30 giây.
var scan_marks: Array = []
var scan_until := 0.0
var _scan_cd := 0.0


func scan_supplies(pos: Vector3) -> void:
	if play_time < _scan_cd:
		Game.say("Máy dò đang sạc lại…")
		return
	_scan_cd = play_time + 8.0
	Sfx.play("ui_open", -2.0, 1.6)
	if not loot.scanned.is_connected(_on_scanned):
		loot.scanned.connect(_on_scanned)
	loot.scan(pos)


func _on_scanned(marks: Array) -> void:
	if not Game.safe_code and city.hospital_safe_cid >= 0:
		# lần quét đầu tiên: bộ nhớ máy còn lưu thông tin két sắt bệnh viện
		Game.safe_code = true
		if shelter and shelter.active:
			if multiplayer.is_server():
				shelter._srv_flag("safe_code")
			else:
				shelter._srv_flag.rpc_id(1, "safe_code")
		dialogue.play(["Máy dò: Bộ nhớ còn lưu một điểm đánh dấu.", "Máy dò: KÉT SẮT — Bệnh viện đa khoa thành phố, toà chính, tầng trên cùng, phòng trưởng khoa. Nội dung: thuốc đặc trị.", "Máy dò: Mã mở két: %s." % city.hospital_safe_code])
	scan_marks = marks
	scan_until = play_time + 30.0
	var f := marks.filter(func(m: Array) -> bool: return m[1] == "food").size()
	var w := marks.filter(func(m: Array) -> bool: return m[1] == "drink").size()
	var md := marks.filter(func(m: Array) -> bool: return m[1] == "med").size()
	Game.say("Máy dò: %d chỗ có đồ ăn, %d chỗ có nước, %d chỗ có thuốc trong vòng 40m." % [f, w, md] if not marks.is_empty() else "Máy dò: quanh đây không còn gì.", "good" if not marks.is_empty() else "")


## Viền sáng món đồ đang trỏ vào; giữ E đủ lâu thì lấy hết chỗ đó.
func _update_pick(delta: float) -> void:
	var p := local_player()
	var node: Node3D = null
	if p and not ui_open():
		var t: Dictionary = p.target
		if t.get("type", "") == "item":
			node = t.node
	if node != _hl:
		if is_instance_valid(_hl):
			_set_outline(_hl, null)
		_hl = node
		if _hl:
			if _outline == null:
				_outline = ShaderMaterial.new()
				_outline.shader = load("res://shaders/outline.gdshader")
			_set_outline(_hl, _outline)
	if _hold_cid >= 0:
		if Input.is_action_pressed("interact") and not ui_open():
			_hold_t += delta
			if _hold_t >= 0.5:
				for id: String in (loot.known.get(_hold_cid, []) as Array).duplicate():
					if not Game.can_take(id) and not Items.get_def(id).has("wallet") and not Items.get_def(id).has("ammo"):
						Game.say("Túi quá nặng. Vứt bớt đồ hoặc tìm balo lớn hơn.", "bad")
						break
					loot.take(_hold_cid, id)
				_hold_cid = -1
		else:
			_hold_cid = -1


func _set_outline(n: Node3D, mat: Material) -> void:
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		mi.material_overlay = mat


# ------------------------------------------------------------------ truy vấn thế giới
func water_depth(p: Vector3) -> float:
	return city.water_depth(p)


func is_indoors(p: Vector3) -> bool:
	return p.y < -0.8 or not city.building_at(p).is_empty()


func darkness() -> float:
	return weather.darkness()


func line_clear(from: Vector3, to: Vector3) -> bool:
	_ray.from = from
	_ray.to = to
	return get_world_3d().direct_space_state.intersect_ray(_ray).is_empty()


## Với tới được không: tia từ mắt tới vật, cho phép chạm vào chính món đồ nội thất chứa nó.
func _reachable(eye: Vector3, pos: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(eye, pos, 3)
	if space.intersect_ray(q).is_empty():
		return true
	# Món đồ nằm trong chính cái tủ/kệ chứa nó: tia đi ngược từ món đồ ra không chạm gì (tia xuất phát trong khối thì bỏ qua khối đó).
	# Còn nếu có tường hay kính chắn giữa thì tia ngược sẽ chạm mặt bên kia của tường.
	q.from = pos
	q.to = eye
	if space.intersect_ray(q).is_empty():
		return true
	# với qua mặt quầy, mặt bàn thấp
	q.from = eye
	q.to = pos + Vector3(0, 0.45, 0)
	return space.intersect_ray(q).is_empty()


## Tìm thứ có thể tương tác mà người chơi đang nhìn vào.
func find_interactable(origin: Vector3, dir: Vector3, player: Node3D) -> Dictionary:
	var eye: Vector3 = player.eye_position()
	if shelter and shelter.active:
		var st: Dictionary = shelter.find_interactable(eye, origin, dir)
		if not st.is_empty():
			return st
	var best := {}
	var best_score := 0.80
	if Game.carrying != "":
		return best              # đang vác: E chỉ để đặt xuống (hoặc tương tác của hầm, xét ở trên)
	# Xác kẻ cướp: vác đi được
	for mi in monsters.list.size():
		var rb: Monster = monsters.list[mi]
		if rb.kind == "robber" and rb.state == "dead" and int(rb.get("carrier")) == 0:
			var bp := rb.global_position + Vector3(0, 0.3, 0)
			if eye.distance_to(bp) < 2.4 and dir.dot((bp - origin).normalized()) > 0.7:
				return {"type": "body", "id": mi, "pos": bp, "label": "Vác xác kẻ cướp (nặng)"}
	# Tủ kín, ngăn kéo, thùng, thi thể: bấm E mở danh sách đồ bên trong
	for cid: int in loot.near(eye):
		if loot.is_exposed(cid):
			continue
		var con0: Dictionary = loot.info.get(cid, {})
		if con0.is_empty():
			continue
		var cpos: Vector3 = con0.pos
		var cd := eye.distance_to(cpos)
		if cd > 2.9:
			continue
		var cscore := dir.dot((cpos - origin).normalized()) + (0.12 if cd < 1.2 else 0.0)
		if cscore > best_score and _reachable(eye, cpos):
			best_score = cscore
			best = {"type": "container", "id": cid, "pos": cpos, "label": "Lục %s" % con0.name + (" (trống)" if loot.emptied.has(cid) else "")}
	# Đồ để lộ ra ngoài (kệ hàng, đồ rơi): nhặt trực tiếp, ưu tiên nếu đang trỏ thẳng vào
	var it: Dictionary = loot.pick_target(origin, dir, eye, 2.7)
	if not it.is_empty() and _reachable(eye, it.pos):
		var con: Dictionary = loot.info.get(int(it.cid), {})
		var nm := Items.item_name(str(it.item))
		var label := "Nhặt " + nm
		if con.get("shop", false) and npcs.owner_present(int(con.get("building", -1)), con.get("pos", Vector3.ZERO)) and not Game.god:
			label = "Mua %s · %s đ" % [nm, Game.format_money(int(Items.get_def(str(it.item)).get("p", 0)))]
		var left: int = (loot.known.get(int(it.cid), []) as Array).size()
		if left > 1:
			label += "   (giữ E: lấy cả %d món)" % left
		var it_score := dir.dot(((it.pos as Vector3) - origin).normalized())
		if best.is_empty() or it_score > best_score + 0.03:
			return {"type": "item", "id": int(it.cid), "item": it.item, "node": it.node, "pos": it.pos, "label": label}
	for i in npcs.list.size():
		var n: Dictionary = npcs.list[i]
		var pos2: Vector3 = (n.pos as Vector3) + Vector3(0, 1.2 if n.alive else 0.3, 0)
		if eye.distance_to(pos2) > 2.8:
			continue
		var score2 := dir.dot((pos2 - origin).normalized())
		if score2 > best_score:
			if n.kind == "wife" or n.kind == "child":
				best_score = score2
				best = {"type": "family", "id": i, "pos": pos2, "label": "Nói chuyện với %s" % ("vợ" if n.kind == "wife" else "con gái")}
			elif n.kind == "hurt" and n.alive:
				best_score = score2
				best = {"type": "help", "id": i, "pos": pos2 - Vector3(0, 0.5, 0), "label": "Người bạn đã giúp" if n.helped else "Giúp người bị thương (cần %s)" % Items.item_name(n.need)}
			elif n.kind == "coworker" and n.alive:
				best_score = score2
				best = {"type": "talk", "id": i, "pos": pos2, "label": "Nói chuyện với %s" % n.name}
			elif n.alive:
				best_score = score2
				best = {"type": "owner", "id": i, "pos": pos2, "label": "Chủ tiệm (lấy hàng trên kệ là trả tiền)"}
	for bed: Vector3 in city.beds:
		if absf(bed.y - eye.y) < 2.2 and eye.distance_to(bed) < 2.6:
			var sbed := dir.dot((bed - origin).normalized())
			if sbed > best_score - 0.15:
				best_score = sbed
				best = {"type": "bed", "id": 0, "pos": bed, "label": "Ngủ tới sáng" if darkness() > 0.45 else "Giường (trời tối mới ngủ được)"}
	var bi: int = bikes.index_near(eye, 2.6)
	if bi >= 0 and not player.riding_bike():
		var bp: Vector3 = (bikes.list[bi].pos as Vector3) + Vector3(0, 0.7, 0)
		var sb := dir.dot((bp - origin).normalized())
		if sb > best_score - 0.1:
			best_score = sb
			best = {"type": "bike", "id": bi, "pos": bp, "label": "Lên xe máy (xăng %d%%)" % int(bikes.list[bi].fuel)}
	if stage >= 1 and stage < 3:
		var hp := city.hatch_pos + Vector3(0, 0.2, 0)
		if eye.distance_to(hp) < 2.8 and dir.dot((hp - origin).normalized()) > 0.6:
			best = {"type": "hatch", "id": 0, "pos": hp, "label": "Cạy cửa hầm" if Game.count("xabeng") > 0 else "Cửa hầm (kẹt cứng)"}
	return best


func interact(t: Dictionary) -> void:
	match t.type:
		"body":
			_req_carry_body(int(t.id))
		"item":
			loot.take(int(t.id), str(t.item))
			_hold_cid = int(t.id)
			_hold_t = 0.0
		"shelter":
			shelter.interact(t)
		"container":
			var con: Dictionary = loot.info.get(int(t.id), {})
			if con.get("locked", false) and not (Game.safe_code or (shelter and shelter.flags.has("safe_code"))):
				Game.say("Két sắt khoá số bốn chữ số. Không biết mã thì không mở được.", "bad")
				Sfx.play("empty")
				return
			inv_ui.open_container(t.id)
		"family":
			_talk_family(t.id)
		"help":
			npcs.help(t.id)
		"bike":
			bikes.mount(t.id)
		"talk":
			Game.say(npcs.talk(t.id))
		"bed":
			if darkness() <= 0.45:
				Game.say("Trời còn sáng, chưa ngủ được.")
			elif Game.hunted or _monster_within(35.0):
				Game.say("Có thứ gì đó đang ở rất gần (trong vòng 35m). Chưa thể ngủ lúc này.", "bad")
			else:
				hud.start_sleep()
		"owner":
			Game.say("Chủ tiệm: 'Cứ lấy đi, trả tiền là được. Đừng làm ồn.'")
		"hatch":
			if Game.count("xabeng") > 0:
				Sfx.play("pry")
				_request_stage(3)
			else:
				Game.say("Cửa hầm kẹt cứng từ bên trong. Cần xà beng để cạy.")
				Sfx.play("empty")


## Người chơi nhận món đồ vừa lấy. Trả về false nếu không nhận được (thiếu tiền, quá nặng).
func grant_item(cid: int, item: String) -> bool:
	var con: Dictionary = loot.info.get(cid, {})
	var def := Items.get_def(item)
	if con.get("shop", false) and npcs.owner_present(int(con.get("building", -1)), con.get("pos", Vector3.ZERO)) and not Game.god:
		var price := int(def.get("p", 0))
		if Game.money < price:
			Game.say("Không đủ tiền: %s giá %s đ." % [def.n, Game.format_money(price)], "bad")
			return false
		if not Game.can_take(item) and not def.has("wallet") and not def.has("ammo"):
			Game.say("Túi quá nặng.", "bad")
			return false
		Game.money -= price
		Game.add_item(item)
		Game.say("Mua %s: -%s đ" % [def.n, Game.format_money(price)])
		return true
	return Game.add_item(item)


# ------------------------------------------------------------------ tiếng động, đánh, bắn, ném
## Tiếng súng: vang rất xa, mọi con quái trong vòng 230m đều kéo về phía đó.
func gun_noise(pos: Vector3) -> void:
	if multiplayer.is_server():
		monsters.hear(pos, 1.0, "gun")
	else:
		_srv_gun.rpc_id(1, pos)


@rpc("any_peer", "reliable")
func _srv_gun(pos: Vector3) -> void:
	if multiplayer.is_server():
		monsters.hear(pos, 1.0, "gun")


func emit_noise(pos: Vector3, loud: float) -> void:
	if multiplayer.is_server():
		monsters.hear(pos, loud, "player")
	else:
		_srv_noise.rpc_id(1, pos, loud)


@rpc("any_peer", "unreliable")
func _srv_noise(pos: Vector3, loud: float) -> void:
	if multiplayer.is_server():
		monsters.hear(pos, clampf(loud, 0.0, 1.0), "player")


func hurt_player(pid: int, amount: float, kind: String, part := "") -> void:
	if pid == multiplayer.get_unique_id():
		_cl_hurt(amount, kind, part)
	else:
		_cl_hurt.rpc_id(pid, amount, kind, part)


@rpc("authority", "reliable")
func _cl_hurt(amount: float, kind: String, part: String) -> void:
	Game.damage(amount, kind, part)


## Đập kính cửa sổ bằng dụng cụ: mở được lối vào/ra, nhưng tiếng kính vỡ vang rất xa.
func player_smash_glass(origin: Vector3, dir: Vector3, reach: float) -> bool:
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + dir * reach, 3))
	if hit.is_empty():
		return false
	var pane: Dictionary = city.pane_at(hit.position)
	if pane.is_empty() or int(pane.b) < 0:
		return false
	if multiplayer.is_server():
		_srv_glass(int(pane.b), int(pane.i))
	else:
		_srv_glass.rpc_id(1, int(pane.b), int(pane.i))
	return true


@rpc("any_peer", "reliable")
func _srv_glass(id: int, idx: int) -> void:
	if not multiplayer.is_server() or id < 0 or id >= city.buildings.size():
		return
	if (city.buildings[id].get("broken", []) as Array).has(idx):
		return
	_broken_glass.append([id, idx])
	_cl_glass.rpc(id, idx, true)


@rpc("authority", "reliable", "call_local")
func _cl_glass(id: int, idx: int, live: bool) -> void:
	var pos := Vector3.ZERO
	for pane: Dictionary in city.panes.get(city.buildings[id].cell, []):
		if int(pane.b) == id and int(pane.i) == idx:
			pos = (pane.box as AABB).get_center()
	city.break_glass(id, idx)
	if live and pos != Vector3.ZERO:
		Sfx.play_at("glass_break", pos, 8.0, 34.0, randf_range(0.95, 1.08))
		fx.glass_shatter(pos)
		if multiplayer.is_server():
			monsters.hear(pos, 0.85, "player")


func player_melee(origin: Vector3, dir: Vector3, reach: float, stun: float, power: float) -> bool:
	var npc: int = npcs.ray_hit(origin, dir, reach)
	if npc >= 0:
		npcs.hit(npc)
		return true
	var m: int = monsters.melee(origin, dir, reach)
	if m >= 0:
		if multiplayer.is_server():
			_srv_melee(m, stun, power)
		else:
			_srv_melee.rpc_id(1, m, stun, power)
		return true
	return false


@rpc("any_peer", "reliable")
func _srv_melee(idx: int, stun: float, power: float) -> void:
	if multiplayer.is_server() and idx >= 0 and idx < monsters.list.size():
		var sender := multiplayer.get_remote_sender_id()
		monsters.list[idx].on_melee(sender if sender != 0 else 1, clampf(stun, 0.0, 4.0), clampf(power, 0.0, 1.0))


func player_shoot(origin: Vector3, dir: Vector3) -> void:
	gun_noise(origin)
	_cl_shot_sound.rpc(origin)
	var m: int = monsters.melee(origin, dir, 160.0)
	if m < 0:
		return
	# Tường chắn đạn
	var target: Vector3 = monsters.list[m].hit_spheres()[0][0]
	_ray.from = origin
	_ray.to = origin + dir * origin.distance_to(target)
	var hit := get_world_3d().direct_space_state.intersect_ray(_ray)
	if not hit.is_empty() and origin.distance_to(hit.position) < origin.distance_to(target) - 3.0:
		return
	if monsters.list[m].kind in ["titan", "grub", "worm"]:
		Game.say("%s không hề hấn gì. Đạn chỉ lún vào lớp thịt của nó." % monsters.list[m].mname)
	if multiplayer.is_server():
		_srv_shot(m)
	else:
		_srv_shot.rpc_id(1, m)


@rpc("any_peer", "unreliable")
func _cl_shot_sound(pos: Vector3) -> void:
	Sfx.play_at("gunshot", pos, 4.0, 30.0)


@rpc("any_peer", "reliable")
func _srv_shot(idx: int) -> void:
	if multiplayer.is_server() and idx >= 0 and idx < monsters.list.size():
		var sender := multiplayer.get_remote_sender_id()
		monsters.list[idx].on_shot(sender if sender != 0 else 1)


func player_throw(kind: String, start: Vector3, vel: Vector3) -> void:
	if multiplayer.is_server():
		_srv_throw(kind, start, vel)
	else:
		_srv_throw.rpc_id(1, kind, start, vel)


@rpc("any_peer", "reliable")
func _srv_throw(kind: String, start: Vector3, vel: Vector3) -> void:
	if not multiplayer.is_server() or not kind in ["phao", "chai"]:
		return
	_thrown.append({"kind": kind, "p": start, "v": vel.limit_length(22.0), "t": 0.0, "fuse": -1.0})
	_cl_thrown.rpc(kind, start, vel.limit_length(22.0))


@rpc("authority", "reliable", "call_local")
func _cl_thrown(kind: String, start: Vector3, vel: Vector3) -> void:
	fx.thrown(kind, start, vel)


func _update_thrown(delta: float) -> void:
	for i in range(_thrown.size() - 1, -1, -1):
		var t: Dictionary = _thrown[i]
		if t.fuse >= 0.0:
			t.fuse -= delta
			if t.fuse <= 0.0:
				_thrown.remove_at(i)
				_cl_landed.rpc(t.kind, t.p)
				monsters.hear(t.p, 1.0, "player")
			continue
		var next: Vector3 = t.p + t.v * delta
		t.v.y -= 14.0 * delta
		t.t += delta
		var blocked := not line_clear(t.p, next)
		if blocked or next.y <= 0.05 or t.t > 6.0:
			if t.kind == "phao":
				t.fuse = 1.1
				t.v = Vector3.ZERO
			else:
				_thrown.remove_at(i)
				_cl_landed.rpc("chai", t.p)
				monsters.hear(t.p, 0.8, "player")
		else:
			t.p = next


@rpc("authority", "reliable", "call_local")
func _cl_landed(kind: String, pos: Vector3) -> void:
	fx.stop_thrown_near(pos)
	if kind == "phao":
		Sfx.play_at("firecracker", pos, 4.0, 26.0)
		fx.dust(pos, 1.2)
	else:
		Sfx.play_at("bottle_break", pos, 4.0, 22.0)


# ------------------------------------------------------------------ ngủ qua đêm
## Có quái vật nào trong bán kính này quanh người chơi không? (Dực Quái bay trên cao không tính.)
func _monster_within(radius: float) -> bool:
	var p := local_player()
	if p == null:
		return false
	for mo: Monster in monsters.list:
		if mo.state == "dormant" or mo.kind == "flyer":
			continue
		if Vector2(mo.global_position.x - p.global_position.x, mo.global_position.z - p.global_position.z).length() < radius:
			return true
	return false


## Màn hình đã tối hẳn: giờ mới tua thời gian.
func request_sleep() -> void:
	if multiplayer.is_server():
		_srv_sleep()
	else:
		_srv_sleep.rpc_id(1)


@rpc("any_peer", "reliable")
func _srv_sleep() -> void:
	if not multiplayer.is_server() or darkness() <= 0.45:
		return
	var sender := multiplayer.get_remote_sender_id()
	weather.skip_to_morning()
	_cl_slept.rpc(sender if sender != 0 else 1)


@rpc("authority", "reliable", "call_local")
func _cl_slept(pid: int) -> void:
	weather.hour = 6.0
	if pid == multiplayer.get_unique_id():
		Game.stamina = 100.0
		Game.hp = minf(100.0, Game.hp + 15.0)
		Game.food = maxf(0.0, Game.food - 18.0)
		Game.water = maxf(0.0, Game.water - 22.0)
		Game.say("Bạn dậy lúc 6 giờ sáng. Người đỡ mệt nhưng đói và khát hơn.", "good")
	else:
		Game.say("Trời đã sáng.")


# ------------------------------------------------------------------ Thủy Quái phá nhà, cây
## Chân Thủy Quái vừa đặt xuống `pos`. (Chỉ máy chủ.) Có tỉ lệ làm hỏng ngôi nhà nó giẫm vào và quật đổ cây gần đó.
func titan_step(pos: Vector3) -> void:
	_cl_trees_down.rpc(pos, 5.0)
	_cl_cars_crushed.rpc(pos, 5.0)
	# Bàn chân đặt vào nhà nào thì nhà đó nát: nhà thấp sập hẳn, nhà cao vỡ mặt tiền trước rồi mới sập.
	# (Nó đi giữa lòng đường nên chỉ giẫm vào nhà khi rẽ ở ngã tư hoặc khi lao khỏi đường để đuổi mồi.)
	if play_time - _last_wreck < 1.5:
		return
	var q := Vector2(pos.x, pos.z)
	for b in city.buildings:
		if b.kind in ["home", "tu", "office", "mall"] or b.get("landmark", false) or b.get("damage", "") == "collapse":
			continue
		if (b.rect as Rect2).grow(0.5).has_point(q):
			_last_wreck = play_time
			var mode := "collapse"
			if b.kind != "tower" and (int(b.floors) >= 4 or b.kind in City.BIG_KINDS) and not b.has("damage"):
				mode = "front"
			_damaged.append([b.id, mode, 1])
			_cl_building_damage.rpc(b.id, mode, 1, true)
			return


## Thân và chân Thủy Quái quẹt vào nhà cao tầng: cả toà đổ sụp.
func titan_brush(pos: Vector3, fwd: Vector3) -> void:
	if play_time - _last_brush < 0.5:
		return
	_last_brush = play_time
	for b in city.buildings:
		if b.kind in ["home", "tu", "office", "mall"] or b.get("landmark", false) or b.get("damage", "") == "collapse":
			continue
		if float(b.floors) * float(b.fh) < 20.0:
			continue
		var rc: Rect2 = b.rect
		var cc := rc.get_center()
		if absf(cc.x - pos.x) > 45.0 or absf(cc.y - pos.z) > 45.0:
			continue
		# thân nó dài: thử ba điểm dọc sống lưng, mỗi điểm một vòng bán kính 9m
		for k: float in [-18.0, 0.0, 18.0]:
			var q := Vector2(pos.x + fwd.x * k, pos.z + fwd.z * k)
			var near := Vector2(clampf(q.x, rc.position.x, rc.end.x), clampf(q.y, rc.position.y, rc.end.y))
			if near.distance_to(q) < 9.0:
				_damaged.append([b.id, "collapse", 1])
				_cl_building_damage.rpc(b.id, "collapse", 1, true)
				return


@rpc("authority", "reliable", "call_local")
func _cl_building_damage(id: int, mode: String, cut: int, live: bool) -> void:
	var b: Dictionary = city.buildings[id]
	city.damage_building(id, mode, cut)
	if not live:
		return
	var c := (b.rect as Rect2).get_center()
	var pos := Vector3(c.x, 1.0, c.y)
	fx.dust(pos, 9.0)
	fx.dust(pos + Vector3(0, 6.0, 0), 7.0)
	fx.debris(Vector3(c.x, 0.0, c.y), 10)
	Sfx.play_at("explosion", pos, 4.0, 40.0, 0.6)
	monsters.shake_from(pos, 0.8, 70.0)
	var p := local_player()
	if p and (b.rect as Rect2).grow(0.5).has_point(Vector2(p.global_position.x, p.global_position.z)) and not Game.god:
		Game.damage(60.0 if mode == "collapse" else 28.0, "crush")
		Game.say("Ngôi nhà đổ sập ngay trên đầu bạn!", "bad")
		if mode == "collapse":
			p.global_position.y = maxf(p.global_position.y, 2.2)


@rpc("authority", "reliable", "call_local")
func _cl_cars_crushed(pos: Vector3, radius: float) -> void:
	for i: int in city.crush_cars(pos, radius):
		var cp: Vector3 = city.cars[i].pos
		fx.dust(cp, 2.5)
		fx.smoke(cp + Vector3(0, 0.5, 0))
		Sfx.play_at("glass", cp, 2.0, 16.0, 0.7)


@rpc("authority", "reliable", "call_local")
func _cl_trees_down(pos: Vector3, radius: float) -> void:
	if city.fell_trees(pos, radius) > 0:
		fx.dust(pos, 3.0)


# ------------------------------------------------------------------ nhiệm vụ
## Có chỉ dẫn đường (bản đồ, la bàn, cột sáng) chưa: chương 1 chỉ có sau khi Thủy Quái trồi lên.
func has_objective() -> bool:
	return (shelter != null and shelter.active) or stage > 0 or home_known


func objective_pos() -> Vector3:
	if shelter and shelter.active:
		return shelter.objective_point()
	return city.tu_pos if stage == 1 else (city.hatch_pos if stage == 2 else city.home_pos)


func _update_quest() -> void:
	var p := local_player()
	if p == null or Game.dead or Game.won:
		return
	# Thủy Quái trồi lên khỏi hồ: lúc này mới nghĩ tới vợ con ở nhà.
	if stage == 0 and not home_known and not (shelter and shelter.active):
		var ti: Monster = null
		for m: Monster in monsters.list:
			if m.kind == "titan":
				ti = m
		if ti and ti.state != "dormant":
			home_known = true
			get_tree().create_timer(3.5).timeout.connect(func() -> void:
				Game.objective = "Về nhà, tìm vợ con"
				dialogue.play(["Bạn: Cái gì… thứ đó vừa chui lên từ trong hồ.", "Bạn: Nó to bằng cả toà nhà…", "Bạn: Mai… bé Na… hai mẹ con đang ở nhà một mình.", "Bạn: Phải về nhà. Ngay bây giờ."], func() -> void:
					Game.say("Bản đồ (M) và la bàn đã chỉ đường về nhà.", "good")))
	# Tới nhà ông Tư lần đầu: nhà trống, phải tự lục.
	if stage == 1 and not _tu_seen and p.global_position.distance_to(Vector3(city.tu_pos.x, 0.3, city.tu_pos.z)) < 6.0:
		_tu_seen = true
		Game.say("Nhà ông Tư trống không. Cửa mở toang, một vệt máu kéo dài ra ngõ. Phải tự tìm xà beng trong nhà.", "bad")
		Sfx.play("sting", -8.0)
	if stage == 1 and Game.count("xabeng") > 0:
		_request_stage(2)


## Gặp vợ con ở nhà: lúc này mới biết phải đi tìm xà beng.
func _talk_family(idx: int) -> void:
	var who: String = npcs.list[idx].kind
	match stage:
		0:
			var lines: Array = []
			if who == "child":
				lines.append({"who": "", "text": "Bé Na lao tới ôm chặt lấy chân bạn, không nói được câu nào."})
			lines.append("Mai: Anh về rồi! Em cứ tưởng… em cứ tưởng anh không về được nữa.")
			lines.append("Mai: Em với con định xuống hầm trú ẩn, nhưng cửa hầm kẹt cứng từ bên trong. Em cạy mãi không được.")
			lines.append("Mai: Bác Tư bên kia công viên có cái xà beng. Anh sang mượn bác ấy đi. Nhanh lên anh, nó cứ đi qua đi lại ngoài phố…")
			if Game.count("xabeng") > 0:
				lines.append("Bạn: Anh có xà beng đây rồi. Hai mẹ con lùi lại.")
			dialogue.play(lines, func() -> void: _request_stage(2 if Game.count("xabeng") > 0 else 1))
		1:
			dialogue.play(["Mai: Nhà bác Tư ở dãy phía nam, bên kia công viên. Nếu bác ấy không có nhà thì anh cứ vào tìm, bác ấy không trách đâu.", "Mai: Đi cẩn thận, anh nhé."] if who == "wife" else ["Bé Na: Bố đi nhanh rồi về nha bố…"])
		_:
			dialogue.play(["Mai: Có xà beng rồi! Cửa hầm ở cuối nhà, anh cạy đi!"] if who == "wife" else [{"who": "", "text": "Bé Na nép sau lưng mẹ, nhìn bạn chờ đợi."}])


func _request_stage(s: int) -> void:
	if multiplayer.is_server():
		_srv_stage(s)
	else:
		_srv_stage.rpc_id(1, s)


@rpc("any_peer", "reliable")
func _srv_stage(s: int) -> void:
	if multiplayer.is_server() and s > stage:
		_cl_stage.rpc(s)


@rpc("authority", "reliable", "call_local")
func _cl_stage(s: int) -> void:
	_apply_stage(s, true)


func _apply_stage(s: int, announce: bool) -> void:
	if s <= stage and s != 0:
		return
	stage = s
	match stage:
		0:
			Game.objective = "Về nhà, tìm vợ con" if home_known else "Chuyện gì đang xảy ra ngoài kia?"
		1:
			Game.objective = "Sang nhà ông Tư tìm xà beng"
			if announce:
				Sfx.play("sting", -6.0)
		2:
			Game.objective = "Mang xà beng về cạy cửa hầm ở nhà"
		3:
			Game.objective = "Đoàn tụ"
			Game.won = true
			Sfx.stop_all_loops()
			# Cắt cảnh: ngôi nhà sập xuống trên cửa hầm, rồi mới tới màn kết chương.
			var cs: CanvasLayer = (load("res://scripts/cutscene.gd") as GDScript).new()
			add_child(cs)
			cs.setup(self)
			cs.play_home_collapse(func() -> void:
				Sfx.play("win", -3.0)
				Game.game_won.emit(Game.cruelty >= 60.0))


# ------------------------------------------------------------------ chết / hồi sinh
func _on_local_death(_reason: String) -> void:
	Sfx.play("sting", -4.0)
	if Net.is_online():
		# đồ đang mang rơi lại tại chỗ ngã xuống, đồng đội nhặt được
		var me := local_player()
		if me:
			var k := 0
			for id: String in Game.inv.keys():
				if Items.get_def(id).has("quest"):
					continue
				for c in mini(Game.count(id), 3):
					if k < 14:
						loot.drop(id, me.global_position + Vector3(cos(k * 0.9) * 0.9, 0.3, sin(k * 0.9) * 0.9))
						k += 1
		_respawn_t = 12.0
		Game.say("Bạn đã gục, đồ đạc rơi lại tại chỗ. Tỉnh lại ở văn phòng sau 12 giây…", "bad")
	else:
		end_ui.show_death()


func _respawn() -> void:
	var p := local_player()
	if p == null:
		return
	Game.reset()
	Game.hp = 60.0
	Game.food = 50.0
	Game.water = 50.0
	Game.objective = Game.objective
	_apply_stage(stage, false)
	match stage:
		1: Game.objective = "Sang nhà ông Tư tìm xà beng"
		2: Game.objective = "Mang xà beng về cạy cửa hầm ở nhà"
	p.global_position = city.start_pos
	p.velocity = Vector3.ZERO
	p.set_third_person(false)
	if shelter and shelter.active:
		# chương 2: được đồng đội kéo về hầm, coi như đã về
		Game.flash_boost = 1.8
		shelter.call("_to_bunker")
		shelter.call("night_pick", "sleep")
		Game.say("Bạn tỉnh lại dưới hầm. Đồ đạc nằm lại chỗ bạn ngã xuống.", "bad")
		return
	Game.say("Bạn tỉnh lại ở văn phòng. Đồ đạc nằm lại chỗ bạn ngã xuống.", "bad")


# ------------------------------------------------------------------ dấu mục tiêu trong thế giới
func _build_marker() -> void:
	_marker = MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.25
	c.bottom_radius = 0.25
	c.height = 60.0
	c.radial_segments = 8
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.52, 0.78, 0.5, 0.35)
	m.no_depth_test = false
	c.material = m
	_marker.mesh = c
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_marker)


func _update_marker() -> void:
	var o := objective_pos()
	_marker.global_position = Vector3(o.x, 30.0, o.z)
	_marker.visible = not Game.won and has_objective()
