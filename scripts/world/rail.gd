class_name Rail
extends RefCounted
## Đường sắt trên cao (theo kiểu tuyến Cát Linh): cầu cạn bê tông cao 11m chạy dọc các trục đường lớn,
## rẽ bằng những khúc cua tròn và lượn nhẹ trên đoạn thẳng. 6 ga (mỗi ga 2 lối lên ở hai bên đường) có mái vòm, cầu thang bộ, rào chắn sân ga.
## Hai đoạn gãy cụt (bên dưới có đống đổ nát đỡ khi nhảy xuống), một đoạn gãy một bên, hai đoàn tàu hỏng.
## Trên cầu cạn chỉ Thủy Quái và Dực Quái nhìn thấy người.

const DECK_Y := 11.0           # mặt cầu (chỗ người đứng)
const HALF := 4.8              # nửa bề rộng cầu (hai đường ray)
const TRACK := 2.1             # tim mỗi đường ray cách tim cầu
const R := 38.0                # bán kính khúc cua
const STEP := 2.0              # khoảng cách các điểm mẫu dọc tuyến
const STATION_LEN := 46.0
const STATION_HALF := 7.6      # nửa bề rộng sân ga (đường ray + sân hai bên)
const NAMES := ["GA BỜ HỒ", "GA HÀNG ĐẬU", "GA TRUNG TÂM", "GA CÔNG VIÊN", "GA NGÕ CHÙA", "GA CUỐI TUYẾN"]

var pts: PackedVector3Array = []     # tim tuyến ở mặt đất
var dist: PackedFloat32Array = []    # quãng đường tích luỹ
var length := 0.0
var stations: Array[Dictionary] = []   # {s, name, side, stair_base, stair_top}
var gaps: Array[Vector2] = []          # các đoạn gãy cụt [s0, s1]
var half_gaps: Array[Vector2] = []     # các đoạn gãy một bên (mất nửa cầu phía bên phải)
var trains: Array[Dictionary] = []     # {s, track, cars, derail}
var _hash: Dictionary = {}             # ô 20m -> chỉ số các điểm mẫu
const CELL := 20.0


