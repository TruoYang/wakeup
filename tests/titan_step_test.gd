extends Node
## Đo chỗ Thủy Quái đặt chân: lúc đi lang thang (không đuổi ai) bàn chân phải đặt ngoài công trình;
## nhà cốt truyện (nhà mình, nhà bác Tư, văn phòng, siêu thị, công trình mốc) không bao giờ bị giẫm.
## Chạy: godot --headless --path . --fixed-fps 60 res://tests/titan_step_test.tscn [-- giây]

var main: Node3D
var city: City
var titan: Monster
var steps := {"wander": 0, "hunt": 0}
var in_bld := {"wander": 0, "hunt": 0}
var story_hits := 0
var where: Array = []
var leg_samples := 0
var leg_bad := 0
var parts: Dictionary = {}


func _inside(q: Vector3) -> bool:
	var p2 := Vector2(q.x, q.z)
	for b in city.buildings:
		if b.get("ruined", false) or b.get("damage", "") == "collapse":
			continue
		if (b.rect as Rect2).has_point(p2) and q.y < float(b.floors) * float(b.fh) + 0.5:
			return true
	return false


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _story(b: Dictionary) -> bool:
	return b.kind in ["home", "tu", "office", "mall"] or b.get("landmark", false)


func _on_planted(pos: Vector3) -> void:
	var mode := "hunt" if titan.hunting() else "wander"
	steps[mode] += 1
	var q := Vector2(pos.x, pos.z)
	for b in city.buildings:
		if b.get("ruined", false) or b.get("damage", "") == "collapse":
			continue
		if (b.rect as Rect2).has_point(q):
			in_bld[mode] += 1
			if _story(b):
				story_hits += 1
			if where.size() < 6:
				where.append("%s(%.0f,%.0f)" % [mode, pos.x, pos.z])
			break


func _ready() -> void:
	var secs := 150
	var noplace := false
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			secs = int(a)
		if a == "noplace":
			noplace = true      # đo kiểu đặt chân cũ (không tránh nhà) để so sánh
	main = (load("res://levels/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await frames(20)
	city = main.city
	var p: CharacterBody3D = main.local_player()
	Game.god = true
	Game.fly = true
	main.civs.set_physics_process(false)
	for m: Monster in main.monsters.list:
		if m.kind == "titan":
			titan = m
	# đánh thức ngay, bỏ đoạn trồi lên khỏi hồ
	titan.state = "wander"
	titan.global_position.y = 0.0
	titan.visible = true
	for l: MonsterLeg in titan.legs:
		l.planted.connect(_on_planted)
		if noplace:
			l.place = Callable()
	for f in range(0, secs * 60, 6):
		await frames(6)
		# lấy mẫu dọc hai đốt của mỗi chân và quanh mép bàn chân: điểm nào nằm trong một toà nhà còn đứng, thấp hơn mái
		if titan.state == "wander":
			leg_samples += 1
			var hit := false
			for l2: MonsterLeg in titan.legs:
				var pts: Array = []
				for seg: Node3D in [l2._upper, l2._lower]:
					for k in 6:
						pts.append(seg.global_transform * Vector3(0, -37.0 * (k + 0.5) / 6.0, 0))
				for a2 in 8:
					pts.append(l2.foot + Vector3(cos(a2 * TAU / 8.0) * 4.5, 1.0, sin(a2 * TAU / 8.0) * 4.5))
				for qi in pts.size():
					if _inside(pts[qi]):
						hit = true
						var part := "đùi" if qi < 6 else ("ống chân" if qi < 12 else "mép bàn chân")
						parts[part] = int(parts.get(part, 0)) + 1
						break
				if hit:
					break
			if hit:
				leg_bad += 1
		if main.dialogue.active:
			main.dialogue.advance()
		p.global_position = Vector3(0, 400, 0)          # ở trên cao: nó không thấy, cứ đi lang thang
	var pct: float = 100.0 * in_bld.wander / maxf(1.0, steps.wander)
	print("Bước lúc đi lang thang: %d, giẫm vào nhà: %d (%.1f%%)" % [steps.wander, in_bld.wander, pct])
	print("Giẫm vào nhà cốt truyện: %d" % story_hits)
	print("Ví dụ: ", " ".join(where))
	var lpct: float = 100.0 * leg_bad / maxf(1.0, leg_samples)
	print("Chân (đùi, ống chân, mép bàn chân) xuyên vào nhà: %d/%d lần lấy mẫu (%.1f%%)" % [leg_bad, leg_samples, lpct])
	print("Theo phần: ", parts)
	var ok: bool = pct <= 3.0 and story_hits == 0 and steps.wander > 20 and lpct <= 8.0
	print("TITAN_STEP_TEST ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
