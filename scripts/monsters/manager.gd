extends Node
## Quản lý quái vật: máy chủ phòng mô phỏng, gửi trạng thái cho các máy khác 20 lần/giây.

const SCRIPTS := {
	"titan": preload("res://scripts/monsters/titan.gd"),
	"worm": preload("res://scripts/monsters/worm.gd"),
	"stalker": preload("res://scripts/monsters/stalker.gd"),
	"flyer": preload("res://scripts/monsters/flyer.gd"),
	"grub": preload("res://scripts/monsters/grub.gd"),
	"crawler": preload("res://scripts/monsters/crawler.gd"),
	"robber": preload("res://scripts/monsters/robber.gd"),
	"towereye": preload("res://scripts/monsters/tower_eye.gd"),
}

var list: Array[Monster] = []
var city: City
var world: Node
var _tick := 0
var _aw_t := 0.0
var _press_t := 25.0
var _press_rng := RandomNumberGenerator.new()
var _ray := PhysicsRayQueryParameters3D.new()
## Dấu chân gần đây của từng người chơi (để Cua Quỷ lần theo vào nhà, lên cầu thang).
var _trails: Dictionary = {}


func setup(c: City, w: Node, seed_v: int) -> void:
	city = c
	world = w
	_ray.collision_mask = 1
	# Thành phố rộng gấp ba nên số quái cũng tăng, nhưng không gấp ba: mật độ thưa hơn một chút, bù lại có bầy Cua Quỷ.
	var kinds: Array[String] = ["titan", "worm", "stalker", "stalker", "flyer", "grub", "worm", "stalker", "stalker", "worm", "flyer", "grub", "stalker", "grub"]
	for i in 12:
		kinds.append("crawler")      # bầy Cua Quỷ nằm chờ dưới lòng đất, trồi lên theo đợt
	for i2 in 6:
		kinds.append("robber")       # kẻ cướp: chỉ xuất hiện khi có chuyện (phá cửa hầm, phục kích ngoài phố)
	kinds.append("towereye")         # Quỷ Mắt trên tháp phát sóng: chỉ thức dậy ở Chương 2
	for kind: String in kinds:
		var m: Monster = SCRIPTS[kind].new()
		m.kind = kind
		m.name = "%s_%d" % [kind, list.size()]
		add_child(m)
		m.setup(self, c, seed_v + list.size() * 977)
		list.append(m)


func _physics_process(delta: float) -> void:
	if list.is_empty() or Game.won:
		return
	if Game.frozen():
		# hội thoại: quái đứng yên tại chỗ, vẫn thở
		for m in list:
			m.visual_tick(delta)
		return
	if multiplayer.is_server():
		_update_trails()
		for m in list:
			m.server_tick(delta)
		_separate()
		_waves(delta)
		_signal_hunt(delta)
		_tick += 1
		if _tick % 3 == 0 and world.online_peers() > 0:
			var states := []
			for m in list:
				states.append(m.pack())
			_sync.rpc(states)
		_press_t -= delta
		if _press_t <= 0.0:
			_press_t = 38.0 / float(Game.diff().sense)
			_close_in()
		_aw_t += delta
		if _aw_t >= 0.15:
			_aw_t = 0.0
			_report_awareness()
	else:
		for m in list:
			m.client_interp(delta)
	for m in list:
		m.visual_tick(delta)


@rpc("authority", "unreliable_ordered")
func _sync(states: Array) -> void:
	for i in mini(states.size(), list.size()):
		list[i].unpack(states[i])


## Gửi một sự kiện (gầm, giẫm, trồi lên, nổ...) tới mọi máy.
func fire(m: Monster, ev: String, arg: Variant = null) -> void:
	if multiplayer.is_server():
		_event.rpc(list.find(m), ev, arg)


@rpc("authority", "reliable", "call_local")
func _event(idx: int, ev: String, arg: Variant) -> void:
	if idx >= 0 and idx < list.size():
		list[idx].event(ev, arg)