# ------------------------------------------------------------------ vạch tuyến
func plan() -> void:
	var corners: Array[Vector3] = [
		Vector3(City.road_x(0) + 6.0, 0, City.road_z(1)),
		Vector3(City.road_x(4), 0, City.road_z(1)),
		Vector3(City.road_x(4), 0, City.road_z(3)),
		Vector3(City.road_x(11), 0, City.road_z(3)),
		Vector3(City.road_x(11), 0, City.road_z(5)),
		Vector3(City.road_x(City.COLS) - 6.0, 0, City.road_z(5)),
	]
	var raw: Array[Vector3] = []
	var straight: Array[float] = []      # 1 = đoạn thẳng (được lượn nhẹ), 0 = khúc cua
	for i in corners.size() - 1:
		var a := corners[i]
		var b := corners[i + 1]
		var dir := (b - a).normalized()
		var s0 := a + dir * (R if i > 0 else 0.0)
		var s1 := b - dir * (R if i < corners.size() - 2 else 0.0)
		var n := maxi(1, int(s0.distance_to(s1) / STEP))
		for k in n:
			raw.append(s0.lerp(s1, float(k) / n))
			straight.append(1.0)
		if i < corners.size() - 2:
			# khúc cua tròn giữa đoạn này và đoạn sau
			var nxt := (corners[i + 2] - b).normalized()
			var center := b - dir * R + nxt * R
			var arc_n := int(R * PI * 0.5 / STEP)
			for k2 in arc_n:
				var th := float(k2) / arc_n * PI * 0.5
				raw.append(center - nxt * R * cos(th) + dir * R * sin(th))
				straight.append(0.0)
	raw.append(corners[corners.size() - 1])
	straight.append(1.0)
	# quãng đường tích luỹ (trước khi lượn)
	var d0: Array[float] = [0.0]
	for i2 in range(1, raw.size()):
		d0.append(d0[i2 - 1] + raw[i2].distance_to(raw[i2 - 1]))
	var total := d0[d0.size() - 1]
	# ga: trên các đoạn thẳng dài
	var st_s: Array[float] = []
	var seg_len := func(i: int) -> Vector2:
		# đoạn thẳng thứ i: [đầu, cuối] theo quãng đường
		var a2 := -1.0
		var k := 0
		var out := Vector2.ZERO
		for j in raw.size():
			if straight[j] > 0.5 and (j == 0 or straight[j - 1] < 0.5):
				if k == i:
					a2 = d0[j]
				k += 1
			if a2 >= 0.0 and (j == raw.size() - 1 or straight[j + 1] < 0.5):
				out = Vector2(a2, d0[j])
				break
		return out
	var s1v: Vector2 = seg_len.call(0)
	var s3v: Vector2 = seg_len.call(2)
	var s5v: Vector2 = seg_len.call(4)
	var office_x := City.block_center(City.OFFICE_BLOCK.x, 0).x
	st_s.append(s1v.x + (office_x - (City.road_x(0) + 6.0)))
	var s2v: Vector2 = seg_len.call(1)
	st_s.append((s2v.x + s2v.y) * 0.5)          # ga giữa: chỗ trú giữa ga đầu và ga thứ hai (vốn cách nhau rất xa)
	st_s.append(lerpf(s3v.x, s3v.y, 0.3))
	st_s.append(lerpf(s3v.x, s3v.y, 0.78))
	var home_x := City.block_center(City.HOME_BLOCK.x, 0).x
	st_s.append(s5v.x + (home_x - City.road_x(11) - R))
	st_s.append(s5v.y - 40.0)
	# lượn nhẹ trên đoạn thẳng (không lượn ở gần khúc cua và trong ga)
	pts = PackedVector3Array()
	for j2 in raw.size():
		var w := 0.0
		if straight[j2] > 0.5:
			var d_c := 1e9
			for j3 in range(maxi(0, j2 - 30), mini(raw.size(), j2 + 31)):
				if straight[j3] < 0.5:
					d_c = minf(d_c, absf(d0[j3] - d0[j2]))
			w = clampf((d_c - 6.0) / 40.0, 0.0, 1.0)
			for ss in st_s:
				w *= clampf((absf(d0[j2] - ss) - STATION_LEN * 0.5 - 4.0) / 30.0, 0.0, 1.0)
		var tan := (raw[mini(j2 + 1, raw.size() - 1)] - raw[maxi(j2 - 1, 0)]).normalized()
		var nrm := Vector3(-tan.z, 0, tan.x)
		pts.append(raw[j2] + nrm * 2.2 * sin(d0[j2] / 64.0) * w)
	dist = PackedFloat32Array()
	dist.append(0.0)
	for j4 in range(1, pts.size()):
		dist.append(dist[j4 - 1] + pts[j4].distance_to(pts[j4 - 1]))
	length = dist[dist.size() - 1]
	# ga, đoạn gãy, tàu (theo quãng đường đã tính lại; độ lệch do lượn rất nhỏ)
	var scale := length / total
	for i5 in st_s.size():
		var s := st_s[i5] * scale
		stations.append({"s": s, "name": NAMES[i5], "side": 1.0 if i5 % 2 == 0 else -1.0})
	gaps = [Vector2(lerpf(stations[2].s, stations[3].s, 0.5) - 9.0, lerpf(stations[2].s, stations[3].s, 0.5) + 9.0),
		Vector2(lerpf(stations[4].s, stations[5].s, 0.55) - 9.0, lerpf(stations[4].s, stations[5].s, 0.55) + 9.0)]
	var s4v: Vector2 = seg_len.call(3)
	var mid4 := (s4v.x + s4v.y) * 0.5 * scale
	half_gaps = [Vector2(mid4 - 8.0, mid4 + 8.0)]
	trains = [{"s": stations[2].s + STATION_LEN * 0.5 + 6.0, "track": -1.0, "cars": 3, "derail": false},
		{"s": lerpf(stations[4].s, gaps[1].x, 0.45), "track": 1.0, "cars": 3, "derail": true}]
	for idx in pts.size():
		var key := Vector2i(floori(pts[idx].x / CELL), floori(pts[idx].z / CELL))
		if not _hash.has(key):
			_hash[key] = []
		(_hash[key] as Array).append(idx)
	for st: Dictionary in stations:
		var f := frame(st.s)
		var side: float = st.side
		var along: Vector3 = f.t
		var out: Vector3 = f.n * side
		st["stair_base"] = (f.p as Vector3) + out * 9.6 - along * 14.0
		st["stair_top"] = (f.p as Vector3) + out * 9.6 + along * 4.5
		# lối lên thứ hai ở bên kia đường, chạy ngược chiều
		st["stair_base2"] = (f.p as Vector3) - out * 9.6 + along * 14.0
		st["stair_top2"] = (f.p as Vector3) - out * 9.6 - along * 4.5


