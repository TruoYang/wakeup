extends Node3D
## Đồ trong các tủ, kệ, thi thể và đồ rơi. Máy chủ phòng giữ nội dung thật; người chơi xin mở / lấy qua mạng.

signal opened(cid: int, items: Array)
signal changed(cid: int, items: Array)

const CELL := 6.0

var city: City
var world: Node
var rng := RandomNumberGenerator.new()
## Chỉ máy chủ: cid -> danh sách vật phẩm còn lại.
var contents: Dictionary = {}
var emptied: Dictionary = {}
var info: Dictionary = {}          # cid -> {pos, name, table, shop, building}
var grid: Dictionary = {}
var drops: Dictionary = {}         # cid -> nút hình ảnh của món đồ rơi
var bodies: Dictionary = {}
var _static_bodies: Array[Node3D] = []
var _next_drop := 100000
## Máy nào cũng có: nội dung các chỗ chứa ở gần mà máy này đã biết (cid -> danh sách đồ) và hình 3D của từng món.
var known: Dictionary = {}
var shown: Dictionary = {}         # cid -> [{item, node}]
var _asked: Dictionary = {}
var _stream_t := 0.0
const SHOW_R := 24.0


func setup(c: City, w: Node, world_seed: int) -> void:
	city = c
	world = w
	rng.seed = world_seed + 99
	for con in c.containers:
		_register(con.id, con)
	# thi thể nằm trên đường
	var r2 := RandomNumberGenerator.new()
	r2.seed = world_seed + 3
	for cp in c.corpses:
		var h := Humanoid.new()
		add_child(h)
		h.setup(cp.color, Color.from_hsv(r2.randf(), 0.2, 0.3), Color("b08a68"))
		h.position = cp.pos
		h.rotation.y = cp.yaw
		h.play_dead(true)
		h.animate(1.0, 0.0, false, false)
		_static_bodies.append(h)


func _register(cid: int, con: Dictionary) -> void:
	info[cid] = con
	var p: Vector3 = con.pos
	var key := Vector3i(floori(p.x / CELL), floori(p.y / 3.4), floori(p.z / CELL))
	if not grid.has(key):
		grid[key] = []
	grid[key].append(cid)


func _process(delta: float) -> void:
	# chỉ vẽ thi thể ở gần để nhẹ máy
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	for h in _static_bodies:
		h.visible = cam.global_position.distance_to(h.position) < 70.0
	_stream_t -= delta
	if _stream_t <= 0.0:
		_stream_t = 0.35
		_stream(cam.global_position)


# ------------------------------------------------------------------ đồ hiện thành vật 3D quanh người chơi
## Mỗi món trong tủ, kệ, thi thể, đồ rơi đều là một vật 3D nhặt trực tiếp. Để nhẹ máy, chỉ dựng hình trong vòng SHOW_R mét.
func _stream(p: Vector3) -> void:
	var want: Dictionary = {}
	var cx := floori(p.x / CELL)
	var cz := floori(p.z / CELL)
	var cy := floori(p.y / 3.4)
	var r := int(ceil(SHOW_R / CELL))
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			for dy in range(-2, 3):
				for cid: int in grid.get(Vector3i(cx + dx, cy + dy, cz + dz), []):
					if is_exposed(cid) and (info[cid].pos as Vector3).distance_to(p) < SHOW_R:
						want[cid] = true
	var ask: Array = []
	for cid: int in want:
		if known.has(cid):
			if not shown.has(cid):
				_build(cid)
		elif not _asked.has(cid):
			_asked[cid] = true
			ask.append(cid)
	for cid2: int in shown.keys():
		if not want.has(cid2) and (info[cid2].pos as Vector3).distance_to(p) > SHOW_R + 6.0:
			_unbuild(cid2)
	if not ask.is_empty():
		if multiplayer.is_server():
			_cl_peek(_peek(ask))
		else:
			_srv_peek.rpc_id(1, ask)


