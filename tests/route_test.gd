extends Node
## Kiểm thử mở đầu Chương 1 và đường chỉ dẫn: chưa có chỉ dẫn cho tới khi Thủy Quái trồi lên; đường đi
## bám mặt đường từ đúng chỗ đứng, không đi ngược, ít rẽ, góc cua bo tròn, không xuyên qua nhà.

var results: Array[String] = []
var failed := false


func check(cond: bool, what: String) -> void:
	results.append(("OK   " if cond else "FAIL ") + what)
	if not cond:
		failed = true


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Góc gấp nhất giữa hai đoạn liên tiếp (độ).
func sharpest(pts: Array[Vector3]) -> float:
	var worst := 0.0
	for k in range(1, pts.size() - 1):
		var d1 := pts[k] - pts[k - 1]
		var d2 := pts[k + 1] - pts[k]
		if d1.length() < 0.01 or d2.length() < 0.01:
			continue
		worst = maxf(worst, rad_to_deg(d1.normalized().angle_to(d2.normalized())))
	return worst


func length(pts: Array[Vector3]) -> float:
	var l := 0.0
	for k in pts.size() - 1:
		l += pts[k].distance_to(pts[k + 1])
	return l


## Số lần xuyên qua khối nhà (bỏ qua 20m đầu và cuối: lúc ra khỏi / đi vào toà nhà).
func through_buildings(city: City, pts: Array[Vector3]) -> int:
	var n := 0
	var total := length(pts)
	var walked := 0.0
	for k in pts.size() - 1:
		var seg := pts[k].distance_to(pts[k + 1])
		var steps := maxi(1, int(seg / 2.0))
		for s in steps:
			var q := pts[k].lerp(pts[k + 1], float(s) / steps)
			var w := walked + seg * float(s) / steps
			if w < 20.0 or w > total - 20.0:
				continue
			if not city.building_at(q).is_empty():
				n += 1
		walked += seg
	return n


func _ready() -> void:
	Game.chapter = 1
	Net.mode = Net.Mode.SOLO
	var main: Node3D = (load("res://levels/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await frames(30)
	var city: City = main.city
	var p: CharacterBody3D = main.local_player()
	# --- mở đầu
	check(not main.has_objective(), "mới tỉnh dậy: chưa có chỉ dẫn về nhà (%s)" % Game.objective)
	check(not Game.objective.contains("nhà"), "mục tiêu ban đầu không nhắc tới nhà: '%s'" % Game.objective)
	var ti: Monster = null
	for m: Monster in main.monsters.list:
		if m.kind == "titan":
			ti = m
	await frames(60 * 10)
	check(ti.state == "dormant" and not main.has_objective(), "10 giây sau vẫn chưa có chỉ dẫn (quái chưa lên)")
	var waited := 0
	while ti.state == "dormant" and waited < 60 * 40:
		await frames(1)
		waited += 1
	await frames(5)
	check(main.has_objective(), "Thủy Quái trồi lên (giây %.0f): có chỉ dẫn" % main.play_time)
	await frames(60 * 4)
	check(main.dialogue.visible or Game.talking, "nhân vật chính nghĩ tới chuyện về nhà (lời thoại)")
	for i in 12:
		main.dialogue.advance()
		await frames(10)
	check(Game.objective == "Về nhà, tìm vợ con", "mục tiêu: '%s'" % Game.objective)
	# --- đường chỉ dẫn
	var r := city.guide_route(p.global_position, city.home_pos)
	check(r[0].distance_to(Vector3(p.global_position.x, 0, p.global_position.z)) < 0.6, "đường bắt đầu từ chỗ đang đứng")
	check(r[-1].distance_to(Vector3(city.home_pos.x, 0, city.home_pos.z)) < 0.6, "đường kết thúc ở nhà")
	check(sharpest(r) < 25.0, "văn phòng → nhà: góc gấp nhất %.0f° (bo tròn)" % sharpest(r))
	check(through_buildings(city, r) == 0, "văn phòng → nhà: không xuyên qua nhà (%d điểm)" % through_buildings(city, r))
	print("văn phòng → nhà: %d điểm, dài %.0fm, đường chim bay %.0fm" % [r.size(), length(r), p.global_position.distance_to(city.home_pos)])
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bad_turn := 0
	var bad_house := 0
	var back := 0
	var ratio := 0.0
	var spent := 0
	for k in 60:
		var a := city.road_point(rng)
		var b := city.road_point(rng)
		city._guide_key = []
		var t0 := Time.get_ticks_usec()
		var rr := city.guide_route(a, b)
		spent += Time.get_ticks_usec() - t0
		if sharpest(rr) >= 25.0:
			bad_turn += 1
		if through_buildings(city, rr) > 0:
			bad_house += 1
		# không đi ngược: điểm thứ hai không được xa đích hơn điểm đầu quá nhiều so với đường thẳng
		if rr.size() > 2 and rr[1].distance_to(a) > 2.0 and (rr[1] - rr[0]).normalized().dot((rr[-1] - rr[0]).normalized()) < -0.7 and length(rr) > a.distance_to(b) * 1.6:
			back += 1
		ratio = maxf(ratio, length(rr) / maxf(1.0, a.distance_to(b)))
	var us := spent / 60.0
	check(bad_turn == 0, "60 đường ngẫu nhiên: %d đường có góc gấp" % bad_turn)
	check(bad_house == 0, "60 đường ngẫu nhiên: %d đường xuyên nhà" % bad_house)
	check(back == 0, "60 đường ngẫu nhiên: %d đường quay ngược lúc đầu" % back)
	check(us < 15000.0, "tính một đường mất %.1f ms" % (us / 1000.0))
	print("đường dài nhất so với chim bay: ×%.2f" % ratio)
	# đứng yên thì dùng lại kết quả cũ (không tính lại mỗi khung hình)
	var r1 := city.guide_route(p.global_position, city.home_pos)
	var t1 := Time.get_ticks_usec()
	for k2 in 100:
		city.guide_route(p.global_position + Vector3(0.5, 0, 0), city.home_pos)
	check((Time.get_ticks_usec() - t1) / 100.0 < 300.0 and r1.size() > 2, "đứng yên: dùng lại đường đã tính")
	for line in results:
		print(line)
	print("KẾT QUẢ: ", "THẤT BẠI" if failed else "TẤT CẢ ĐẠT")
	get_tree().quit(1 if failed else 0)