## Vị trí, hướng tiếp tuyến và pháp tuyến tại quãng đường s.
func frame(s: float) -> Dictionary:
	s = clampf(s, 0.0, length)
	var lo := 0
	var hi := dist.size() - 1
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if dist[mid] <= s:
			lo = mid
		else:
			hi = mid
	var t := 0.0 if dist[hi] - dist[lo] < 0.001 else (s - dist[lo]) / (dist[hi] - dist[lo])
	var p := pts[lo].lerp(pts[hi], t)
	var tan := (pts[hi] - pts[lo]).normalized()
	return {"p": p, "t": tan, "n": Vector3(-tan.z, 0, tan.x)}


## Khoảng cách ngang nhỏ nhất từ một hình chữ nhật (mặt bằng) tới tim tuyến, kèm quãng đường của điểm gần nhất.
func rect_dist(r: Rect2) -> Vector2:
	var best := 1e9
	var best_s := 0.0
	var c0 := Vector2i(floori((r.position.x - 30.0) / CELL), floori((r.position.y - 30.0) / CELL))
	var c1 := Vector2i(floori((r.end.x + 30.0) / CELL), floori((r.end.y + 30.0) / CELL))
	for cx in range(c0.x, c1.x + 1):
		for cz in range(c0.y, c1.y + 1):
			for idx: int in _hash.get(Vector2i(cx, cz), []):
				var p := pts[idx]
				var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
				var dz := maxf(maxf(r.position.y - p.z, 0.0), p.z - r.end.y)
				var d := sqrt(dx * dx + dz * dz)
				if d < best:
					best = d
					best_s = dist[idx]
	return Vector2(best, best_s)


func near_station(s: float, extra := 0.0) -> Dictionary:
	for st: Dictionary in stations:
		if absf(s - float(st.s)) < STATION_LEN * 0.5 + extra:
			return st
	return {}


## Nhà này có vướng cầu cạn, ga hoặc cầu thang lên ga không (vướng thì không xây).
func blocks(r: Rect2) -> bool:
	var d := rect_dist(r)
	if d.x < HALF + 1.2:
		return true
	if not near_station(d.y, 16.0).is_empty() and d.x < 12.5:
		return true
	return false


## Điểm này có đang ở trên mặt cầu không (để quái dưới đất không nhìn thấy người trên cao).
func on_deck(p: Vector3) -> bool:
	if p.y < DECK_Y - 2.0:
		return false
	var d := rect_dist(Rect2(p.x, p.z, 0, 0))
	return d.x < STATION_HALF + 3.0


## Đứng dưới mái vòm của một ga trên cao.
func under_canopy(p: Vector3) -> bool:
	if p.y < DECK_Y - 1.0 or p.y > DECK_Y + 4.0:
		return false
	var d := rect_dist(Rect2(p.x, p.z, 0, 0))
	return d.x < STATION_HALF + 0.3 and not near_station(d.y).is_empty()


func in_gap(s: float) -> bool:
	for g in gaps:
		if s > g.x and s < g.y:
			return true
	return false


func in_half_gap(s: float) -> bool:
	for g in half_gaps:
		if s > g.x and s < g.y:
			return true
	return false