func _peek(ids: Array) -> Dictionary:
	var out: Dictionary = {}
	for cid: int in ids:
		if info.has(cid) or contents.has(cid):
			out[cid] = _items_of(cid).duplicate()
	return out


@rpc("any_peer", "reliable")
func _srv_peek(ids: Array) -> void:
	if not multiplayer.is_server() or ids.size() > 400:
		return
	_reply(_sender(), "_cl_peek", [_peek(ids)])


@rpc("authority", "reliable")
func _cl_peek(d: Dictionary) -> void:
	for cid: int in d:
		_set_known(cid, d[cid])


## Nội dung một chỗ chứa vừa đổi (ai đó lấy, trả lại, vứt): mọi máy cập nhật hình ảnh.
@rpc("authority", "reliable", "call_local")
func _cl_set(cid: int, items: Array) -> void:
	if known.has(cid) or shown.has(cid):
		_set_known(cid, items)


func _broadcast(cid: int) -> void:
	if multiplayer.is_server():
		_cl_set.rpc(cid, _items_of(cid).duplicate())


## Mỗi món giữ nguyên chỗ của nó trên kệ / mặt tủ: lấy đi một món thì các món còn lại không bị xếp lại.
var _slots: Dictionary = {}      # cid -> Array[int] (ô của từng món, cùng thứ tự với known[cid])
var _nslots: Dictionary = {}     # cid -> số ô lúc mới thấy lần đầu (để cách xếp mặt tủ không đổi)


func _assign_slots(cid: int, items: Array) -> void:
	var old_items: Array = known.get(cid, [])
	var old_slots: Array = _slots.get(cid, [])
	if not _nslots.has(cid):
		_nslots[cid] = maxi(1, items.size())
	var used := {}
	var out: Array = []
	out.resize(items.size())
	var taken := {}
	# giữ ô cũ cho những món vẫn còn (khớp theo loại, lần lượt)
	for i in items.size():
		out[i] = -1
		for j in old_items.size():
			if not taken.has(j) and j < old_slots.size() and old_items[j] == items[i]:
				taken[j] = true
				out[i] = old_slots[j]
				used[old_slots[j]] = true
				break
	# món mới: ô trống nhỏ nhất
	var next := 0
	for i2 in items.size():
		if int(out[i2]) < 0:
			while used.has(next):
				next += 1
			out[i2] = next
			used[next] = true
	_slots[cid] = out
	_nslots[cid] = maxi(int(_nslots[cid]), next + 1 if items.size() > 0 else 1)


func _set_known(cid: int, items: Array) -> void:
	_assign_slots(cid, items)
	known[cid] = items
	if shown.has(cid):
		_unbuild(cid)
		_build(cid)
	elif world and world.local_player() and (info.get(cid, {}).get("pos", Vector3(1e9, 0, 0)) as Vector3).distance_to(world.local_player().global_position) < SHOW_R:
		_build(cid)