## Thành phố khép dần quanh người chơi: cứ khoảng nửa phút, một con Săn Mồi đang đi tuần và Thủy Quái
## đổi hướng về khu vực người chơi đang ở (không biết chính xác chỗ, chỉ lảng vảng gần đó).
func _close_in() -> void:
	var ps := players()
	if ps.is_empty():
		return
	var p: Node3D = ps[_press_rng.randi() % ps.size()]
	var near := city.road_project(p.global_position + Vector3(_press_rng.randf_range(-45.0, 45.0), 0.0, _press_rng.randf_range(-45.0, 45.0)))
	var best: Monster = null
	var best_d := 1e9
	for mo in list:
		if mo.kind == "stalker" and mo.state == "patrol":
			var d := mo.global_position.distance_to(p.global_position)
			if d > 60.0 and d < best_d:
				best_d = d
				best = mo
	if best:
		best.set("_dest", near)
	for mo2 in list:
		if mo2.kind == "titan" and mo2.state == "wander" and mo2.global_position.distance_to(p.global_position) > 90.0:
			mo2.set("route", city.road_route(mo2.global_position, near))


## Quái lớn không đi xuyên qua nhau: Săn Mồi bị đẩy dạt khỏi thân Bạch Trùng, khỏi Săn Mồi khác và khỏi chân Thủy Quái.
func _separate() -> void:
	for s in list:
		if s.kind != "stalker":
			continue
		var push := Vector3.ZERO
		for o in list:
			if o == s:
				continue
			if o.kind == "grub":
				var segs: Array = o.get("segs")
				for i in range(0, segs.size(), 2):
					var sp: Vector3 = (segs[i] as Node3D).global_position
					var d := Vector2(s.global_position.x - sp.x, s.global_position.z - sp.z)
					var need := 6.5 - d.length()
					if need > 0.0 and d.length() > 0.01:
						push += Vector3(d.x, 0, d.y).normalized() * need
				var hd := Vector2(s.global_position.x - o.global_position.x, s.global_position.z - o.global_position.z)
				if hd.length() < 7.5 and hd.length() > 0.01:
					push += Vector3(hd.x, 0, hd.y).normalized() * (7.5 - hd.length())
			elif o.kind == "stalker" or o.kind == "titan":
				var rr := 12.0 if o.kind == "stalker" else 16.0
				var d2 := Vector2(s.global_position.x - o.global_position.x, s.global_position.z - o.global_position.z)
				if o.kind == "titan" and o.global_position.y < -5.0:
					continue
				if d2.length() < rr and d2.length() > 0.01:
					push += Vector3(d2.x, 0, d2.y).normalized() * (rr - d2.length())
		if push.length() > 0.01:
			var mover: CharacterBody3D = s.get("mover")
			mover.global_position += push.limit_length(0.25)
			s.global_position = mover.global_position


## Các đợt Cua Quỷ: cứ khoảng một phút rưỡi, vài con trồi lên từ khe nứt hoặc bờ hồ gần người chơi.
## Mỗi đợt tối đa 3 con, cùng lúc không quá 7 con trên mặt đất; con nào đi lạc xa thì chui xuống lại.
var _wave_t := 45.0
const WAVE_MAX_ACTIVE := 7