# ------------------------------------------------------------------ dựng hình
func build(city: City) -> void:
	var node := Node3D.new()
	node.name = "Rail"
	city.add_child(node)
	var mb := MeshBuilder.new(node)
	var conc := Color(0.86, 0.85, 0.82)
	var dark_c := Color(0.62, 0.62, 0.6)
	var rail_c := Color(0.45, 0.42, 0.4)
	var panel := Color(0.78, 0.82, 0.86)
	var seg := 4.0
	var s := 0.0
	var k := 0
	while s < length:
		var s_mid := s + seg * 0.5
		var f := frame(s_mid)
		var p: Vector3 = f.p
		var t: Vector3 = f.t
		var yaw := atan2(t.x, t.z)
		var rot := Basis(Vector3.UP, yaw)
		var nrm: Vector3 = f.n
		var station := near_station(s_mid)
		var gap := in_gap(s_mid)
		var half := in_half_gap(s_mid)
		if not gap:
			var w := STATION_HALF * 2.0 if not station.is_empty() else HALF * 2.0
			var off := Vector3.ZERO
			if half:
				w = HALF            # chỉ còn nửa cầu bên trái
				off = -nrm * HALF * 0.5
			# mặt cầu + dầm hộp bên dưới
			mb.box("concrete", p + off + Vector3(0, DECK_Y - 0.25, 0), Vector3(w, 0.5, seg + 0.12), conc, 2, "ext", rot, "concrete")
			mb.box("concrete", p + off * 0.6 + Vector3(0, DECK_Y - 1.2, 0), Vector3(minf(w, 5.4) - 0.6, 1.4, seg + 0.12), dark_c, 0, "ext", rot)
			# hai đường ray (bên bị gãy thì mất ray)
			for tr: float in [-1.0, 1.0]:
				if half and tr > 0.0:
					continue
				var tc := p + nrm * TRACK * tr
				mb.box("concrete", tc + Vector3(0, DECK_Y + 0.08, 0), Vector3(2.4, 0.16, seg + 0.12), Color(0.78, 0.77, 0.74), 0, "ext", rot)
				for rr: float in [-0.72, 0.72]:
					mb.box("metal", tc + nrm * rr + Vector3(0, DECK_Y + 0.26, 0), Vector3(0.08, 0.16, seg + 0.12), rail_c, 0, "ext", rot)
				if k % 2 == 0:
					for q in 4:
						mb.box("wood", tc + t * (q - 1.5) * 1.0 + Vector3(0, DECK_Y + 0.17, 0), Vector3(2.0, 0.06, 0.22), Color(0.55, 0.5, 0.44), 0, "ext", rot)
			# lan can hai bên (ga thì sân ga có rào riêng)
			if station.is_empty():
				for sd: float in [-1.0, 1.0]:
					if half and sd > 0.0:
						continue
					var ep := p + nrm * (HALF - 0.12) * sd + Vector3(0, DECK_Y + 0.55, 0)
					mb.box("paint", ep, Vector3(0.12, 1.1, seg + 0.05), panel, 2, "ext", rot, "metal")
					mb.box("metal", ep + Vector3(0, 0.6, 0), Vector3(0.18, 0.08, seg + 0.05), Color(0.7, 0.72, 0.75), 0, "ext", rot)
		# trụ cầu mỗi 28m, đứng giữa lòng đường
		if k % 7 == 3 and not gap:
			mb.box("concrete", p + Vector3(0, (DECK_Y - 1.9) * 0.5, 0), Vector3(1.9, DECK_Y - 1.9, 1.9), conc, 2, "ext", rot)
			mb.box("concrete", p + Vector3(0, DECK_Y - 1.75, 0), Vector3(5.6, 1.1, 2.4), dark_c, 0, "ext", rot)
		s += seg
		k += 1
	# đầu tuyến: tường chắn cuối đường ray
	for e: float in [0.6, length - 0.6]:
		var fe := frame(e)
		mb.box("concrete", (fe.p as Vector3) + Vector3(0, DECK_Y + 0.6, 0), Vector3(HALF * 2.0, 1.2, 0.4), conc, 2, "ext", Basis(Vector3.UP, atan2((fe.t as Vector3).x, (fe.t as Vector3).z)))
	_build_gaps(city, mb)
	_build_stations(city, mb)
	_build_trains(mb)
	mb.commit(200.0)


