extends Node
## Đo quái vật đi xuyên tường: cho thế giới tự chạy vài phút (người chơi bay cao, quái không thấy),
## cứ vài khung hình lại kiểm tra các điểm trên thân quái có nằm trong khối nhà nào không.
## Chạy: godot --headless --path . --fixed-fps 60 res://tests/wall_test.tscn [-- giây]

var main: Node3D
var city: City
var stats: Dictionary = {}      # loài -> {samples, bad, worst}


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _note(kind: String, pts: Array) -> void:
	var s: Dictionary = stats.get(kind, {"samples": 0, "bad": 0, "where": []})
	s.samples += 1
	for q: Vector3 in pts:
		var b := city.building_at(q)
		if not b.is_empty():
			s.bad += 1
			if s.where.size() < 4:
				s.where.append("(%.0f,%.0f)" % [q.x, q.z])
			break
	stats[kind] = s


func mon_pos(kind: String) -> String:
	for m: Monster in main.monsters.list:
		if m.kind == kind:
			return "(%.0f,%.0f)" % [m.global_position.x, m.global_position.z]
	return ""


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var secs := 180
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			secs = int(a)
	main = (load("res://levels/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await frames(20)
	city = main.city
	var p: CharacterBody3D = main.local_player()
	Game.god = true
	Game.fly = true
	main.civs.set_physics_process(false)
	p.global_position = Vector3(0, 400, 0)
	# cho Cua Quỷ trồi lên cả đàn để có dữ liệu
	for m: Monster in main.monsters.list:
		if m.kind == "crawler" and m.has_method("spawn_at"):
			var at := city.road_point(m.rng)
			m.spawn_at(at, at)
	for m: Monster in main.monsters.list:
		if m.kind == "grub":
			var bb := city.building_at(m.global_position)
			print("GRUB at ", m.global_position, " state=", m.state, " in=", bb.get("kind", ""), " ", bb.get("rect", ""), " closed=", city.in_closed(m.global_position, 1.0), " route=", m.route.size())
	for q: Vector3 in [Vector3(-122,0,-41), Vector3(-127,0,-42)]:
		var b0 := city.building_at(q)
		print("SPOT ", q, " kind=", b0.get("kind", ""), " rect=", b0.get("rect", ""), " floors=", b0.get("floors", ""))
	var n := secs * 60
	for f in range(0, n, 6):
		await frames(6)
		p.global_position = Vector3(0, 400, 0)
		if main.dialogue.active:
			main.dialogue.advance()
		if f % 120 == 0:
			for m: Monster in main.monsters.list:
				if m.kind == "grub" and m.global_position.z < -190.0:
					print("G3 ", m.global_position, " r0=", m.route[0] if m.route.size() > 0 else null, " n=", m.route.size(), " yaw=", m.yaw)
		if f % 600 == 0:
			print("t=%ds frozen=%s grub0=%s" % [f / 60, Game.frozen(), mon_pos("grub")])
		for m: Monster in main.monsters.list:
			match m.kind:
				"grub":
					var pts: Array = [m.global_position]
					for i in range(0, m.segs.size(), 2):
						var g: Node3D = m.segs[i]
						var r: float = m.seg_r[i] * 0.75
						var side: Vector3 = g.global_transform.basis.x.normalized()
						pts.append(Vector3(g.global_position.x, 0.5, g.global_position.z))
						pts.append(g.global_position + side * r)
						pts.append(g.global_position - side * r)
					_note("Bạch Trùng (đầu + thân)", pts)
				"stalker":
					_note("Săn Mồi (tâm thân)", [m.global_position])
					_note("Săn Mồi (mũi)", [m.global_position + m.forward() * 10.5])
				"crawler":
					if m.state != "dormant" and m.state != "dead" and m.state != "emerge" and not m.wall_mode:
						_note("Cua Quỷ (ngoài đường)", [m.global_position])
				"robber":
					if m.visible:
						_note("Kẻ cướp", [m.global_position])
	var fail := false
	for k: String in stats:
		var s: Dictionary = stats[k]
		var pct: float = 100.0 * s.bad / maxf(1.0, s.samples)
		print("%-28s %5d mẫu, %4d lần trong nhà (%.1f%%) %s" % [k, s.samples, s.bad, pct, " ".join(s.where)])
		if pct > 1.0:
			fail = true
	print("WALL_TEST ", "FAIL" if fail else "PASS")
	get_tree().quit(1 if fail else 0)
