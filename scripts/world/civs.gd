extends Node3D
## Dân thường chạy loạn trên phố. Quái vật giẫm, đớp, thiêu họ; thi thể để lại lục được đồ.
## Máy chủ phòng mô phỏng, các máy khác nhận vị trí 6 lần/giây.

const COUNT := 130

var city: City
var world: Node
var rng := RandomNumberGenerator.new()
var list: Array[Dictionary] = []     # {node, pos, dest, alive, speed, yaw, scream}
var _sync_t := 0.0


func setup(c: City, w: Node, seed_v: int) -> void:
	city = c
	world = w
	rng.seed = seed_v + 31
	for i in COUNT:
		var h := Humanoid.new()
		add_child(h)
		h.setup(Color.from_hsv(rng.randf(), 0.4, 0.8), Color.from_hsv(rng.randf(), 0.2, 0.35), Color("c99a70"))
		var p := city.road_point(rng)
		while p.distance_to(city.start_pos) < 22.0 or city._near_underground(p, 4.0):
			p = city.road_point(rng)
		h.position = p
		list.append({"node": h, "pos": p, "dest": city.road_point(rng), "alive": true, "speed": 0.0, "yaw": 0.0, "scream": rng.randf_range(2.0, 8.0), "net": p})


func alive_count() -> int:
	var n := 0
	for c in list:
		if c.alive:
			n += 1
	return n


func _physics_process(delta: float) -> void:
	if list.is_empty():
		return
	if multiplayer.is_server():
		_simulate(delta)
		_sync_t += delta
		if _sync_t > 0.16 and world.online_peers() > 0:
			_sync_t = 0.0
			var pos := PackedVector3Array()
			var alive := 0
			for i in list.size():
				pos.append(list[i].pos)
				if list[i].alive:
					alive |= 1 << i
			_cl_sync.rpc(pos, alive)
	var cam := get_viewport().get_camera_3d()
	for c in list:
		var h: Humanoid = c.node
		if not multiplayer.is_server() and c.alive:
			var before: Vector3 = c.pos
			c.pos = (c.pos as Vector3).lerp(c.net, minf(1.0, delta * 8.0))
			var mv := (c.pos as Vector3) - before
			c.speed = lerpf(c.speed, mv.length() / maxf(delta, 0.001), 0.2)
			if mv.length() > 0.001:
				c.yaw = lerp_angle(c.yaw, atan2(mv.x, mv.z), minf(1.0, delta * 8.0))
		# Ban đêm: phần lớn trốn trong nhà (không thấy trên đường), số ít còn lại đi rón rén.
		var night: bool = world.darkness() > 0.6
		var hiding := night and (list.find(c) % 4 != 0)
		c["hiding"] = hiding
		h.visible = c.alive and not hiding and cam != null and cam.global_position.distance_to(c.pos) < 90.0
		if h.visible:
			h.position = c.pos
			h.rotation.y = c.yaw
			h.animate(delta, c.speed, night and c.speed < 3.0, false)


func _simulate(delta: float) -> void:
	var night: bool = world.darkness() > 0.6
	for c in list:
		if not c.alive or c.get("hiding", false):
			continue
		var pos: Vector3 = c.pos
		# quái vật gần nhất
		var threat := Vector3.ZERO
		var threat_d := 999.0
		for m: Monster in world.monsters.list:
			if m.state == "dormant" or m.kind == "worm" and m.state != "erupt":
				continue
			var mp := m.global_position
			var d := Vector2(mp.x - pos.x, mp.z - pos.z).length()
			if d < threat_d:
				threat_d = d
				threat = mp
			# bị đớp / bị đè
			var kill_r := 3.0 if m.kind == "stalker" else (3.6 if m.kind == "grub" else 0.0)
			if kill_r > 0.0 and d < kill_r:
				_kill(c)
				break
		if not c.alive:
			continue
		var speed := 1.2 if night else 2.6      # đêm thì đi rón rén
		var goal: Vector3 = c.dest
		if threat_d < 45.0:
			speed = 6.3
			var away := (pos - threat)
			away.y = 0.0
			if pos.distance_to(c.dest) < 6.0 or (c.dest - pos).dot(away) < 0.0:
				# chạy tới ngã tư xa quái vật nhất trong các ngã tư lân cận
				var n := city.nearest_node(pos)
				var best := pos + away.normalized() * 30.0
				var best_d := -1.0
				for off: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q := n + off
					if not city.node_open(q):
						continue
					var qp := city.node_pos(q) + Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4))
					var dd := qp.distance_to(threat)
					if dd > best_d:
						best_d = dd
						best = qp
				c.dest = best
			# tiếng la hét thu hút quái vật săn mồi
			c.scream -= delta
			if c.scream <= 0.0:
				c.scream = rng.randf_range(5.0, 11.0)
				world.monsters.hear(pos, 0.62, "civ")
		elif pos.distance_to(c.dest) < 3.0:
			c.dest = city.road_point(rng)
		var to: Vector3 = goal - pos
		to.y = 0.0
		if to.length() > 0.5:
			var dir := to.normalized()
			var next := pos + dir * speed * delta
			if city._near_underground(next, 0.6):
				c.dest = city.road_point(rng)
			else:
				c.pos = next
				c.yaw = lerp_angle(c.yaw, atan2(dir.x, dir.z), minf(1.0, delta * 6.0))
		c.speed = speed


func _kill(c: Dictionary) -> void:
	c.alive = false
	var idx := list.find(c)
	_cl_died.rpc(idx, c.pos)
	world.loot.add_body(c.pos)


## Một cú giẫm / vụ nổ tại `pos`: ai trong bán kính thì chết. (Chỉ máy chủ.)
func crush(pos: Vector3, radius: float) -> void:
	if not multiplayer.is_server():
		return
	for c in list:
		if c.alive and not c.get("hiding", false) and Vector2(c.pos.x - pos.x, c.pos.z - pos.z).length() < radius:
			_kill(c)


@rpc("authority", "unreliable_ordered")
func _cl_sync(pos: PackedVector3Array, alive: int) -> void:
	for i in mini(pos.size(), list.size()):
		list[i].net = pos[i]
		if not (alive & (1 << i)) and list[i].alive:
			list[i].alive = false


@rpc("authority", "reliable", "call_local")
func _cl_died(idx: int, pos: Vector3) -> void:
	if idx < 0 or idx >= list.size():
		return
	list[idx].alive = false
	world.fx.dust(pos, 1.2)
	world.fx.blood(pos)