func _waves(delta: float) -> void:
	_wave_t -= delta
	if _wave_t > 0.0:
		return
	_wave_t = _press_rng.randf_range(75.0, 115.0) / float(Game.diff().sense)
	var ps := players()
	if ps.is_empty():
		return
	var pool: Array[Monster] = []
	var active := 0
	for m in list:
		if m.kind == "crawler":
			if m.state == "dormant":
				pool.append(m)
			elif m.state != "dead":
				active += 1
	var n := mini(mini(2 + _press_rng.randi() % 2, WAVE_MAX_ACTIVE - active), pool.size())
	if n <= 0:
		return
	var p: Node3D = ps[_press_rng.randi() % ps.size()]
	# chỗ trồi lên: các khe nứt và hai bờ thoải của hồ, cách người chơi 40-190m
	var sites: Array = []
	for ch in city.chasms:
		var c: Vector2 = (ch.rect as Rect2).get_center()
		sites.append([Vector3(c.x, -3.2, c.y), Vector3(c.x + _press_rng.randf_range(-4.0, 4.0), 0.02, c.y + (4.6 if _press_rng.randf() < 0.5 else -4.6))])
	var lk := city.lake_rect
	for sg: float in [-1.0, 1.0]:
		for k in 2:
			var z := lk.get_center().y + _press_rng.randf_range(-lk.size.y * 0.35, lk.size.y * 0.35)
			var x_in := lk.get_center().x + sg * (lk.size.x * 0.5 - 6.0)
			sites.append([Vector3(x_in, -2.5, z), Vector3(lk.get_center().x + sg * (lk.size.x * 0.5 + 5.0), City.BASE + 0.02, z)])
	var near: Array = []
	for st: Array in sites:
		var d := (st[1] as Vector3).distance_to(p.global_position)
		if d > 40.0 and d < 190.0:
			near.append(st)
	if near.is_empty():
		return
	near.sort_custom(func(a: Array, b: Array) -> bool: return (a[1] as Vector3).distance_to(p.global_position) < (b[1] as Vector3).distance_to(p.global_position))
	var site: Array = near[_press_rng.randi() % mini(3, near.size())]
	for i in n:
		var off := Vector3(_press_rng.randf_range(-1.5, 1.5), 0.0, _press_rng.randf_range(-1.0, 1.0)) * float(i)
		pool[i].call("spawn_at", (site[0] as Vector3) + off, (site[1] as Vector3) + off)


## Phục kích khi vác máy phát tín hiệu (chỉ chế độ Khó hoặc co-op): lúc vừa nhấc máy lên, một đợt Cua Quỷ trồi lên
## ngay trên mặt đường quanh trạm (gần hơn đợt thường) và mò thẳng tới người vác; sau đó cứ 40-55 giây lại thêm vài con
## cho tới khi máy được đặt xuống bệ trong hầm.
var _signal_t := -1.0
var _signal_was := false


func signal_ambush_on() -> bool:
	return Game.difficulty == "hard" or world.online_peers() > 0


func _signal_hunt(delta: float) -> void:
	var sh: Node = world.get("shelter")
	if sh == null or not signal_ambush_on():
		return
	var mc: Dictionary = sh.get("machine") if sh.get("machine") != null else {}
	var carrying := str(mc.get("state", "")) == "carried"
	if not carrying:
		_signal_was = false
		return
	var carrier: Node3D = player_by_id(int(mc.get("carrier", 0)))
	if carrier == null:
		return
	if not _signal_was:
		_signal_was = true
		_signal_t = 40.0
		var first := 3 + mini(2, world.online_peers())       # co-op: thêm 1 con mỗi người chơi khác (tối đa 5)
		spawn_crawlers_near(carrier, first, 28.0, 70.0)
		return
	_signal_t -= delta
	if _signal_t <= 0.0:
		_signal_t = _press_rng.randf_range(40.0, 55.0)
		spawn_crawlers_near(carrier, 2, 35.0, 80.0)


## Cho n Cua Quỷ trồi lên từ mặt đường cách người chơi `p` từ dmin tới dmax mét, rồi mò thẳng tới chỗ người đó.
## Trả về số con đã trồi lên (giới hạn bởi số con đang ngủ và tổng số trên mặt đất).
func spawn_crawlers_near(p: Node3D, n: int, dmin: float, dmax: float) -> int:
	var pool: Array[Monster] = []
	var active := 0
	for m in list:
		if m.kind == "crawler":
			if m.state == "dormant":
				pool.append(m)
			elif m.state != "dead":
				active += 1
	n = mini(mini(n, WAVE_MAX_ACTIVE + 2 - active), pool.size())
	var made := 0
	for i in n:
		var exit_pos := Vector3.ZERO
		for attempt in 16:
			var a := _press_rng.randf() * TAU
			var r := _press_rng.randf_range(dmin, dmax)
			var q := city.road_project(p.global_position + Vector3(cos(a) * r, 0.0, sin(a) * r))
			var d := Vector2(q.x - p.global_position.x, q.z - p.global_position.z).length()
			if d >= dmin * 0.8 and d <= dmax * 1.2 and city.building_at(q).is_empty() and city.water_depth(q + Vector3(0, 0.3, 0)) <= 0.0:
				exit_pos = Vector3(q.x, 0.02, q.z)
				break
		if exit_pos == Vector3.ZERO:
			continue
		var cr: Monster = pool[made]
		cr.call("spawn_at", exit_pos + Vector3(0, -3.2, 0), exit_pos)
		cr.set("lure", p.get_multiplayer_authority())
		world.fx.cracks(exit_pos, 3.0)
		made += 1
	return made