## Đoạn gãy: đầu dầm gãy lởm chởm, bê tông vụn rơi thành đống bên dưới (nhảy xuống đống này chỉ rơi khoảng 5m).
func _build_gaps(city: City, mb: MeshBuilder) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7171
	var conc := Color(0.82, 0.8, 0.76)
	for g in gaps:
		for e: float in [g.x, g.y]:
			var f := frame(e)
			for i in 5:
				var q: Vector3 = (f.p as Vector3) + (f.n as Vector3) * rng.randf_range(-HALF, HALF) + Vector3(0, DECK_Y - rng.randf_range(0.2, 1.4), 0)
				mb.box("concrete", q, Vector3(rng.randf_range(0.6, 1.6), rng.randf_range(0.3, 0.8), rng.randf_range(0.5, 1.4)), conc, 0, "ext", Basis.from_euler(Vector3(rng.randf_range(-0.6, 0.6), rng.randf() * TAU, rng.randf_range(-0.6, 0.6))))
			# thép thò ra
			for j in 6:
				var r0: Vector3 = (f.p as Vector3) + (f.n as Vector3) * rng.randf_range(-HALF + 0.4, HALF - 0.4) + Vector3(0, DECK_Y - 0.3, 0)
				mb.box("rust", r0, Vector3(0.05, 0.05, rng.randf_range(0.8, 2.0)), Color(0.45, 0.32, 0.25), 0, "ext", Basis(Vector3.UP, atan2((f.t as Vector3).x, (f.t as Vector3).z)) * Basis.from_euler(Vector3(rng.randf_range(-0.6, 0.3), 0, rng.randf_range(-0.3, 0.3))))
		# đống đổ nát: các bậc to dần lên giữa, đỉnh cao khoảng 6m
		var fm := frame((g.x + g.y) * 0.5)
		var c: Vector3 = fm.p
		var yaw := atan2((fm.t as Vector3).x, (fm.t as Vector3).z)
		for lvl in 5:
			var k := 1.0 - lvl * 0.18
			mb.box("concrete", c + Vector3(0, 0.6 + lvl * 1.2, 0), Vector3(12.0 * k, 1.2, 20.0 * k), conc.darkened(lvl * 0.04), 1, "ext", Basis(Vector3.UP, yaw + rng.randf_range(-0.15, 0.15)), "concrete")
		for m in 26:
			var r := rng.randf()
			var q2 := c + Vector3(rng.randf_range(-6.0, 6.0) * (1.0 - r * 0.6), 0.6 + r * 5.6, rng.randf_range(-9.0, 9.0) * (1.0 - r * 0.6))
			mb.box("concrete" if rng.randf() < 0.7 else "rust", q2, Vector3(rng.randf_range(0.8, 3.2), rng.randf_range(0.4, 1.2), rng.randf_range(0.8, 3.0)), conc, 0, "ext", Basis.from_euler(Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4))))
		city.barricades.append(Rect2(c.x - 9.0, c.z - 9.0, 18.0, 18.0))
	# gãy một bên: nửa cầu bên phải đổ xuống, nghiêng tựa vào đống vụn
	for h in half_gaps:
		var fh := frame((h.x + h.y) * 0.5)
		var ch: Vector3 = (fh.p as Vector3) + (fh.n as Vector3) * HALF * 0.5
		var yaw2 := atan2((fh.t as Vector3).x, (fh.t as Vector3).z)
		mb.box("concrete", ch + Vector3(0, DECK_Y * 0.45, 0), Vector3(HALF, 0.5, h.y - h.x), conc, 1, "ext", Basis(Vector3.UP, yaw2) * Basis(Vector3.BACK, -0.9), "concrete")
		for m2 in 12:
			mb.box("concrete", ch + (fh.n as Vector3) * rng.randf_range(0.0, 3.0) + Vector3(0, rng.randf_range(0.3, 1.5), 0) + (fh.t as Vector3) * rng.randf_range(-7.0, 7.0), Vector3(rng.randf_range(0.6, 2.0), rng.randf_range(0.4, 1.0), rng.randf_range(0.6, 2.0)), conc, 0, "ext", Basis.from_euler(Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, 0)))