## Chỗ đặt món thứ i trong n món của một chỗ chứa: xếp thành hàng trên mặt tủ/kệ, hoặc rải trên đất (đồ rơi, thi thể).
func _slot_pos(cid: int, i: int, n: int) -> Vector3:
	var con: Dictionary = info[cid]
	var base: Vector3 = con.pos
	if con.has("shelf"):
		# kệ hàng: chia các ô đều theo tầng, theo mặt, dọc chiều dài kệ; mỗi chỗ chứa xếp hàng vào các ô khác nhau
		var lay: Dictionary = con.shelf
		var levels: Array = lay.levels
		var sides: Array = lay.sides
		var per_row := maxi(4, int(float(lay.half) * 2.0 / 0.32))
		var total := levels.size() * sides.size() * per_row
		var order: Array = range(total)
		var r := RandomNumberGenerator.new()
		r.seed = cid * 977 + 13
		for k in range(total - 1, 0, -1):
			var j := r.randi() % (k + 1)
			var tmp: int = order[k]
			order[k] = order[j]
			order[j] = tmp
		var slot: int = order[i % total]
		var lv: float = levels[slot % levels.size()]
		var sd: float = sides[(slot / levels.size()) % sides.size()]
		var col := slot / (levels.size() * sides.size())
		var along := -float(lay.half) + (col + 0.5) * float(lay.half) * 2.0 / per_row
		return (lay.c as Vector3) + (lay.axis as Vector3) * along + (lay.side as Vector3) * sd + Vector3(0, lv, 0)
	var ground: bool = con.get("drop", false) or con.get("table", "") in ["civ_body", "sol_body"]
	var off := Vector3.ZERO
	if ground:
		var a := float(cid % 7) + i * 2.1
		off = Vector3(cos(a), 0, sin(a)) * (0.35 + 0.18 * (i % 3)) if n > 1 or not con.get("drop", false) else Vector3.ZERO
		if con.get("table", "") in ["civ_body", "sol_body"]:
			off += Vector3(0.6, 0, 0)
	else:
		var cols := mini(n, 4)
		off = Vector3(((i % cols) - (cols - 1) * 0.5) * 0.26, 0, (float(i / cols) - 0.5 * float((n - 1) / cols)) * 0.24)
	var from := base + off + Vector3(0, 0.35, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -2.6, 0), 3)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return (hit.position as Vector3) + Vector3(0, 0.005, 0) if not hit.is_empty() else base + off - Vector3(0, 0.3, 0)


func _build(cid: int) -> void:
	var items: Array = known.get(cid, [])
	var nodes: Array = []
	for i in items.size():
		var id: String = items[i]
		var n := ItemModels.make(id)
		n.scale = Vector3.ONE * 1.3
		add_child(n)
		var slots: Array = _slots.get(cid, [])
		var si: int = slots[i] if i < slots.size() else i
		n.global_position = _slot_pos(cid, si, int(_nslots.get(cid, items.size())))
		n.rotation.y = float((cid * 7 + si * 13) % 31) * 0.2
		nodes.append({"item": id, "node": n, "i": i})
	shown[cid] = nodes


func _unbuild(cid: int) -> void:
	for e: Dictionary in shown.get(cid, []):
		(e.node as Node).queue_free()
	shown.erase(cid)


# ------------------------------------------------------------------ máy dò nhu yếu phẩm
signal scanned(marks: Array)

func scan(pos: Vector3) -> void:
	if multiplayer.is_server():
		_srv_scan(pos)
	else:
		_srv_scan.rpc_id(1, pos)