## Cho n kẻ cướp xuất hiện quanh `center` (chỉ máy chủ). Trả về những con đã xuất hiện.
func spawn_robbers(center: Vector3, n: int, spread := 2.0, inside := false) -> Array:
	var out: Array = []
	var r := RandomNumberGenerator.new()
	r.randomize()
	var loots := ["mitom", "nuocsuoi", "bang", "luongkho", "chai", "banhmi", "giamdau", "cahop"]
	for m in list:
		if out.size() >= n:
			break
		if m.kind != "robber":
			continue
		var free: bool = m.state == "dormant" or (m.state == "dead" and int(m.get("carrier")) == 0 and not world.shelter.in_bunker(m.global_position))
		if not free:
			continue
		var off := Vector3(r.randf_range(-spread, spread), 0.0, r.randf_range(-spread, spread)) if not inside else Vector3(r.randf_range(-0.6, 0.6), 0.0, r.randf_range(-0.6, 0.6)) * float(out.size())
		var loot: Array = []
		for k in 1 + r.randi() % 3:
			loot.append(loots[r.randi() % loots.size()])
		m.call("spawn_at", center + off, loot)
		out.append(m)
	return out


## Kẻ cướp còn đang đánh (chưa gục).
func robbers_fighting() -> int:
	var n := 0
	for m in list:
		if m.kind == "robber" and m.state == "fight":
			n += 1
	return n


func _update_trails() -> void:
	for p in get_tree().get_nodes_in_group("players"):
		var pid: int = p.get_multiplayer_authority()
		var t: PackedVector3Array = _trails.get(pid, PackedVector3Array())
		var pos: Vector3 = p.global_position
		if t.is_empty():
			t.append(pos)
		else:
			var d := t[t.size() - 1].distance_to(pos)
			if d > 9.0:
				t = PackedVector3Array([pos])        # dịch chuyển tức thời (hồi sinh): bỏ dấu cũ
			elif d > 0.9:
				t.append(pos)
				if t.size() > 170:
					t = t.slice(t.size() - 150)
		_trails[pid] = t


func trail_of(pid: int) -> PackedVector3Array:
	return _trails.get(pid, PackedVector3Array())


# ------------------------------------------------------------------ người chơi & cảm nhận
## Những người chơi còn sống, không ẩn (chế độ thần).
func players() -> Array:
	var out := []
	for p in get_tree().get_nodes_in_group("players"):
		if p.net_flags & (4 | 16):
			continue
		out.append(p)
	return out


func player_by_id(pid: int) -> Node3D:
	for p in get_tree().get_nodes_in_group("players"):
		if p.get_multiplayer_authority() == pid:
			return p
	return null


func clear_line(from: Vector3, to: Vector3) -> bool:
	_ray.from = from
	_ray.to = to
	return get_viewport().world_3d.direct_space_state.intersect_ray(_ray).is_empty()