## Ga: sân ga hai bên, rào chắn sân ga (cao 0,85m, nhảy qua được), mái vòm trắng, cầu thang bộ xuống vỉa hè.
func _build_stations(city: City, mb: MeshBuilder) -> void:
	var white := Color(0.94, 0.93, 0.9)
	var yellow := Color(0.92, 0.78, 0.3)
	var green := Color(0.35, 0.62, 0.36)
	for st: Dictionary in stations:
		var s0: float = float(st.s) - STATION_LEN * 0.5
		var f := frame(st.s)
		var c: Vector3 = f.p
		var t: Vector3 = f.t
		var nrm: Vector3 = f.n
		var yaw := atan2(t.x, t.z)
		var rot := Basis(Vector3.UP, yaw)
		var side: float = st.side
		# sân ga: nhô cao hơn đường ray 0,6m; mép sân có rào chắn
		for sd: float in [-1.0, 1.0]:
			var pc := c + nrm * sd * (HALF + (STATION_HALF - HALF) * 0.5)
			mb.box("tile", pc + Vector3(0, DECK_Y + 0.3, 0), Vector3(STATION_HALF - HALF, 0.6, STATION_LEN), Color(0.9, 0.88, 0.84), 2, "ext", rot, "tile")
			mb.box("paint", pc - nrm * sd * ((STATION_HALF - HALF) * 0.5 - 0.15) + Vector3(0, DECK_Y + 0.61, 0), Vector3(0.3, 0.02, STATION_LEN), yellow, 0, "ext", rot)
			# rào chắn mép sân ga (chắn người rơi xuống đường ray) — nhảy qua được
			var fence := c + nrm * sd * (HALF + 0.08) + Vector3(0, DECK_Y + 0.6 + 0.42, 0)
			mb.box("paint", fence, Vector3(0.1, 0.85, STATION_LEN), Color(0.82, 0.86, 0.88), 2, "ext", rot, "metal")
			mb.box("paint", fence + Vector3(0, 0.45, 0), Vector3(0.14, 0.06, STATION_LEN), green, 0, "ext", rot)
			for g in 7:
				mb.box("paint", fence + t * (-STATION_LEN * 0.5 + 1.0 + g * (STATION_LEN - 2.0) / 6.0) + Vector3(0, 0.1, 0), Vector3(0.16, 1.05, 0.12), green, 0, "ext", rot)
			# tường ngoài sân ga (phía có cầu thang chừa một ô cửa ở chỗ chiếu nghỉ)
			var wc := c + nrm * sd * (STATION_HALF - 0.1) + Vector3(0, DECK_Y + 1.6, 0)
			# cửa ra chiếu nghỉ: bên "side" ở đoạn [4,3; 7,7], bên kia đối xứng ở [-7,7; -4,3]
			var a0 := -STATION_LEN * 0.5
			var b1 := STATION_LEN * 0.5
			var g0 := 4.3 if sd == side else -7.7
			var g1 := 7.7 if sd == side else -4.3
			mb.box("paint", wc + t * (a0 + g0) * 0.5, Vector3(0.2, 2.0, g0 - a0), white, 2, "ext", rot, "concrete")
			mb.box("paint", wc + t * (g1 + b1) * 0.5, Vector3(0.2, 2.0, b1 - g1), white, 2, "ext", rot, "concrete")
		# mái vòm: các vòng cung trắng ghép lại, hai đầu ốp mảng vàng
		for a in 9:
			var th := lerpf(-1.25, 1.25, a / 8.0)
			var rp := c + nrm * sin(th) * (STATION_HALF + 0.4) + Vector3(0, DECK_Y + 3.2 + cos(th) * 3.4, 0)
			mb.box("paint", rp, Vector3(2.9, 0.18, STATION_LEN + 2.0), white, 0, "ext", rot * Basis(Vector3.BACK, -th))
		for e: float in [-1.0, 1.0]:
			mb.box("paint", c + t * e * (STATION_LEN * 0.5 + 0.9) + Vector3(0, DECK_Y + 4.6, 0), Vector3(STATION_HALF * 2.0, 2.6, 0.2), yellow, 0, "ext", rot)
		city._label_yaw = yaw + (PI if side < 0.0 else 0.0)
		city._add_label(c + nrm * side * (STATION_HALF + 0.2) + Vector3(0, DECK_Y + 3.0, 0), str(st.name), 1.0, 1.2, Color(0.15, 0.35, 0.2))
		var lbl: Label3D = city.get_child(city.get_child_count() - 1)
		lbl.rotation.y = yaw + PI * 0.5 * side
		lbl.visibility_range_end = 220.0
		city._label_yaw = NAN
		for k_side in 2:
			var sside: float = side if k_side == 0 else -side
			var dirx := 1.0 if k_side == 0 else -1.0          # bên kia: cầu thang chạy ngược chiều
			# cầu thang bộ: từ vỉa hè chạy dọc theo tuyến lên mép sân ga
			var base: Vector3 = st.stair_base if k_side == 0 else st.stair_base2
			var top: Vector3 = st.stair_top if k_side == 0 else st.stair_top2
			city._stair_flight(mb, base + Vector3(0, City.BASE, 0), top + Vector3(0, DECK_Y + 0.6, 0), 2.2, Color(0.82, 0.82, 0.8), "concrete")
			var srot := Basis(Vector3.UP, yaw + (0.0 if k_side == 0 else PI))
			var mid := (base + top) * 0.5
			var slope_len := base.distance_to(top)
			var ang := atan2(DECK_Y + 0.6 - City.BASE, slope_len)
			for sd2: float in [-1.15, 1.15]:
				var rail_c := mid + nrm * sd2 * sside + Vector3(0, (DECK_Y + 0.6 + City.BASE) * 0.5 + 0.55, 0)
				mb.box("paint", rail_c, Vector3(0.08, 1.0, sqrt(slope_len * slope_len + (DECK_Y + 0.6) * (DECK_Y + 0.6))), Color(0.7, 0.72, 0.75), 2, "ext", srot * Basis(Vector3.RIGHT, -ang), "metal")
			for k3 in 6:
				var pp := base.lerp(top, k3 / 5.0) + Vector3(0, lerpf(City.BASE, DECK_Y + 0.6, k3 / 5.0), 0)
				mb.box("concrete", pp - Vector3(0, (pp.y) * 0.5, 0), Vector3(0.35, maxf(0.2, pp.y - 0.3), 0.35), Color(0.75, 0.75, 0.73), 0, "ext", srot)
			# chiếu nghỉ: nối đỉnh cầu thang vào sân ga qua ô cửa ở tường ngoài
			var land_c := c + nrm * sside * 9.05 + t * 6.0 * dirx + Vector3(0, DECK_Y + 0.35, 0)
			mb.box("tile", land_c, Vector3(3.5, 0.5, 3.4), Color(0.9, 0.88, 0.84), 2, "ext", rot, "tile")
			mb.box("paint", land_c + Vector3(0, 0.27, 0), Vector3(2.0, 0.02, 2.0), yellow, 0, "ext", rot)
			mb.box("paint", c + nrm * sside * 10.8 + t * 6.0 * dirx + Vector3(0, DECK_Y + 1.1, 0), Vector3(0.08, 1.0, 3.4), Color(0.7, 0.72, 0.75), 2, "ext", rot, "metal")
			mb.box("paint", c + nrm * sside * 9.05 + t * 7.7 * dirx + Vector3(0, DECK_Y + 1.1, 0), Vector3(3.5, 1.0, 0.08), Color(0.7, 0.72, 0.75), 2, "ext", rot, "metal")
			mb.box("paint", land_c + Vector3(0, 2.6, 0), Vector3(3.8, 0.12, 3.8), white, 0, "ext", rot)
			city._add_label(base + Vector3(0, 3.0, 0), "↑ " + str(st.name), 1.0, 0.4, Color(0.2, 0.5, 0.25))