@rpc("any_peer", "reliable")
func _srv_scan(pos: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var marks: Array = []
	for cid: int in info:
		var cp: Vector3 = info[cid].pos
		if cp.distance_to(pos) > 40.0 or emptied.has(cid):
			continue
		var kinds := {}
		for id: String in _items_of(cid):
			var cat: String = Items.get_def(id).get("cat", "")
			if cat in ["food", "drink", "med"]:
				kinds[cat] = true
		if not kinds.is_empty():
			marks.append([cp, "med" if kinds.has("med") else ("food" if kinds.has("food") else "drink")])
	_reply(_sender(), "_cl_scanned", [marks])


@rpc("authority", "reliable")
func _cl_scanned(marks: Array) -> void:
	scanned.emit(marks)


## Đồ để lộ ra ngoài (bày trên kệ hàng, rơi dưới đất) thì hiện 3D và nhặt trực tiếp.
## Đồ cất trong tủ kín (tủ lạnh, ngăn kéo, tủ quần áo, hòm, thùng, thi thể…) thì phải mở ra xem danh sách.
func is_exposed(cid: int) -> bool:
	var con: Dictionary = info.get(cid, {})
	return con.has("shelf") or con.get("drop", false)


## Món đồ đang hiện gần nhất theo hướng nhìn: {cid, item, node, pos} hoặc {}.
func pick_target(origin: Vector3, dir: Vector3, eye: Vector3, reach: float) -> Dictionary:
	var best := {}
	var best_s := 0.93
	for cid: int in shown:
		var con_pos: Vector3 = info[cid].pos
		if con_pos.distance_to(eye) > reach + 1.5:
			continue
		for e: Dictionary in shown[cid]:
			var node: Node3D = e.node
			var c := node.global_position + Vector3(0, 0.07, 0)
			var d := eye.distance_to(c)
			if d > reach:
				continue
			var s := dir.dot((c - origin).normalized()) + (0.05 if d < 1.2 else 0.0)
			if s > best_s:
				best_s = s
				best = {"cid": cid, "item": e.item, "node": node, "pos": c}
	return best


## Các chỗ lục đồ quanh một điểm.
func near(p: Vector3) -> Array:
	var out := []
	var cx := floori(p.x / CELL)
	var cy := floori(p.y / 3.4)
	var cz := floori(p.z / CELL)
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				var ids: Array = grid.get(Vector3i(cx + dx, cy + dy, cz + dz), [])
				out.append_array(ids)
	return out


func _items_of(cid: int) -> Array:
	if not contents.has(cid):
		var con: Dictionary = info.get(cid, {})
		var items: Array = Items.roll(con.get("table", "house"), int(con.get("count", 2)), rng)
		if con.get("table", "") == "tu_box":
			items = ["xabeng", "bang", "gaysat"]
		match con.get("table", ""):
			"mansion_vault_0":
				items = ["maydo", "xabeng", "sungluc", "bangdan", "kinhdem", "baloxin"]
			"mansion_vault_1":
				items = ["xabeng", "aogiap", "bangdan", "bangdan", "socuu", "kinhdem"]
			"school_staff":
				items = ["xabeng", "giamdau", "bang", "caphe"]
			"hospital_safe":
				items = ["thuocdactri", "khangsinh", "khangsinh", "socuu"]
		if cid == city.school_med_cid:
			items.append("thuocdactri")
		if con.get("table", "") == "civ_body" and rng.randf() < 0.3:
			items.append("dongho")
		if con.get("table", "") == "sol_body":
			if rng.randf() < 0.5:
				items.append("sungluc")
			items.append("bangdan")
		contents[cid] = items
	return contents[cid]


# ------------------------------------------------------------------ mở / lấy
func open(cid: int) -> void:
	if multiplayer.is_server():
		_srv_open(cid)
	else:
		_srv_open.rpc_id(1, cid)


@rpc("any_peer", "reliable")
func _srv_open(cid: int) -> void:
	if not multiplayer.is_server() or not info.has(cid):
		return
	_reply(_sender(), "_cl_opened", [cid, _items_of(cid).duplicate()])


func take(cid: int, item: String) -> void:
	if multiplayer.is_server():
		_srv_take(cid, item)
	else:
		_srv_take.rpc_id(1, cid, item)


@rpc("any_peer", "reliable")
func _srv_take(cid: int, item: String) -> void:
	if not multiplayer.is_server() or not info.has(cid):
		return
	var items := _items_of(cid)
	var idx := items.find(item)
	if idx < 0:
		_reply(_sender(), "_cl_changed", [cid, items.duplicate()])
		return
	items.remove_at(idx)
	_reply(_sender(), "_cl_granted", [cid, item, items.duplicate()])
	_broadcast(cid)
	if items.is_empty():
		_cl_emptied.rpc(cid)


## Trả lại món đồ vào chỗ cũ (khi túi không chứa nổi).
func put_back(cid: int, item: String) -> void:
	if multiplayer.is_server():
		_srv_put_back(cid, item)
	else:
		_srv_put_back.rpc_id(1, cid, item)


@rpc("any_peer", "reliable")
func _srv_put_back(cid: int, item: String) -> void:
	if multiplayer.is_server() and info.has(cid):
		_items_of(cid).append(item)
		_cl_refilled.rpc(cid)
		_broadcast(cid)


func drop(item: String, pos: Vector3) -> void:
	if multiplayer.is_server():
		_srv_drop(item, pos)
	else:
		_srv_drop.rpc_id(1, item, pos)


@rpc("any_peer", "reliable")
func _srv_drop(item: String, pos: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var cid := _next_drop
	_next_drop += 1
	contents[cid] = [item]
	_cl_drop_added.rpc(cid, pos, item)
	_broadcast(cid)


## Thi thể mới (dân thường bị quái vật giết): lục được đồ. (Chỉ máy chủ.)
func add_body(pos: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var cid := _next_drop
	_next_drop += 1
	var items: Array = Items.roll("civ_body", 2 + rng.randi() % 2, rng)
	if rng.randf() < 0.25:
		items.append("dongho")
	contents[cid] = items
	_cl_body_added.rpc(cid, pos + Vector3(0, 0.35, 0))


@rpc("authority", "reliable", "call_local")
func _cl_body_added(cid: int, pos: Vector3) -> void:
	_register(cid, {"id": cid, "pos": pos, "name": "Thi thể", "table": "civ_body", "shop": false, "building": -1, "count": 2})
	var h := Humanoid.new()
	add_child(h)
	h.setup(Color.from_hsv(randf(), 0.35, 0.6), Color(0.2, 0.2, 0.24))
	h.position = pos - Vector3(0, 0.35, 0)
	h.rotation.y = randf() * TAU
	h.play_dead(true)
	h.animate(1.0, 0.0, false, false)
	h.set_process(false)
	bodies[cid] = h


func _sender() -> int:
	var id := multiplayer.get_remote_sender_id()
	return id if id != 0 else multiplayer.get_unique_id()


func _reply(pid: int, method: String, args: Array) -> void:
	if pid == multiplayer.get_unique_id():
		callv(method, args)
	else:
		rpc_id.callv([pid, method] + args)


@rpc("authority", "reliable")
func _cl_opened(cid: int, items: Array) -> void:
	opened.emit(cid, items)


@rpc("authority", "reliable")
func _cl_changed(cid: int, items: Array) -> void:
	changed.emit(cid, items)


@rpc("authority", "reliable")
func _cl_granted(cid: int, item: String, items: Array) -> void:
	if not world.grant_item(cid, item):
		put_back(cid, item)
		items = items + [item]
	changed.emit(cid, items)


@rpc("authority", "reliable", "call_local")
func _cl_emptied(cid: int) -> void:
	emptied[cid] = true
	if drops.has(cid):
		# drops[cid] chỉ là cờ đánh dấu (true), hình 3D của món đồ nằm trong `shown`: gỡ nó trước khi xoá info,
		# nếu không vòng hiển thị sau sẽ đọc info[cid] đã mất và lỗi.
		_unbuild(cid)
		known.erase(cid)
		_asked.erase(cid)
		drops.erase(cid)
		var p: Vector3 = info[cid].pos
		var key := Vector3i(floori(p.x / CELL), floori(p.y / 3.4), floori(p.z / CELL))
		(grid.get(key, []) as Array).erase(cid)
		info.erase(cid)


@rpc("authority", "reliable", "call_local")
func _cl_refilled(cid: int) -> void:
	emptied.erase(cid)


@rpc("authority", "reliable", "call_local")
func _cl_drop_added(cid: int, pos: Vector3, item: String) -> void:
	_register(cid, {"id": cid, "pos": pos, "name": Items.item_name(item), "table": "", "shop": false, "building": -1, "count": 1, "drop": true})
	drops[cid] = true
	_asked.erase(cid)


## Gửi cho người mới vào phòng danh sách chỗ đã bị lấy sạch và đồ đang rơi.
func sync_to(pid: int) -> void:
	_cl_state.rpc_id(pid, emptied.keys())
	for cid: int in drops:
		_cl_drop_added.rpc_id(pid, cid, info[cid].pos, (contents[cid] as Array)[0] if not (contents[cid] as Array).is_empty() else "banhmi")


@rpc("authority", "reliable")
func _cl_state(empty_ids: Array) -> void:
	for cid: int in empty_ids:
		emptied[cid] = true