## Mức nhìn thấy người chơi (0 = không thấy). Tường, sàn, mái đều chắn tầm nhìn; kính thì không.
func sees(eye: Vector3, p: Node3D, sight: float, facing := Vector3.ZERO, fov_cos := -1.0) -> float:
	var pos: Vector3 = p.global_position
	var crouch: bool = (p.net_flags & 1) != 0
	var swim: bool = (p.net_flags & 2) != 0
	var height := 0.9 if crouch else 1.6
	# Lặn hẳn xuống nước thì không bị thấy.
	if city.water_depth(pos + Vector3(0, height, 0)) > 0.05:
		return 0.0
	# Trên cầu cạn đường sắt: chỉ những con nhìn từ trên cao (Thủy Quái, Dực Quái) mới thấy.
	if eye.y < 25.0 and city.rail.on_deck(pos):
		return 0.0
	var reach := sight * float(Game.diff().sense)
	if City.in_forest(pos):
		if eye.y > 25.0:
			return 0.0                    # tán cây che kín: từ trên cao không thấy người trong rừng
		reach *= 0.4                      # thân cây, bụi rậm che khuất
	# Đứng dưới mái vòm ga trên cao: bị che hẳn, không con nào thấy.
	if city.rail.under_canopy(pos):
		return 0.0
	var dark: float = world.darkness()
	reach *= clampf(1.0 - float(p.net_stealth), 0.5, 1.3)
	reach *= lerpf(1.0, 0.8, dark)                         # ban đêm tầm nhìn giảm khoảng 20%
	if crouch:
		reach *= lerpf(0.62, 0.5, dark)                    # ngồi xuống thì khó thấy hơn, ban đêm càng khó
	elif float(p.net_speed) > 5.5:
		reach *= 1.3                                       # chạy thì dễ bị để ý
	if (p.net_flags & 8) != 0 and dark > 0.4 and eye.y < 25.0:
		reach *= 1.7                                       # bật đèn pin ban đêm: Săn Mồi, Cua Quỷ... thấy từ rất xa
	if swim:
		reach *= 0.7
	var to := pos + Vector3(0, height * 0.6, 0) - eye
	var dist := to.length()
	if dist > reach:
		return 0.0
	if fov_cos > -1.0 and dist > 3.0 and facing.dot(to / dist) < fov_cos:
		return 0.0
	var clear := 0
	for h: float in [height, height * 0.55, 0.25]:
		if clear_line(eye, pos + Vector3(0, h, 0)):
			clear += 1
	if clear == 0:
		return 0.0
	return (clear / 3.0) * clampf(1.4 - dist / reach, 0.25, 1.4)


func hurt(p: Node3D, amount: float, kind: String, part := "") -> void:
	world.hurt_player(p.get_multiplayer_authority(), amount, kind, part)


## Có mái/sàn che phía trên điểm này không?
func covered(pos: Vector3, height := 40.0) -> bool:
	return not clear_line(pos + Vector3(0, 1.0, 0), pos + Vector3(0, height, 0))


## Tiếng động trong thế giới (bước chân lớn, súng, pháo, nổ...). loud 0..1.
func hear(pos: Vector3, loud: float, source := "player") -> void:
	if not multiplayer.is_server():
		return
	for m in list:
		if source == "gun":
			var d := m.global_position.distance_to(pos)
			if d > 230.0 or m.hunting() or m.state in ["dormant", "dead"]:
				continue
			# đưa tiếng nổ vào trong tầm nghe của nó, rồi chỉ đích là đúng chỗ nổ súng
			var near := pos if d < 40.0 else m.global_position + (pos - m.global_position).normalized() * 40.0
			m.heard(near, 1.0, "player")
			m.last_seen = pos
			if "_dest" in m:
				m.set("_dest", pos)
		else:
			m.heard(pos, loud, source)


func melee(origin: Vector3, dir: Vector3, reach: float) -> int:
	for i in list.size():
		if list[i].ray_hit(origin, dir, reach):
			return i
	return -1


func _report_awareness() -> void:
	for p in get_tree().get_nodes_in_group("players"):
		var pid: int = p.get_multiplayer_authority()
		var best := 0.0
		var sense := ""
		var hunted := false
		for m in list:
			var a: float = m.aw.get(pid, 0.0)
			if a > best:
				best = a
				sense = m.sense
			if m.target_id == pid and m.hunting():
				hunted = true
		if pid == multiplayer.get_unique_id():
			_aware(best, sense, hunted)
		else:
			_aware.rpc_id(pid, best, sense, hunted)


@rpc("authority", "unreliable_ordered")
func _aware(level: float, sense: String, hunted: bool) -> void:
	Game.awareness = level
	Game.sense = sense
	Game.hunted = hunted


## Rung màn hình theo khoảng cách tới một điểm (gọi trên từng máy). freq: nhịp rung (thấp = chậm, nặng; cao = nhanh, gấp).
func shake_from(pos: Vector3, strength: float, radius: float, freq := 1.0) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var d := cam.global_position.distance_to(pos)
	if d < radius:
		Game.shake_freq = freq
		Game.shake.emit(strength * pow(1.0 - d / radius, 1.3))