## Tàu hỏng: ba toa trắng sọc xanh nằm trên một đường ray; một đoàn trật bánh, toa nghiêng.
func _build_trains(mb: MeshBuilder) -> void:
	var body := Color(0.93, 0.93, 0.9)
	var stripe := Color(0.25, 0.6, 0.35)
	var glass := Color(0.2, 0.26, 0.32)
	for tr: Dictionary in trains:
		for car in int(tr.cars):
			var s: float = float(tr.s) + car * 19.5
			var f := frame(s)
			var yaw := atan2((f.t as Vector3).x, (f.t as Vector3).z)
			var tilt := 0.0
			var shift := 0.0
			if tr.derail:
				tilt = [0.0, 0.12, 0.2][car % 3]
				shift = [0.0, 0.5, 0.9][car % 3]
				yaw += [0.0, 0.05, 0.11][car % 3]
			var rot := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, tilt * float(tr.track))
			var c: Vector3 = (f.p as Vector3) + (f.n as Vector3) * (TRACK + shift) * float(tr.track) + Vector3(0, DECK_Y + 2.2, 0)
			mb.box("paint", c, Vector3(2.9, 3.4, 18.6), body, 2, "ext", rot, "metal")
			mb.box("paint", c + rot * Vector3(0, -0.7, 0), Vector3(2.94, 0.5, 18.62), stripe, 0, "ext", rot)
			mb.box("paint", c + rot * Vector3(0, 0.45, 0), Vector3(2.96, 0.9, 16.8), glass, 0, "ext", rot)
			mb.box("dark", c + rot * Vector3(0, -1.85, 0), Vector3(2.4, 0.4, 16.0), Color(0.2, 0.2, 0.22), 0, "ext", rot)
