class_name City
extends Node3D
## Dựng toàn bộ thành phố bằng code từ một hạt giống (mọi máy trong phòng dựng ra giống hệt nhau):
## đường, vỉa hè, nhà ống vào được (tầng, cầu thang, mái), cửa hàng, hồ sâu, xe, cây, đèn đường.

const COLS := 18
const ROWS := 7
const BW := 56.0          # chiều dài khối nhà (X)
const BD := 48.0          # chiều sâu khối nhà (Z)
const ROAD := 14.0
const PX := BW + ROAD
const PZ := BD + ROAD
const LOT := 5.0
const HOUSE_D := 14.0
const FH := 3.4           # chiều cao tầng
const T := 0.15           # dày tường
const BASE := 0.2         # cao độ sàn tầng trệt (mặt vỉa hè)
const WATER_Y := -0.12
const LAKE_DEPTH := 5.0
## Công viên hồ: 2x2 ô gộp lại (kể cả các con đường ở giữa) thành một hồ lớn có bờ cỏ, cây cối.
const LAKE_ZONE := Rect2i(2, 1, 2, 2)
## Công viên lớn: 4x2 ô. Nửa tây là rừng cây rậm (khó bị phát hiện), nửa đông là bãi cỏ trống (đi xe thoải mái, dễ lộ).
const PARK_ZONE := Rect2i(7, 4, 4, 2)
const FOREST_ZONE := Rect2i(7, 4, 2, 2)
const LAKE_BLOCK := Vector2i(2, 1)
const OFFICE_BLOCK := Vector2i(2, 0)      # ngay phía bắc hồ, mặt tiền nhìn thẳng xuống hồ
const HOME_BLOCK := Vector2i(12, 5)
const TU_BLOCK := Vector2i(8, 6)      # bên kia công viên: gặp vợ con xong phải băng qua công viên rồi quay về
const MALL_BLOCK := Vector2i(5, 1)
const SITE_BLOCK := Vector2i(6, 3)    # công trường đang xây, có cần cẩu tháp trèo lên được
## Các khu tập thể: mỗi khu gộp 2x2 ô, nuốt luôn những con đường lớn nằm giữa; bên trong chỉ có ngõ nhỏ ngoằn ngoèo.
const HOODS: Array[Rect2i] = [Rect2i(0, 4, 2, 2), Rect2i(12, 0, 2, 2), Rect2i(4, 5, 2, 2),
	Rect2i(8, 0, 2, 2), Rect2i(0, 2, 1, 2), Rect2i(11, 2, 2, 1), Rect2i(2, 4, 2, 2), Rect2i(13, 3, 1, 2),
	Rect2i(2, 6, 2, 1), Rect2i(10, 6, 2, 1), Rect2i(4, 3, 1, 2), Rect2i(11, 4, 1, 1), Rect2i(0, 0, 1, 1),
	Rect2i(15, 1, 2, 2), Rect2i(16, 3, 2, 2), Rect2i(14, 6, 2, 1), Rect2i(17, 0, 1, 1), Rect2i(14, 0, 1, 1)]
## Biển hiệu trên mặt tiền những nhà đóng cửa (chỉ để nhìn, không vào được).
const SIGNS := ["TẠP HOÁ", "CẮT TÓC GỘI ĐẦU", "SỬA XE MÁY", "PHỞ BÒ", "BÚN CHẢ", "CƠM BÌNH DÂN", "BIA HƠI", "ĐIỆN THOẠI DI ĐỘNG",
	"PHOTO COPY", "VẬT LIỆU XÂY DỰNG", "KARAOKE", "NHÀ NGHỈ", "VÀNG BẠC", "GẠO", "TRÀ ĐÁ", "MAY ĐO", "ĐIỆN NƯỚC", "IN ẤN",
	"SỬA CHỮA ĐIỆN TỬ", "BÁNH CUỐN", "NỘI THẤT", "ĐỒ GỖ", "KÍNH MẮT", "THỜI TRANG TRẺ EM", "BÁN HÀNG ONLINE"]
const CRANE_H := 40.8
## Công trình đặc thù (mỗi cái chiếm trọn một cụm ô, kể cả các con đường bên trong).
## Bố trí theo độ khó: bệnh viện sát nhà (ngay phía nam), hai biệt phủ ở xa vừa, trường học xa nhất (góc tây nam).
const HOSPITAL_ZONE := Rect2i(12, 6, 2, 1)
const SCHOOL_ZONE := Rect2i(0, 6, 2, 1)
const BIGSUPER_ZONE := Rect2i(10, 0, 2, 2)
const MANSION_ZONES: Array[Rect2i] = [Rect2i(5, 4, 2, 1), Rect2i(4, 0, 2, 1)]
const RADIO_ZONE := Rect2i(2, 3, 2, 1)
const RADIO_BLOCK := Vector2i(2, 3)


## Mọi cụm ô công trình đặc thù (mỗi cụm nuốt luôn các con đường bên trong).
static func landmark_zones() -> Array[Rect2i]:
	var out: Array[Rect2i] = [HOSPITAL_ZONE, SCHOOL_ZONE, BIGSUPER_ZONE, RADIO_ZONE]
	out.append_array(MANSION_ZONES)
	return out
const TOWER_H := 72.0
const BIG_KINDS := ["office", "tower", "mall", "super", "restaurant", "hospital", "school"]
const PARK_FLOOR := -4.0


## Khu thương mại: các khối quanh hồ và trung tâm thương mại (nhà to, cao ốc, siêu thị, nhà hàng lớn).
static func is_commercial(cell: Vector2i) -> bool:
	return cell.x >= 4 and cell.x <= 7 and cell.y <= 2 and cell != MALL_BLOCK and cell_kind(cell) == ""


## Loại ô đặc biệt: lake | forest | field | site | slum, hoặc "" nếu là khối nhà thường.
static func cell_kind(cell: Vector2i) -> String:
	if LAKE_ZONE.has_point(cell):
		return "lake"
	if FOREST_ZONE.has_point(cell):
		return "forest"
	if PARK_ZONE.has_point(cell):
		return "field"
	if cell == SITE_BLOCK:
		return "site"
	for lz: Rect2i in landmark_zones():
		if lz.has_point(cell):
			return "landmark"
	for hz: Rect2i in HOODS:
		if hz.has_point(cell):
			return "slum"
	return ""


## Vùng thế giới mà một cụm ô chiếm (gồm cả các con đường nằm giữa các ô đó).
static func zone_rect(z: Rect2i) -> Rect2:
	var a := block_center(z.position.x, z.position.y)
	var b := block_center(z.position.x + z.size.x - 1, z.position.y + z.size.y - 1)
	return Rect2(a.x - BW * 0.5, a.z - BD * 0.5, b.x - a.x + BW, b.z - a.z + BD)


static func in_lake_zone(p: Vector3, margin := 0.0) -> bool:
	return zone_rect(LAKE_ZONE).grow(margin).has_point(Vector2(p.x, p.z))


static func in_park(p: Vector3, margin := 0.0) -> bool:
	return zone_rect(PARK_ZONE).grow(margin).has_point(Vector2(p.x, p.z))


## Trong rừng cây rậm của công viên: quái vật khó nhìn thấy người.
static func in_forest(p: Vector3) -> bool:
	return zone_rect(FOREST_ZONE).has_point(Vector2(p.x, p.z))


static func in_landmark_zone(p: Vector3, margin := 0.0) -> bool:
	for lz: Rect2i in landmark_zones():
		if zone_rect(lz).grow(margin).has_point(Vector2(p.x, p.z)):
			return true
	return false


static func in_hood(p: Vector3, margin := 0.0) -> bool:
	for hz: Rect2i in HOODS:
		if zone_rect(hz).grow(margin).has_point(Vector2(p.x, p.z)):
			return true
	return false


## Các vùng không còn đường xe chạy bên trong: công viên hồ và các khu tập thể.
static func closed_zones() -> Array[Rect2i]:
	var out: Array[Rect2i] = [LAKE_ZONE]
	out.append_array(landmark_zones())
	out.append_array(HOODS)
	return out


static func in_closed(p: Vector3, margin := 0.0) -> bool:
	return in_lake_zone(p, margin) or in_hood(p, margin) or in_landmark_zone(p, margin)


static func in_zone(p: Vector3, margin := 0.0) -> bool:
	return in_lake_zone(p, margin) or in_park(p, margin) or in_hood(p, margin) or in_landmark_zone(p, margin)

const HOUSE_COLORS := ["e8d9a8", "d9c58f", "c9d4d8", "e3bfa8", "b9c7a6", "dedccf", "e8c76a", "a9bccd", "d8a890", "c2b8d0", "f0e6d0", "9fb8a8"]
const SHOPS := {
	"grocery": {"name": "TẠP HÓA", "color": "d9452f", "tables": ["g_noodle", "g_drink", "g_can", "g_snack", "g_misc"], "weight": 5.0},
	"pharmacy": {"name": "NHÀ THUỐC", "color": "2f9a57", "tables": ["p_band", "p_pain", "p_anti", "p_tool"], "weight": 3.0},
	"clothes": {"name": "THỜI TRANG", "color": "8a4fb0", "tables": ["c_coat", "c_work", "c_acc", "c_helmet"], "weight": 2.0},
	"shoes": {"name": "GIÀY DÉP", "color": "2f7fd0", "tables": ["s_sport", "s_work"], "weight": 1.2},
	"bags": {"name": "BALO TÚI XÁCH", "color": "d08a2f", "tables": ["b_small", "b_big"], "weight": 1.2},
	"hardware": {"name": "KIM KHÍ", "color": "6a7078", "tables": ["h_tool", "h_pipe", "h_misc"], "weight": 1.6},
	"bike": {"name": "SỬA XE", "color": "c8302a", "tables": ["k_parts", "k_helmet", "k_fuel"], "weight": 1.4},
	"food": {"name": "CƠM PHỞ", "color": "e8b21c", "tables": ["foodshop", "f_cab"], "weight": 2.2},
	"cafe": {"name": "CÀ PHÊ", "color": "7a5230", "tables": ["cafe", "f_cab"], "weight": 1.6},
}
const CONTAINER_NAMES := {
	"fridge": "Tủ lạnh", "kitchen": "Tủ bếp", "wardrobe": "Tủ quần áo", "medbox": "Tủ thuốc", "drawer": "Ngăn kéo",
	"office": "Bàn làm việc", "register": "Quầy thu ngân", "civ_body": "Thi thể", "sol_body": "Thi thể người lính",
	"ammo": "Hòm đạn", "army_med": "Túi quân y", "ration": "Thùng lương khô", "street": "Thùng hàng", "tu_box": "Hòm đồ nghề của ông Tư",
	"hospital": "Tủ thuốc", "mansion": "Tủ đồ", "radio_room": "Tủ thiết bị",
}

var rng := RandomNumberGenerator.new()
var buildings: Array[Dictionary] = []
var containers: Array[Dictionary] = []
var lamps: Array[Vector3] = []
var cars: Array[Dictionary] = []
var npc_spots: Array[Dictionary] = []      # chủ cửa hàng, ông Tư
var start_pos := Vector3.ZERO
var home_pos := Vector3.ZERO
var hatch_pos := Vector3.ZERO
var home_back := Vector3.ZERO
var rebuild_ms: Array = []       # đo thời gian dựng lại từng khối nhà (gỡ lỗi hiệu năng)     # sân sau nhà (ống thông khí của hầm)
var tu_pos := Vector3.ZERO
var lake_rect := Rect2()
var lake_land: Array[Rect2] = []       # các mảng đất đắp lấn vào lòng hồ (bờ lượn, đảo)
var island := Rect2()
var bounds := Rect2()
var lamp_lights: Array[OmniLight3D] = []
var _tree_xf: Array[Transform3D] = []
var bikes: Array[Dictionary] = []
## Hầm đi bộ dưới đường: {z, x0, x1, entrances: [x...], block_x}
var tunnel: Dictionary = {}
var chasm := Rect2()
var chasms: Array[Dictionary] = []          # {rect, kind}: kind = plank | tree | slab | ruin
var beds: Array[Vector3] = []
var corpses: Array[Dictionary] = []          # {pos, yaw, color}
var barricades: Array[Rect2] = []
var extras: Array[Rect2] = []              # các khối cơi nới, lấn chiếm trong hẻm (để vẽ lên bản đồ)
var block_specs: Dictionary = {}            # ô -> danh sách thông số nhà (để dựng lại khi nhà bị phá)
var _label_yaw := NAN          # hướng biển hiệu của ngôi nhà xoay đang dựng
var rail := Rail.new()
var landmarks: Array[Dictionary] = []      # {name, pos} để ghi trên bản đồ
var school_med_cid := -1                     # tủ khoá ở trường có lọ thuốc của bé Na
var hospital_safe_cid := -1                  # két sắt bệnh viện
var hospital_safe_code := ""
var radio_pos := Vector3.ZERO                # chỗ đặt máy phát tín hiệu (trạm phát sóng)
var tower_pos := Vector3.ZERO
var crane_pos := Vector3.ZERO
var slum_lanes: Dictionary = {}             # ô -> các con ngõ của xóm (toạ độ so với tâm ô)
var slum_obbs: Dictionary = {}
var block_nodes: Dictionary = {}
var panes: Dictionary = {}                  # ô -> danh sách ô kính còn nguyên {b, i, box}
var tree_mm: Array[MultiMesh] = []
var _rebuilding := false
var _seed := 0
const TUNNEL_FLOOR := -4.4
const TUNNEL_HALF := 2.0


static func block_center(c: int, r: int) -> Vector3:
	return Vector3((c - (COLS - 1) * 0.5) * PX, 0.0, (r - (ROWS - 1) * 0.5) * PZ)


## Toạ độ X của trục đường dọc thứ i (0..COLS) và Z của trục đường ngang thứ j (0..ROWS).
static func road_x(i: int) -> float:
	return (i - COLS * 0.5) * PX


static func road_z(j: int) -> float:
	return (j - ROWS * 0.5) * PZ


func build(world_seed: int) -> void:
	rng.seed = world_seed
	var hw := COLS * PX * 0.5 + ROAD * 0.5 + 10.0
	var hd := ROWS * PZ * 0.5 + ROAD * 0.5 + 10.0
	bounds = Rect2(-hw, -hd, hw * 2.0, hd * 2.0)
	rail.plan()
	_build_ground(hw, hd)
	_seed = world_seed
	for r in ROWS:
		for c in COLS:
			_build_cell(Vector2i(c, r))
	_build_streets()
	rail.build(self)
	_build_trees()


func _build_cell(cell: Vector2i) -> void:
	var node := Node3D.new()
	node.name = "Block_%d_%d" % [cell.x, cell.y]
	add_child(node)
	block_nodes[cell] = node
	rng.seed = _seed + cell.x * 7919 + cell.y * 104729
	panes.erase(cell)
	_label_yaw = NAN
	var mb := MeshBuilder.new(node)
	match cell_kind(cell):
		"lake":
			if cell == LAKE_BLOCK:
				_build_lake(mb)
		"forest", "field":
			_build_park(mb, cell)
		"site":
			_build_site(mb, cell)
		"landmark":
			_build_landmark(mb, cell)
		"slum":
			for hz: Rect2i in HOODS:
				if hz.position == cell:
					_build_slum(mb, cell, zone_rect(hz))
		_:
			_build_block(mb, cell)
	mb.commit(150.0 if cell_kind(cell) == "slum" else 80.0)


## Phá một ngôi nhà rồi dựng lại cả khối nhà chứa nó. mode: top (mất các tầng trên) | front (sập mặt tiền) | collapse (sập hẳn).
func damage_building(id: int, mode: String, cut: int) -> void:
	if id < 0 or id >= buildings.size():
		return
	var b: Dictionary = buildings[id]
	b["damage"] = mode
	b["cut"] = cut
	if mode == "collapse":
		b["ruined"] = true
	var cell: Vector2i = b.cell
	var old: Node = block_nodes.get(cell)
	if old:
		old.queue_free()
	_rebuilding = true
	var t0 := Time.get_ticks_usec()
	_build_cell(cell)
	if OS.has_feature("editor") or OS.is_debug_build():
		rebuild_ms.append([cell, (Time.get_ticks_usec() - t0) / 1000.0, str(b.kind)])
	_rebuilding = false


## Cây trong bán kính quanh `pos` bị quật đổ.
func fell_trees(pos: Vector3, radius: float) -> int:
	var n := 0
	for i in _tree_xf.size():
		var xf := _tree_xf[i]
		if xf.basis.get_scale().x < 0.01:
			continue
		if Vector2(xf.origin.x - pos.x, xf.origin.z - pos.z).length() < radius:
			n += 1
			var away := (xf.origin - pos)
			away.y = 0.0
			var yaw := atan2(away.x, away.z)
			# thân cây nằm rạp xuống đất, ngọn hướng ra xa
			var lying := Basis(Vector3.UP, yaw) * Basis(Vector3(1, 0, 0), PI * 0.5 - 0.06)
			var scale_v := xf.basis.get_scale().x
			_tree_xf[i] = Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), xf.origin)
			var heights := [1.6, 4.3]
			for k in tree_mm.size():
				tree_mm[k].set_instance_transform(i, Transform3D(lying.scaled(Vector3.ONE * scale_v), xf.origin + Vector3(0, 0.35 if k == 0 else 0.9, 0) + lying * Vector3(0, float(heights[k]) * scale_v, 0)))
	return n


# ------------------------------------------------------------------ mặt đất, đường
func _build_ground(hw: float, hd: float) -> void:
	var node := Node3D.new()
	node.name = "Ground"
	add_child(node)
	var mb := MeshBuilder.new(node)
	# Tấm nhựa đường khoét lỗ ở công viên hồ (hồ là một cái hố thật).
	_plan_underground()
	var holes: Array[Rect2] = [zone_rect(LAKE_ZONE), _parking_hole()]
	for ch in chasms:
		holes.append(ch.rect)
	for ex: float in tunnel.entrances:
		holes.append(Rect2(ex, float(tunnel.z) - 0.95, 7.2, 1.9))
	_slab_holes(mb, "asphalt", Rect2(-hw, -hd, hw * 2.0, hd * 2.0), holes)
	_build_tunnel(mb)
	for ch2 in chasms:
		_build_chasm(mb, ch2.rect, ch2.kind)
	# Tường vô hình quanh bản đồ.
	for side in 4:
		var horizontal := side < 2
		var sg := -1.0 if side % 2 == 0 else 1.0
		var size := Vector3(hw * 2.0, 60.0, 1.0) if horizontal else Vector3(1.0, 60.0, hd * 2.0)
		var pos := Vector3(0, 28, sg * hd) if horizontal else Vector3(sg * hw, 28, 0)
		mb.collider(pos, size, "concrete", 2)
	# Công viên lớn: thảm cỏ phủ kín cả cụm ô, các con đường bên trong chỉ còn là lối mòn đất.
	var pr := zone_rect(PARK_ZONE)
	var fr := zone_rect(FOREST_ZONE)
	mb.box("grass", Vector3(fr.get_center().x, 0.02, fr.get_center().y), Vector3(fr.size.x, 0.04, fr.size.y), Color(0.62, 0.78, 0.6), 1, "ext", Basis.IDENTITY, "grass")
	var field_r := Rect2(fr.end.x, pr.position.y, pr.end.x - fr.end.x, pr.size.y)
	mb.box("grass", Vector3(field_r.get_center().x, 0.02, field_r.get_center().y), Vector3(field_r.size.x, 0.04, field_r.size.y), Color(0.9, 1.0, 0.8), 1, "ext", Basis.IDENTITY, "grass")
	for i in range(PARK_ZONE.position.x + 1, PARK_ZONE.end.x):
		mb.box("dirt", Vector3(road_x(i), 0.045, pr.get_center().y), Vector3(3.2, 0.012, pr.size.y), Color(0.9, 0.85, 0.72), 0)
	for j in range(PARK_ZONE.position.y + 1, PARK_ZONE.end.y):
		mb.box("dirt", Vector3(pr.get_center().x, 0.046, road_z(j)), Vector3(pr.size.x, 0.012, 3.2), Color(0.9, 0.85, 0.72), 0)
	# Vết nứt trên mặt đường sau trận rung chấn (chỉ là vết, đi qua được; các khe nứt sâu thì phải tìm cách băng qua).
	var crng := RandomNumberGenerator.new()
	crng.seed = _seed * 31 + 7
	for k in 260:
		var cp0 := road_point(crng)
		if in_zone(cp0, 2.0) or _near_underground(cp0, 3.0):
			continue
		var heading := crng.randf() * TAU
		var segs := 3 + crng.randi() % 6
		var width := crng.randf_range(0.07, 0.22)
		for sgi in segs:
			var ln := crng.randf_range(0.9, 2.6)
			heading += crng.randf_range(-0.8, 0.8)
			var dir := Vector3(cos(heading), 0, sin(heading))
			var mid2 := cp0 + dir * ln * 0.5
			mb.box("dark", Vector3(mid2.x, 0.011, mid2.z), Vector3(ln + 0.1, 0.02, width * crng.randf_range(0.6, 1.2)), Color(0.12, 0.12, 0.13), 0, "ext", Basis(Vector3.UP, -heading))
			if crng.randf() < 0.3:       # nhánh phụ
				var bh := heading + (1.0 if crng.randf() < 0.5 else -1.0) * crng.randf_range(0.6, 1.2)
				var bl := crng.randf_range(0.6, 1.5)
				var bm := cp0 + dir * ln * 0.6 + Vector3(cos(bh), 0, sin(bh)) * bl * 0.5
				mb.box("dark", Vector3(bm.x, 0.0112, bm.z), Vector3(bl, 0.02, width * 0.5), Color(0.12, 0.12, 0.13), 0, "ext", Basis(Vector3.UP, -bh))
			cp0 += dir * ln
	# Vạch kẻ đường
	var white := Color(0.85, 0.85, 0.8)
	for j in ROWS + 1:
		var z := road_z(j)
		var x := -hw + 4.0
		while x < hw - 4.0:
			if not _near_intersection_x(x) and not in_zone(Vector3(x, 0, z)):
				mb.box("flat", Vector3(x, 0.012, z), Vector3(3.0, 0.02, 0.16), white, 0)
			x += 7.0
	for i in COLS + 1:
		var x2 := road_x(i)
		var z2 := -hd + 4.0
		while z2 < hd - 4.0:
			if not _near_intersection_z(z2) and not in_zone(Vector3(x2, 0, z2)):
				mb.box("flat", Vector3(x2, 0.012, z2), Vector3(0.16, 0.02, 3.0), white, 0)
			z2 += 7.0
	# Vạch sang đường ở các ngã tư
	for i in COLS + 1:
		for j in ROWS + 1:
			var p := Vector3(road_x(i), 0.013, road_z(j))
			if in_zone(p):
				continue
			for k in 7:
				var o := -4.8 + k * 1.6
				mb.box("flat", p + Vector3(o, 0, ROAD * 0.5 + 1.6), Vector3(0.7, 0.02, 2.4), white, 0)
				mb.box("flat", p + Vector3(o, 0, -ROAD * 0.5 - 1.6), Vector3(0.7, 0.02, 2.4), white, 0)
				mb.box("flat", p + Vector3(ROAD * 0.5 + 1.6, 0, o), Vector3(2.4, 0.02, 0.7), white, 0)
				mb.box("flat", p + Vector3(-ROAD * 0.5 - 1.6, 0, o), Vector3(2.4, 0.02, 0.7), white, 0)
	mb.commit()


## Tấm sàn có các lỗ chữ nhật (hồ, cửa hầm, khe nứt): cắt thành các mảnh quanh lỗ.
func _slab_holes(mb: MeshBuilder, mat: String, r: Rect2, holes: Array[Rect2], y0 := -1.0, y1 := 0.0) -> void:
	for i in holes.size():
		var h := holes[i].intersection(r)
		if h.size.x <= 0.01 or h.size.y <= 0.01:
			continue
		var rest := holes.slice(i + 1)
		_slab_holes(mb, mat, Rect2(r.position.x, r.position.y, h.position.x - r.position.x, r.size.y), rest, y0, y1)
		_slab_holes(mb, mat, Rect2(h.end.x, r.position.y, r.end.x - h.end.x, r.size.y), rest, y0, y1)
		_slab_holes(mb, mat, Rect2(h.position.x, r.position.y, h.size.x, h.position.y - r.position.y), rest, y0, y1)
		_slab_holes(mb, mat, Rect2(h.position.x, h.end.y, h.size.x, r.end.y - h.end.y), rest, y0, y1)
		return
	if r.size.x > 0.01 and r.size.y > 0.01:
		_slab(mb, mat, r.position.x, r.end.x, r.position.y, r.end.y, y0, y1)


## Lỗ dốc xuống tầng hầm để xe (nằm trong trung tâm thương mại).
func _parking_hole() -> Rect2:
	var c := block_center(MALL_BLOCK.x, MALL_BLOCK.y)
	var oz := c.z + BD * 0.5 - 2.0
	return Rect2(c.x - 22.0, oz - 14.0, 4.0, 10.0)


func _plan_underground() -> void:
	var tz := road_z(4)
	var ents: Array[float] = []
	for i in range(1, 7):
		ents.append(road_x(i) + 14.0)
	tunnel = {"z": tz, "x0": road_x(1) + 11.0, "x1": road_x(7) - 4.0, "entrances": ents, "block_x": road_x(4) - 22.0}
	# Các khe nứt sâu cắt ngang những con đường dọc, rải khắp thành phố; mỗi khe một cách băng qua.
	var kinds := ["plank", "tree", "slab", "ruin"]
	var n := 0
	for ci in range(1, COLS):
		for rj in ROWS:
			if (ci * 5 + rj * 3 + ci * rj) % 5 != 0:
				continue
			if cell_kind(Vector2i(ci - 1, rj)) in ["lake", "forest", "field", "slum"] or cell_kind(Vector2i(ci, rj)) in ["lake", "forest", "field", "slum"]:
				continue
			if rj == OFFICE_BLOCK.y and absi(ci - OFFICE_BLOCK.x) <= 1:
				continue
			var kind: String = kinds[n % 4]
			n += 1
			var cx := road_x(ci)
			var cz := (road_z(rj) + road_z(rj + 1)) * 0.5 + (9.0 if kind == "tree" else 0.0)
			chasms.append({"rect": Rect2(cx - ROAD * 0.5, cz - 1.7, ROAD, 3.4), "kind": kind})
	chasm = chasms[0].rect


## Hầm đi bộ chạy dưới con đường phía nam: 4 cửa xuống, một đoạn sập phải lên mặt đất đi vòng.
func _build_tunnel(mb: MeshBuilder) -> void:
	var tz: float = tunnel.z
	var x0: float = tunnel.x0
	var x1: float = tunnel.x1
	var fl := TUNNEL_FLOOR
	var grey := Color(0.72, 0.72, 0.7)
	var cxm := (x0 + x1) * 0.5
	var length := x1 - x0
	mb.box("tile", Vector3(cxm, fl - 0.2, tz), Vector3(length, 0.4, TUNNEL_HALF * 2.0 + 0.6), Color(0.8, 0.8, 0.78), 1, "ext", Basis.IDENTITY, "tile")
	for sg: float in [-1.0, 1.0]:
		mb.box("concrete", Vector3(cxm, (fl - 1.0) * 0.5, tz + sg * (TUNNEL_HALF + 0.15)), Vector3(length, -1.0 - fl, 0.3), grey)
		# dải đèn khẩn cấp
		var lx := x0 + 6.0
		while lx < x1:
			mb.box("emit", Vector3(lx, -1.35, tz + sg * (TUNNEL_HALF - 0.02)), Vector3(1.2, 0.08, 0.04), Color(0.55, 0.75, 0.6), 0)
			lx += 16.0
	for ex: float in [x0, x1]:
		mb.box("concrete", Vector3(ex, (fl - 1.0) * 0.5, tz), Vector3(0.3, -1.0 - fl, TUNNEL_HALF * 2.0 + 0.6), grey)
	# cầu thang xuống ở mỗi cửa hầm (đi xuống về phía đông)
	var run := 6.6
	var rise := -fl
	for ex2: float in tunnel.entrances:
		var steps := 22
		for i in steps:
			var sx := ex2 + 0.3 + run * i / steps
			mb.box("concrete", Vector3(sx + run / steps * 0.5, -rise * (i + 1) / steps + rise / steps * 0.5 - 0.0, tz), Vector3(run / steps, rise / steps, 1.8), Color(0.8, 0.8, 0.78), 0)
		var ang := atan2(rise, run)
		var rot := Basis(Vector3(0, 0, 1), -ang)
		var mid := Vector3(ex2 + 0.3 + run * 0.5, -rise * 0.5, tz)
		mb.collider(mid - (rot * Vector3.UP) * 0.1, Vector3(sqrt(run * run + rise * rise), 0.2, 1.8), "concrete", 1, rot)
		# lan can thấp quanh miệng hầm + biển chỉ
		for sg2: float in [-1.0, 1.0]:
			mb.box("concrete", Vector3(ex2 + 3.6, 0.45, tz + sg2 * 1.05), Vector3(7.4, 0.9, 0.2), grey)
		mb.box("concrete", Vector3(ex2 + 7.3, 0.45, tz), Vector3(0.2, 0.9, 2.3), grey)
		mb.box("emit", Vector3(ex2 + 7.3, 1.25, tz), Vector3(0.12, 0.5, 1.6), Color(0.3, 0.6, 0.9), 0)
		_add_label(Vector3(ex2 + 7.38, 1.25, tz), "HẦM ĐI BỘ", 1.0, 0.22, Color.WHITE)
		(get_child(get_child_count() - 1) as Label3D).rotation.y = PI * 0.5
	# đoạn hầm sập
	var bx: float = tunnel.block_x
	for m in 16:
		var sz := Vector3(rng.randf_range(0.8, 2.2), rng.randf_range(0.6, 1.8), rng.randf_range(0.8, 2.0))
		var q := Vector3(bx + rng.randf_range(-2.0, 2.0), fl + rng.randf_range(0.2, 2.6), tz + rng.randf_range(-1.6, 1.6))
		mb.box("concrete", q, sz, Color(0.7, 0.68, 0.64), 1, "ext", Basis.from_euler(Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4))))
	mb.collider(Vector3(bx, fl + 1.7, tz), Vector3(2.4, 3.4, TUNNEL_HALF * 2.0), "concrete", 1)
	# vài thứ để lục trong hầm
	for k in 5:
		var px := lerpf(x0 + 10.0, x1 - 10.0, (k + 0.5) / 5.0)
		if absf(px - bx) < 6.0:
			continue
		mb.box("wood", Vector3(px, fl + 0.3, tz + 1.5), Vector3(0.9, 0.6, 0.6), Color(0.8, 0.72, 0.6))
		_add_container("street" if k % 2 == 0 else "ration", Vector3(px, fl + 0.8, tz + 1.5), -1, 2 + rng.randi() % 2)


## Khe nứt cắt ngang một con đường, sâu 5m. Mỗi khe có một cách băng qua khác nhau, và một dốc đất để leo lên nếu lỡ rơi xuống.
func _build_chasm(mb: MeshBuilder, r: Rect2, kind: String) -> void:
	var depth := 5.0
	var c := r.get_center()
	var dark := Color(0.4, 0.38, 0.36)
	mb.box("rock", Vector3(c.x, -depth - 0.3, c.y), Vector3(r.size.x, 0.6, r.size.y), dark)
	for sg: float in [-1.0, 1.0]:
		mb.box("rock", Vector3(c.x, -depth * 0.5 - 0.5, c.y + sg * (r.size.y * 0.5 + 0.2)), Vector3(r.size.x + 0.8, depth - 1.0, 0.4), dark)
		mb.box("rock", Vector3(c.x + sg * (r.size.x * 0.5 + 0.2), -depth * 0.5 - 0.5, c.y), Vector3(0.4, depth - 1.0, r.size.y), dark)
	var span := r.size.y + 1.6
	match kind:
		"plank":
			# hai tấm ván bắc qua
			mb.box("wood", Vector3(c.x - 3.0, 0.04, c.y), Vector3(0.9, 0.08, span), Color(0.8, 0.7, 0.55), 1, "ext", Basis.IDENTITY, "wood")
			mb.box("wood", Vector3(c.x + 1.2, 0.04, c.y), Vector3(0.5, 0.08, span), Color(0.7, 0.6, 0.45), 1, "ext", Basis(Vector3.UP, 0.12), "wood")
		"tree":
			# một cây lớn đổ ngang khe: đi trên thân cây
			var trunk := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.4
			cyl.bottom_radius = 0.55
			cyl.height = span + 5.0
			cyl.radial_segments = 10
			var tm := StandardMaterial3D.new()
			tm.albedo_texture = Mats.tex("res://assets/tex/wood_color.jpg")
			tm.albedo_color = Color(0.45, 0.36, 0.3)
			tm.uv1_scale = Vector3(1, 3, 1)
			cyl.material = tm
			trunk.mesh = cyl
			trunk.rotation = Vector3(PI * 0.5, 0.0, 0.0)
			trunk.position = Vector3(c.x - 1.5, 0.3, c.y + 1.0)
			mb.root.add_child(trunk)
			mb.collider(Vector3(c.x - 1.5, 0.22, c.y + 1.0), Vector3(0.95, 0.44, span + 4.6), "wood", 1)
			for k in 3:
				var crown := MeshInstance3D.new()
				var sp := SphereMesh.new()
				sp.radius = 1.6
				sp.height = 2.6
				sp.radial_segments = 8
				sp.rings = 5
				var fm := ShaderMaterial.new()
				fm.shader = load("res://shaders/foliage.gdshader")
				sp.material = fm
				crown.mesh = sp
				crown.position = Vector3(c.x - 1.5 + (k - 1) * 1.6, 1.0, c.y + span * 0.5 + 3.6 + k * 0.7)
				mb.root.add_child(crown)
		"slab":
			# một mảng tường bê tông rơi xuống, nằm vắt qua khe, hơi nghiêng
			mb.box("concrete", Vector3(c.x + 2.0, 0.16, c.y), Vector3(2.6, 0.26, span + 0.8), Color(0.78, 0.76, 0.72), 1, "ext", Basis(Vector3(0, 0, 1), 0.07) * Basis(Vector3.UP, 0.1), "concrete")
			mb.box("brick", Vector3(c.x + 3.6, 0.2, c.y - span * 0.5 - 0.6), Vector3(1.4, 0.4, 1.0), Color(0.8, 0.78, 0.74), 1, "ext", Basis(Vector3.UP, 0.6))
		"ruin":
			# cả một toà nhà đổ xuống lấp khe: phải trèo qua đống đổ nát
			mb.collider(Vector3(c.x - 0.5, 0.2, c.y), Vector3(5.6, 0.5, span + 1.0), "concrete", 1)
			mb.collider(Vector3(c.x - 0.5, 0.65, c.y), Vector3(3.8, 0.45, span - 0.6), "concrete", 1)
			mb.box("concrete", Vector3(c.x - 0.5, -2.4, c.y), Vector3(5.6, 5.0, r.size.y), Color(0.7, 0.68, 0.64), 0)
			for m in 22:
				var sz := Vector3(rng.randf_range(0.8, 2.6), rng.randf_range(0.25, 0.7), rng.randf_range(0.8, 2.4))
				var q := Vector3(c.x - 0.5 + rng.randf_range(-2.6, 2.6), rng.randf_range(0.15, 0.75), c.y + rng.randf_range(-span * 0.5, span * 0.5))
				mb.box("concrete" if rng.randf() < 0.6 else ("brick" if rng.randf() < 0.6 else "plaster"), q, sz, Color(0.78, 0.74, 0.7), 0, "ext", Basis.from_euler(Vector3(rng.randf_range(-0.25, 0.25), rng.randf() * TAU, rng.randf_range(-0.25, 0.25))))
			# một mảng tường còn nguyên cửa sổ nằm nghiêng trên đống gạch
			mb.box("plaster", Vector3(c.x + 0.8, 1.1, c.y + 0.4), Vector3(4.2, 0.3, 3.0), Color("d9c58f"), 0, "ext", Basis.from_euler(Vector3(0.25, 0.4, 0.12)))
	# dốc đất ở đầu phía đông để leo lên
	var run := 8.0
	var ang := atan2(depth, run)
	var rot := Basis(Vector3(0, 0, 1), ang)
	mb.box("dirt", Vector3(r.end.x - run * 0.5, -depth * 0.5, c.y + 0.9) - (rot * Vector3.UP) * 0.25, Vector3(sqrt(run * run + depth * depth), 0.5, 1.4), Color(0.7, 0.66, 0.58), 1, "ext", rot)


func _slab(mb: MeshBuilder, mat: String, x0: float, x1: float, z0: float, z1: float, y0 := -1.0, y1 := 0.0) -> void:
	mb.box(mat, Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5), Vector3(x1 - x0, y1 - y0, z1 - z0))


func _near_intersection_x(x: float) -> bool:
	for i in COLS + 1:
		if absf(x - road_x(i)) < ROAD * 0.5 + 4.5:
			return true
	return false


func _near_intersection_z(z: float) -> bool:
	for j in ROWS + 1:
		if absf(z - road_z(j)) < ROAD * 0.5 + 4.5:
			return true
	return false


# ------------------------------------------------------------------ hồ
func _build_lake(mb: MeshBuilder) -> void:
	var zr := zone_rect(LAKE_ZONE)
	var c := Vector3(zr.get_center().x, 0.0, zr.get_center().y)
	var LW := zr.size.x
	var LD := zr.size.y
	var rim := 15.0
	var ix := LW * 0.5 - rim     # nửa chiều dài lòng hồ
	var iz := LD * 0.5 - rim
	lake_rect = Rect2(c.x - ix, c.z - iz, ix * 2.0, iz * 2.0)
	var bottom := -LAKE_DEPTH
	var green := Color(0.8, 0.95, 0.75)
	# Bờ cỏ quanh hồ (dày xuống tận đáy để làm thành hồ).
	mb.box("grass", Vector3(c.x, (BASE + bottom - 0.4) * 0.5, c.z - LD * 0.5 + rim * 0.5), Vector3(LW, BASE - bottom + 0.4, rim), green)
	mb.box("grass", Vector3(c.x, (BASE + bottom - 0.4) * 0.5, c.z + LD * 0.5 - rim * 0.5), Vector3(LW, BASE - bottom + 0.4, rim), green)
	mb.box("grass", Vector3(c.x - LW * 0.5 + rim * 0.5, (BASE + bottom - 0.4) * 0.5, c.z), Vector3(rim, BASE - bottom + 0.4, iz * 2.0), green)
	mb.box("grass", Vector3(c.x + LW * 0.5 - rim * 0.5, (BASE + bottom - 0.4) * 0.5, c.z), Vector3(rim, BASE - bottom + 0.4, iz * 2.0), green)
	# Đáy hồ
	mb.box("rock", Vector3(c.x, bottom - 0.3, c.z), Vector3(ix * 2.0, 0.6, iz * 2.0), Color(0.6, 0.62, 0.6))
	# Hai bờ thoải phía tây và đông để lội xuống / bơi lên.
	var angle := deg_to_rad(33.0)
	var rise := BASE - bottom
	var run := rise / tan(angle)
	var length := sqrt(rise * rise + run * run)
	for sg: float in [-1.0, 1.0]:
		var top_x := c.x + sg * ix
		var mid := Vector3(top_x - sg * run * 0.5, (BASE + bottom) * 0.5, c.z)
		var rot := Basis(Vector3(0, 0, 1), sg * angle)
		var normal := rot * Vector3.UP
		mb.box("dirt", mid - normal * 0.3, Vector3(length + 0.6, 0.6, iz * 2.0), Color(0.75, 0.72, 0.62), 1, "ext", rot)
	# Mặt nước
	var water := MeshInstance3D.new()
	water.name = "Water"
	var pm := PlaneMesh.new()
	pm.size = Vector2(ix * 2.0, iz * 2.0)
	pm.subdivide_width = 56
	pm.subdivide_depth = 46
	water.mesh = pm
	var wm := ShaderMaterial.new()
	wm.shader = load("res://shaders/water.gdshader")
	water.material_override = wm
	water.position = Vector3(c.x, WATER_Y, c.z)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mb.root.add_child(water)
	_natural_shore(mb, c, ix, iz, bottom)
	# Công viên quanh hồ: lối dạo lát đá, ghế đá, hàng cây, bụi cây
	var walk := Color(0.92, 0.9, 0.84)
	mb.box("sidewalk", Vector3(c.x, BASE + 0.01, c.z - LD * 0.5 + rim - 3.0), Vector3(LW - 2.0 * rim + 8.0, 0.02, 2.4), walk, 0)
	mb.box("sidewalk", Vector3(c.x, BASE + 0.01, c.z + LD * 0.5 - rim + 3.0), Vector3(LW - 2.0 * rim + 8.0, 0.02, 2.4), walk, 0)
	mb.box("sidewalk", Vector3(c.x - LW * 0.5 + rim - 3.0, BASE + 0.01, c.z), Vector3(2.4, 0.02, LD - 2.0 * rim + 8.0), walk, 0)
	mb.box("sidewalk", Vector3(c.x + LW * 0.5 - rim + 3.0, BASE + 0.01, c.z), Vector3(2.4, 0.02, LD - 2.0 * rim + 8.0), walk, 0)
	for k in 70:
		# cây rải trên dải cỏ sát đường (vòng ngoài), chừa lối dạo sát mép nước
		var side := k % 4
		var t := rng.randf_range(-0.5, 0.5)
		var depth := rng.randf_range(1.5, rim - 5.5)
		var p := Vector3.ZERO
		if side == 0:
			p = Vector3(c.x + t * (LW - 4.0), BASE, c.z - LD * 0.5 + depth)
		elif side == 1:
			p = Vector3(c.x + t * (LW - 4.0), BASE, c.z + LD * 0.5 - depth)
		elif side == 2:
			p = Vector3(c.x - LW * 0.5 + depth, BASE, c.z + t * (LD - 4.0))
		else:
			p = Vector3(c.x + LW * 0.5 - depth, BASE, c.z + t * (LD - 4.0))
		_tree_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.9, 1.7)), p))
	for k in 16:
		var a := k / 16.0 * TAU + 0.2
		var bp := Vector3(c.x + clampf(cos(a) * LW, -LW * 0.5 + rim - 1.2, LW * 0.5 - rim + 1.2), BASE, c.z + clampf(sin(a) * LD, -LD * 0.5 + rim - 1.2, LD * 0.5 - rim + 1.2))
		mb.box("concrete", bp + Vector3(0, 0.25, 0), Vector3(1.8, 0.5, 0.6), Color(0.8, 0.8, 0.78), 1, "ext", Basis(Vector3.UP, a))
	for k in 30:
		var a3 := rng.randf() * TAU
		var bq := Vector3(c.x + clampf(cos(a3) * LW, -LW * 0.5 + 2.0, LW * 0.5 - 2.0), BASE, c.z + clampf(sin(a3) * LD, -LD * 0.5 + 2.0, LD * 0.5 - 2.0))
		var bs := rng.randf_range(0.7, 1.4)
		mb.box("grass", bq + Vector3(0, bs * 0.4, 0), Vector3(bs * 1.5, bs * 0.8, bs * 1.2), Color(0.45, 0.62, 0.4), 0, "ext", Basis(Vector3.UP, rng.randf() * TAU))
	_add_label(Vector3(c.x, 2.6, c.z - LD * 0.5 + 0.6), "CÔNG VIÊN HỒ", -1.0, 1.1, Color.WHITE)


## Bờ hồ lượn lồi lõm như hồ thật (đắp đất lấn vào lòng hồ chữ nhật), một đảo nhỏ có đình và cây, cầu cong ra đảo.
## Hai bờ thoải phía tây và đông vẫn chừa khoảng giữa để lội lên.
func _natural_shore(mb: MeshBuilder, c: Vector3, ix: float, iz: float, bottom: float) -> void:
	var land := Color(0.78, 0.72, 0.6)
	var grass := Color(0.62, 0.8, 0.55)
	var noise := FastNoiseLite.new()
	noise.seed = _seed + 404
	noise.frequency = 0.035
	var step := 1.5
	# bờ bắc và nam: lấn vào 0..14m
	for side: float in [-1.0, 1.0]:
		var x := -ix
		while x < ix:
			var depth := clampf(4.0 + 12.0 * noise.get_noise_2d(x, side * 50.0), 0.0, 15.0)
			if absf(x) > ix - 10.0:
				depth = maxf(depth, 6.0 + (absf(x) - (ix - 10.0)) * 1.2)       # góc hồ bo tròn
			if depth > 0.6:
				var zc := c.z + side * (iz - depth * 0.5)
				_land_column(mb, Vector3(c.x + x + step * 0.5, 0, zc), Vector2(step + 0.3, depth), bottom, land, grass)
			x += step
	# bờ tây và đông: chỉ lấn ở hai đầu, chừa đoạn giữa (dốc lội lên)
	for side2: float in [-1.0, 1.0]:
		var z := -iz
		while z < iz:
			if absf(z) > iz * 0.32:
				var depth2 := clampf(3.0 + 9.0 * noise.get_noise_2d(side2 * 70.0, z), 0.0, 11.0)
				if depth2 > 0.6:
					_land_column(mb, Vector3(c.x + side2 * (ix - depth2 * 0.5), 0, c.z + z + step * 0.5), Vector2(depth2, step + 0.3), bottom, land, grass)
			z += step
	# đảo nhỏ lệch về phía nam
	var ic := Vector3(c.x + ix * 0.5, 0, c.z + iz * 0.3)
	for k in 7:
		var a := k / 7.0 * PI
		var rx := 10.0 * absf(cos(a * 0.5 + 0.2)) + 3.0
		_land_column(mb, ic + Vector3(0, 0, (k - 3) * 2.0), Vector2(rx * 2.0, 2.4), bottom, land, grass)
	island = Rect2(ic.x - 12.0, ic.z - 7.5, 24.0, 15.0)
	for t in 4:
		_tree_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.0, 1.5)), ic + Vector3(rng.randf_range(-7.0, 7.0), BASE, rng.randf_range(-5.0, -2.0))))
	# đình nhỏ trên đảo: bốn cột đỏ, mái ngói cong
	var red := Color(0.7, 0.2, 0.15)
	for px: float in [-1.6, 1.6]:
		for pz: float in [-1.6, 1.6]:
			mb.box("paint", ic + Vector3(px + 4.0, BASE + 1.3, pz + 2.0), Vector3(0.22, 2.6, 0.22), red)
	mb.box("roof", ic + Vector3(4.0, BASE + 2.75, 2.0), Vector3(4.6, 0.3, 4.6), Color(0.6, 0.35, 0.25))
	mb.box("roof", ic + Vector3(4.0, BASE + 3.1, 2.0), Vector3(3.0, 0.5, 3.0), Color(0.6, 0.35, 0.25))
	mb.box("concrete", ic + Vector3(4.0, BASE + 0.08, 2.0), Vector3(4.4, 0.16, 4.4), Color(0.8, 0.78, 0.74))
	# cầu cong màu đỏ từ bờ nam ra đảo
	var start := Vector3(ic.x - 2.0, 0, c.z + iz - 6.0)
	var end := Vector3(ic.x - 2.0, 0, ic.z + 6.5)
	var segs := 12
	for i in segs:
		var t0 := float(i) / segs
		var t1 := float(i + 1) / segs
		var y0 := BASE + 1.4 * sin(t0 * PI)
		var y1 := BASE + 1.4 * sin(t1 * PI)
		var p0 := start.lerp(end, t0) + Vector3(0, y0, 0)
		var p1 := start.lerp(end, t1) + Vector3(0, y1, 0)
		var mid := (p0 + p1) * 0.5
		var dirv := (p1 - p0)
		var ang := atan2(dirv.y, Vector2(dirv.x, dirv.z).length())
		var rot := Basis(Vector3.UP, atan2(dirv.x, dirv.z)) * Basis(Vector3.RIGHT, -ang)
		mb.box("wood", mid, Vector3(2.2, 0.16, dirv.length() + 0.05), red, 1, "ext", rot, "wood")
		for sx: float in [-1.05, 1.05]:
			mb.box("paint", mid + Vector3(sx, 0.55, 0), Vector3(0.08, 0.08, dirv.length() + 0.05), red, 0, "ext", rot)
			mb.collider(mid + Vector3(sx, 0.5, 0), Vector3(0.08, 1.0, dirv.length()), "wood", 2, rot)
	for i2 in segs + 1:
		var tt := float(i2) / segs
		var pp := start.lerp(end, tt) + Vector3(0, BASE + 1.4 * sin(tt * PI), 0)
		for sx2: float in [-1.05, 1.05]:
			mb.box("paint", pp + Vector3(sx2, 0.3, 0), Vector3(0.1, 0.6, 0.1), red, 0)


func _land_column(mb: MeshBuilder, ctr: Vector3, size: Vector2, bottom: float, land: Color, grass: Color) -> void:
	mb.box("dirt", Vector3(ctr.x, (bottom + BASE - 0.06) * 0.5, ctr.z), Vector3(size.x, BASE - 0.06 - bottom, size.y), land)
	mb.box("grass", Vector3(ctr.x, BASE - 0.03, ctr.z), Vector3(size.x, 0.06, size.y), grass, 1, "ext", Basis.IDENTITY, "grass")
	lake_land.append(Rect2(ctr.x - size.x * 0.5, ctr.z - size.y * 0.5, size.x, size.y))


## Độ sâu nước tại một điểm (0 nếu không ở trong hồ): khoảng cách từ mặt nước xuống điểm đó.
func water_depth(p: Vector3) -> float:
	if lake_rect.has_point(Vector2(p.x, p.z)) and p.y < WATER_Y:
		for r in lake_land:
			if r.has_point(Vector2(p.x, p.z)):
				return 0.0
		return WATER_Y - p.y
	return 0.0


# ------------------------------------------------------------------ công viên lớn: rừng cây và bãi cỏ
func _build_park(mb: MeshBuilder, cell: Vector2i) -> void:
	var c := block_center(cell.x, cell.y)
	if cell_kind(cell) == "forest":
		# Rừng rậm: cây to mọc dày, bụi rậm, đá, thân cây đổ. Chừa các lối mòn (vị trí các con đường cũ).
		for k in 95:
			var p := Vector3(c.x + rng.randf_range(-PX * 0.5 + 2.4, PX * 0.5 - 2.4), 0.04, c.z + rng.randf_range(-PZ * 0.5 + 2.4, PZ * 0.5 - 2.4))
			if not in_forest(p):
				continue
			_tree_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.2, 2.4)), p))
		for k in 46:
			var q := Vector3(c.x + rng.randf_range(-PX * 0.5 + 2.4, PX * 0.5 - 2.4), 0.04, c.z + rng.randf_range(-PZ * 0.5 + 2.4, PZ * 0.5 - 2.4))
			if not in_forest(q):
				continue
			var bs := rng.randf_range(0.8, 1.7)
			mb.box("grass", q + Vector3(0, bs * 0.45, 0), Vector3(bs * 1.6, bs * 0.9, bs * 1.3), Color(0.38, 0.55, 0.36), 0, "ext", Basis(Vector3.UP, rng.randf() * TAU))
		for k in 7:
			var rp := Vector3(c.x + rng.randf_range(-BW * 0.45, BW * 0.45), 0.04, c.z + rng.randf_range(-BD * 0.45, BD * 0.45))
			var rs := rng.randf_range(0.6, 1.5)
			mb.box("rock", rp + Vector3(0, rs * 0.35, 0), Vector3(rs * 1.4, rs * 0.8, rs), Color(0.75, 0.76, 0.74), 1, "ext", Basis.from_euler(Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.2, 0.2))))
		for k in 3:
			var lp := Vector3(c.x + rng.randf_range(-BW * 0.4, BW * 0.4), 0.3, c.z + rng.randf_range(-BD * 0.4, BD * 0.4))
			mb.box("wood", lp, Vector3(rng.randf_range(3.0, 6.0), 0.5, 0.5), Color(0.5, 0.4, 0.32), 1, "ext", Basis(Vector3.UP, rng.randf() * TAU))
		if rng.randf() < 0.6:
			var cp2 := Vector3(c.x + rng.randf_range(-12.0, 12.0), 0.04, c.z + rng.randf_range(-10.0, 10.0))
			mb.box("wood", cp2 + Vector3(0, 0.3, 0), Vector3(0.9, 0.6, 0.6), Color(0.6, 0.55, 0.45))
			_add_container("street", cp2 + Vector3(0, 0.75, 0), -1, 2)
		if cell == FOREST_ZONE.position:
			_add_label(Vector3(c.x - BW * 0.5 + 0.4, 2.6, c.z), "CÔNG VIÊN", 1.0, 1.1, Color.WHITE)
			(get_child(get_child_count() - 1) as Label3D).rotation.y = -PI * 0.5
	else:
		# Bãi cỏ trống: không có gì che chắn. Vài cột gôn, ghế băng cho ra dáng sân bóng.
		if (cell.x + cell.y) % 2 == 0:
			for sg: float in [-1.0, 1.0]:
				var gx := c.x + sg * 22.0
				for gz: float in [-3.0, 3.0]:
					mb.box("paint", Vector3(gx, 1.2, c.z + gz), Vector3(0.12, 2.4, 0.12), Color.WHITE, 2)
				mb.box("paint", Vector3(gx, 2.4, c.z), Vector3(0.12, 0.12, 6.1), Color.WHITE, 0)
		for k in 2:
			var bp := Vector3(c.x + rng.randf_range(-BW * 0.45, BW * 0.45), 0.04, c.z + (BD * 0.5 - 1.0) * (1.0 if k == 0 else -1.0))
			mb.box("wood", bp + Vector3(0, 0.25, 0), Vector3(1.8, 0.5, 0.5), Color(0.6, 0.5, 0.4))


# ------------------------------------------------------------------ công trường và cần cẩu tháp
## Một vế cầu thang thẳng: bậc nhìn thấy + một tấm dốc để đi.
func _stair_flight(mb: MeshBuilder, from: Vector3, to: Vector3, width: float, col: Color, mat := "metal") -> void:
	var d := to - from
	var run := Vector2(d.x, d.z).length()
	var rise := d.y
	var dir := Vector3(d.x, 0, d.z).normalized()
	var side := Vector3(-dir.z, 0, dir.x)
	var steps := maxi(3, int(round(rise / 0.24)))
	var yaw_b := Basis(side, Vector3.UP, dir * -1.0).orthonormalized()
	for i in steps:
		var t := (i + 0.5) / steps
		var pos := from + dir * run * t + Vector3(0, rise * (i + 1.0) / steps - 0.04, 0)
		mb.box(mat, pos, Vector3(width, 0.06, run / steps + 0.02), col, 0, "ext", yaw_b)
	var slope := d.normalized()
	var up2 := side.cross(slope).normalized()
	if up2.y < 0.0:
		up2 = -up2
	var rot := Basis(side, up2, side.cross(up2)).orthonormalized()
	mb.collider((from + to) * 0.5 - up2 * 0.08, Vector3(width, 0.16, d.length() + 0.3), mat, 1, rot)


## Tháp cầu thang xoắn vuông quanh thân cần cẩu, cao tới `height`.
func _stair_tower(mb: MeshBuilder, base: Vector3, height: float, col: Color) -> void:
	var h := 1.7
	var corners := [Vector3(-h, 0, -h), Vector3(h, 0, -h), Vector3(h, 0, h), Vector3(-h, 0, h)]
	var rise := 1.7
	var flights := int(round(height / rise))
	var grey := Color(0.7, 0.72, 0.74)
	for k in flights + 1:
		var cpos: Vector3 = base + corners[k % 4] + Vector3(0, k * rise, 0)
		mb.box("metal", cpos + Vector3(0, -0.06, 0), Vector3(1.3, 0.12, 1.3), grey, 1, "ext", Basis.IDENTITY, "metal")
		if k < flights:
			var a: Vector3 = corners[k % 4]
			var b: Vector3 = corners[(k + 1) % 4]
			var dir := (b - a).normalized()
			_stair_flight(mb, base + a + dir * 0.62 + Vector3(0, k * rise, 0), base + b - dir * 0.62 + Vector3(0, (k + 1) * rise, 0), 1.15, grey)
	# thân tháp (lõi) + bốn trụ góc + giằng ngang
	mb.box("paint", base + Vector3(0, height * 0.5, 0), Vector3(1.5, height, 1.5), col, 1)
	for cn: Vector3 in [Vector3(-2.4, 0, -2.4), Vector3(2.4, 0, -2.4), Vector3(2.4, 0, 2.4), Vector3(-2.4, 0, 2.4)]:
		mb.box("paint", base + cn + Vector3(0, height * 0.5, 0), Vector3(0.18, height, 0.18), col, 0)
	var y := 1.1
	while y < height + 1.0:
		for sd in 4:
			var horizontal := sd % 2 == 0
			var off := Vector3(0, y, -2.4 if sd == 0 else 2.4) if horizontal else Vector3(-2.4 if sd == 1 else 2.4, y, 0)
			# lan can: thanh nhìn thấy + tấm chắn trong suốt để không rơi ra ngoài (chừa lối vào ở chân tháp)
			mb.box("paint", base + off, Vector3(4.8 if horizontal else 0.08, 0.08, 0.08 if horizontal else 4.8), col, 0)
		y += rise
	for sd in 4:
		var horizontal2 := sd % 2 == 0
		var y0 := 2.3 if sd == 3 else 0.0
		var off2 := Vector3(0, 0, -2.42 if sd == 0 else 2.42) if horizontal2 else Vector3(-2.42 if sd == 3 else 2.42, 0, 0)
		mb.collider(base + off2 + Vector3(0, (y0 + height + 1.2) * 0.5, 0), Vector3(4.9 if horizontal2 else 0.1, height + 1.2 - y0, 0.1 if horizontal2 else 4.9), "metal", 2)


func _build_site(mb: MeshBuilder, cell: Vector2i) -> void:
	var c := block_center(cell.x, cell.y)
	mb.box("dirt", Vector3(c.x, BASE * 0.5, c.z), Vector3(BW, BASE, BD), Color(0.86, 0.8, 0.68))
	var yellow := Color("e8b21c")
	var conc := Color(0.82, 0.81, 0.78)
	# Hàng rào tôn quanh công trường, chừa hai cổng
	for sg: float in [-1.0, 1.0]:
		var x := -BW * 0.5 + 1.0
		while x < BW * 0.5 - 1.0:
			if absf(x + 2.0) > 4.0 and not near_rail_stair(Vector3(c.x + x + 2.0, 0, c.z + sg * (BD * 0.5 - 0.6)), 3.5):
				mb.box("rust", Vector3(c.x + x + 2.0, BASE + 1.1, c.z + sg * (BD * 0.5 - 0.6)), Vector3(3.9, 2.2, 0.08), Color(0.55, 0.65, 0.75))
			x += 4.0
		var z := -BD * 0.5 + 1.0
		while z < BD * 0.5 - 1.0:
			if not near_rail_stair(Vector3(c.x + sg * (BW * 0.5 - 0.6), 0, c.z + z + 2.0), 3.5):
				mb.box("rust", Vector3(c.x + sg * (BW * 0.5 - 0.6), BASE + 1.1, c.z + z + 2.0), Vector3(0.08, 2.2, 3.9), Color(0.55, 0.65, 0.75))
			z += 4.0
	# Toà nhà đang xây dở: khung bê tông 6 tầng, sàn trống, chưa có tường, cầu thang bộ thô
	var ox := c.x - 8.0
	var oz := c.z - 3.0
	var bw2 := 26.0
	var bd2 := 18.0
	var fh2 := 3.4
	var floors := 6
	for f in floors + 1:
		var y := BASE + f * fh2
		if f > 0:
			# sàn khoét ô cầu thang ở góc
			_slab_holes(mb, "concrete", Rect2(ox - bw2 * 0.5, oz - bd2 * 0.5, bw2, bd2), [Rect2(ox + bw2 * 0.5 - 6.4, oz - bd2 * 0.5 + 1.0, 5.2, 2.6)], y - 0.25, y)
		if f < floors:
			var cx := -bw2 * 0.5 + 0.4
			while cx <= bw2 * 0.5 - 0.3:
				for cz: float in [-bd2 * 0.5 + 0.4, 0.0, bd2 * 0.5 - 0.4]:
					mb.box("concrete", Vector3(ox + cx, y + fh2 * 0.5 - 0.12, oz + cz), Vector3(0.55, fh2 - 0.25, 0.55), conc)
				cx += 6.3
			# cầu thang: một vế thẳng trong ô khoét
			_stair_flight(mb, Vector3(ox + bw2 * 0.5 - 6.2, y, oz - bd2 * 0.5 + 2.3), Vector3(ox + bw2 * 0.5 - 1.4, y + fh2, oz - bd2 * 0.5 + 2.3), 1.6, conc, "concrete")
			# lưới an toàn thấp ở mép sàn (chỉ vài đoạn, chỗ có chỗ không)
			if f > 0:
				for sg2: float in [-1.0, 1.0]:
					if rng.randf() < 0.7:
						mb.box("rust", Vector3(ox + rng.randf_range(-6.0, 6.0), y + 0.5, oz + sg2 * (bd2 * 0.5 - 0.1)), Vector3(rng.randf_range(6.0, 12.0), 1.0, 0.06), Color(0.9, 0.5, 0.2), 2)
		# vật liệu, thùng đồ nghề trên các sàn
		if f > 0 and f < floors and rng.randf() < 0.75:
			var q := Vector3(ox + rng.randf_range(-9.0, 4.0), y + 0.3, oz + rng.randf_range(-5.0, 5.0))
			mb.box("wood", q, Vector3(1.0, 0.6, 0.7), Color(0.7, 0.6, 0.45))
			_add_container(["h_tool", "h_pipe", "h_misc"][rng.randi() % 3], q + Vector3(0, 0.5, 0), -1, 2)
		if f > 0 and f <= floors:
			for k in 2:
				var sp := Vector3(ox + rng.randf_range(-10.0, 8.0), y + 0.25, oz + rng.randf_range(-6.0, 6.0))
				mb.box("brick" if rng.randf() < 0.5 else "concrete", sp, Vector3(rng.randf_range(0.8, 1.8), 0.5, rng.randf_range(0.6, 1.2)), conc)
	_add_label(Vector3(c.x - 2.0, 3.0, c.z + BD * 0.5 - 0.5), "CÔNG TRƯỜNG", 1.0, 0.9, Color("ffd24a"))
	# Đống cát, ống cống, gạch dưới sân
	for k in 9:
		var gp := Vector3(c.x + rng.randf_range(-BW * 0.42, BW * 0.2), BASE, c.z + rng.randf_range(BD * 0.22, BD * 0.42) * (1.0 if k % 2 == 0 else -1.0))
		var gs := rng.randf_range(0.6, 1.6)
		mb.box(["dirt", "concrete", "brick"][k % 3], gp + Vector3(0, gs * 0.4, 0), Vector3(gs * 1.8, gs * 0.8, gs * 1.3), conc, 1, "ext", Basis(Vector3.UP, rng.randf() * TAU))
	# Cần cẩu tháp: trèo cầu thang quanh thân lên tới buồng lái, đi ra được trên cần
	var cb := Vector3(c.x + BW * 0.5 - 9.0, BASE, c.z + BD * 0.5 - 12.0)
	crane_pos = cb
	mb.box("concrete", cb + Vector3(0, 0.15, 0), Vector3(6.4, 0.3, 6.4), conc)
	_stair_tower(mb, cb + Vector3(0, 0.3, 0), CRANE_H, yellow)
	var top := cb + Vector3(0, 0.3 + CRANE_H, 0)
	mb.box("metal", top + Vector3(0, -0.08, 0), Vector3(7.0, 0.16, 7.0), Color(0.7, 0.72, 0.74), 1, "ext", Basis.IDENTITY, "metal")      # sàn đỉnh
	for sd in 4:
		var hz := sd % 2 == 0
		var o3 := Vector3(0, 0.55, -3.45 if sd == 0 else 3.45) if hz else Vector3(-3.45 if sd == 1 else 3.45, 0.55, 0)
		if sd == 1:
			continue          # phía tây để trống: lối ra cần cẩu
		mb.box("paint", top + o3, Vector3(7.0 if hz else 0.08, 1.1, 0.08 if hz else 7.0), yellow, 2)
	mb.box("paint", top + Vector3(1.9, 1.25, 1.9), Vector3(2.4, 2.5, 2.4), yellow)                 # buồng lái
	mb.box("glass", top + Vector3(1.9, 1.5, 0.68), Vector3(2.0, 1.2, 0.04), Color.WHITE, 0)
	_add_container("ration", top + Vector3(-1.6, 0.6, 2.2), -1, 3)
	mb.box("wood", top + Vector3(-1.6, 0.3, 2.2), Vector3(0.9, 0.6, 0.6), Color(0.45, 0.5, 0.35))
	# cần (vươn về phía tây 44m, đi bộ ra được) và đối trọng (phía đông)
	var jib := 44.0
	mb.box("paint", top + Vector3(-3.5 - jib * 0.5, -0.1, 0), Vector3(jib, 0.2, 1.3), yellow, 1, "ext", Basis.IDENTITY, "metal")
	for sg3: float in [-1.0, 1.0]:
		mb.box("paint", top + Vector3(-3.5 - jib * 0.5, 0.5, sg3 * 0.65), Vector3(jib, 0.08, 0.08), yellow, 0)
		mb.collider(top + Vector3(-3.5 - jib * 0.5, 0.5, sg3 * 0.7), Vector3(jib, 1.0, 0.08), "metal", 2)
		var px2 := 0.0
		while px2 < jib:
			mb.box("paint", top + Vector3(-3.5 - px2, 0.25, sg3 * 0.65), Vector3(0.08, 0.5, 0.08), yellow, 0)
			px2 += 2.2
	mb.box("paint", top + Vector3(3.5 + 7.0, -0.1, 0), Vector3(14.0, 0.2, 1.3), yellow, 1, "ext", Basis.IDENTITY, "metal")
	mb.box("concrete", top + Vector3(3.5 + 11.5, -1.0, 0), Vector3(4.0, 1.6, 2.0), conc)
	mb.box("paint", top + Vector3(0, 4.5, 0), Vector3(0.9, 9.0, 0.9), yellow)                    # chóp tháp
	mb.box("dark", top + Vector3(-22.0, 4.4, 0), Vector3(40.0, 0.06, 0.06), Color(0.15, 0.15, 0.16), 0, "ext", Basis(Vector3(0, 0, 1), -0.21))
	mb.box("dark", top + Vector3(-26.0, -9.0, 0), Vector3(0.06, 18.0, 0.06), Color(0.15, 0.15, 0.16), 0)     # cáp treo móc
	mb.box("paint", top + Vector3(-26.0, -18.4, 0), Vector3(0.7, 0.9, 0.5), yellow, 0)


# ------------------------------------------------------------------ khu ổ chuột (xóm ngõ)
## Hai hình chữ nhật xoay (tâm, hướng trục ngang, nửa rộng, nửa sâu) có chồng lên nhau không?
func _obb_overlap(c1: Vector2, t1: Vector2, hx1: float, hz1: float, c2: Vector2, t2: Vector2, hx2: float, hz2: float, margin: float) -> bool:
	var n1 := Vector2(-t1.y, t1.x)
	var n2 := Vector2(-t2.y, t2.x)
	var d := c2 - c1
	for ax: Vector2 in [t1, n1, t2, n2]:
		var r1 := absf(t1.dot(ax)) * hx1 + absf(n1.dot(ax)) * hz1
		var r2 := absf(t2.dot(ax)) * hx2 + absf(n2.dot(ax)) * hz2
		if absf(d.dot(ax)) > r1 + r2 + margin:
			return false
	return true


## Vạch các con ngõ của một xóm: hai ngõ chính uốn lượn xuyên qua xóm và nhiều ngách cụt rẽ ra từ đó.
## Không có ô bàn cờ nào: mỗi ngõ là một đường đi lang thang, đổi hướng liên tục.
func _slum_lanes(hx: float, hz: float) -> Array:
	var lanes: Array = []
	var cells_n := maxf(1.0, (hx * 2.0 * hz * 2.0) / (BW * BD))
	var mains := 4 if cells_n >= 3.0 else 2
	for main in mains:
		var pts := PackedVector2Array()
		var horiz := main % 2 == 0
		var band := (-0.45 if main < 2 else 0.45) if mains == 4 else rng.randf_range(-0.25, 0.25)       # ngõ ngang, ngõ dọc, mỗi cái một dải
		var p := Vector2(-hx, hz * (band + rng.randf_range(-0.3, 0.3))) if horiz else Vector2(hx * (band + rng.randf_range(-0.3, 0.3)), -hz)
		var base := 0.0 if horiz else PI * 0.5
		var heading := base + rng.randf_range(-0.4, 0.4)
		pts.append(p)
		for step in 140:
			heading += rng.randf_range(-0.55, 0.55)
			heading = clampf(heading, base - 1.05, base + 1.05)
			# đừng bò sát mép xóm
			if horiz:
				if p.y > hz - 9.0: heading -= 0.35
				if p.y < -hz + 9.0: heading += 0.35
			else:
				if p.x > hx - 9.0: heading += 0.35
				if p.x < -hx + 9.0: heading -= 0.35
			p += Vector2(cos(heading), sin(heading)) * 2.4
			pts.append(p)
			if (horiz and p.x >= hx) or (not horiz and p.y >= hz):
				break
		lanes.append({"pts": pts, "w": rng.randf_range(1.6, 2.0), "main": true})
	for br in int(4.0 * cells_n):
		var parent: Dictionary = lanes[rng.randi() % lanes.size()]
		var ppts: PackedVector2Array = parent.pts
		if ppts.size() < 4:
			continue
		var i := clampi(1 + rng.randi() % (ppts.size() - 2), 1, ppts.size() - 2)
		var tangent := (ppts[i + 1] - ppts[i - 1]).normalized()
		var heading2 := tangent.angle() + (1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(1.0, 1.9)
		var q := ppts[i]
		var pts2 := PackedVector2Array([q])
		for step in 5 + rng.randi() % 10:
			heading2 += rng.randf_range(-0.7, 0.7)
			q += Vector2(cos(heading2), sin(heading2)) * 2.4
			if absf(q.x) > hx - 4.0 or absf(q.y) > hz - 4.0:
				break
			pts2.append(q)
		if pts2.size() >= 3:
			lanes.append({"pts": pts2, "w": rng.randf_range(1.2, 1.5), "main": false})
	return lanes


## Điểm này (toạ độ trong xóm) có nằm trên lòng một con ngõ không?
func _on_slum_lane(lanes: Array, c: Vector2, t: Vector2, hx: float, hz: float, skip: int) -> bool:
	var n := Vector2(-t.y, t.x)
	for li in lanes.size():
		var lane: Dictionary = lanes[li]
		var grow: float = float(lane.w) * 0.5 - (0.12 if li == skip else 0.0)
		for lp: Vector2 in lane.pts:
			var d := lp - c
			if absf(d.dot(t)) < hx + grow and absf(d.dot(n)) < hz + grow:
				return true
	return false


func _build_slum(mb: MeshBuilder, cell: Vector2i, zr: Rect2) -> void:
	var mains := 4 if zr.size.x * zr.size.y >= 3.0 * BW * BD else 2
	var cells_n := maxf(1.0, (zr.size.x * zr.size.y) / (BW * BD))
	var c := Vector3(zr.get_center().x, 0.0, zr.get_center().y)
	var HX := zr.size.x * 0.5
	var HZ := zr.size.y * 0.5
	var c2 := Vector2(c.x, c.z)
	# Nền vỉa hè như mọi khối nhà khác: khu tập thể chỉ khác ở chỗ nhà cửa, ngõ ngách xây lộn xộn.
	mb.box("sidewalk", Vector3(c.x, BASE * 0.5, c.z), Vector3(HX * 2.0, BASE, HZ * 2.0))
	if _rebuilding:
		for spec: Dictionary in block_specs.get(cell, []):
			_build_house(mb, spec)
	else:
		block_specs[cell] = []
		var lanes := _slum_lanes(HX, HZ)
		slum_lanes[cell] = lanes
		var placed: Array = []
		var limit_x := HX - 0.6
		var limit_z := HZ - 0.6
		var try_place := func(front: Vector2, face: Vector2, w: float, d: float, lane_i: int, kind: String) -> bool:
			# front: giữa mặt tiền; face: hướng mặt tiền nhìn ra
			var t := Vector2(face.y, -face.x)
			var ctr := front - face * d * 0.5
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					var corner := ctr + t * sx * w * 0.5 + face * sz * d * 0.5
					if absf(corner.x) > limit_x or absf(corner.y) > limit_z:
						return false
			if _on_slum_lane(lanes, ctr, t, w * 0.5, d * 0.5, lane_i):
				return false
			for o: Array in placed:
				if _obb_overlap(ctr, t, w * 0.5, d * 0.5, o[0], o[1], o[2], o[3], 0.12):
					return false
			placed.append([ctr, t, w * 0.5, d * 0.5])
			var b := {
				"id": buildings.size(), "kind": "house", "shop": "", "s": 1.0, "w": w, "d": d, "fh": FH,
				"origin": Vector3(c.x + front.x, BASE, c.z + front.y), "yaw": atan2(face.x, face.y),
				"floors": [1, 2, 2, 2, 3, 3, 3, 4][rng.randi() % 8],
				"color": Color(HOUSE_COLORS[rng.randi() % HOUSE_COLORS.size()]),
				"roof_access": rng.randf() < 0.45, "name": "Nhà dân", "cell": cell, "seed": rng.randi(), "back_door": rng.randf() < 0.4,
			}
			if kind == "house" and rng.randf() < 0.6:
				b.kind = "closed"
				b.name = "Nhà đóng cửa"
			if kind == "tro":
				b.kind = "tro"
				b.name = "Dãy trọ"
				b.floors = 2 if d > 6.5 else 1
				b.fh = 2.9
				b.color = Color(["e6d6a8", "cfe0d0", "e8c8b0", "d8d8e6"][rng.randi() % 4])
				b.back_door = false
			elif rng.randf() < 0.07:
				b["damage"] = "collapse"
				b["ruined"] = true
			(block_specs[cell] as Array).append(b)
			_build_house(mb, b)
			return true
		# Mặt ngoài của khu vẫn là dãy nhà phố bình thường quay ra đường lớn; chỉ hở ra ở miệng các con ngõ.
		for edge in 4:
			var horizontal := edge < 2
			var sg := -1.0 if edge % 2 == 0 else 1.0
			var half_e := HX if horizontal else HZ
			var face_e := Vector2(0, sg) if horizontal else Vector2(sg, 0)
			var x := -half_e + 0.8
			while x < half_e - 4.0:
				var w0: float = [4.0, 5.0, 5.0, 6.0][rng.randi() % 4]
				var d0: float = [9.0, 10.0, 11.0, 12.0][rng.randi() % 4]
				var setb := rng.randf_range(1.5, 2.6)
				var front0 := (Vector2(x + w0 * 0.5, sg * (HZ - setb)) if horizontal else Vector2(sg * (HX - setb), x + w0 * 0.5))
				if try_place.call(front0, face_e, w0, d0, -1, "house"):
					x += w0 + (0.0 if rng.randf() < 0.85 else rng.randf_range(0.7, 1.0))
				else:
					x += 0.7
		# Dãy trọ: vài dãy phòng dài nằm dọc các con ngõ chính.
		for tro_i in maxi(1, int(cells_n * 0.8)):
			for attempt in 80:
				var tl: Dictionary = lanes[rng.randi() % mains]
				var tp: PackedVector2Array = tl.pts
				var ti := 1 + rng.randi() % (tp.size() - 2)
				var ttg := (tp[ti + 1] - tp[ti - 1]).normalized()
				var tn := Vector2(-ttg.y, ttg.x) * (1.0 if rng.randf() < 0.5 else -1.0)
				var two := rng.randf() < 0.45
				var rooms := 4 + rng.randi() % 4
				if try_place.call(tp[ti] + tn * (float(tl.w) * 0.5 + 0.3), -tn, rooms * 3.2, 7.0 if two else 5.9, -1, "tro"):
					break
		# Nhà bám dọc hai bên từng con ngõ, mặt tiền quay ra ngõ, xoay theo đúng chỗ ngõ uốn.
		for li in lanes.size():
			var lane: Dictionary = lanes[li]
			var pts: PackedVector2Array = lane.pts
			for side: float in [-1.0, 1.0]:
				var acc := rng.randf_range(0.0, 2.0)
				var next_at := 0.0
				var w := rng.randf_range(4.0, 6.0)
				for i in pts.size() - 1:
					var seg := pts[i + 1] - pts[i]
					var ln := seg.length()
					var tg := seg / ln
					var nrm := Vector2(-tg.y, tg.x) * side
					while next_at <= acc + ln:
						var pos := pts[i] + tg * (next_at - acc)
						var d: float = [8.0, 8.0, 9.0, 10.0, 11.0][rng.randi() % 5]
						var front := pos + nrm * (float(lane.w) * 0.5 + rng.randf_range(0.05, 0.45))
						if try_place.call(front, -nrm, w, d, li, "house"):
							next_at += w + (rng.randf_range(0.05, 0.3) if rng.randf() < 0.75 else rng.randf_range(0.8, 1.2))     # thỉnh thoảng chừa một khe lách người
							w = rng.randf_range(4.0, 6.0)
						else:
							next_at += 0.8
					acc += ln
		# Lấp các khoảng trống còn lại bằng nhà quay đủ mọi hướng (nhà trong lõi xóm, phải lách qua khe mới tới).
		for attempt in int(1300.0 * cells_n):
			var a := rng.randf() * TAU
			try_place.call(Vector2(rng.randf_range(-limit_x, limit_x), rng.randf_range(-limit_z, limit_z)), Vector2(cos(a), sin(a)), rng.randf_range(4.0, 5.2), [8.0, 8.0, 9.0, 10.0][rng.randi() % 4], -1, "house")
		slum_obbs[cell] = placed
	rng.seed = _seed + cell.x * 31 + cell.y * 17 + 5
	var lanes2: Array = slum_lanes.get(cell, [])
	# Rác, thùng phuy trong các hốc không phải lối đi
	var obbs: Array = slum_obbs.get(cell, [])
	for k in 150:
		var q := Vector2(rng.randf_range(-HX * 0.95, HX * 0.95), rng.randf_range(-HZ * 0.95, HZ * 0.95))
		if _on_slum_lane(lanes2, q, Vector2.RIGHT, 0.5, 0.5, -1):
			continue
		var inside := false
		for o2: Array in obbs:
			if _obb_overlap(q, Vector2.RIGHT, 0.45, 0.45, o2[0], o2[1], o2[2], o2[3], 0.0):
				inside = true
				break
		if inside:
			continue
		var s2 := rng.randf_range(0.35, 0.75)
		var p3 := Vector3(c.x + q.x, BASE, c.z + q.y)
		mb.box(["wood", "rust", "concrete"][rng.randi() % 3], p3 + Vector3(0, s2 * 0.5, 0), Vector3(s2 * 1.1, s2, s2), Color(0.78, 0.74, 0.68), 1, "ext", Basis(Vector3.UP, rng.randf() * TAU))
		if rng.randf() < 0.2:
			_add_container("street", p3 + Vector3(0, s2 + 0.25, 0), -1, 2)
	_label_yaw = NAN
	var _unused := c2


## Nhà đóng cửa: một khối đặc (không có bên trong), mặt tiền có cửa cuốn kéo xuống, cửa sổ tối, ban công, đôi khi một tấm biển hiệu.
func _build_closed(mb: MeshBuilder, b: Dictionary, n: int) -> void:
	var w: float = b.w
	var d: float = b.d
	var fh: float = b.fh
	var hw := w * 0.5
	var col: Color = b.color
	var top := n * fh
	var wall_mat := "brick" if rng.randf() < 0.15 else "plaster"
	_hb(mb, b, wall_mat, -hw, hw, 0, top, -d, 0, col, 1, "ext")
	var glass := Color(0.26, 0.32, 0.4)
	var frame := Color(0.85, 0.84, 0.8)
	for k in n:
		var y0 := k * fh
		if k == 0:
			# cửa cuốn kéo kín
			var sh_col := [Color(0.62, 0.64, 0.68), Color(0.5, 0.58, 0.66), Color(0.7, 0.62, 0.5)][rng.randi() % 3] as Color
			_hb(mb, b, "metal", -hw + 0.3, hw - 0.3, 0.0, 2.6, 0.0, 0.05, sh_col, 0, "ext")
			var yy := 0.12
			while yy < 2.6:
				_hb(mb, b, "dark", -hw + 0.3, hw - 0.3, yy, yy + 0.025, 0.05, 0.06, sh_col.darkened(0.25), 0, "ext")
				yy += 0.16
			_hb(mb, b, "metal", -hw + 0.25, hw - 0.25, 2.6, 2.85, 0.0, 0.18, sh_col.darkened(0.15), 0, "ext")
		else:
			# cửa sổ tối, khung trắng
			_hb(mb, b, "flat", -1.25, 1.25, y0 + 0.9, y0 + 2.4, 0.0, 0.03, glass, 0, "ext")
			_hb(mb, b, "flat", -1.32, 1.32, y0 + 0.84, y0 + 0.9, 0.0, 0.06, frame, 0, "ext")
			_hb(mb, b, "flat", -0.03, 0.03, y0 + 0.9, y0 + 2.4, 0.03, 0.05, frame, 0, "ext")
			if (int(b.id) + k) % 3 != 0:
				# ban công nhô ra, lan can sắt
				_hb(mb, b, "concrete", -hw, hw, y0 - 0.12, y0, 0, 0.7, col.darkened(0.1), 1, "ext")
				_hb(mb, b, "dark", -hw, hw, y0 + 0.74, y0 + 0.8, 0.64, 0.7, Color(0.16, 0.16, 0.18), 0, "ext")
				var px := -hw + 0.05
				while px < hw:
					_hb(mb, b, "dark", px - 0.02, px + 0.02, y0, y0 + 0.76, 0.65, 0.69, Color(0.16, 0.16, 0.18), 0, "ext")
					px += 0.35
				if rng.randf() < 0.4:
					# chậu cây trên ban công
					_hb(mb, b, "grass", -hw + 0.3, -hw + 0.7, y0, y0 + 0.4, 0.15, 0.55, Color(0.4, 0.62, 0.36), 0, "ext")
	# mái: tôn, ngói, hoặc sân thượng có bồn nước
	var roof := rng.randi() % 3
	if roof == 0:
		_hb(mb, b, "rust", -hw - 0.2, hw + 0.2, top, top + 0.12, -d - 0.2, 0.3, Color(0.6, 0.62, 0.66), 1, "ext")
	elif roof == 1:
		_hb(mb, b, "roof", -hw, hw, top, top + 0.5, -d, 0.0, Color(0.95, 0.6, 0.5), 1, "ext")
	else:
		_hb(mb, b, wall_mat, -hw, hw, top, top + 0.6, -T, 0, col, 1, "ext")
		_hb(mb, b, "paint", -0.5, 0.5, top, top + 1.0, -d + 0.6, -d + 1.6, Color(0.88, 0.9, 0.92), 0, "ext")
	# biển hiệu
	if rng.randf() < 0.4:
		var sc := Color.from_hsv(rng.randf(), rng.randf_range(0.5, 0.85), rng.randf_range(0.55, 0.85))
		_hb(mb, b, "paint", -hw + 0.15, hw - 0.15, 2.9, 3.5, 0.0, 0.1, sc, 0, "ext")
		_add_label(_to_world(b, Vector3(0, 3.2, 0.12)), SIGNS[rng.randi() % SIGNS.size()], float(b.s), clampf(0.12 * w / 4.0, 0.12, 0.3), Color.WHITE)


## Dãy trọ: một dãy phòng nhỏ giống hệt nhau, chung hiên; loại hai tầng có cầu thang ngoài và hành lang phía trước.
func _build_tro(mb: MeshBuilder, b: Dictionary) -> void:
	var w: float = b.w
	var hw := w * 0.5
	var n: int = b.floors
	var fh: float = b.fh
	var off := 2.4 if n == 2 else 1.3            # hiên (và cầu thang) phía trước dãy phòng
	var d: float = b.d
	var col: Color = b.color
	var inner := col.lerp(Color.WHITE, 0.5)
	var rooms := int(round(w / 3.2))
	var rw := w / rooms
	var top := n * fh
	for f in n:
		var y := f * fh
		if f > 0:
			_floor(mb, b, "concrete", -hw, hw, y, -d, -off, Color(0.85, 0.84, 0.8), "ext")
			# hành lang trước các phòng tầng trên + lan can
			_hb(mb, b, "concrete", -hw, hw, y - 0.18, y, -off, -off + 1.25, Color(0.85, 0.84, 0.8), 1, "ext")
			_hb(mb, b, "dark", -hw, hw - 4.9, y + 0.9, y + 0.96, -off + 1.2, -off + 1.25, Color(0.2, 0.2, 0.22), 0, "ext")
			mb.collider(_to_world(b, Vector3(-2.45, y + 0.5, -off + 1.22)), Vector3(w - 4.9, 1.0, 0.06), "metal", 2, _brot(b))
		# tường sau, tường hai đầu, vách ngăn phòng
		_hb(mb, b, "plaster", -hw, hw, y, y + fh, -d, -d + T, col, 1, "ext")
		for k in rooms + 1:
			var px := -hw + k * rw
			_hb(mb, b, "plaster", clampf(px - T * 0.5, -hw, hw - T), clampf(px + T * 0.5, -hw + T, hw), y, y + fh, -d + T, -off, col if (k == 0 or k == rooms) else inner, 1, "ext" if (k == 0 or k == rooms) else "int")
		# mặt trước: mỗi phòng một cửa và một cửa sổ
		var openings: Array = []
		for k in rooms:
			var x0 := -hw + k * rw
			openings.append([x0 + 0.35, x0 + 1.2, y, y + 2.05, false])
			openings.append([x0 + 1.6, x0 + rw - 0.4, y + 1.0, y + 2.0, true])
		_wall_x(mb, b, "plaster", -hw, hw, y, y + fh, -off - T, -off, openings, col, "ext")
		# đồ trong phòng: giường, bàn con, có phòng có đồ để lục
		for k in rooms:
			var xc := -hw + (k + 0.5) * rw
			_hb(mb, b, "wood", xc + 0.25, xc + rw * 0.5 - 0.25, y, y + 0.35, -d + 0.3, -d + 2.2, Color(0.62, 0.52, 0.42), 1, "int")
			_hb(mb, b, "flat", xc + 0.28, xc + rw * 0.5 - 0.28, y + 0.35, y + 0.45, -d + 0.35, -d + 2.15, Color.from_hsv(rng.randf(), 0.3, 0.82), 0, "int")
			if not _rebuilding and rng.randf() < 0.5:
				beds.append(_to_world(b, Vector3(xc + rw * 0.25, y + 0.6, -d + 1.2)))
			if rng.randf() < 0.6:
				_hb(mb, b, "wood", xc - rw * 0.5 + 0.3, xc - rw * 0.5 + 1.0, y, y + 0.65, -d + 0.3, -d + 0.95, Color(0.68, 0.58, 0.44), 1, "int")
				if rng.randf() < 0.6:
					_add_container(["house", "kitchen", "drawer"][rng.randi() % 3], _to_world(b, Vector3(xc - rw * 0.5 + 0.65, y + 0.9, -d + 0.62)), int(b.id), 1 + rng.randi() % 2)
	# mái tôn chìa ra che hiên, cột hiên
	_hb(mb, b, "rust", -hw - 0.3, hw + 0.3, top, top + 0.1, -d - 0.3, -off + 1.4, Color(0.6, 0.66, 0.74), 1, "ext")
	for k in rooms + 1:
		var px2 := clampf(-hw + k * rw, -hw + 0.06, hw - 0.06)
		_hb(mb, b, "concrete", px2 - 0.06, px2 + 0.06, 0, top, -off + 1.12, -off + 1.24, Color(0.85, 0.84, 0.8), 0, "ext")
	if n == 2:
		# cầu thang ngoài ở đầu dãy, chạy dọc mặt trước lên hành lang
		_stair_flight(mb, _to_world(b, Vector3(hw - 4.8, 0.0, -off + 1.8)), _to_world(b, Vector3(hw - 0.9, fh, -off + 1.8)), 1.05, Color(0.8, 0.8, 0.78), "concrete")
		_hb(mb, b, "concrete", hw - 0.9, hw, fh - 0.18, fh, -off + 1.25, -off + 2.35, Color(0.85, 0.84, 0.8), 1, "ext")
		_hb(mb, b, "concrete", hw - 4.9, hw, fh - 0.18, fh, -off + 1.2, -off + 1.3, Color(0.85, 0.84, 0.8), 0, "ext")
	_add_label(_to_world(b, Vector3(-hw + 1.6, top - 0.45, -off + 1.45)), "NHÀ TRỌ", 1.0, 0.34, Color("fff2c0"))


## Một căn nhà tạm: vách tôn/gỗ/gạch, mái tôn, một cửa không cánh, bên trong một cái giường hoặc cái thùng.
func _build_shack(mb: MeshBuilder, b: Dictionary) -> void:
	var w: float = b.w
	var d: float = b.d
	var hw := w * 0.5
	var h := 2.5
	var mat: String = b.get("wall", "rust")
	var col: Color = b.color
	_hb(mb, b, mat, -hw, -hw + T, 0, h, -d, 0, col, 1, "ext")
	_hb(mb, b, mat, hw - T, hw, 0, h, -d, 0, col, 1, "ext")
	var door_x := rng.randf_range(-hw + 0.8, hw - 1.6)
	_wall_x(mb, b, mat, -hw + T, hw - T, 0, h, -T, 0, [[door_x, door_x + 0.95, 0.0, 2.0, false]], col, "ext")
	var back: Array = []
	if b.get("back_door", false):
		back.append([-0.45, 0.45, 0.0, 2.0, false])
	elif rng.randf() < 0.5:
		back.append([-0.5, 0.4, 1.1, 1.9, false])
	_wall_x(mb, b, mat, -hw + T, hw - T, 0, h, -d, -d + T, back, col, "ext")
	_hb(mb, b, "rust", -hw - 0.35, hw + 0.35, h, h + 0.08, -d - 0.35, 0.5, Color(0.62, 0.64, 0.68), 1, "ext")
	if rng.randf() < 0.4:      # tấm bạt, đá chặn mái
		_hb(mb, b, "flat", -hw * 0.6, hw * 0.3, h + 0.08, h + 0.11, -d * 0.8, -d * 0.2, Color.from_hsv(rng.randf(), 0.5, 0.75), 0, "ext")
	_hb(mb, b, "concrete", -0.2, 0.2, h + 0.08, h + 0.3, -d * 0.5 - 0.2, -d * 0.5 + 0.2, Color(0.7, 0.7, 0.7), 0, "ext")
	# đồ đạc
	var bx := hw - T - 0.5 if door_x < 0.0 else -hw + T + 0.5
	_hb(mb, b, "wood", bx - 0.45, bx + 0.45, 0, 0.35, -d + T + 0.1, -d + T + 2.0, Color(0.6, 0.5, 0.4), 1, "int")
	_hb(mb, b, "flat", bx - 0.42, bx + 0.42, 0.35, 0.45, -d + T + 0.15, -d + T + 1.95, Color.from_hsv(rng.randf(), 0.3, 0.8), 0, "int")
	if rng.randf() < 0.55:
		var kx := -bx
		_hb(mb, b, "wood", kx - 0.35, kx + 0.35, 0, 0.6, -d + T + 0.2, -d + T + 0.9, Color(0.66, 0.56, 0.42), 1, "int")
		_add_container("house" if rng.randf() < 0.6 else "kitchen", _to_world(b, Vector3(kx, 0.85, -d + T + 0.55)), int(b.id), 1 + rng.randi() % 2)


# ------------------------------------------------------------------ khối nhà
func _build_block(mb: MeshBuilder, cell: Vector2i) -> void:
	var c := block_center(cell.x, cell.y)
	# Vỉa hè + hẻm sau
	if cell == MALL_BLOCK:
		_slab_holes(mb, "sidewalk", Rect2(c.x - BW * 0.5, c.z - BD * 0.5, BW, BD), [_parking_hole()], 0.0, BASE)
	else:
		mb.box("sidewalk", Vector3(c.x, BASE * 0.5, c.z), Vector3(BW, BASE, BD))
	mb.box("dirt", Vector3(c.x, BASE + 0.005, c.z), Vector3(BW - 2.0, 0.01, BD - 2.0 * (HOUSE_D + 2.0)), Color(0.8, 0.78, 0.72), 0)
	if _rebuilding:
		for spec: Dictionary in block_specs.get(cell, []):
			_build_house(mb, spec)
	else:
		block_specs[cell] = []
		if cell == OFFICE_BLOCK:
			_build_office(mb, c)
			_house_row(mb, cell, c, -1.0)
		elif cell == MALL_BLOCK:
			_build_mall(mb, c)
			_house_row(mb, cell, c, -1.0)
		elif is_commercial(cell):
			_commercial_row(mb, cell, c, 1.0)
			_commercial_row(mb, cell, c, -1.0)
		else:
			_house_row(mb, cell, c, 1.0)
			_house_row(mb, cell, c, -1.0)
	if cell == OFFICE_BLOCK or cell == MALL_BLOCK:
		return
	rng.seed = _seed + cell.x * 31 + cell.y * 17 + 5
	# Rác, thùng hàng trong hẻm
	for k in 5:
		var p := Vector3(c.x + rng.randf_range(-BW * 0.45, BW * 0.45), BASE, c.z + rng.randf_range(-2.0, 2.0))
		var s := rng.randf_range(0.5, 1.0)
		mb.box("wood" if rng.randf() < 0.6 else "rust", p + Vector3(0, s * 0.5, 0), Vector3(s * 1.2, s, s), Color(0.8, 0.75, 0.7), 1, "ext", Basis(Vector3.UP, rng.randf() * TAU))
		if rng.randf() < 0.35:
			_add_container("street", p + Vector3(0, s + 0.25, 0), -1, 2)
	# Khu dân cư quy hoạch kém: người ta cơi nới, xây lấn ra hẻm sau, mỗi nhà một kiểu.
	# Mỗi khối một kiểu, không khối nào giống khối nào: khoảng 4/10 khối hẻm sau thông thoáng, 4/10 khối chỉ lác đác
	# vài chỗ cơi nới ngắn, còn lại mới là hẻm bị lấn dày đặc phải lách qua lách lại.
	var lane_style := rng.randf()
	if not is_commercial(cell):
		var ex := -BW * 0.5 + rng.randf_range(4.0, 8.0)
		var from_side := 1.0 if rng.randf() < 0.5 else -1.0
		if lane_style < 0.4:
			ex = 1e9                          # hẻm thông thoáng
		elif lane_style < 0.8:
			ex += rng.randf_range(0.0, 24.0)
		while ex < BW * 0.5 - 5.0:
			var ew := rng.randf_range(2.4, 4.6)
			var reach := rng.randf_range(9.5, 14.0)                 # thò vào hẻm sâu chừng này (hẻm rộng ~18m)
			if lane_style < 0.8:
				reach = rng.randf_range(2.5, 7.0)
				ew = rng.randf_range(2.0, 6.0)
			var eh := 2.7 if rng.randf() < 0.6 else 5.6
			var z_edge := from_side * 9.6
			var z_tip := z_edge - from_side * reach
			var ez0 := minf(z_edge, z_tip)
			var ez1 := maxf(z_edge, z_tip)
			var emat: String = ["plaster", "brick", "rust", "plaster"][rng.randi() % 4]
			var ecol := Color(HOUSE_COLORS[rng.randi() % HOUSE_COLORS.size()]) if emat == "plaster" else Color(0.82, 0.8, 0.76)
			mb.box(emat, Vector3(c.x + ex, BASE + eh * 0.5, c.z + (ez0 + ez1) * 0.5), Vector3(ew, eh, ez1 - ez0), ecol)
			mb.box("rust", Vector3(c.x + ex, BASE + eh + 0.08, c.z + (ez0 + ez1) * 0.5), Vector3(ew + 0.5, 0.1, ez1 - ez0 + 0.5), Color(0.6, 0.62, 0.66), 0)     # mái tôn
			if not _rebuilding:
				extras.append(Rect2(c.x + ex - ew * 0.5, c.z + ez0, ew, ez1 - ez0))
			# vài thứ bày lấn thêm ở đầu khối: chậu cây, thùng, xe hàng
			var tip := Vector3(c.x + ex + rng.randf_range(-1.0, 1.0), BASE, c.z + z_tip - from_side * rng.randf_range(0.6, 1.4))
			var js := rng.randf_range(0.5, 0.9)
			mb.box("wood" if rng.randf() < 0.5 else "concrete", tip + Vector3(0, js * 0.5, 0), Vector3(js * 1.3, js, js), Color(0.78, 0.72, 0.62), 1, "ext", Basis(Vector3.UP, rng.randf() * TAU))
			if lane_style < 0.8:
				ex += ew + rng.randf_range(12.0, 30.0)
				from_side = 1.0 if rng.randf() < 0.5 else -1.0
			else:
				ex += ew + rng.randf_range(4.5, 8.5)
				from_side = -from_side
		# Hàng quán, mái che lấn ra vỉa hè phía trước
		for kk in 4:
			var sgn := 1.0 if rng.randf() < 0.5 else -1.0
			var sx2 := c.x + rng.randf_range(-BW * 0.42, BW * 0.42)
			var sz2 := c.z + sgn * (BD * 0.5 - rng.randf_range(0.6, 1.0))
			mb.box("wood", Vector3(sx2, BASE + 0.45, sz2), Vector3(rng.randf_range(1.4, 2.4), 0.9, 0.8), Color(0.8, 0.72, 0.6))
			mb.box("flat", Vector3(sx2, BASE + 2.15, sz2), Vector3(2.8, 0.06, 1.6), Color.from_hsv(rng.randf(), 0.55, 0.8), 0)
			for px2: float in [-1.2, 1.2]:
				mb.box("dark", Vector3(sx2 + px2, BASE + 1.07, sz2 + sgn * 0.6), Vector3(0.05, 2.15, 0.05), Color(0.2, 0.2, 0.22), 0)
	# Nhiều hẻm sau còn là ngõ cụt (bị tường bịt một đầu), có khi bịt cả giữa hẻm.
	if not is_commercial(cell):
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		if rng.randf() < 0.6:
			mb.box("brick", Vector3(c.x + side * (BW * 0.5 - 0.6), BASE + 1.4, c.z), Vector3(0.3, 2.8, 20.0), Color(0.85, 0.8, 0.75))
		if rng.randf() < 0.35:
			var wx := c.x + rng.randf_range(-12.0, 12.0)
			mb.box("brick", Vector3(wx, BASE + 1.3, c.z - 4.6), Vector3(0.3, 2.6, 10.8), Color(0.85, 0.8, 0.75))


## Dãy nhà dân: lô rộng hẹp khác nhau (4-7,5m), xen hẻm nhỏ, thỉnh thoảng một chung cư; một số nhà đã hỏng sẵn.
func _house_row(mb: MeshBuilder, cell: Vector2i, c: Vector3, s: float) -> void:
	var half := BW * 0.5 - 0.5
	var x := -half
	var towers := 0
	var special := ""
	if cell == HOME_BLOCK and s > 0.0:
		special = "home"
	elif cell == TU_BLOCK and s < 0.0:
		special = "tu"
	while x < half - 3.9:
		var w: float = [4.0, 5.0, 5.0, 5.0, 6.0, 7.5][rng.randi() % 6]
		var is_special := special != "" and x <= -2.5 and x + w > -2.5
		if is_special:
			x = -2.5
			w = 5.0
		w = minf(w, half - x)
		if w < 3.9:
			break
		if not is_special and rng.randf() < 0.1:
			x += 2.2 if rng.randf() < 0.6 else 5.0      # hẻm nhỏ thông ra sau, hoặc một lô đất trống
			continue
		var b := {
			"id": buildings.size(), "kind": "house", "shop": "", "s": s, "w": w, "d": [HOUSE_D, HOUSE_D, 12.0, 13.0, 15.0][rng.randi() % 5], "fh": FH,
			"origin": Vector3(c.x + s * (x + w * 0.5), BASE, c.z + s * (BD * 0.5 - 2.0)),
			"floors": [1, 2, 2, 3, 3, 3, 4, 4, 5][rng.randi() % 9],
			"color": Color(HOUSE_COLORS[rng.randi() % HOUSE_COLORS.size()]),
			"roof_access": rng.randf() < 0.45, "name": "Nhà dân", "cell": cell, "seed": rng.randi(),
			"back_door": rng.randf() < 0.4,
		}
		if is_special and special == "home":
			b.kind = "home"
			b.name = "Nhà của bạn"
			b.floors = 3
			b.d = HOUSE_D
			b.color = Color("e8d9a8")
			b.back_door = true
			special = ""
		elif is_special:
			b.kind = "tu"
			b.name = "Nhà ông Tư"
			b.floors = 2
			b.d = HOUSE_D
			b.back_door = true
			special = ""
		elif towers == 0 and special == "" and x + 15.0 < half and rng.randf() < 0.035:
			towers += 1
			w = 15.0
			b.kind = "tower"
			b.name = "Chung cư"
			b.w = w
			b.d = HOUSE_D
			b.floors = 9 + rng.randi() % 6
			b.roof_access = true
			b.back_door = false
			b.color = Color(["b8c2cc", "c9c0b0", "a9b4bd", "d0c8bc"][rng.randi() % 4])
			b.origin = Vector3(c.x + s * (x + w * 0.5), BASE, c.z + s * (BD * 0.5 - 2.0))
		elif rng.randf() < 0.12:
			# khu dân cư: hàng quán ít, nhỏ lẻ
			b.kind = "shop"
			b.shop = _pick_shop()
			b.name = SHOPS[b.shop].name
			b.d = HOUSE_D
			b.w = maxf(w, 5.0)
			b.back_door = false
		# Xây lấn chiếm: nhà thì thò ra vỉa hè, nhà thì lùi vào, mặt phố không còn thẳng hàng.
		if b.kind == "house" or b.kind == "shop":
			var setback := rng.randf_range(-1.6, 1.3)
			b.origin = (b.origin as Vector3) + Vector3(0, 0, s * setback)
		# Phần lớn nhà dân đóng cửa im ỉm: chỉ là mặt tiền, không vào được (đỡ nặng máy, đỡ phải lục từng nhà).
		if b.kind == "house" and rng.randf() < 0.6:
			b.kind = "closed"
			b.name = "Nhà đóng cửa"
		# Một số nhà đã hỏng sẵn khi bạn tới
		if b.kind in ["house", "closed"] and rng.randf() < 0.15:
			var roll := rng.randf()
			b["damage"] = "top" if roll < 0.4 else ("front" if roll < 0.7 else "collapse")
			b["cut"] = 1 + rng.randi() % maxi(1, int(b.floors) / 2)
			if b.damage == "collapse":
				b["ruined"] = true
		(block_specs[cell] as Array).append(b)
		_build_house(mb, b)
		x += float(b.w)


## Dãy công trình lớn của khu thương mại: siêu thị, nhà hàng lớn, cao ốc.
func _commercial_row(mb: MeshBuilder, cell: Vector2i, c: Vector3, s: float) -> void:
	var half := BW * 0.5 - 1.0
	var x := -half
	var kinds := ["super", "restaurant", "tower", "tower", "restaurant", "bigshop"]
	while x < half - 12.0:
		var kind: String = kinds[rng.randi() % kinds.size()]
		var w := 26.0
		var b := {
			"id": buildings.size(), "kind": kind, "shop": "", "s": s, "w": w, "d": 18.0, "fh": 4.0,
			"origin": Vector3.ZERO, "floors": 2, "color": Color(["cfd6dc", "d8cfc0", "b9c6cf", "e0d6c8"][rng.randi() % 4]),
			"roof_access": true, "name": "", "cell": cell, "seed": rng.randi(), "back_door": true,
		}
		match kind:
			"super":
				b.name = "Siêu thị"
				b.w = minf(30.0, half - x)
				b.d = 19.0
				b.floors = 1
				b.fh = 5.0
				b.color = Color("e6e0d2")
			"restaurant":
				b.name = "Nhà hàng"
				b.w = minf(22.0, half - x)
				b.d = 18.0
				b.floors = 2
				b.color = Color("e2c9a6")
			"tower":
				b.name = "Cao ốc" if rng.randf() < 0.6 else "Khách sạn"
				b.w = minf(18.0, half - x)
				b.d = 16.0
				b.fh = FH
				b.floors = 12 + rng.randi() % 9
				b.back_door = false
			"bigshop":
				b.kind = "shop"
				b.shop = _pick_shop()
				b.name = SHOPS[b.shop].name
				b.w = minf(10.0, half - x)
				b.d = HOUSE_D
				b.fh = FH
				b.floors = 2 + rng.randi() % 3
				b.back_door = false
		if float(b.w) < 9.0:
			break
		b.origin = Vector3(c.x + s * (x + float(b.w) * 0.5), BASE, c.z + s * (BD * 0.5 - 2.0))
		(block_specs[cell] as Array).append(b)
		_build_house(mb, b)
		x += float(b.w) + 1.5


func _build_mall(mb: MeshBuilder, c: Vector3) -> void:
	var b := {
		"id": buildings.size(), "kind": "mall", "shop": "", "s": 1.0, "w": 46.0, "d": 29.0, "fh": 4.4,
		"origin": Vector3(c.x, BASE, c.z + BD * 0.5 - 2.0), "floors": 3, "color": Color("d8d2c4"),
		"roof_access": true, "name": "Trung tâm thương mại", "cell": MALL_BLOCK, "seed": rng.randi(),
	}
	(block_specs[MALL_BLOCK] as Array).append(b)
	_build_house(mb, b)


func _pick_shop() -> String:
	# Bảo đảm luôn có đủ nhà thuốc.
	var pharm := 0
	var shops := 0
	for b in buildings:
		if b.kind == "shop":
			shops += 1
			if b.shop == "pharmacy":
				pharm += 1
	if shops >= 4 and pharm * 6 < shops:
		return "pharmacy"
	var total := 0.0
	for k: String in SHOPS:
		total += SHOPS[k].weight
	var r := rng.randf() * total
	for k: String in SHOPS:
		r -= SHOPS[k].weight
		if r <= 0.0:
			return k
	return "grocery"


func _build_office(mb: MeshBuilder, c: Vector3) -> void:
	var b := {
		"id": buildings.size(), "kind": "office", "shop": "", "s": 1.0, "w": 26.0, "d": 20.0, "fh": 3.6,
		"origin": Vector3(c.x, BASE, c.z + BD * 0.5 - 2.0), "floors": 4, "color": Color("aab4bd"),
		"roof_access": true, "name": "Văn phòng", "cell": OFFICE_BLOCK, "seed": rng.randi(),
	}
	(block_specs[OFFICE_BLOCK] as Array).append(b)
	_build_house(mb, b)
	start_pos = _to_world(b, Vector3(-4.0, 0.05, -4.5))


# Đổi toạ độ trong nhà (x ngang, y từ sàn trệt, z=0 ở mặt tiền, âm dần vào trong) ra thế giới.
func _to_world(b: Dictionary, p: Vector3) -> Vector3:
	var o: Vector3 = b.origin
	if b.has("yaw"):
		return o + Basis(Vector3.UP, float(b.yaw)) * p        # nhà xoay tự do (xóm ngõ)
	var s: float = b.s
	return Vector3(o.x + s * p.x, o.y + p.y, o.z + s * p.z)


## Hướng xoay của ngôi nhà (nhà trong khu tập thể xoay tự do theo con ngõ).
func _brot(b: Dictionary) -> Basis:
	return Basis(Vector3.UP, float(b.yaw)) if b.has("yaw") else Basis.IDENTITY


func _hb(mb: MeshBuilder, b: Dictionary, mat: String, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, col := Color.WHITE, solid := 1, layer := "int", surface := "") -> void:
	if x1 - x0 < 0.01 or y1 - y0 < 0.005 or z1 - z0 < 0.01:
		return
	var center := _to_world(b, Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5))
	mb.box(mat, center, Vector3(x1 - x0, y1 - y0, z1 - z0), col, solid, layer, Basis(Vector3.UP, float(b.yaw)) if b.has("yaw") else Basis.IDENTITY, surface)


## Sàn có khoét các lỗ (giếng thang cuốn...): holes là các Rect2(x0, z0, rộng, sâu) theo toạ độ nhà, không chồng nhau theo x.
func _floor_h(mb: MeshBuilder, b: Dictionary, mat: String, x0: float, x1: float, y: float, z0: float, z1: float, col: Color, layer: String, holes: Array) -> void:
	if holes.is_empty():
		_floor(mb, b, mat, x0, x1, y, z0, z1, col, layer)
		return
	var xs: Array[float] = [x0, x1]
	for h: Rect2 in holes:
		xs.append(clampf(h.position.x, x0, x1))
		xs.append(clampf(h.end.x, x0, x1))
	xs.sort()
	for i in xs.size() - 1:
		var a := xs[i]
		var bx := xs[i + 1]
		if bx - a < 0.01:
			continue
		var zs: Array = [[z0, z1]]
		for h2: Rect2 in holes:
			if h2.position.x < bx - 0.001 and h2.end.x > a + 0.001:
				var nz: Array = []
				for seg: Array in zs:
					if h2.end.y <= seg[0] or h2.position.y >= seg[1]:
						nz.append(seg)
					else:
						if h2.position.y > seg[0]:
							nz.append([seg[0], h2.position.y])
						if h2.end.y < seg[1]:
							nz.append([h2.end.y, seg[1]])
				zs = nz
		for seg2: Array in zs:
			_floor(mb, b, mat, a, bx, y, seg2[0], seg2[1], col, layer)


## Tường ngăn phòng chạy dọc trục x (đặt ở z = zc), khoét cửa đi rộng 1,2m tại các x trong `doors`.
func _pwall_x(mb: MeshBuilder, b: Dictionary, y: float, fh: float, x0: float, x1: float, zc: float, doors: Array, col: Color) -> void:
	var cuts: Array = []
	for dx: float in doors:
		cuts.append([dx - 0.6, dx + 0.6])
	cuts.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
	var t0 := x0
	for c: Array in cuts:
		_hb(mb, b, "plaster", t0, maxf(t0, c[0]), y, y + fh - 0.2, zc - 0.06, zc + 0.06, col, 1)
		_hb(mb, b, "plaster", c[0], c[1], y + 2.2, y + fh - 0.2, zc - 0.06, zc + 0.06, col, 1)
		t0 = c[1]
	_hb(mb, b, "plaster", t0, x1, y, y + fh - 0.2, zc - 0.06, zc + 0.06, col, 1)


## Tường ngăn phòng chạy dọc trục z (đặt ở x = xc), khoét cửa tại các z trong `doors`.
func _pwall_z(mb: MeshBuilder, b: Dictionary, y: float, fh: float, z0: float, z1: float, xc: float, doors: Array, col: Color) -> void:
	var cuts: Array = []
	for dz: float in doors:
		cuts.append([dz - 0.6, dz + 0.6])
	cuts.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
	var t0 := z0
	for c: Array in cuts:
		_hb(mb, b, "plaster", xc - 0.06, xc + 0.06, y, y + fh - 0.2, t0, maxf(t0, c[0]), col, 1)
		_hb(mb, b, "plaster", xc - 0.06, xc + 0.06, y + 2.2, y + fh - 0.2, c[0], c[1], col, 1)
		t0 = c[1]
	_hb(mb, b, "plaster", xc - 0.06, xc + 0.06, y, y + fh - 0.2, t0, z1, col, 1)


## Một mảng sàn dày 0,2m kèm lớp trần sơn trắng ở mặt dưới (khoét ô cầu thang thì trần cũng khoét theo).
func _floor(mb: MeshBuilder, b: Dictionary, mat: String, x0: float, x1: float, y: float, z0: float, z1: float, col: Color, layer: String) -> void:
	_hb(mb, b, mat, x0, x1, y - 0.2, y, z0, z1, col, 1, layer)
	_hb(mb, b, "paint", x0, x1, y - 0.215, y - 0.2, z0, z1, Color(0.96, 0.95, 0.92), 0)


## Tường chạy theo trục X tại z∈[z0,z1], có các ô trống. Mỗi ô: [xa, xb, ya, yb, có_kính].
func _wall_x(mb: MeshBuilder, b: Dictionary, mat: String, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, openings: Array, col: Color, layer: String) -> void:
	openings.sort_custom(func(a: Array, c2: Array) -> bool: return a[0] < c2[0])
	var x := x0
	for o: Array in openings:
		_hb(mb, b, mat, x, o[0], y0, y1, z0, z1, col, 1, layer)
		_hb(mb, b, mat, o[0], o[1], y0, o[2], z0, z1, col, 1, layer)
		_hb(mb, b, mat, o[0], o[1], o[3], y1, z0, z1, col, 1, layer)
		if o[4]:
			var zm := (z0 + z1) * 0.5
			_glass(mb, b, o[0], o[1], o[2], o[3], zm, layer)
			_hb(mb, b, "dark", o[0], o[1], o[2] - 0.06, o[2], z0 - 0.04, z1 + 0.04, Color(0.25, 0.25, 0.27), 0, layer)
		x = o[1]
	_hb(mb, b, mat, x, x1, y0, y1, z0, z1, col, 1, layer)


## Một ô kính cửa sổ. Kính đập vỡ được: ô đã vỡ thì bỏ trống, rơi vài mảnh xuống sàn.
func _glass(mb: MeshBuilder, b: Dictionary, x0: float, x1: float, y0: float, y1: float, zm: float, layer: String) -> void:
	var idx: int = b.get("_pane", 0)
	b["_pane"] = idx + 1
	var center := _to_world(b, Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, zm))
	if (b.get("broken", []) as Array).has(idx):
		for k in 3:
			var sp := _to_world(b, Vector3(lerpf(x0, x1, 0.2 + k * 0.3), y0 + 0.02, zm + (0.18 if k % 2 == 0 else -0.2)))
			mb.box("glass", sp, Vector3(0.22, 0.02, 0.16), Color.WHITE, 0, layer, Basis(Vector3.UP, k * 1.3))
		return
	_hb(mb, b, "glass", x0, x1, y0, y1, zm - 0.02, zm + 0.02, Color.WHITE, 2, layer)
	var cell: Vector2i = b.get("cell", Vector2i(-1, -1))
	if not panes.has(cell):
		panes[cell] = []
	var yw: float = b.get("yaw", 0.0)
	var hx := (x1 - x0) * 0.5
	var ext := Vector3(absf(cos(yw)) * hx + absf(sin(yw)) * 0.25 + 0.1, (y1 - y0) * 0.5 + 0.1, absf(sin(yw)) * hx + absf(cos(yw)) * 0.25 + 0.1)
	(panes[cell] as Array).append({"b": int(b.get("id", -1)), "i": idx, "box": AABB(center - ext, ext * 2.0)})


## Ô kính ở điểm này (hoặc {} nếu không có).
func pane_at(p: Vector3) -> Dictionary:
	for cell: Vector2i in panes:
		for pane: Dictionary in panes[cell]:
			if (pane.box as AABB).has_point(p):
				return pane
	return {}


## Đập vỡ một ô kính rồi dựng lại khối nhà chứa nó.
func break_glass(id: int, idx: int) -> void:
	if id < 0 or id >= buildings.size():
		return
	var b: Dictionary = buildings[id]
	var br: Array = b.get("broken", [])
	if br.has(idx):
		return
	br.append(idx)
	b["broken"] = br
	var cell: Vector2i = b.cell
	var old: Node = block_nodes.get(cell)
	if old:
		old.queue_free()
	_rebuilding = true
	_build_cell(cell)
	_rebuilding = false


func _build_house(mb: MeshBuilder, b: Dictionary) -> void:
	b["_pane"] = 0
	_label_yaw = float(b.yaw) if b.has("yaw") else NAN
	var w: float = b.w
	var d: float = b.d
	var fh: float = b.fh
	var n: int = b.floors
	rng.seed = int(b.seed)
	var dmg: String = b.get("damage", "")
	if dmg == "top":
		n = maxi(1, n - int(b.get("cut", 1)))
	var roof_access: bool = b.roof_access and dmg != "top"
	var hw := w * 0.5
	var col: Color = b.color
	var inner := col.lerp(Color.WHITE, 0.55)
	var top := n * fh
	var is_big: bool = b.kind in BIG_KINDS
	var is_shop: bool = b.kind == "shop"
	var o: Vector3 = b.origin
	var s: float = b.s
	var xa := minf(o.x - s * hw, o.x + s * hw)
	var za := minf(o.z, o.z - s * d)
	b["rect"] = Rect2(xa, za, w, d)
	if b.has("yaw"):
		var poly := PackedVector2Array()
		var rr := Rect2()
		for corner: Vector3 in [Vector3(-hw, 0, 0), Vector3(hw, 0, 0), Vector3(hw, 0, -d), Vector3(-hw, 0, -d)]:
			var wc := _to_world(b, corner)
			poly.append(Vector2(wc.x, wc.z))
			rr = Rect2(wc.x, wc.z, 0, 0) if poly.size() == 1 else rr.expand(Vector2(wc.x, wc.z))
		b["poly"] = poly
		b["rect"] = rr
	b["door"] = _to_world(b, Vector3(0, 0, 1.0))
	# Nhà vướng cầu cạn đường sắt, ga, cầu thang lên ga: đã bị giải toả, không xây.
	if not (b.kind in ["home", "tu", "office", "mall"]) and not b.get("landmark", false) and rail.blocks(b.rect):
		return
	if not _rebuilding:
		buildings.append(b)
	if dmg == "collapse":
		_ruin_mound(mb, b)
		return
	if b.kind == "shack":
		_build_shack(mb, b)
		return
	if b.kind == "tro":
		_build_tro(mb, b)
		return
	if b.kind == "closed":
		_build_closed(mb, b, n)
		return

	var wall_mat := "brick" if (not is_big and rng.randf() < 0.18) else "plaster"
	var parapet := 0.9 if roof_access else 0.35
	# Tường bên + tường sau (cao tới lan can mái)
	_hb(mb, b, wall_mat, -hw, -hw + T, 0, top + parapet, -d, 0, col, 1, "ext")
	_hb(mb, b, wall_mat, hw - T, hw, 0, top + parapet, -d, 0, col, 1, "ext")
	if is_big:
		for k in n:
			var wins := []
			var xw := -hw + 2.0
			while xw < hw - 3.0:
				wins.append([xw, xw + 2.2, k * fh + 1.0, k * fh + 2.5, true])
				xw += 3.6
			_wall_x(mb, b, wall_mat, -hw + T, hw - T, k * fh, (k + 1) * fh, -d, -d + T, wins, col, "ext")
		_hb(mb, b, wall_mat, -hw + T, hw - T, top, top + parapet, -d, -d + T, col, 1, "ext")
	else:
		if b.get("back_door", false):
			# cửa sau thông ra hẻm
			_wall_x(mb, b, wall_mat, -hw + T, hw - T, 0, fh, -d, -d + T, [[-0.5, 0.5, 0.0, 2.2, false]], col, "ext")
			_hb(mb, b, wall_mat, -hw + T, hw - T, fh, top + parapet, -d, -d + T, col, 1, "ext")
		else:
			_hb(mb, b, wall_mat, -hw + T, hw - T, 0, top + parapet, -d, -d + T, col, 1, "ext")

	# Mặt tiền từng tầng
	for k in n:
		var y0 := k * fh
		var y1 := (k + 1) * fh
		var ops := []
		if k == 0:
			if is_big:
				ops.append([-1.6, 1.6, 0.0, 2.8, false])
				# vách kính từ sàn tới trần hai bên cửa, nhìn ra hồ
				var xl := -1.9 - 3.2
				while xl > -hw + 0.4:
					ops.append([xl, xl + 3.2, 0.1, 3.3, true])
					xl -= 3.4
				var xr := 1.9
				while xr + 3.2 < hw - 0.4:
					ops.append([xr, xr + 3.2, 0.1, 3.3, true])
					xr += 3.4
			elif is_shop:
				ops.append([-hw + 0.5, hw - 0.5, 0.0, 2.8, false])
			else:
				ops.append([-1.7, -0.6, 0.0, 2.3, false])
				ops.append([0.3, 1.9, 1.0, 2.2, true])
		else:
			if is_big:
				var xw3 := -hw + 1.5
				while xw3 < hw - 3.0:
					ops.append([xw3, xw3 + 3.2, y0 + 0.1, y0 + 3.3, true])
					xw3 += 3.4
			else:
				ops.append([-1.3, 1.3, y0 + 0.9, y0 + 2.4, true])
		if not (dmg == "front" and k >= 1):
			_wall_x(mb, b, wall_mat, -hw + T, hw - T, y0, y1, -T, 0, ops, col, "ext")
		# Ban công / mái che nhô ra
		if not is_big and k >= 1 and (b.id + k) % 3 != 0 and dmg != "front":
			_hb(mb, b, "concrete", -hw, hw, y0 - 0.12, y0, 0, 0.7, col.darkened(0.1), 1, "ext")
			_hb(mb, b, "dark", -hw, hw, y0 + 0.74, y0 + 0.8, 0.64, 0.7, Color(0.16, 0.16, 0.18), 2, "ext")
			_hb(mb, b, "dark", -hw, hw, y0 + 0.36, y0 + 0.4, 0.65, 0.69, Color(0.16, 0.16, 0.18), 0, "ext")
			var px := -hw + 0.05
			while px < hw:
				_hb(mb, b, "dark", px - 0.02, px + 0.02, y0, y0 + 0.76, 0.65, 0.69, Color(0.16, 0.16, 0.18), 0, "ext")
				px += 0.35
			mb.collider(_to_world(b, Vector3(0, y0 + 0.4, 0.67)), Vector3(hw * 2.0, 0.8, 0.06), "metal", 2, _brot(b))
	_hb(mb, b, wall_mat, -hw + T, hw - T, top, top + parapet, -T, 0, col, 1, "ext")

	# Biển hiệu + cửa cuốn + mái hiên cho cửa hàng
	if is_shop:
		var sc := Color(SHOPS[b.shop].color)
		_hb(mb, b, "emit", -hw + 0.2, hw - 0.2, 2.85, 3.35, 0.0, 0.12, sc, 0, "ext")
		_hb(mb, b, "metal", -hw + 0.4, hw - 0.4, 2.55, 2.8, -0.1, 0.05, Color(0.5, 0.5, 0.52), 0, "ext")
		_hb(mb, b, "metal", -hw, hw, 2.82, 2.86, 0.0, 1.3, sc.darkened(0.2), 0, "ext")
		_add_label(_to_world(b, Vector3(0, 3.1, 0.14)), SHOPS[b.shop].name, s, 0.42, Color.WHITE)
	elif b.kind == "mall":
		_hb(mb, b, "emit", -12.0, 12.0, 4.6, 6.0, 0.0, 0.14, Color("c8302a"), 0, "ext")
		_add_label(_to_world(b, Vector3(0, 5.3, 0.17)), "TRUNG TÂM THƯƠNG MẠI", s, 0.9, Color.WHITE)
	elif b.kind == "tower":
		_add_label(_to_world(b, Vector3(0, 3.0, 0.03)), str(b.name).to_upper(), s, 0.3, Color(0.15, 0.15, 0.15))
	elif b.kind == "super" or b.kind == "restaurant":
		var sc2 := Color("2f9a57") if b.kind == "super" else Color("c8302a")
		_hb(mb, b, "emit", -hw * 0.6, hw * 0.6, fh - 1.0, fh + 0.1, 0.0, 0.14, sc2, 0, "ext")
		_add_label(_to_world(b, Vector3(0, fh - 0.45, 0.17)), "SIÊU THỊ" if b.kind == "super" else "NHÀ HÀNG", s, 0.8, Color.WHITE)
	elif b.kind == "home" or b.kind == "tu":
		_add_label(_to_world(b, Vector3(0.6, 2.6, 0.03)), "SỐ 12" if b.kind == "home" else "ÔNG TƯ", s, 0.22, Color(0.15, 0.15, 0.15))

	# Sàn trệt (lát gạch) + các tầng + mái
	if b.kind == "mall":
		# sàn trệt chừa lỗ dốc xuống tầng hầm để xe
		_hb(mb, b, "concrete", -hw + 5.2, hw - T, 0.0, 0.012, -d + T, -T, Color(0.9, 0.9, 0.88), 0)
		_hb(mb, b, "concrete", -hw + T, -hw + 5.2, 0.0, 0.012, -d + T, -14.2, Color(0.9, 0.9, 0.88), 0)
		_hb(mb, b, "concrete", -hw + T, -hw + 5.2, 0.0, 0.012, -3.8, -T, Color(0.9, 0.9, 0.88), 0)
		_build_parking(mb, b)
	else:
		_hb(mb, b, "concrete" if is_big else "tile", -hw + T, hw - T, 0.0, 0.012, -d + T, -T, Color(0.9, 0.9, 0.88) if is_big else Color(0.95, 0.93, 0.9), 0)
	var flights := n if roof_access else n - 1
	var well_w := 1.15 if not is_big else 1.6
	var well_z0 := -d + 1.2      # đỉnh cầu thang (sát tường sau)
	var well_z1 := -d + 5.4      # chân cầu thang
	for k in range(1, n + 1):
		var y := k * fh
		if dmg == "top" and k == n:
			continue        # các tầng trên đã bị giật mất: không còn mái
		var is_roof := k == n
		var has_hole := (k - 1) < flights
		var right := (k - 1) % 2 == 0
		var mat := "roof" if (is_roof and not roof_access) else ("concrete" if is_roof else ("wood" if (b.id + k) % 3 != 0 else "tile"))
		var layer := "ext" if is_roof else "int"
		var scol := Color.WHITE if not is_roof else Color(0.85, 0.85, 0.85)
		var fholes: Array = []
		if b.has("holes") and not is_roof:
			fholes = (b.holes as Array).duplicate()
		if not has_hole:
			_floor_h(mb, b, mat, -hw + T, hw - T, y, -d + T, -T, scol, layer, fholes)
		else:
			var hx0 := (hw - T - well_w) if right else (-hw + T)
			var hx1 := (hw - T) if right else (-hw + T + well_w)
			_floor_h(mb, b, mat, -hw + T, hw - T, y, well_z1, -T, scol, layer, fholes)
			_floor_h(mb, b, mat, -hw + T, hw - T, y, -d + T, well_z0, scol, layer, fholes)
			_floor(mb, b, mat, -hw + T, hx0, y, well_z0, well_z1, scol, layer)
			_floor(mb, b, mat, hx1, hw - T, y, well_z0, well_z1, scol, layer)
			# Lan can quanh ô cầu thang
			var rail_x := hx0 if right else hx1
			_hb(mb, b, "dark", rail_x - 0.03, rail_x + 0.03, y, y + 0.95, well_z0, well_z1, Color(0.2, 0.2, 0.22), 2, layer)
			_hb(mb, b, "dark", hx0, hx1, y, y + 0.95, well_z1 - 0.03, well_z1 + 0.03, Color(0.2, 0.2, 0.22), 2, layer)
	# Cầu thang: bậc để nhìn, một mặt dốc để đi cho êm.
	for k in flights:
		var right2 := k % 2 == 0
		var sx0 := (hw - T - well_w) if right2 else (-hw + T)
		var sx1 := sx0 + well_w
		var yb := k * fh
		var run := (well_z1 - 0.2) - well_z0
		var steps := 17
		for i in steps:
			var z1 := well_z1 - 0.2 - run * i / steps
			var z0 := z1 - run / steps
			_hb(mb, b, "concrete", sx0, sx1, yb + fh * i / steps, yb + fh * (i + 1) / steps, z0, z1, Color(0.82, 0.8, 0.78), 0)
		var ang := atan2(fh, run)
		var length := sqrt(fh * fh + run * run)
		var rot := _brot(b) * Basis(Vector3(1, 0, 0), s * ang)
		var mid := _to_world(b, Vector3((sx0 + sx1) * 0.5, yb + fh * 0.5, (well_z0 + well_z1 - 0.2) * 0.5))
		mb.collider(mid - (rot * Vector3.UP) * 0.1 + Vector3(0, 0.1, 0), Vector3(well_w, 0.2, length), "concrete", 1, rot)

	# Mái dốc lợp ngói cho một số nhà không có lối lên mái
	if not roof_access and not is_big and dmg == "" and b.id % 3 == 0:
		var ang := deg_to_rad(24.0)
		var half := hw / cos(ang)
		for sg: float in [-1.0, 1.0]:
			var rot := _brot(b) * Basis(Vector3(0, 0, 1), -sg * ang * s)
			var mid := _to_world(b, Vector3(sg * hw * 0.5, top + 0.35 + tan(ang) * hw * 0.5, -d * 0.5))
			mb.box("roof", mid, Vector3(half + 0.2, 0.14, d + 0.6), Color(0.95, 0.6, 0.5), 1, "ext", rot, "tile")
	if dmg == "top":
		# mép tường nham nhở + gạch vụn trên sàn tầng cụt
		for m in 14:
			var px := rng.randf_range(-hw, hw)
			var on_side := rng.randf() < 0.6
			var sx := (hw - T * 0.5) * (1.0 if rng.randf() < 0.5 else -1.0)
			var hgt := rng.randf_range(0.4, 2.4)
			if on_side:
				var pz := rng.randf_range(-d, 0.0)
				_hb(mb, b, wall_mat, sx - T * 0.5, sx + T * 0.5, top, top + hgt, pz - 0.6, pz + 0.6, col, 1, "ext")
			else:
				_hb(mb, b, wall_mat, px - 0.6, px + 0.6, top, top + hgt, -d, -d + T, col, 1, "ext")
		_rubble(mb, _to_world(b, Vector3(0, top - fh + 0.0, -d * 0.5)), Vector2(hw - 0.5, d * 0.5 - 0.6), 10, 0.9)
	elif dmg == "front":
		_rubble(mb, _to_world(b, Vector3(0, 0.0, 2.2)), Vector2(hw, 2.0), 12, 1.2)
	_furnish(mb, b, well_w, well_z1)


## Gạch đá vụn rải quanh một điểm (half: nửa kích thước vùng rải theo x và z).
func _rubble(mb: MeshBuilder, center: Vector3, half: Vector2, count: int, max_h: float) -> void:
	for m in count:
		var sz := Vector3(rng.randf_range(0.4, 1.6), rng.randf_range(0.2, max_h), rng.randf_range(0.4, 1.4))
		var q := center + Vector3(rng.randf_range(-half.x, half.x), sz.y * 0.5, rng.randf_range(-half.y, half.y))
		mb.box("concrete" if rng.randf() < 0.55 else "brick", q, sz, Color(0.78, 0.75, 0.7), 1, "ext", Basis.from_euler(Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.2, 0.2))))


## Ngôi nhà sập hẳn: một đống đổ nát cao, trèo lên được.
func _ruin_mound(mb: MeshBuilder, b: Dictionary) -> void:
	var hw: float = b.w * 0.5
	var d: float = b.d
	var col: Color = b.color
	if b.kind == "home":
		_home_ruin(mb, b, hw, d, col)
		return
	# các bậc đổ nát thoải dần để trèo lên
	for step in 4:
		var k := 1.0 - step * 0.22
		mb.collider(_to_world(b, Vector3(0, 0.22 + step * 0.45, -d * 0.5)), Vector3(hw * 2.0 * k + 1.0, 0.45, d * k + 1.5), "concrete", 1, _brot(b))
	for m in 34:
		var sz := Vector3(rng.randf_range(0.8, 3.0), rng.randf_range(0.25, 0.9), rng.randf_range(0.8, 2.8))
		var r := rng.randf()
		var q := _to_world(b, Vector3(rng.randf_range(-hw - 0.5, hw + 0.5) * (1.0 - r * 0.5), 0.2 + r * 1.7, -d * 0.5 + rng.randf_range(-d * 0.5, d * 0.5 + 1.0) * (1.0 - r * 0.5)))
		var mat := "concrete" if rng.randf() < 0.5 else ("brick" if rng.randf() < 0.5 else "plaster")
		mb.box(mat, q, sz, col if mat == "plaster" else Color(0.78, 0.75, 0.7), 0, "ext", Basis.from_euler(Vector3(rng.randf_range(-0.35, 0.35), rng.randf() * TAU, rng.randf_range(-0.35, 0.35))))
	# vài mảng tường còn đứng
	for m2 in 3:
		var hgt := rng.randf_range(1.5, 4.5)
		var sx := (hw - T) * (1.0 if m2 % 2 == 0 else -1.0)
		var pz := rng.randf_range(-d + 1.0, -1.0)
		_hb(mb, b, "plaster", sx - T, sx + T, 0, hgt, pz - 1.2, pz + 1.2, col, 1, "ext")


func _furnish(mb: MeshBuilder, b: Dictionary, well_w: float, well_z1: float) -> void:
	var hw: float = b.w * 0.5
	var d: float = b.d
	var fh: float = b.fh
	var n: int = b.floors
	var wood := Color(0.85, 0.72, 0.55)
	match b.kind:
		"shop":
			var info: Dictionary = SHOPS[b.shop]
			var tables: Array = info.tables
			# Kệ hàng dọc hai bên + quầy thu ngân
			var zc := -2.2
			var idx := 0
			while zc > well_z1 + 1.2:
				for side: float in [-1.0, 1.0]:
					var x := side * (hw - T - 0.3)
					# kệ: tấm lưng + các tầng gỗ + hàng hoá nhiều màu
					mb.collider(_to_world(b, Vector3(x, 0.95, zc)), Vector3(0.5, 1.9, 1.8), "wood", 1, _brot(b))
					_hb(mb, b, "paint", x + side * 0.2, x + side * 0.25, 0, 1.9, zc - 0.9, zc + 0.9, Color(0.9, 0.88, 0.84), 0)
					for sh in 4:
						_hb(mb, b, "wood", x - 0.25, x + 0.25, 0.1 + sh * 0.5, 0.14 + sh * 0.5, zc - 0.9, zc + 0.9, Color(0.9, 0.82, 0.7), 0)
					var lay := _shelf_layout(b, x, 0.0, zc, 0.85, [0.145, 0.645, 1.145, 1.645], [-side * 0.04])
					_add_container(tables[idx % tables.size()], _to_world(b, Vector3(x, 1.1, zc)), b.id, 6 + rng.randi() % 5, true, {"shelf": lay})
					idx += 1
				zc -= 2.4
			_hb(mb, b, "wood", -0.4, 1.0, 0, 1.0, well_z1 + 0.2, well_z1 + 0.8, wood, 1)
			_add_container("register", _to_world(b, Vector3(0.3, 1.1, well_z1 + 0.5)), b.id, 1, true)
			_add_npc("owner", _to_world(b, Vector3(0.3, 0.0, well_z1 - 0.3)), b.id, 0.0 if b.s > 0 else PI)
		"mall":
			# Ba tầng, mỗi tầng một nhóm hàng; quầy thu ngân ở cửa.
			var zones := [["g_noodle", "g_drink", "g_can", "g_snack", "g_misc", "f_cab"], ["c_coat", "c_work", "c_acc", "s_sport", "s_work", "b_small", "b_big"], ["h_tool", "h_pipe", "h_misc", "k_parts", "k_helmet", "p_band", "p_pain", "p_anti"]]
			var idx := 0
			for k in n:
				var y0 := k * fh
				var tables: Array = zones[k % zones.size()]
				var x := -hw + 4.0
				while x < hw - 3.0:
					var z := -6.5
					while z > well_z1 + 2.5:
						if not (k == 0 and absf(x) < 3.0 and z > -8.0):
							var lay2 := _gondola(mb, b, x, y0, z, 1.5)
							_add_container(tables[idx % tables.size()], _to_world(b, Vector3(x, y0 + 1.1, z)), b.id, 8 + rng.randi() % 7, true, {"shelf": lay2})
							idx += 1
						z -= 4.4
					x += 4.2
			for rx: float in [-9.0, 0.0, 9.0]:
				_hb(mb, b, "wood", rx - 1.0, rx + 1.0, 0, 1.0, -3.4, -2.8, wood, 1)
				_add_container("register", _to_world(b, Vector3(rx, 1.1, -3.1)), b.id, 2, true)
				_add_npc("owner", _to_world(b, Vector3(rx, 0.0, -4.0)), b.id, 0.0 if b.s > 0 else PI)
		"super":
			# mỗi tầng một nhóm hàng: tầng 1 thực phẩm, tầng 2 quần áo - giày - balo, tầng 3 dụng cụ - thuốc - phụ tùng
			var floor_tables := [["g_noodle", "g_drink", "g_can", "g_snack", "g_misc", "f_cab", "fridge"],
				["c_coat", "c_work", "c_acc", "s_sport", "s_work", "b_small", "b_big"],
				["h_tool", "h_pipe", "h_misc", "k_parts", "k_helmet", "p_band", "p_pain", "p_anti"]]
			var holes: Array = b.get("holes", [])
			var sidx := 0
			for fk in n:
				var fy := fk * fh
				var st_tables: Array = floor_tables[fk % floor_tables.size()]
				var big: bool = b.get("landmark", false)
				var sx := -hw + 3.5
				while sx < hw - 2.5:
					var sz := -6.0 if fk == 0 else -3.0
					while sz > -d + 3.0:
						var blocked := false
						for h: Rect2 in holes:
							if h.grow(2.2).has_point(Vector2(sx, sz)) or h.grow(2.2).has_point(Vector2(sx, sz + 1.5)) or h.grow(2.2).has_point(Vector2(sx, sz - 1.5)):
								blocked = true
						if absf(sx) > hw - 3.6 and sz < -d + 7.0:
							blocked = true          # chừa chỗ cầu thang bộ ở hai đầu
						if not blocked:
							var lay3 := _gondola(mb, b, sx, fy, sz, 1.5)
							var per := (14 + rng.randi() % 8) if big else (8 + rng.randi() % 7)
							_add_container(st_tables[sidx % st_tables.size()], _to_world(b, Vector3(sx, fy + 1.1, sz)), b.id, per, true, {"shelf": lay3})
						sidx += 1
						sz -= 4.4 if fk == 0 else 5.2
					sx += 3.8 if fk == 0 else 4.6
				if big:
					# dải đèn trần + dầm trần sẫm màu, cột vuông: nhìn rõ trần cao, không lẫn với bầu trời
					var lx := -hw + 6.0
					while lx < hw - 4.0:
						_hb(mb, b, "emit", lx - 0.15, lx + 0.15, fy + fh - 0.32, fy + fh - 0.24, -d + 4.0, -4.0, Color(0.95, 0.95, 0.88), 0)
						_hb(mb, b, "dark", lx + 2.8, lx + 3.1, fy + fh - 0.6, fy + fh - 0.22, -d + 1.0, -1.0, Color(0.35, 0.37, 0.4), 0)
						lx += 12.0
					var cx2 := -hw + 12.0
					while cx2 < hw - 8.0:
						var cz2 := -14.0
						while cz2 > -d + 8.0:
							_hb(mb, b, "concrete", cx2 - 0.4, cx2 + 0.4, fy, fy + fh - 0.2, cz2 - 0.4, cz2 + 0.4, Color(0.72, 0.72, 0.7), 1)
							cz2 -= 20.0
						cx2 += 24.0
				if fk > 0 and big:
					var lbl: String = ["", "THỜI TRANG - GIÀY DÉP - BALO", "ĐIỆN MÁY - DỤNG CỤ - NHÀ THUỐC"][mini(fk, 2)]
					_add_label(_to_world(b, Vector3(0, fy + fh - 1.2, -1.0)), lbl, b.s, 0.9, Color(0.2, 0.45, 0.3))
			for rx2: float in [-hw * 0.5, 0.0, hw * 0.5]:
				_hb(mb, b, "wood", rx2 - 1.0, rx2 + 1.0, 0, 1.0, -3.2, -2.6, wood, 1)
				_add_container("register", _to_world(b, Vector3(rx2, 1.1, -2.9)), b.id, 2, true)
			_add_npc("owner", _to_world(b, Vector3(0.0, 0.0, -3.8)), b.id, 0.0 if b.s > 0 else PI)
			_add_npc("owner", _to_world(b, Vector3(hw * 0.5, 0.0, -3.8)), b.id, 0.0 if b.s > 0 else PI)
		"restaurant":
			# bàn ghế kín hai tầng, quầy và bếp lớn phía sau
			for k in n:
				var ry := k * fh
				var tx := -hw + 3.0
				while tx < hw - 2.0:
					var tz := -3.5
					while tz > -d + 7.0:
						_hb(mb, b, "wood", tx - 0.7, tx + 0.7, ry + 0.7, ry + 0.76, tz - 0.5, tz + 0.5, wood, 1)
						_hb(mb, b, "wood", tx - 0.06, tx + 0.06, ry, ry + 0.7, tz - 0.06, tz + 0.06, wood.darkened(0.3), 0)
						for cx2: float in [-1.05, 1.05]:
							_hb(mb, b, "flat", tx + cx2 - 0.2, tx + cx2 + 0.2, ry, ry + 0.45, tz - 0.2, tz + 0.2, Color(0.55, 0.2, 0.18), 0)
						tz -= 2.6
					tx += 3.4
			_hb(mb, b, "wood", -hw + 2.0, hw - 2.0, 0, 1.05, -d + 5.6, -d + 6.2, wood.darkened(0.2), 1)
			for kx2 in 4:
				var bx2 := lerpf(-hw + 3.0, hw - 3.0, kx2 / 3.0)
				_hb(mb, b, "rust", bx2 - 0.8, bx2 + 0.8, 0, 0.9, -d + 0.4, -d + 1.1, Color(0.85, 0.85, 0.85), 1)
				_add_container(["f_kitchen", "f_cab", "fridge", "f_kitchen"][kx2], _to_world(b, Vector3(bx2, 1.05, -d + 0.75)), b.id, 3 + rng.randi() % 3, true)
			_add_container("register", _to_world(b, Vector3(0.0, 1.15, -d + 5.9)), b.id, 2, true)
			_add_npc("owner", _to_world(b, Vector3(0.0, 0.0, -d + 5.0)), b.id, 0.0 if b.s > 0 else PI)
		"hospital":
			_furnish_hospital(mb, b, hw, d, fh, n, well_w)
		"mansion", "guest":
			_furnish_mansion(mb, b, hw, d, fh, n)
		"garage":
			_hb(mb, b, "metal", -hw + 0.6, -hw + 1.2, 0, 1.8, -d + 0.5, -d + 4.0, Color(0.5, 0.52, 0.55), 1)
			if not _rebuilding:
				_add_container("hardware", _to_world(b, Vector3(-hw + 0.9, 1.0, -d + 2.0)), int(b.id), 3)
		"school":
			_furnish_school(mb, b, hw, d, fh, n, well_w)
		"radio":
			# phòng máy: tủ thiết bị dọc tường, bàn điều khiển
			for k in 4:
				var rx := -hw + 1.2 + k * 1.9
				_hb(mb, b, "metal", rx - 0.4, rx + 0.4, 0, 1.9, -d + 0.4, -d + 1.0, Color(0.35, 0.38, 0.42), 1)
				_hb(mb, b, "emit", rx - 0.2, rx + 0.2, 1.2, 1.3, -d + 1.0, -d + 1.02, Color(0.3, 0.9, 0.4), 0)
			_hb(mb, b, "wood", -1.5, 1.5, 0.75, 0.8, -3.0, -2.2, wood, 1)
			_add_container("radio_room", _to_world(b, Vector3(0.0, 0.95, -2.6)), b.id, 3)
		"office":
			for cw: Array in [[-7.0, -7.5], [5.5, -5.0], [9.0, -9.0]]:
				_add_npc("coworker", _to_world(b, Vector3(cw[0], 0.0, cw[1])), b.id, rng.randf() * TAU)
			for k in n:
				var y := k * fh
				for row in 3:
					for colm in 5:
						if k == 0 and colm == 2:
							continue
						var x2 := -hw + 3.0 + colm * 4.6
						var z2 := -3.5 - row * 3.6
						_hb(mb, b, "wood", x2 - 0.8, x2 + 0.8, y + 0.7, y + 0.78, z2 - 0.4, z2 + 0.4, wood, 1)
						_hb(mb, b, "dark", x2 - 0.75, x2 - 0.65, y, y + 0.7, z2 - 0.35, z2 + 0.35, Color(0.3, 0.3, 0.32), 0)
						_hb(mb, b, "dark", x2 + 0.65, x2 + 0.75, y, y + 0.7, z2 - 0.35, z2 + 0.35, Color(0.3, 0.3, 0.32), 0)
						_hb(mb, b, "dark", x2 - 0.3, x2 + 0.3, y + 0.8, y + 1.2, z2 - 0.3, z2 - 0.25, Color(0.1, 0.1, 0.12), 0)
						_add_container("office", _to_world(b, Vector3(x2, y + 0.95, z2)), b.id, 1 + rng.randi() % 2)
		_:
			# Nhà dân: bếp + tủ lạnh ở tầng trệt, phòng ngủ ở trên.
			var kx := -(hw - T - 0.35)
			_hb(mb, b, "wood", kx - 0.3, kx + 0.3, 0, 0.9, -7.5, -5.2, wood, 1)
			_add_container("kitchen", _to_world(b, Vector3(kx, 1.05, -6.4)), b.id, 2 + rng.randi() % 2)
			_hb(mb, b, "paint", kx - 0.3, kx + 0.35, 0, 1.7, -4.9, -4.2, Color(0.92, 0.94, 0.96), 1)
			_add_container("fridge", _to_world(b, Vector3(kx, 1.0, -4.55)), b.id, 2 + rng.randi() % 3)
			# Tầng trệt mỗi nhà một kiểu: phòng ăn / phòng khách / kho kiêm chỗ sửa xe
			var rx := hw - T - 0.35
			match b.id % 3:
				0:
					_hb(mb, b, "wood", 0.9, 2.1, 0.7, 0.76, -3.6, -2.2, wood, 1)
					_hb(mb, b, "wood", 1.0, 1.1, 0, 0.7, -3.5, -2.3, wood, 0)
					_hb(mb, b, "wood", 1.9, 2.0, 0, 0.7, -3.5, -2.3, wood, 0)
					for cz: float in [-3.3, -2.5]:
						_hb(mb, b, "wood", 0.45, 0.8, 0, 0.45, cz - 0.2, cz + 0.2, wood.darkened(0.2), 0)
				1:
					# ghế sofa + bàn trà + kệ tivi
					var sofa := Color.from_hsv(rng.randf(), 0.35, 0.55)
					_hb(mb, b, "flat", rx - 0.55, rx + 0.3, 0, 0.42, -4.0, -1.8, sofa, 1)
					_hb(mb, b, "flat", rx + 0.05, rx + 0.3, 0.42, 0.9, -4.0, -1.8, sofa.darkened(0.15), 0)
					_hb(mb, b, "wood", rx - 1.6, rx - 0.95, 0, 0.36, -3.4, -2.4, wood, 1)
					_hb(mb, b, "wood", -rx + 0.2 - 0.45, -rx + 0.2, 0, 0.5, -2.9, -1.3, wood.darkened(0.2), 1)
					_hb(mb, b, "dark", -rx - 0.2, -rx - 0.12, 0.6, 1.25, -2.7, -1.5, Color(0.06, 0.06, 0.07), 0)
					_add_container("drawer", _to_world(b, Vector3(-rx - 0.05, 0.65, -2.1)), b.id, 1 + rng.randi() % 2)
				2:
					# kho: kệ sắt, bàn dụng cụ, thùng hàng
					_hb(mb, b, "rust", rx - 0.3, rx + 0.3, 0, 1.9, -3.9, -2.1, Color(0.75, 0.75, 0.75), 1)
					_add_container("h_misc", _to_world(b, Vector3(rx, 1.0, -3.0)), b.id, 2 + rng.randi() % 2)
					_hb(mb, b, "wood", rx - 0.45, rx + 0.3, 0, 0.85, -1.7, -0.6, wood.darkened(0.25), 1)
					for kb in 3:
						var bs := rng.randf_range(0.45, 0.7)
						_hb(mb, b, "wood", -0.4 + kb * 0.75, -0.4 + kb * 0.75 + bs, 0, bs, -4.6, -4.6 + bs, Color(0.8, 0.7, 0.55), 1)
					_add_container("street", _to_world(b, Vector3(0.4, 0.8, -4.3)), b.id, 2)
			for k in range(1, n):
				var y3 := k * fh
				var bx := (hw - T - 1.0) * (1.0 if k % 2 == 0 else -1.0)
				_hb(mb, b, "wood", bx - 0.9, bx + 0.9, y3, y3 + 0.35, -4.2, -2.1, wood, 1)
				_hb(mb, b, "flat", bx - 0.85, bx + 0.85, y3 + 0.35, y3 + 0.5, -4.15, -2.15, Color.from_hsv(rng.randf(), 0.25, 0.85), 0)
				_hb(mb, b, "flat", bx - 0.6, bx + 0.6, y3 + 0.5, y3 + 0.62, -4.05, -3.55, Color(0.95, 0.95, 0.92), 0)
				if not _rebuilding:
					beds.append(_to_world(b, Vector3(bx, y3 + 0.6, -3.15)))
				# vách ngăn phòng có cửa (một số tầng)
				if (b.id + k) % 2 == 0 and d >= 13.0:
					_wall_x(mb, b, "paint", -hw + T, hw - T, y3, y3 + fh - 0.2, -5.75, -5.65, [[-0.5, 0.5, y3, y3 + 2.1, false]], Color(0.93, 0.91, 0.86), "int")
				var wx := -bx
				_hb(mb, b, "wood", wx - 0.3 if wx > 0 else wx - 0.6, wx + 0.6 if wx > 0 else wx + 0.3, y3, y3 + 1.9, -8.2, -6.9, wood.darkened(0.15), 1)
				_add_container("wardrobe", _to_world(b, Vector3(wx, y3 + 1.0, -7.55)), b.id, 1 + rng.randi() % 3)
				# Tầng trên xen kẽ: phòng ngủ có thêm góc làm việc / giá sách
				if (b.id + k) % 3 == 1:
					_hb(mb, b, "wood", wx - 0.4, wx + 0.4, y3 + 0.7, y3 + 0.76, -1.9, -0.7, wood, 1)
					_hb(mb, b, "wood", wx - 0.35, wx + 0.35, y3, y3 + 0.7, -0.78, -0.72, wood, 0)
					_hb(mb, b, "wood", wx - 0.35, wx + 0.35, y3, y3 + 0.7, -1.88, -1.82, wood, 0)
					_hb(mb, b, "flat", wx - 0.25, wx + 0.25, y3, y3 + 0.45, -1.5, -1.1, Color(0.2, 0.2, 0.25), 0)
					_add_container("office", _to_world(b, Vector3(wx, y3 + 0.95, -1.3)), b.id, 1 + rng.randi() % 2)
				elif (b.id + k) % 3 == 2:
					_hb(mb, b, "wood", wx - 0.2, wx + 0.2, y3, y3 + 1.8, -2.4, -0.9, wood.darkened(0.1), 1)
					for sh in 4:
						var bz := -2.3
						while bz < -1.05:
							var bw := rng.randf_range(0.05, 0.12)
							_hb(mb, b, "flat", wx - 0.16, wx + 0.16, y3 + 0.1 + sh * 0.43, y3 + 0.1 + sh * 0.43 + rng.randf_range(0.22, 0.34), bz, bz + bw, Color.from_hsv(rng.randf(), 0.5, 0.6), 0)
							bz += bw + 0.01
				if rng.randf() < 0.5:
					_hb(mb, b, "wood", bx - 0.3, bx + 0.3, y3, y3 + 0.55, -1.7, -1.1, wood, 1)
					_add_container("drawer" if rng.randf() < 0.6 else "medbox", _to_world(b, Vector3(bx, y3 + 0.7, -1.4)), b.id, 1 + rng.randi() % 2)
			if b.kind == "home":
				home_pos = _to_world(b, Vector3(0, 0, -5.0))
				hatch_pos = _to_world(b, Vector3(0.2, 0.0, -9.6))
				home_back = _to_world(b, Vector3(1.0, BASE, -float(b.d) - 2.4))
				_hb(mb, b, "rust", -0.4, 0.8, 0.0, 0.06, -10.2, -9.0, Color(0.7, 0.7, 0.7), 0)
				# vợ và con đang nấp trong nhà
				_add_npc("wife", _to_world(b, Vector3(-0.6, 0.0, -8.0)), b.id, 0.0 if b.s > 0 else PI)
				_add_npc("child", _to_world(b, Vector3(-1.2, 0.0, -8.5)), b.id, 0.0 if b.s > 0 else PI)
			elif b.kind == "tu":
				# Ông Tư không còn ở nhà. Xà beng nằm trong hòm đồ nghề trên tầng 2.
				tu_pos = _to_world(b, Vector3(0.2, fh + 0.5, -2.6))
				_hb(mb, b, "rust", -0.3, 0.7, fh, fh + 0.45, -3.0, -2.3, Color(0.6, 0.2, 0.18), 1)
				_add_container("tu_box", _to_world(b, Vector3(0.2, fh + 0.7, -2.65)), b.id, 3)
				_hb(mb, b, "flat", -1.6, 0.4, 0.013, 0.02, -2.6, 1.6, Color(0.32, 0.05, 0.05), 0)        # vệt máu kéo ra cửa


## Kệ hàng hai mặt đứng giữa lối đi, dài 2*half theo chiều sâu nhà.
## Kệ hàng hai mặt giữa cửa hàng. Hàng hoá thật (nhặt được) được bày lên từng tầng theo bố cục trả về.
# ------------------------------------------------------------------ công trình đặc thù
## Một ngôi nhà của công trình đặc thù: lưu vào block_specs để dựng lại được khi bị phá kính / bị giẫm.
func _landmark_house(mb: MeshBuilder, cell: Vector2i, spec: Dictionary) -> Dictionary:
	spec["id"] = buildings.size()
	spec["cell"] = cell
	spec["landmark"] = true
	if not spec.has("shop"):
		spec["shop"] = ""
	if not spec.has("back_door"):
		spec["back_door"] = false
	(block_specs[cell] as Array).append(spec)
	_build_house(mb, spec)
	return spec


func _build_landmark(mb: MeshBuilder, cell: Vector2i) -> void:
	var zr := Rect2()
	var zone := Rect2i()
	for lz: Rect2i in landmark_zones():
		if lz.has_point(cell):
			zone = lz
	if cell != zone.position:
		return
	zr = zone_rect(zone)
	var c := Vector3(zr.get_center().x, 0, zr.get_center().y)
	mb.box("sidewalk", Vector3(c.x, BASE * 0.5, c.z), Vector3(zr.size.x, BASE, zr.size.y))
	var fresh := not _rebuilding
	if _rebuilding:
		for spec: Dictionary in block_specs.get(cell, []):
			_build_house(mb, spec)
	else:
		block_specs[cell] = []
	var seed_v := _seed + cell.x * 613 + cell.y * 1031
	if zone == HOSPITAL_ZONE:
		_build_hospital(mb, cell, zr, fresh, seed_v)
	elif zone == SCHOOL_ZONE:
		_build_school(mb, cell, zr, fresh, seed_v)
	elif zone == BIGSUPER_ZONE:
		_build_bigsuper(mb, cell, zr, fresh, seed_v)
	elif zone == RADIO_ZONE:
		_build_radio(mb, cell, zr, fresh, seed_v)
	else:
		_build_mansion(mb, cell, zr, fresh, seed_v, MANSION_ZONES.find(zone))


## Tường rào quanh khu, chừa cổng ở các vị trí cho trước (toạ độ dọc theo cạnh, tính từ góc trên trái).
func _compound_fence(mb: MeshBuilder, zr: Rect2, gates: Array, h: float, col: Color, mat := "plaster") -> void:
	var edges := [[zr.position, Vector2(zr.end.x, zr.position.y)], [Vector2(zr.position.x, zr.end.y), zr.end], [zr.position, Vector2(zr.position.x, zr.end.y)], [Vector2(zr.end.x, zr.position.y), zr.end]]
	for ei in 4:
		var a: Vector2 = edges[ei][0]
		var b2: Vector2 = edges[ei][1]
		var horiz := ei < 2
		var length := a.distance_to(b2)
		var inset := 0.6 * (1.0 if ei % 2 == 0 else -1.0)
		var cuts: Array = []
		for g: Array in gates:
			if int(g[0]) == ei:
				cuts.append([float(g[1]) - float(g[2]) * 0.5, float(g[1]) + float(g[2]) * 0.5])
		cuts.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
		var t0 := 0.6
		cuts.append([length - 0.6, length + 1.0])
		for cut: Array in cuts:
			var t1: float = cut[0]
			if t1 - t0 > 0.2:
				var mid := (t0 + t1) * 0.5
				var p := (Vector2(a.x + mid, a.y + inset) if horiz else Vector2(a.x + inset, a.y + mid))
				mb.box(mat, Vector3(p.x, BASE + h * 0.5, p.y), Vector3(t1 - t0 if horiz else 0.3, h, 0.3 if horiz else t1 - t0), col)
				mb.box("concrete", Vector3(p.x, BASE + h + 0.06, p.y), Vector3((t1 - t0) if horiz else 0.42, 0.12, 0.42 if horiz else (t1 - t0)), col.darkened(0.1), 0)
			t0 = float(cut[1])


func _landmark_label(pos: Vector3, text: String, yaw: float, size: float, color: Color, far := 160.0) -> void:
	if _rebuilding:
		return
	_label_yaw = yaw
	_add_label(pos, text, 1.0, size, color)
	(get_child(get_child_count() - 1) as Label3D).visibility_range_end = far
	_label_yaw = NAN


## Bệnh viện đa khoa: toà chính 4 tầng nhìn ra phố phía nam, khoa cấp cứu 2 tầng phía bắc, sân giữa có cây, xe cứu thương.
## Bệnh viện đa khoa: tổ hợp 3 toà xếp chữ U quay mặt về phía bắc (về phía nhà), sân trong có cây, xe cứu thương.
## Toà sau (nằm ngang): khoa nội trú + phòng trưởng khoa có két; hai toà cánh: phòng bệnh, phòng khám, khoa dược.
func _build_hospital(mb: MeshBuilder, cell: Vector2i, zr: Rect2, fresh: bool, seed_v: int) -> void:
	rng.seed = seed_v
	var c := Vector3(zr.get_center().x, 0, zr.get_center().y)
	var back_z := zr.end.y - 3.0 - 15.0
	var wing_x := zr.size.x * 0.5 - 12.0
	if fresh:
		_landmark_house(mb, cell, {"kind": "hospital", "part": "back", "s": -1.0, "w": zr.size.x - 6.0, "d": 15.0, "fh": 3.6, "floors": 3, "origin": Vector3(c.x, BASE, back_z),
			"color": Color("eef0f2"), "roof_access": true, "name": "Khoa nội trú", "seed": rng.randi(), "safe": true})
		for sd: float in [-1.0, 1.0]:
			_landmark_house(mb, cell, {"kind": "hospital", "part": "wing", "s": -1.0, "w": 18.0, "d": back_z - zr.position.y - 3.0, "fh": 3.6, "floors": 3,
				"origin": Vector3(c.x + sd * wing_x, BASE, zr.position.y + 3.0), "color": Color("f2ece2"), "roof_access": false,
				"name": "Khoa khám bệnh" if sd < 0.0 else "Khoa cấp cứu", "seed": rng.randi(), "pharmacy": sd > 0.0})
		landmarks.append({"name": "BỆNH VIỆN", "pos": c})
	rng.seed = seed_v + 7
	_compound_fence(mb, zr, [[0, zr.size.x * 0.5, 14.0]], 1.8, Color(0.92, 0.92, 0.9))
	# chữ thập đỏ và biển trên mặt tiền toà sau, nhìn vào sân trong (về phía bắc)
	mb.box("emit", Vector3(c.x, BASE + 9.6, back_z - 0.2), Vector3(3.2, 0.9, 0.12), Color(0.9, 0.15, 0.12), 0)
	mb.box("emit", Vector3(c.x, BASE + 9.6, back_z - 0.2), Vector3(0.9, 3.2, 0.12), Color(0.9, 0.15, 0.12), 0)
	_landmark_label(Vector3(c.x, BASE + 7.6, back_z - 0.3), "BỆNH VIỆN ĐA KHOA THÀNH PHỐ", PI, 0.9, Color(0.75, 0.1, 0.1))
	_landmark_label(Vector3(c.x, BASE + 2.6, zr.position.y - 0.2), "BỆNH VIỆN ĐA KHOA", PI, 0.7, Color(0.75, 0.1, 0.1))
	for sd2: float in [-1.0, 1.0]:
		_landmark_label(Vector3(c.x + sd2 * wing_x, BASE + 3.4, zr.position.y + 2.8), "KHOA KHÁM BỆNH" if sd2 < 0.0 else "KHOA CẤP CỨU", PI, 0.6, Color(0.75, 0.1, 0.1))
	# sân trong: cỏ, cây, ghế đá; xe cứu thương
	var court := Vector3(c.x, 0, (zr.position.y + back_z) * 0.5)
	mb.box("grass", Vector3(court.x, BASE + 0.02, court.z), Vector3(zr.size.x - 50.0, 0.04, back_z - zr.position.y - 8.0), Color(0.62, 0.8, 0.55), 0)
	for k in 8:
		if not _rebuilding:
			_tree_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(court.x - 30.0 + k * 8.5, BASE, court.z + rng.randf_range(-6.0, 6.0))))
	if not _rebuilding:
		for k2 in 3:
			_car(mb, Vector3(c.x - 10.0 + k2 * 8.0, 0.0, back_z - 5.0), PI * 0.5, Color("f4f2ee"), false)
			_add_container("army_med", Vector3(c.x - 10.0 + k2 * 8.0, 1.2, back_z - 2.5), -1, 2)


## Trong các toà bệnh viện: hành lang + dãy phòng bệnh nhỏ (2 giường, tủ đầu giường), phòng khám, khoa dược có
## tủ thuốc kính chữ thập đỏ nhìn rõ từ xa, phòng trưởng khoa có két sắt.
func _furnish_hospital(mb: MeshBuilder, b: Dictionary, hw: float, d: float, fh: float, n: int, _well_w: float) -> void:
	var white := Color(0.93, 0.94, 0.95)
	var steel := Color(0.7, 0.72, 0.75)
	var wall_col := Color(0.9, 0.93, 0.92)
	var r := RandomNumberGenerator.new()
	r.seed = int(b.seed) + 5
	var rooms: Array = []        # [x0, x1, z0, z1, y, kind]
	var wing: bool = b.get("part", "") == "wing"
	for k in n:
		var y := k * fh
		if wing:
			# toà cánh: hành lang dọc giữa (x trong ±1,6), phòng hai bên, chừa đầu phía sau cho cầu thang
			var z_end := -d + 6.6
			var step := 5.0
			var doors: Array = []
			var z := -0.4
			while z - step > z_end - 0.01:
				doors.append(z - step * 0.5)
				z -= step
			for sx: float in [-1.0, 1.0]:
				_pwall_z(mb, b, y, fh, z_end, -2.4 if k == 0 else -0.2, sx * 1.6, doors, wall_col)
			# đèn tuýp trần hành lang + chân tường xanh bệnh viện
			var lz := -2.0
			while lz > z_end + 1.0:
				_hb(mb, b, "emit", -0.5, 0.5, y + fh - 0.3, y + fh - 0.24, lz - 0.12, lz + 0.12, Color(0.92, 0.96, 0.95), 0)
				lz -= 4.0
			for sx3: float in [-1.0, 1.0]:
				_hb(mb, b, "paint", sx3 * 1.6 - 0.07, sx3 * 1.6 + 0.07, y, y + 1.0, z_end, -0.2, Color(0.55, 0.75, 0.7), 0)
			var zw := -0.4 - step
			while zw > z_end + 0.5:
				_pwall_x(mb, b, y, fh, -hw + 0.15, -1.6, zw, [], wall_col)
				_pwall_x(mb, b, y, fh, 1.6, hw - 0.15, zw, [], wall_col)
				zw -= step
			_pwall_x(mb, b, y, fh, -hw + 0.15, -1.6, z_end, [], wall_col)
			_pwall_x(mb, b, y, fh, 1.6, hw - 0.15, z_end, [], wall_col)
			var zr2 := -0.4
			var ri := 0
			while zr2 - step > z_end - 0.01:
				for sx2: float in [-1.0, 1.0]:
					var kind := "ward"
					if b.get("pharmacy", false) and k == 0 and ri < 2:
						kind = "pharmacy"
					elif ri % 3 == 2:
						kind = "clinic"
					rooms.append([minf(sx2 * 1.6, sx2 * (hw - 0.15)), maxf(sx2 * 1.6, sx2 * (hw - 0.15)), zr2 - step, zr2, y, kind, sx2])
					ri += 1
				zr2 -= step
		else:
			# toà sau: hành lang dọc theo chiều dài, phòng phía sau, phòng phía trước (sảnh ở giữa tầng trệt)
			var xa := -hw + 2.4
			var xb := hw - 2.4
			var za := -d + 6.6
			var zb := -d + 9.4
			var rw := (xb - xa) / roundf((xb - xa) / 5.5)
			var bdoors: Array = []
			var fdoors: Array = []
			var x := xa
			var ri2 := 0
			while x < xb - 0.5:
				bdoors.append(x + rw * 0.5)
				var kind2 := "ward" if ri2 % 4 != 3 else "clinic"
				if b.get("safe", false) and k == n - 1 and absf(x + rw * 0.5) < rw:
					kind2 = "chief"
				rooms.append([x, x + rw, -d + 0.15, za, y, kind2, 1.0])
				var lobby := k == 0 and absf(x + rw * 0.5) < rw * 1.6
				if not lobby:
					fdoors.append(x + rw * 0.5)
					rooms.append([x, x + rw, zb, -0.15, y, "ward" if ri2 % 2 == 0 else "clinic", -1.0])
				x += rw
				ri2 += 1
			_pwall_x(mb, b, y, fh, xa, xb, za, bdoors, wall_col)
			_pwall_x(mb, b, y, fh, xa, xb, zb, fdoors, wall_col)
			var lx2 := xa + 2.0
			while lx2 < xb - 1.0:
				_hb(mb, b, "emit", lx2 - 0.12, lx2 + 0.12, y + fh - 0.3, y + fh - 0.24, za + 0.8, zb - 0.8, Color(0.92, 0.96, 0.95), 0)
				lx2 += 4.0
			var xw := xa + rw
			while xw < xb - 0.5:
				_pwall_z(mb, b, y, fh, -d + 0.15, za, xw, [], wall_col)
				if not (k == 0 and absf(xw) < rw * 1.7):
					_pwall_z(mb, b, y, fh, zb, -0.15, xw, [], wall_col)
				xw += rw
			if k == 0:
				# sảnh: quầy tiếp đón, ghế chờ
				_hb(mb, b, "wood", -4.0, 4.0, y, y + 1.05, -4.0, -3.2, Color(0.8, 0.82, 0.86), 1)
				_add_container("medbox", _to_world(b, Vector3(-2.0, y + 1.2, -3.6)), b.id, 2)
				for row in 2:
					_hb(mb, b, "metal", -7.0, 7.0, y + 0.42, y + 0.48, -6.0 - row * 1.2, -5.6 - row * 1.2, Color(0.3, 0.5, 0.7), 1)
	for rm: Array in rooms:
		var x0: float = rm[0]
		var x1: float = rm[1]
		var z0: float = rm[2]
		var z1: float = rm[3]
		var y2: float = rm[4]
		var cx := (x0 + x1) * 0.5
		var cz := (z0 + z1) * 0.5
		match str(rm[5]):
			"ward":
				# 2 giường bệnh có tủ đầu giường
				for bi in 2:
					if wing:
						var bz := z0 + 1.0 + bi * 2.4
						var bx0: float = x1 - 2.2 if float(rm[6]) > 0.0 else x0 + 0.2
						_hb(mb, b, "metal", bx0, bx0 + 2.0, y2, y2 + 0.55, bz - 0.5, bz + 0.5, steel, 1)
						_hb(mb, b, "flat", bx0 + 0.05, bx0 + 1.95, y2 + 0.55, y2 + 0.68, bz - 0.48, bz + 0.48, white, 0)
						if not _rebuilding and r.randf() < 0.25:
							beds.append(_to_world(b, Vector3(bx0 + 1.0, y2 + 0.9, bz)))
						if r.randf() < 0.6:
							_hb(mb, b, "metal", bx0 + 0.6, bx0 + 1.0, y2, y2 + 0.8, bz + 0.6, bz + 1.0, white, 1)
							if not _rebuilding:
								_add_container("hospital", _to_world(b, Vector3(bx0 + 0.8, y2 + 0.95, bz + 0.8)), b.id, 2 + r.randi() % 2)
					else:
						var bx := x0 + 1.0 + bi * 2.4
						var zz0: float = z0 + 0.2 if float(rm[6]) > 0.0 else z1 - 2.2
						_hb(mb, b, "metal", bx - 0.5, bx + 0.5, y2, y2 + 0.55, zz0, zz0 + 2.0, steel, 1)
						_hb(mb, b, "flat", bx - 0.48, bx + 0.48, y2 + 0.55, y2 + 0.68, zz0 + 0.05, zz0 + 1.95, white, 0)
						if not _rebuilding and r.randf() < 0.25:
							beds.append(_to_world(b, Vector3(bx, y2 + 0.9, zz0 + 1.0)))
						if r.randf() < 0.6:
							_hb(mb, b, "metal", bx + 0.6, bx + 1.0, y2, y2 + 0.8, zz0, zz0 + 0.4, white, 1)
							if not _rebuilding:
								_add_container("hospital", _to_world(b, Vector3(bx + 0.8, y2 + 0.95, zz0 + 0.2)), b.id, 2 + r.randi() % 2)
			"clinic":
				# phòng khám: bàn bác sĩ, giường khám, tủ thuốc kính
				_hb(mb, b, "wood", cx - 0.8, cx + 0.8, y2, y2 + 0.78, cz - 0.4, cz + 0.4, Color(0.75, 0.75, 0.78), 1)
				_med_cabinet(mb, b, x0 + 0.5, y2, z0 + 0.6, 1)
			"pharmacy":
				# khoa dược: nhiều tủ thuốc kính dọc tường
				var tx := x0 + 0.6
				while tx < x1 - 0.6:
					_med_cabinet(mb, b, tx, y2, z0 + 0.4, 2)
					tx += 1.1
			"chief":
				# phòng trưởng khoa: bàn làm việc, két sắt khoá số
				_hb(mb, b, "wood", cx - 1.0, cx + 1.0, y2, y2 + 0.78, cz - 0.5, cz + 0.5, Color(0.45, 0.3, 0.2), 1)
				if not b.has("_safe_done"):
					b["_safe_done"] = true
					_hb(mb, b, "metal", x1 - 1.3, x1 - 0.2, y2, y2 + 1.1, z0 + 0.2, z0 + 1.1, Color(0.3, 0.32, 0.36), 1)
					_hb(mb, b, "emit", x1 - 0.9, x1 - 0.6, y2 + 0.7, y2 + 0.85, z0 + 1.1, z0 + 1.13, Color(0.9, 0.7, 0.2), 0)
					if not _rebuilding:
						_add_container("hospital_safe", _to_world(b, Vector3(x1 - 0.75, y2 + 1.25, z0 + 0.65)), b.id, 3)
						hospital_safe_cid = containers.size() - 1
						containers[hospital_safe_cid]["name"] = "Két sắt (khoá số)"
						containers[hospital_safe_cid]["locked"] = true
						var rs := RandomNumberGenerator.new()
						rs.seed = _seed + 4321
						hospital_safe_code = "%04d" % rs.randi_range(1000, 9999)
	b.erase("_safe_done")


## Tủ thuốc đứng: thân trắng, cửa kính xanh nhạt, chữ thập đỏ phát sáng nhẹ (nhìn rõ trong phòng tối).
func _med_cabinet(mb: MeshBuilder, b: Dictionary, x: float, y: float, z: float, count: int) -> void:
	_hb(mb, b, "metal", x - 0.45, x + 0.45, y, y + 1.9, z - 0.2, z + 0.2, Color(0.95, 0.96, 0.97), 1)
	_hb(mb, b, "glass", x - 0.4, x + 0.4, y + 0.9, y + 1.8, z + 0.2, z + 0.22, Color(0.7, 0.85, 0.9, 0.5), 0)
	_hb(mb, b, "emit", x - 0.16, x + 0.16, y + 1.45, y + 1.53, z + 0.23, z + 0.24, Color(0.9, 0.12, 0.1), 0)
	_hb(mb, b, "emit", x - 0.04, x + 0.04, y + 1.33, y + 1.65, z + 0.23, z + 0.24, Color(0.9, 0.12, 0.1), 0)
	if not _rebuilding:
		_add_container("hospital", _to_world(b, Vector3(x, y + 1.0, z + 0.3)), b.id, count + r_count())
		containers[containers.size() - 1]["name"] = "Tủ thuốc"


func r_count() -> int:
	return rng.randi() % 2


## Trường tiểu học: dãy lớp học 3 tầng, nhà thể chất, sân trường có cột cờ, khung thành.
func _build_school(mb: MeshBuilder, cell: Vector2i, zr: Rect2, fresh: bool, seed_v: int) -> void:
	rng.seed = seed_v
	var c := Vector3(zr.get_center().x, 0, zr.get_center().y)
	if fresh:
		_landmark_house(mb, cell, {"kind": "school", "s": -1.0, "w": 74.0, "d": 13.0, "fh": 3.6, "floors": 3, "origin": Vector3(c.x - 14.0, BASE, zr.position.y + 3.0),
			"color": Color("f2d98a"), "roof_access": true, "name": "Trường tiểu học", "seed": rng.randi()})
		_landmark_house(mb, cell, {"kind": "hall", "s": -1.0, "w": 24.0, "d": 18.0, "fh": 6.0, "floors": 1, "origin": Vector3(c.x + 44.0, BASE, zr.position.y + 3.0),
			"color": Color("e8c070"), "roof_access": false, "name": "Nhà thể chất", "seed": rng.randi()})
		landmarks.append({"name": "TRƯỜNG HỌC", "pos": c})
	rng.seed = seed_v + 7
	_compound_fence(mb, zr, [[0, zr.size.x * 0.5 - 14.0, 8.0], [1, zr.size.x * 0.5, 8.0]], 1.6, Color(0.95, 0.85, 0.55))
	_landmark_label(Vector3(c.x - 14.0, BASE + 11.5, zr.position.y + 2.8), "TRƯỜNG TIỂU HỌC HOA SEN", PI, 0.9, Color(0.7, 0.2, 0.1))
	# sân trường: nền xi măng sơn kẻ, cột cờ, hai khung thành, ghế đá, cây bàng
	var yard := Vector3(c.x - 6.0, 0, zr.end.y - 13.0)
	mb.box("paint", yard + Vector3(0, BASE + 0.015, 0), Vector3(60.0, 0.02, 18.0), Color(0.82, 0.8, 0.76), 0)
	mb.box("paint", yard + Vector3(0, BASE + 0.03, 0), Vector3(0.15, 0.02, 18.0), Color.WHITE, 0)
	mb.box("metal", Vector3(c.x - 14.0, BASE + 5.0, zr.position.y + 22.0), Vector3(0.12, 10.0, 0.12), Color(0.8, 0.8, 0.82), 1)
	mb.box("flat", Vector3(c.x - 13.2, BASE + 9.3, zr.position.y + 22.0), Vector3(1.5, 1.0, 0.04), Color(0.85, 0.12, 0.1), 0)
	for sx: float in [-28.0, 16.0]:
		for gz: float in [-2.0, 2.0]:
			mb.box("paint", yard + Vector3(sx, BASE + 1.0, gz), Vector3(0.1, 2.0, 0.1), Color.WHITE, 2)
		mb.box("paint", yard + Vector3(sx, BASE + 2.0, 0), Vector3(0.1, 0.1, 4.1), Color.WHITE, 0)
	for k in 5:
		if not _rebuilding:
			_tree_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * 1.5), Vector3(zr.position.x + 6.0 + k * 9.0, BASE, zr.end.y - 3.5)))


func _furnish_school(mb: MeshBuilder, b: Dictionary, hw: float, d: float, fh: float, n: int, well_w: float) -> void:
	var desk := Color(0.75, 0.6, 0.42)
	var locker := Color(0.35, 0.55, 0.75)
	var staff_done := false
	for k in n:
		var y := k * fh
		# bàn học thành dãy
		var x := -hw + 3.0
		while x < hw - 3.0 - well_w:
			for row in 3:
				var z := -3.0 - row * 1.8
				_hb(mb, b, "wood", x - 0.6, x + 0.6, y + 0.65, y + 0.7, z - 0.3, z + 0.3, desk, 1)
				_hb(mb, b, "wood", x - 0.55, x - 0.5, y, y + 0.65, z - 0.25, z + 0.25, desk.darkened(0.3), 0)
				_hb(mb, b, "wood", x + 0.5, x + 0.55, y, y + 0.65, z - 0.25, z + 0.25, desk.darkened(0.3), 0)
			x += 2.0
		# bảng đen mỗi 10m
		var bx := -hw + 6.0
		while bx < hw - 6.0:
			_hb(mb, b, "flat", bx - 1.6, bx + 1.6, y + 1.0, y + 2.2, -0.35, -0.3, Color(0.12, 0.25, 0.18), 0)
			bx += 12.0
		# tủ khoá học sinh dọc tường sau
		var lx := -hw + 1.0
		while lx < hw - 1.0 - well_w - 0.6:
			_hb(mb, b, "metal", lx, lx + 0.55, y, y + 1.8, -d + 0.2, -d + 0.75, locker if int(lx) % 2 == 0 else locker.darkened(0.12), 1)
			_hb(mb, b, "dark", lx + 0.42, lx + 0.47, y + 0.9, y + 1.05, -d + 0.75, -d + 0.77, Color(0.15, 0.15, 0.16), 0)
			if not _rebuilding:
				_add_container("school_locker", _to_world(b, Vector3(lx + 0.27, y + 1.0, -d + 0.95)), b.id, 2)
				containers[containers.size() - 1]["name"] = "Tủ khoá học sinh"
			lx += 0.6
		# phòng giáo viên ở tầng trệt: tủ đồ nghề có xà beng
		if k == 0 and not staff_done:
			staff_done = true
			_hb(mb, b, "wood", hw - 6.0, hw - 4.8, y, y + 1.9, -6.0, -5.4, Color(0.55, 0.4, 0.3), 1)
			if not _rebuilding:
				_add_container("school_staff", _to_world(b, Vector3(hw - 5.4, y + 1.0, -5.1)), b.id, 3)
				containers[containers.size() - 1]["name"] = "Tủ phòng giáo viên"
	if not _rebuilding and school_med_cid < 0:
		# một tủ khoá ngẫu nhiên giữ lọ thuốc bé Na làm rơi
		var lockers: Array[int] = []
		for con in containers:
			if con.table == "school_locker" and int(con.building) == int(b.id):
				lockers.append(int(con.id))
		var r := RandomNumberGenerator.new()
		r.seed = _seed + 5150
		school_med_cid = lockers[r.randi() % lockers.size()]


## Đại siêu thị: một gian hàng khổng lồ một tầng rộng cỡ cái hồ, kệ hàng thành lối, bãi đỗ xe phía trước.
## Hai giếng thang cuốn (toạ độ trong nhà: x, z, rộng, sâu) ở hai bên lối giữa.
const SUPER_HOLES := [Rect2(-13.6, -47.0, 3.2, 14.0), Rect2(10.4, -47.0, 3.2, 14.0)]


## Thang cuốn đã hỏng (đi bộ lên xuống như cầu thang): mỗi giếng một dãy thang nối các tầng, có lan can kính, tay vịn.
func _escalators(mb: MeshBuilder, b: Dictionary) -> void:
	var fh: float = b.fh
	var n: int = b.floors
	for h: Rect2 in SUPER_HOLES:
		var x := h.get_center().x
		for k in n - 1:
			var y0 := k * fh
			var from := _to_world(b, Vector3(x, y0, h.end.y + 0.6))
			var to := _to_world(b, Vector3(x, y0 + fh, h.position.y - 0.05))
			_stair_flight(mb, from, to, 1.4, Color(0.55, 0.57, 0.6), "metal")
			for sd: float in [-0.78, 0.78]:
				# thành kính hai bên + tay vịn đen
				var a := _to_world(b, Vector3(x + sd, y0 + 0.55, h.end.y + 0.6))
				var bb := _to_world(b, Vector3(x + sd, y0 + fh + 0.55, h.position.y - 0.05))
				var mid := (a + bb) * 0.5
				var dir := (bb - a)
				var up := Vector3.UP
				var fwd := dir.normalized()
				var side := fwd.cross(up).normalized()
				var up2 := side.cross(fwd).normalized()
				mb.box("glass", mid, Vector3(0.05, 0.9, dir.length()), Color(0.75, 0.88, 0.92, 0.35), 0, "int", Basis(side, up2, -fwd))
				mb.box("dark", mid + up2 * 0.48, Vector3(0.1, 0.08, dir.length()), Color(0.1, 0.1, 0.1), 0, "int", Basis(side, up2, -fwd))
			# lan can quanh miệng giếng ở tầng trên
			var yt := y0 + fh
			for sx: float in [h.position.x, h.end.x]:
				_hb(mb, b, "glass", sx - 0.04, sx + 0.04, yt, yt + 1.0, h.position.y, h.end.y, Color(0.75, 0.88, 0.92, 0.35), 2)
				_hb(mb, b, "dark", sx - 0.05, sx + 0.05, yt + 1.0, yt + 1.06, h.position.y, h.end.y, Color(0.1, 0.1, 0.1), 0)
			_hb(mb, b, "glass", h.position.x, h.end.x, yt, yt + 1.0, h.end.y - 0.04, h.end.y + 0.04, Color(0.75, 0.88, 0.92, 0.35), 2)


func _build_bigsuper(mb: MeshBuilder, cell: Vector2i, zr: Rect2, fresh: bool, seed_v: int) -> void:
	rng.seed = seed_v
	var c := Vector3(zr.get_center().x, 0, zr.get_center().y)
	if fresh:
		_landmark_house(mb, cell, {"kind": "super", "s": 1.0, "w": 104.0, "d": 80.0, "fh": 7.0, "floors": 3, "origin": Vector3(c.x, BASE, zr.end.y - 24.0),
			"color": Color("e6e2d8"), "roof_access": false, "name": "Đại siêu thị", "seed": rng.randi(), "holes": SUPER_HOLES})
		landmarks.append({"name": "ĐẠI SIÊU THỊ", "pos": c})
	_escalators(mb, (block_specs[cell] as Array)[0])
	rng.seed = seed_v + 7
	mb.box("emit", Vector3(c.x, BASE + 7.6, zr.end.y - 23.8), Vector3(40.0, 2.2, 0.2), Color(0.85, 0.2, 0.15), 0)
	_landmark_label(Vector3(c.x, BASE + 7.6, zr.end.y - 23.6), "ĐẠI SIÊU THỊ TỔNG HỢP", 0.0, 1.5, Color.WHITE, 260.0)
	# bãi đỗ xe phía trước: vạch sơn, xe, xe đẩy hàng
	var lot := Rect2(zr.position.x + 2.0, zr.end.y - 22.0, zr.size.x - 4.0, 20.0)
	var lx := lot.position.x + 3.0
	while lx < lot.end.x - 3.0:
		mb.box("flat", Vector3(lx, BASE + 0.015, lot.get_center().y), Vector3(0.12, 0.02, 9.0), Color(0.95, 0.95, 0.9), 0)
		lx += 3.0
	if not _rebuilding:
		for k in 9:
			var cp := Vector3(lot.position.x + 4.5 + rng.randi_range(0, 36) * 3.0, 0.0, lot.get_center().y)
			_car(mb, cp, PI * 0.5 if rng.randf() < 0.5 else -PI * 0.5, Color.from_hsv(rng.randf(), 0.4, 0.75), rng.randf() < 0.2)
		for k2 in 6:
			var tp := Vector3(rng.randf_range(lot.position.x, lot.end.x), BASE, rng.randf_range(lot.position.y, lot.end.y))
			mb.box("metal", tp + Vector3(0, 0.5, 0), Vector3(0.6, 0.6, 0.9), Color(0.7, 0.72, 0.75), 1, "ext", Basis(Vector3.UP, rng.randf() * TAU))


## Trạm phát sóng: tháp thép 72m sơn trắng đỏ, phòng máy dưới chân tháp, rào bao quanh.
func _build_radio(mb: MeshBuilder, cell: Vector2i, zr: Rect2, fresh: bool, seed_v: int) -> void:
	rng.seed = seed_v
	var c := Vector3(zr.get_center().x, 0, zr.get_center().y)
	# trạm nghiên cứu hình tròn có mái vòm (thay cho phòng máy nhỏ)
	var lab := Vector3(c.x + 26.0, BASE, c.z + 2.0)
	if fresh:
		radio_pos = lab + Vector3(0, 0.05, 0)
		landmarks.append({"name": "TRẠM PHÁT SÓNG", "pos": c})
	_research_dome(mb, lab, fresh)
	rng.seed = seed_v + 7
	_compound_fence(mb, zr, [[1, lab.x - zr.position.x, 8.0]], 2.4, Color(0.6, 0.62, 0.66), "rust")
	_landmark_label(Vector3(lab.x, BASE + 6.6, lab.z + RES_R + 0.6), "TRẠM NGHIÊN CỨU - PHÁT SÓNG", 0.0, 0.8, Color(0.15, 0.25, 0.4))
	var base := Vector3(c.x - 26.0, BASE, c.z - 4.0)
	tower_pos = base
	mb.box("concrete", base + Vector3(0, 0.25, 0), Vector3(16.0, 0.5, 16.0), Color(0.75, 0.75, 0.73))
	# bốn chân tháp chụm dần lên đỉnh, thanh giằng chéo, sơn từng đoạn trắng đỏ
	var levels := 12
	var seg_h := TOWER_H / levels
	for i in levels:
		var y0 := i * seg_h
		var y1 := y0 + seg_h
		var w0 := lerpf(6.5, 1.2, y0 / TOWER_H)
		var w1 := lerpf(6.5, 1.2, y1 / TOWER_H)
		var col := Color(0.92, 0.92, 0.9) if i % 2 == 0 else Color(0.82, 0.18, 0.14)
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var p0 := base + Vector3(sx * w0, y0 + 0.5, sz * w0)
				var p1 := base + Vector3(sx * w1, y1 + 0.5, sz * w1)
				var dir := p1 - p0
				var rot := Basis.looking_at(dir.normalized(), Vector3.FORWARD if absf(dir.normalized().y) > 0.99 else Vector3.UP)
				mb.box("paint", (p0 + p1) * 0.5, Vector3(0.35, 0.35, dir.length() + 0.1), col, 2, "ext", rot, "metal")
		# giằng ngang ở mỗi tầng
		for side in 4:
			var horiz := side < 2
			var sg := -1.0 if side % 2 == 0 else 1.0
			var pc := base + (Vector3(0, y1 + 0.5, sg * w1) if horiz else Vector3(sg * w1, y1 + 0.5, 0))
			mb.box("paint", pc, Vector3(w1 * 2.0 if horiz else 0.2, 0.2, 0.2 if horiz else w1 * 2.0), col, 0)
			# giằng chéo
			var a := base + (Vector3(-w0, y0 + 0.5, sg * w0) if horiz else Vector3(sg * w0, y0 + 0.5, -w0))
			var b2 := base + (Vector3(w1, y1 + 0.5, sg * w1) if horiz else Vector3(sg * w1, y1 + 0.5, w1))
			var dd := b2 - a
			mb.box("paint", (a + b2) * 0.5, Vector3(0.14, 0.14, dd.length()), col.darkened(0.1), 0, "ext", Basis.looking_at(dd.normalized(), Vector3.UP))
		# sàn thao tác ở 1/3, 2/3 và đỉnh
		if i == 3 or i == 7 or i == levels - 1:
			mb.box("metal", base + Vector3(0, y1 + 0.55, 0), Vector3(w1 * 2.0 + 2.0, 0.12, w1 * 2.0 + 2.0), Color(0.55, 0.56, 0.58), 1, "ext", Basis.IDENTITY, "metal")
	# ăng-ten và đèn báo trên đỉnh
	mb.box("metal", base + Vector3(0, TOWER_H + 4.0, 0), Vector3(0.25, 8.0, 0.25), Color(0.85, 0.85, 0.85), 0)
	mb.box("emit", base + Vector3(0, TOWER_H + 8.2, 0), Vector3(0.6, 0.6, 0.6), Color(1.0, 0.2, 0.15), 0)
	for k in 3:
		var dish := base + Vector3([1.6, -1.4, 0.2][k], 40.0 + k * 9.0, [0.4, 1.2, -1.6][k])
		mb.box("paint", dish, Vector3(1.6, 1.6, 0.25), Color(0.95, 0.95, 0.95), 0, "ext", Basis(Vector3.UP, k * 2.1))


const RES_R := 11.0       # bán kính trạm nghiên cứu


## Trạm nghiên cứu: tường tròn trắng xám có dải đèn xanh, cửa trượt quay ra phố, mái vòm cầu kính mờ, đĩa ăng-ten trên mái.
## Bên trong: bàn điều khiển vòng quanh tường, giá thiết bị, bệ đặt máy phát tín hiệu ở giữa.
func _research_dome(mb: MeshBuilder, c: Vector3, fresh: bool) -> void:
	var segs := 32
	var wall_h := 4.2
	mb.box("tile", c + Vector3(0, 0.1, 0), Vector3(RES_R * 2.0, 0.2, RES_R * 2.0), Color(0.82, 0.84, 0.86), 1, "int", Basis.IDENTITY, "tile")
	for i in segs:
		var a := (i + 0.5) / segs * TAU
		# cửa: hai đoạn quay về phía nam (ra phố)
		var ang := wrapf(a - PI * 0.5, -PI, PI)
		if absf(ang) < TAU / segs * 1.1:
			continue
		var p := c + Vector3(cos(a), 0, sin(a)) * RES_R
		var seg_w := TAU * RES_R / segs + 0.15
		var rot := Basis(Vector3.UP, -a + PI * 0.5)
		mb.box("plaster", p + Vector3(0, wall_h * 0.5, 0), Vector3(seg_w, wall_h, 0.35), Color(0.86, 0.88, 0.9), 1, "ext", rot, "concrete")
		mb.box("emit", p + Vector3(0, wall_h - 0.4, 0) + Vector3(cos(a), 0, sin(a)) * 0.19, Vector3(seg_w, 0.12, 0.02), Color(0.3, 0.85, 0.95), 0, "ext", rot)
		mb.box("dark", p + Vector3(0, 0.15, 0) + Vector3(cos(a), 0, sin(a)) * 0.19, Vector3(seg_w, 0.3, 0.05), Color(0.25, 0.27, 0.3), 0, "ext", rot)
	# khung cửa trượt
	var door := c + Vector3(0, 0, RES_R)
	for sx: float in [-1.0, 1.0]:
		mb.box("metal", door + Vector3(sx * 2.3, wall_h * 0.5, 0), Vector3(0.4, wall_h, 0.6), Color(0.4, 0.43, 0.47), 1)
	mb.box("metal", door + Vector3(0, wall_h - 0.3, 0), Vector3(5.0, 0.6, 0.6), Color(0.4, 0.43, 0.47), 1)
	mb.box("glass", door + Vector3(-3.4, 1.6, 0.4), Vector3(1.8, 3.2, 0.06), Color(0.6, 0.8, 0.9, 0.4), 0)
	# trần phẳng chặn mưa (bên dưới mái vòm)
	mb.box("paint", c + Vector3(0, wall_h + 0.1, 0), Vector3(RES_R * 1.45, 0.2, RES_R * 1.45), Color(0.32, 0.36, 0.42), 1)
	for e4 in 4:
		# 4 mảng trần nối ra tới tường tròn (che kín, mắt trên tháp không nhìn xuyên được)
		var dir4 := Vector3(cos(e4 * PI * 0.5), 0, sin(e4 * PI * 0.5))
		mb.box("paint", c + dir4 * RES_R * 0.86 + Vector3(0, wall_h + 0.04, 0), Vector3(RES_R * 0.4 if absf(dir4.x) > 0.5 else RES_R * 1.2, 0.2, RES_R * 1.2 if absf(dir4.x) > 0.5 else RES_R * 0.4), Color(0.32, 0.36, 0.42), 1)
	for li in 8:
		var la := li * TAU / 8.0
		mb.box("emit", c + Vector3(cos(la) * 5.0, wall_h - 0.02, sin(la) * 5.0), Vector3(1.6, 0.06, 0.3), Color(0.6, 0.95, 1.0), 0, "ext", Basis(Vector3.UP, -la))
	# bên trong: bàn điều khiển, giá thiết bị, bệ máy
	for k in 10:
		var a2 := (k + 0.5) / 10.0 * TAU
		if absf(wrapf(a2 - PI * 0.5, -PI, PI)) < 0.6:
			continue
		var q := c + Vector3(cos(a2), 0, sin(a2)) * (RES_R - 1.2)
		var r2 := Basis(Vector3.UP, -a2 + PI * 0.5)
		mb.box("metal", q + Vector3(0, 0.5, 0), Vector3(2.4, 1.0, 0.9), Color(0.32, 0.35, 0.4), 1, "int", r2)
		mb.box("emit", q + Vector3(0, 1.05, 0) - Vector3(cos(a2), 0, sin(a2)) * 0.2, Vector3(1.8, 0.05, 0.3), Color(0.3, 0.9, 0.5) if k % 2 == 0 else Color(0.95, 0.6, 0.2), 0, "int", r2)
		if k % 3 == 0:
			mb.box("metal", q + Vector3(0, 1.5, 0) + Vector3(cos(a2), 0, sin(a2)) * 0.3, Vector3(2.2, 2.0, 0.4), Color(0.25, 0.27, 0.3), 1, "int", r2)
			if fresh:
				_add_container("radio_room", q + Vector3(0, 1.2, 0), -1, 3)
				containers[containers.size() - 1]["name"] = "Tủ thiết bị"
	mb.box("metal", c + Vector3(0, 0.45, 0), Vector3(1.6, 0.7, 1.6), Color(0.45, 0.48, 0.52), 1)
	if fresh and not _rebuilding:
		# mái vòm cầu: nửa khối cầu kính mờ, đỉnh có đĩa ăng-ten
		var dome := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = RES_R + 0.2
		sm.height = RES_R + 0.2
		sm.is_hemisphere = true
		sm.radial_segments = 48
		sm.rings = 16
		dome.mesh = sm
		var dm := StandardMaterial3D.new()
		dm.albedo_color = Color(0.74, 0.8, 0.86)
		dm.metallic = 0.0
		dm.roughness = 0.6
		dm.rim_enabled = true
		dm.cull_mode = BaseMaterial3D.CULL_DISABLED
		dome.material_override = dm
		dome.position = c + Vector3(0, wall_h, 0)
		add_child(dome)
		# gân thép trên mái vòm
		for g in 8:
			var rib := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = RES_R + 0.12
			tm.outer_radius = RES_R + 0.42
			tm.rings = 48
			rib.mesh = tm
			var rmat := StandardMaterial3D.new()
			rmat.albedo_color = Color(0.85, 0.87, 0.9)
			rib.material_override = rmat
			rib.position = c + Vector3(0, wall_h, 0)
			rib.rotation = Vector3(PI * 0.5, g * PI / 8.0, 0)
			add_child(rib)
		var dish := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 2.2
		cyl.bottom_radius = 0.3
		cyl.height = 1.0
		dish.mesh = cyl
		dish.material_override = rmat_white()
		dish.position = c + Vector3(3.0, wall_h + RES_R * 0.85, 2.0)
		dish.rotation = Vector3(0.5, 0.0, -0.3)
		add_child(dish)


func rmat_white() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.95, 0.96)
	return m


## Biệt phủ: tường rào cao, cổng sắt, vườn, bể bơi, biệt thự 3 tầng trắng; có phòng kho chứa đồ xịn.
## Biệt phủ (chiếm 2 ô): dinh thự chính 3 tầng chia nhiều phòng, nhà khách 2 tầng, gara; vườn, bể bơi, tường rào.
## Đồ xịn (máy dò, kính nhìn đêm, súng...) nằm trong phòng kho ở một phòng ngẫu nhiên: phải lục từng phòng.
func _build_mansion(mb: MeshBuilder, cell: Vector2i, zr: Rect2, fresh: bool, seed_v: int, idx: int) -> void:
	rng.seed = seed_v
	var c := Vector3(zr.get_center().x, 0, zr.get_center().y)
	var vx := c.x - 22.0
	if fresh:
		var villa := _landmark_house(mb, cell, {"kind": "mansion", "s": 1.0, "w": 36.0, "d": 22.0, "fh": 3.8, "floors": 3, "origin": Vector3(vx, BASE, zr.end.y - 12.0),
			"color": Color("f4f0e6"), "roof_access": true, "name": "Dinh thự", "seed": rng.randi(), "back_door": true, "vault": idx})
		_landmark_house(mb, cell, {"kind": "guest", "s": 1.0, "w": 18.0, "d": 14.0, "fh": 3.4, "floors": 2, "origin": Vector3(c.x + 26.0, BASE, zr.end.y - 16.0),
			"color": Color("efe6d4"), "roof_access": false, "name": "Nhà khách", "seed": rng.randi(), "vault": idx})
		_landmark_house(mb, cell, {"kind": "garage", "s": 1.0, "w": 14.0, "d": 10.0, "fh": 3.6, "floors": 1, "origin": Vector3(c.x + 50.0, BASE, zr.end.y - 6.0),
			"color": Color("d8d2c4"), "roof_access": false, "name": "Gara", "seed": rng.randi()})
		landmarks.append({"name": "BIỆT PHỦ", "pos": c})
		villa["landmark"] = true
	rng.seed = seed_v + 7
	_compound_fence(mb, zr, [[1, vx - zr.position.x, 5.0], [1, c.x + 50.0 - zr.position.x, 6.0]], 3.2, Color(0.88, 0.84, 0.74))
	for gx: float in [-2.8, 2.8]:
		mb.box("plaster", Vector3(vx + gx, BASE + 2.1, zr.end.y - 0.6), Vector3(0.8, 4.2, 0.8), Color(0.8, 0.76, 0.66))
		mb.box("emit", Vector3(vx + gx, BASE + 4.4, zr.end.y - 0.6), Vector3(0.45, 0.45, 0.45), Color(1.0, 0.85, 0.6), 0)
	_landmark_label(Vector3(vx, BASE + 5.0, zr.end.y - 0.2), "BIỆT PHỦ " + ["HOÀNG GIA", "KIM LONG"][maxi(idx, 0) % 2], 0.0, 0.6, Color(0.6, 0.45, 0.15))
	# mặt tiền dinh thự: hàng cột cao hai tầng, ban công dài
	for cx: float in [-12.0, -6.0, -2.0, 2.0, 6.0, 12.0]:
		mb.box("paint", Vector3(vx + cx, BASE + 3.8, zr.end.y - 12.0 + 1.8), Vector3(0.6, 7.6, 0.6), Color(0.96, 0.95, 0.9), 1)
	mb.box("concrete", Vector3(vx, BASE + 7.65, zr.end.y - 12.0 + 1.4), Vector3(30.0, 0.3, 3.0), Color(0.9, 0.88, 0.82), 1)
	# vườn, lối đi lát đá, bể bơi, đài phun nước
	mb.box("grass", Vector3(c.x, BASE + 0.02, c.z), Vector3(zr.size.x - 2.0, 0.04, zr.size.y - 2.0), Color(0.55, 0.78, 0.5), 0)
	mb.box("sidewalk", Vector3(vx, BASE + 0.03, zr.end.y - 5.5), Vector3(4.0, 0.04, 9.0), Color(0.92, 0.9, 0.84), 0)
	mb.box("tile", Vector3(c.x + 30.0, BASE - 0.4, zr.position.y + 9.0), Vector3(20.0, 0.8, 10.0), Color(0.9, 0.9, 0.88), 1)
	mb.box("flat", Vector3(c.x + 30.0, BASE + 0.05, zr.position.y + 9.0), Vector3(19.0, 0.05, 9.0), Color(0.35, 0.7, 0.9), 0)
	mb.box("plaster", Vector3(vx, BASE + 0.4, zr.end.y - 5.0), Vector3(3.0, 0.8, 3.0), Color(0.85, 0.82, 0.76), 1)
	mb.box("flat", Vector3(vx, BASE + 0.82, zr.end.y - 5.0), Vector3(2.6, 0.04, 2.6), Color(0.35, 0.65, 0.85), 0)
	for k in 12:
		if not _rebuilding:
			_tree_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.0, 1.6)), Vector3(zr.position.x + 3.0 + k * 10.5, BASE, zr.position.y + 2.5)))
	if not _rebuilding:
		_car(mb, Vector3(c.x + 47.0, 0.2, zr.end.y - 9.0), 0.0, Color("1a1a1e"), false, 1.1)
		_car(mb, Vector3(c.x + 53.0, 0.2, zr.end.y - 9.0), 0.0, Color("8a1c1c"), false, 1.0)
		_car(mb, Vector3(c.x + 12.0, 0.2, zr.end.y - 6.0), 0.3, Color("d8d8dc"), false, 1.1)


## Trong dinh thự / nhà khách: hành lang giữa, phòng hai bên, mỗi phòng một kiểu (ngủ, khách, làm việc, kho).
func _furnish_mansion(mb: MeshBuilder, b: Dictionary, hw: float, d: float, fh: float, n: int) -> void:
	var wall_col := Color(0.95, 0.92, 0.86)
	var wood := Color(0.55, 0.36, 0.22)
	var r := RandomNumberGenerator.new()
	r.seed = int(b.seed) + 99
	var xa := -hw + 2.2           # chừa hai đầu cho cầu thang
	var xb := hw - 2.2
	var za := -d + 6.6            # tường sau hành lang
	var zb := -d + 9.2            # tường trước hành lang
	var rooms: Array = []         # [x0, x1, z0, z1, y]
	for k in n:
		var y := k * fh
		var back_w := (xb - xa) / maxf(1.0, roundf((xb - xa) / 6.5))
		var front_w := (xb - xa) / maxf(1.0, roundf((xb - xa) / 8.5))
		var back_doors: Array = []
		var x := xa
		while x < xb - 0.5:
			back_doors.append(x + back_w * 0.5)
			rooms.append([x, x + back_w, -d + 0.2, za, y])
			x += back_w
		var front_doors: Array = []
		var x2 := xa
		while x2 < xb - 0.5:
			var hall := k == 0 and absf(x2 + front_w * 0.5) < front_w * 0.6       # sảnh lớn ở tầng trệt, ngay cửa chính
			if not hall:
				front_doors.append(x2 + front_w * 0.5)
				rooms.append([x2, x2 + front_w, zb, -0.2, y])
			x2 += front_w
		_pwall_x(mb, b, y, fh, xa, xb, za, back_doors, wall_col)
		_pwall_x(mb, b, y, fh, xa, xb, zb, front_doors, wall_col)
		var xw := xa + back_w
		while xw < xb - 0.5:
			_pwall_z(mb, b, y, fh, -d + 0.15, za, xw, [], wall_col)
			xw += back_w
		var xw2 := xa + front_w
		while xw2 < xb - 0.5:
			if not (k == 0 and (absf(xw2) < front_w * 1.1)):
				_pwall_z(mb, b, y, fh, zb, -0.15, xw2, [], wall_col)
			xw2 += front_w
	# phòng kho đồ xịn: một phòng ngẫu nhiên (chỉ ở dinh thự chính của biệt phủ)
	var vault_room := -1
	if b.kind == "mansion" and not rooms.is_empty():
		vault_room = r.randi() % rooms.size()
	for i in rooms.size():
		var rm: Array = rooms[i]
		var cx: float = (float(rm[0]) + float(rm[1])) * 0.5
		var cz: float = (float(rm[2]) + float(rm[3])) * 0.5
		var y2: float = rm[4]
		var depth: float = absf(float(rm[3]) - float(rm[2]))
		if i == vault_room:
			_hb(mb, b, "metal", cx - 0.6, cx + 0.6, y2, y2 + 1.3, float(rm[2]) + 0.1, float(rm[2]) + 0.9, Color(0.3, 0.3, 0.33), 1)
			_hb(mb, b, "emit", cx - 0.1, cx + 0.1, y2 + 0.9, y2 + 1.0, float(rm[2]) + 0.9, float(rm[2]) + 0.93, Color(0.9, 0.7, 0.2), 0)
			if not _rebuilding:
				_add_container("mansion_vault_%d" % maxi(int(b.get("vault", 0)), 0), _to_world(b, Vector3(cx, y2 + 1.4, float(rm[2]) + 0.5)), int(b.id), 5)
				containers[containers.size() - 1]["name"] = "Phòng kho của chủ nhà"
			continue
		match r.randi() % 4:
			0:      # phòng ngủ: giường lớn, tủ đầu giường
				_hb(mb, b, "wood", cx - 1.0, cx + 1.0, y2, y2 + 0.45, float(rm[2]) + 0.2, float(rm[2]) + 2.4, wood, 1)
				_hb(mb, b, "flat", cx - 0.95, cx + 0.95, y2 + 0.45, y2 + 0.62, float(rm[2]) + 0.25, float(rm[2]) + 2.35, Color(0.92, 0.9, 0.86), 0)
			1:      # phòng khách: sofa, bàn trà
				_hb(mb, b, "wood", cx - 1.4, cx + 1.4, y2, y2 + 0.45, float(rm[2]) + 0.3, float(rm[2]) + 1.1, Color(0.45, 0.3, 0.32), 1)
				_hb(mb, b, "wood", cx - 0.6, cx + 0.6, y2, y2 + 0.42, cz - 0.4, cz + 0.4, wood, 1)
			2:      # phòng làm việc: bàn, giá sách
				_hb(mb, b, "wood", cx - 0.9, cx + 0.9, y2, y2 + 0.78, cz - 0.5, cz + 0.5, wood, 1)
				_hb(mb, b, "wood", float(rm[0]) + 0.2, float(rm[0]) + 0.6, y2, y2 + 2.0, float(rm[2]) + 0.5, float(rm[3]) - 0.5, wood.darkened(0.2), 1)
			_:
				pass
		# tủ đồ: 1-2 cái mỗi phòng
		var cabs := 1 + r.randi() % 2 if depth > 3.0 else 1
		for cb in cabs:
			var tx := float(rm[1]) - 0.55 - cb * 1.3
			_hb(mb, b, "wood", tx - 0.5, tx + 0.5, y2, y2 + 1.8, float(rm[3]) - 0.65, float(rm[3]) - 0.15, wood.lightened(0.15), 1)
			if not _rebuilding:
				_add_container("mansion", _to_world(b, Vector3(tx, y2 + 1.0, float(rm[3]) - 0.4)), int(b.id), 3)
				containers[containers.size() - 1]["name"] = "Tủ đồ nhà giàu"


func _gondola(mb: MeshBuilder, b: Dictionary, x: float, y: float, zc: float, half: float) -> Dictionary:
	mb.collider(_to_world(b, Vector3(x, y + 0.9, zc)), Vector3(0.7, 1.8, half * 2.0), "wood", 1, _brot(b))
	_hb(mb, b, "paint", x - 0.03, x + 0.03, y, y + 1.8, zc - half, zc + half, Color(0.9, 0.88, 0.84), 0)
	for sh in 4:
		_hb(mb, b, "wood", x - 0.35, x + 0.35, y + 0.1 + sh * 0.45, y + 0.14 + sh * 0.45, zc - half, zc + half, Color(0.9, 0.82, 0.7), 0)
	return _shelf_layout(b, x, y, zc, half, [0.145, 0.595, 1.045, 1.495], [-0.19, 0.19])


## Bố cục bày hàng của một kệ, theo toạ độ thế giới: tâm chân kệ, trục dọc kệ, trục ngang, các tầng, các mặt.
func _shelf_layout(b: Dictionary, x: float, y: float, zc: float, half: float, levels: Array, sides: Array) -> Dictionary:
	var c := _to_world(b, Vector3(x, y, zc))
	var axis := (_to_world(b, Vector3(x, y, zc + 1.0)) - c).normalized()
	var side := (_to_world(b, Vector3(x + 1.0, y, zc)) - c).normalized()
	return {"c": c, "axis": axis, "side": side, "half": half, "levels": levels, "sides": sides}


func _add_npc(kind: String, pos: Vector3, building: int, yaw: float) -> void:
	if not _rebuilding:
		npc_spots.append({"kind": kind, "pos": pos, "building": building, "yaw": yaw})


func _add_container(table: String, pos: Vector3, building: int, count: int, shop := false, extra := {}) -> void:
	if _rebuilding:
		return
	var kind_name: String = CONTAINER_NAMES.get(table, "Kệ hàng")
	var con := {"id": containers.size(), "table": table, "pos": pos, "building": building, "count": count, "shop": shop, "name": kind_name}
	con.merge(extra)
	containers.append(con)


func _add_label(pos: Vector3, text: String, s: float, size: float, color: Color) -> void:
	if _rebuilding:
		return
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.rotation.y = 0.0 if s > 0.0 else PI
	if not is_nan(_label_yaw):
		l.rotation.y = _label_yaw
	l.pixel_size = size / 64.0
	l.font_size = 64
	l.modulate = color
	l.outline_size = 8
	l.outline_modulate = Color(0, 0, 0, 0.6)
	l.visibility_range_end = 70.0
	add_child(l)


# ------------------------------------------------------------------ đường phố: đèn, xe, thi thể, chốt chặn
func _build_streets() -> void:
	var node := Node3D.new()
	node.name = "Streets"
	add_child(node)
	var mb := MeshBuilder.new(node)
	# Đèn đường ở góc các khối nhà và giữa khối
	for r in ROWS:
		for c in COLS:
			var ck := cell_kind(Vector2i(c, r))
			if ck in ["lake", "forest", "field", "slum"]:
				continue
			var bc := block_center(c, r)
			for off: Vector2 in [Vector2(-1, -1), Vector2(1, 1), Vector2(0, -1), Vector2(0, 1)]:
				var p := Vector3(bc.x + off.x * (BW * 0.5 - 0.7), BASE, bc.z + off.y * (BD * 0.5 - 0.7))
				_lamp(mb, p, off.y)
			# Cây trên vỉa hè
			for i in 5:
				for sg: float in [-1.0, 1.0]:
					if rng.randf() < 0.4 or ck != "":
						continue
					var tp := Vector3(bc.x - BW * 0.5 + 6.0 + i * 11.0 + rng.randf_range(-1.5, 1.5), BASE, bc.z + sg * (BD * 0.5 - 0.9))
					_tree_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.25)), tp))
	# Xe máy dựng trên vỉa hè (lên xe được)
	for r2 in ROWS:
		for c2 in COLS:
			if cell_kind(Vector2i(c2, r2)) in ["lake", "forest", "field", "slum"]:
				continue
			var bc2 := block_center(c2, r2)
			for nb in 2 + rng.randi() % 2:
				var sgz := 1.0 if rng.randf() < 0.5 else -1.0
				bikes.append({"pos": Vector3(bc2.x + rng.randf_range(-BW * 0.45, BW * 0.45), BASE, bc2.z + sgz * (BD * 0.5 - 0.75)), "yaw": PI * 0.5 + rng.randf_range(-0.3, 0.3), "fuel": rng.randf_range(6.0, 30.0), "broken": rng.randf() < 0.55})
	# Xe đỗ / xe lật
	var car_colors := ["c8302a", "e8e2d4", "2f5fa8", "3a3d40", "d9a24a", "6a8a5a", "b8b8bc"]
	for k in 250:
		var horizontal := rng.randf() < 0.6
		var p2: Vector3
		var yaw: float
		if horizontal:
			var j := rng.randi() % (ROWS + 1)
			p2 = Vector3(rng.randf_range(bounds.position.x + 14.0, bounds.end.x - 14.0), 0.0, road_z(j) + (3.6 if rng.randf() < 0.5 else -3.6) * (1.0 if rng.randf() < 0.75 else 0.3))
			yaw = 0.0 if rng.randf() < 0.5 else PI
		else:
			var i2 := rng.randi() % (COLS + 1)
			p2 = Vector3(road_x(i2) + (3.6 if rng.randf() < 0.5 else -3.6), 0.0, rng.randf_range(bounds.position.y + 14.0, bounds.end.y - 14.0))
			yaw = PI * 0.5 if rng.randf() < 0.5 else -PI * 0.5
		if p2.distance_to(start_pos) < 16.0 or _near_underground(p2, 6.0) or in_zone(p2, 1.0):
			continue
		var toppled := rng.randf() < 0.28
		yaw += rng.randf_range(-0.5, 0.5) if toppled or rng.randf() < 0.3 else 0.0
		_car(mb, p2, yaw, Color(car_colors[rng.randi() % car_colors.size()]), toppled)
	# Thi thể dân thường (lục được đồ, đôi khi có đồng hồ định vị)
	for k in 100:
		var p3 := road_point(rng)
		if p3.distance_to(start_pos) < 20.0 or _near_underground(p3, 3.0) or in_zone(p3):
			continue
		_body(mb, p3, Color.from_hsv(rng.randf(), 0.35, 0.6), "civ_body")
	# Chốt quân đội bị phá: bao cát, hòm đạn, thi thể lính
	var cp := Vector3(road_x(5), 0.0, road_z(2) + 9.0)
	for i3 in 7:
		var bx := cp + Vector3(-5.4 + i3 * 1.8, 0.0, 0.0)
		if i3 == 3:
			continue
		mb.box("dirt", bx + Vector3(0, 0.45, 0), Vector3(1.7, 0.9, 0.8), Color(0.72, 0.68, 0.55))
	_car(mb, cp + Vector3(2.5, 0, 6.0), 0.4, Color("4a5a3a"), false, 1.25)
	for i4 in 4:
		_body(mb, cp + Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(2.0, 9.0)), Color("4a5a3a"), "sol_body")
	for tname: String in ["ammo", "army_med", "ration"]:
		var q := cp + Vector3(rng.randf_range(-5, 5), 0, rng.randf_range(1.5, 4.0))
		mb.box("wood", q + Vector3(0, 0.3, 0), Vector3(0.9, 0.6, 0.6), Color(0.45, 0.5, 0.35))
		_add_container(tname, q + Vector3(0, 0.75, 0), -1, 2 + rng.randi() % 2)
	# Đống đổ nát chắn đường
	# Các đống đổ nát lớn chắn ngang đường, giữa các khối nhà
	var blocked := 0
	for tries in 260:
		if blocked >= 38:
			break
		var along_x := rng.randf() < 0.55
		var bp: Vector3
		if along_x:
			bp = Vector3(block_center(rng.randi() % COLS, 0).x + rng.randf_range(-12.0, 12.0), 0.0, road_z(rng.randi() % (ROWS + 1)))
		else:
			bp = Vector3(road_x(rng.randi() % (COLS + 1)), 0.0, block_center(0, rng.randi() % ROWS).z + rng.randf_range(-10.0, 10.0))
		if bp.distance_to(start_pos) < 45.0 or bp.distance_to(home_pos) < 30.0 or bp.distance_to(cp) < 25.0 or _near_underground(bp, 12.0) or in_zone(bp, 14.0):
			continue
		var clash := false
		for r0 in barricades:
			if r0.grow(40.0).has_point(Vector2(bp.x, bp.z)):
				clash = true
		if clash:
			continue
		_barricade(mb, bp, along_x)
		blocked += 1
	# Người bị thương ngồi bên đường, cần giúp
	for k5 in 34:
		var hp := road_point(rng)
		var side_z := rng.randf() < 0.5
		hp += Vector3(0.0 if side_z else (6.2 if rng.randf() < 0.5 else -6.2), 0.0, (6.2 if rng.randf() < 0.5 else -6.2) if side_z else 0.0)
		if hp.distance_to(start_pos) > 25.0 and not _near_underground(hp, 4.0) and on_road(hp) and not in_zone(hp, 1.0):
			_add_npc("hurt", hp, -1, rng.randf() * TAU)
	for k2 in 62:
		var p4 := road_point(rng)
		if p4.distance_to(start_pos) < 18.0 or p4.distance_to(cp) < 15.0 or _near_underground(p4, 8.0) or in_zone(p4, 2.0) or near_rail_stair(p4, 5.0):
			continue
		for m in 7:
			var sz := Vector3(rng.randf_range(0.6, 2.4), rng.randf_range(0.3, 1.1), rng.randf_range(0.6, 2.0))
			var q2 := p4 + Vector3(rng.randf_range(-3.5, 3.5), sz.y * 0.5 - 0.05, rng.randf_range(-2.5, 2.5))
			mb.box("concrete" if rng.randf() < 0.7 else "brick", q2, sz, Color(0.8, 0.78, 0.75), 1, "ext", Basis.from_euler(Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.2, 0.2))))
	mb.commit()
	# Bóng đèn (bật khi trời tối)
	for lp in lamps:
		var light := OmniLight3D.new()
		light.position = lp
		light.light_color = Color("ffd49a")
		light.omni_range = 22.0
		light.light_energy = 0.0
		light.shadow_enabled = false
		light.distance_fade_enabled = true
		light.distance_fade_begin = 70.0
		light.distance_fade_length = 20.0
		light.visible = false
		node.add_child(light)
		lamp_lights.append(light)


func _near_underground(p: Vector3, margin: float) -> bool:
	for ch in chasms:
		if (ch.rect as Rect2).grow(margin).has_point(Vector2(p.x, p.z)):
			return true
	for ex: float in tunnel.entrances:
		if Rect2(ex, float(tunnel.z) - 1.2, 7.4, 2.4).grow(margin).has_point(Vector2(p.x, p.z)):
			return true
	return false


## Điểm này có nằm trên lối lên ga (cầu thang + 2,5m quanh đó) không: không đặt đèn, xe, đống đổ nát chắn lối.
func near_rail_stair(p: Vector3, margin := 2.6) -> bool:
	if rail == null or rail.stations.is_empty():
		return false
	var q := Vector2(p.x, p.z)
	for st: Dictionary in rail.stations:
		for k in 2:
			if not st.has("stair_base2") and k == 1:
				continue
			var a3: Vector3 = st.stair_base if k == 0 else st.stair_base2
			var b3: Vector3 = st.stair_top if k == 0 else st.stair_top2
			var a := Vector2(a3.x, a3.z) - Vector2(b3.x - a3.x, b3.z - a3.z).normalized() * 3.0
			var b := Vector2(b3.x, b3.z)
			var ab := b - a
			var t := clampf((q - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			if (a + ab * t).distance_to(q) < margin:
				return true
	return false


func _lamp(mb: MeshBuilder, p: Vector3, dir_z: float) -> void:
	if near_rail_stair(p):
		return
	var grey := Color(0.35, 0.36, 0.38)
	mb.box("metal", p + Vector3(0, 3.0, 0), Vector3(0.16, 6.0, 0.16), grey, 2)
	mb.box("metal", p + Vector3(0, 5.95, dir_z * 0.9), Vector3(0.1, 0.1, 1.8), grey, 0)
	mb.box("emit", p + Vector3(0, 5.86, dir_z * 1.6), Vector3(0.3, 0.1, 0.6), Color(1.0, 0.85, 0.6), 0)
	lamps.append(p + Vector3(0, 5.6, dir_z * 1.6))


## Mỗi chiếc xe là một nút riêng (để Thủy Quái giẫm bẹp được).
func _car(_mb: MeshBuilder, p: Vector3, yaw: float, color: Color, toppled: bool, scale := 1.0) -> void:
	if near_rail_stair(p, 4.0):
		return
	var node := Node3D.new()
	node.name = "Car%d" % cars.size()
	node.position = p
	add_child(node)
	var mb := MeshBuilder.new(node)
	var basis := Basis(Vector3.UP, yaw)
	var lift := 0.0
	if toppled:
		basis = basis * Basis(Vector3(1, 0, 0), PI * 0.5 * (1.0 if rng.randf() < 0.5 else -1.0))
		lift = 0.55 * scale
	var xf := Transform3D(basis.scaled(Vector3.ONE * scale), Vector3(0, lift, 0))
	var parts := [
		["paint", Vector3(0, 0.62, 0), Vector3(1.75, 0.6, 4.2), color, 1],
		["paint", Vector3(0, 1.2, -0.25), Vector3(1.6, 0.58, 2.2), color.darkened(0.08), 1],
		["glass", Vector3(0, 1.2, -0.25), Vector3(1.62, 0.44, 2.0), Color.WHITE, 0],
		["dark", Vector3(0, 0.3, 0), Vector3(1.6, 0.1, 3.9), Color(0.08, 0.08, 0.09), 0],
	]
	for wx: float in [-0.85, 0.85]:
		for wz: float in [-1.35, 1.35]:
			parts.append(["dark", Vector3(wx, 0.33, wz), Vector3(0.24, 0.66, 0.66), Color(0.07, 0.07, 0.08), 0])
	for part: Array in parts:
		var size: Vector3 = part[2]
		mb.box(part[0], xf * (part[1] as Vector3), size * scale, part[3], part[4], "ext", basis)
	mb.commit()
	cars.append({"pos": p, "yaw": yaw, "node": node, "crushed": false})


## Xe trong bán kính quanh `pos` bị giẫm bẹp. Trả về chỉ số các xe vừa bị bẹp.
func crush_cars(pos: Vector3, radius: float) -> Array:
	var out := []
	for i in cars.size():
		var car: Dictionary = cars[i]
		if car.crushed or Vector2(car.pos.x - pos.x, car.pos.z - pos.z).length() > radius:
			continue
		car.crushed = true
		var n: Node3D = car.node
		n.scale = Vector3(1.15, 0.22, 1.1)
		n.rotation.z = 0.06
		out.append(i)
	return out


## Thi thể nằm trên đường (hình người, lục được đồ).
func _body(mb: MeshBuilder, p: Vector3, color: Color, table: String) -> void:
	var yaw := rng.randf() * TAU
	mb.box("flat", p + Vector3(0.1, 0.006, 0.1), Vector3(1.5, 0.01, 1.3), Color(0.35, 0.05, 0.05), 0, "ext", Basis(Vector3.UP, yaw * 0.7))
	corpses.append({"pos": p, "yaw": yaw, "color": color})
	_add_container(table, p + Vector3(0, 0.35, 0), -1, 2 + rng.randi() % 2)


## Nhà của bạn sau khi sập (chương 2): tường bao còn trơ lại một tầng, cửa trước và cửa sau còn lối đi,
## gạch đá dồn về các góc; khoảng giữa nhà (chỗ nắp hầm) và lối ra cửa sau được dọn trống.
func _home_ruin(mb: MeshBuilder, b: Dictionary, hw: float, d: float, col: Color) -> void:
	_hb(mb, b, "concrete", -hw + T, hw - T, 0, 0.05, -d + T, -T, Color(0.6, 0.58, 0.55), 1, "ext")
	for sx: float in [-1.0, 1.0]:
		_hb(mb, b, "plaster", sx * (hw - T) - T, sx * (hw - T) + T, 0, rng.randf_range(2.2, 3.6), -d, 0, col, 1, "ext")
	# tường trước: chừa lối cửa chính; tường sau: chừa cửa sau ra sân
	_hb(mb, b, "plaster", -hw, -0.9, 0, 2.6, -T, 0, col, 1, "ext")
	_hb(mb, b, "plaster", 0.9, hw, 0, 1.8, -T, 0, col, 1, "ext")
	_hb(mb, b, "plaster", -hw, 0.2, 0, 2.2, -d, -d + T, col, 1, "ext")
	_hb(mb, b, "plaster", 1.8, hw, 0, 3.0, -d, -d + T, col, 1, "ext")
	var hatch_l := Vector2(0.2, -9.6)
	for m in 40:
		var sz := Vector3(rng.randf_range(0.5, 1.8), rng.randf_range(0.2, 0.8), rng.randf_range(0.5, 1.6))
		var lx := rng.randf_range(-hw + 0.6, hw - 0.6)
		var lz := rng.randf_range(-d + 0.6, -0.6)
		# dọn trống: quanh nắp hầm, lối từ cửa chính vào, lối ra cửa sau
		if Vector2(lx, lz).distance_to(hatch_l) < 2.2 or absf(lx) < 1.3 or (absf(lx - 1.0) < 1.4 and lz < -d + 4.0):
			continue
		var q := _to_world(b, Vector3(lx, sz.y * 0.5, lz))
		var mat := "concrete" if rng.randf() < 0.5 else ("brick" if rng.randf() < 0.5 else "plaster")
		mb.box(mat, q, sz, col if mat == "plaster" else Color(0.78, 0.75, 0.7), 1 if sz.y > 0.5 else 0, "ext", Basis.from_euler(Vector3(rng.randf_range(-0.25, 0.25), rng.randf() * TAU, rng.randf_range(-0.25, 0.25))))
	# một mảng sàn tầng trên sập chéo xuống góc nhà
	_hb(mb, b, "concrete", -hw + T, -0.6, 0.0, 0.25, -d + 1.0, -d + 5.0, Color(0.7, 0.68, 0.64), 0, "ext")


## Đống đổ nát cao chắn ngang đường (không trèo qua được): chỉ còn một lối hẹp sát mép vỉa hè, hoặc phải đi vòng / xuyên qua nhà.
func _barricade(mb: MeshBuilder, p: Vector3, along_x: bool) -> void:
	var gap_side := 1.0 if rng.randf() < 0.5 else -1.0
	var span := ROAD + 2.4          # chắn lòng đường + một bên vỉa hè
	var across := Vector3(0, 0, 1) if along_x else Vector3(1, 0, 0)
	var along := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
	var centre := p - across * gap_side * 1.2
	var size := Vector3(4.5, 3.4, span) if along_x else Vector3(span, 3.4, 4.5)
	mb.collider(centre + Vector3(0, 1.7, 0), size, "concrete", 2)
	barricades.append(Rect2(centre.x - size.x * 0.5, centre.z - size.z * 0.5, size.x, size.z))
	for m in 46:
		var sz := Vector3(rng.randf_range(1.0, 3.4), rng.randf_range(0.4, 1.4), rng.randf_range(1.0, 3.0))
		var h := rng.randf() * rng.randf() * 3.2
		var q := centre + across * rng.randf_range(-span * 0.5, span * 0.5) + along * rng.randf_range(-2.2, 2.2) * (1.0 - h / 4.0) + Vector3(0, h + sz.y * 0.4, 0)
		var mat := "concrete" if rng.randf() < 0.5 else ("brick" if rng.randf() < 0.5 else "plaster")
		mb.box(mat, q, sz, Color(HOUSE_COLORS[rng.randi() % HOUSE_COLORS.size()]) if mat == "plaster" else Color(0.78, 0.75, 0.7), 0, "ext", Basis.from_euler(Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4))))
	# một xe bị vùi
	_car(mb, centre + along * 3.2 + across * rng.randf_range(-3.0, 3.0), rng.randf() * TAU, Color("6a727c"), true)


## Tầng hầm để xe dưới trung tâm thương mại: xuống bằng dốc ở đầu phía tây trong toà nhà.
func _build_parking(mb: MeshBuilder, b: Dictionary) -> void:
	var hw: float = b.w * 0.5
	var d: float = b.d
	var o: Vector3 = b.origin
	var fl := PARK_FLOOR
	var grey := Color(0.7, 0.7, 0.68)
	var cx := o.x
	var cz := o.z - d * 0.5
	mb.box("concrete", Vector3(cx, fl - 0.2, cz), Vector3(b.w, 0.4, d), Color(0.62, 0.62, 0.6), 1, "ext", Basis.IDENTITY, "concrete")
	for sg: float in [-1.0, 1.0]:
		mb.box("concrete", Vector3(cx + sg * hw, (fl - 1.0) * 0.5, cz), Vector3(0.3, -1.0 - fl, d), grey)
		mb.box("concrete", Vector3(cx, (fl - 1.0) * 0.5, cz + sg * d * 0.5), Vector3(b.w, -1.0 - fl, 0.3), grey)
	var px := -hw + 8.0
	while px < hw - 3.0:
		for pz: float in [-d * 0.3, d * 0.3]:
			mb.box("concrete", Vector3(cx + px, (fl - 1.0) * 0.5, cz + pz), Vector3(0.7, -1.0 - fl, 0.7), grey)
		mb.box("emit", Vector3(cx + px + 4.0, -1.06, cz), Vector3(2.4, 0.06, 0.2), Color(0.75, 0.8, 0.7), 0)
		px += 8.0
	# dốc xuống: từ z=-4 (mặt sàn trệt) tới z=-14 (sàn hầm)
	var run := 10.0
	var rise := BASE - fl
	var ang := atan2(rise, run)
	var rot := Basis(Vector3(1, 0, 0), -ang)
	var mid := Vector3(cx - hw + 3.0, (BASE + fl) * 0.5, o.z - 9.0)
	mb.box("concrete", mid - (rot * Vector3.UP) * 0.15, Vector3(3.8, 0.3, sqrt(run * run + rise * rise)), Color(0.66, 0.66, 0.64), 1, "ext", rot, "concrete")
	# lan can quanh miệng dốc
	mb.box("concrete", Vector3(cx - hw + 5.1, BASE + 0.45, o.z - 9.0), Vector3(0.2, 0.9, 10.2), grey)
	mb.box("concrete", Vector3(cx - hw + 3.0, BASE + 0.45, o.z - 14.1), Vector3(4.2, 0.9, 0.2), grey)
	_add_label(Vector3(cx - hw + 3.0, BASE + 2.6, o.z - 3.6), "↓ TẦNG HẦM ĐỂ XE", 1.0, 0.3, Color(1, 0.9, 0.5))
	# xe đỗ + đồ để lục
	var colors := ["c8302a", "e8e2d4", "2f5fa8", "3a3d40", "d9a24a", "6a8a5a"]
	for k in 12:
		var vx := -hw + 9.0 + (k % 6) * 6.2
		var vz := -d * 0.5 + (4.0 if k < 6 else d - 4.0)
		_car(mb, Vector3(cx + vx, fl, o.z + vz - d * 0.5 + d * 0.5), PI * 0.5 if k % 2 == 0 else -PI * 0.5, Color(colors[rng.randi() % colors.size()]), false)
	for k2 in 7:
		var q := Vector3(cx + rng.randf_range(-hw + 8.0, hw - 2.0), fl, cz + rng.randf_range(-d * 0.35, d * 0.35))
		mb.box("wood", q + Vector3(0, 0.3, 0), Vector3(0.9, 0.6, 0.6), Color(0.75, 0.68, 0.55))
		_add_container(["street", "k_fuel", "k_parts", "ration"][k2 % 4], q + Vector3(0, 0.8, 0), -1, 2 + rng.randi() % 2)


func _build_trees() -> void:
	if _tree_xf.is_empty():
		return
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.14
	trunk.bottom_radius = 0.22
	trunk.height = 3.2
	trunk.radial_segments = 7
	var tm := StandardMaterial3D.new()
	tm.albedo_texture = Mats.tex("res://assets/tex/wood_color.jpg")
	tm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	tm.albedo_color = Color(0.45, 0.36, 0.3)
	tm.uv1_scale = Vector3(1, 2, 1)
	trunk.material = tm
	var crown := SphereMesh.new()
	crown.radius = 1.9
	crown.height = 3.2
	crown.radial_segments = 10
	crown.rings = 6
	var cm := ShaderMaterial.new()
	cm.shader = load("res://shaders/foliage.gdshader")
	crown.material = cm
	for pair: Array in [[trunk, 1.6], [crown, 4.3]]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = pair[0]
		mm.instance_count = _tree_xf.size()
		for i in _tree_xf.size():
			var xf := _tree_xf[i]
			mm.set_instance_transform(i, Transform3D(xf.basis, xf.origin + Vector3(0, float(pair[1]) * xf.basis.get_scale().y, 0)))
		tree_mm.append(mm)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.name = "Trees"
		add_child(mmi)
	var body := StaticBody3D.new()
	body.name = "TreeTrunks"
	body.collision_layer = 2
	body.collision_mask = 0
	body.set_meta("surface", "wood")
	add_child(body)
	var shape := CylinderShape3D.new()
	shape.radius = 0.24
	shape.height = 3.2
	for xf2 in _tree_xf:
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = xf2.origin + Vector3(0, 1.6, 0)
		body.add_child(cs)


# ------------------------------------------------------------------ tiện ích cho quái vật / nhiệm vụ / bản đồ
## Một điểm ngẫu nhiên trên lòng đường (không rơi vào công viên hồ: ở đó không còn đường).
func road_point(r: RandomNumberGenerator) -> Vector3:
	for attempt in 12:
		var p: Vector3
		if r.randf() < 0.6:
			p = Vector3(r.randf_range(bounds.position.x + 16.0, bounds.end.x - 16.0), 0.0, road_z(r.randi() % (ROWS + 1)) + r.randf_range(-4.0, 4.0))
		else:
			p = Vector3(road_x(r.randi() % (COLS + 1)) + r.randf_range(-4.0, 4.0), 0.0, r.randf_range(bounds.position.y + 16.0, bounds.end.y - 16.0))
		if not in_closed(p, 1.0):
			return p
	return Vector3(road_x(0), 0.0, road_z(0))


## Điểm gần nhất nằm trên tim một con đường (đường nằm trong công viên hồ, khu tập thể thì không tính).
func road_project(p: Vector3) -> Vector3:
	var best := p
	var best_d := 1e9
	var zones: Array[Rect2] = []
	for z: Rect2i in closed_zones():
		zones.append(zone_rect(z))
	for j in ROWS + 1:
		var q := Vector3(clampf(p.x, road_x(0), road_x(COLS)), 0.0, road_z(j))
		for lz in zones:
			if lz.has_point(Vector2(q.x, q.z)):
				q.x = lz.position.x - ROAD * 0.5 if absf(q.x - lz.position.x) < absf(q.x - lz.end.x) else lz.end.x + ROAD * 0.5
		var d := q.distance_to(Vector3(p.x, 0.0, p.z))
		if d < best_d:
			best_d = d
			best = q
	for i in COLS + 1:
		var q2 := Vector3(road_x(i), 0.0, clampf(p.z, road_z(0), road_z(ROWS)))
		for lz2 in zones:
			if lz2.has_point(Vector2(q2.x, q2.z)):
				q2.z = lz2.position.y - ROAD * 0.5 if absf(q2.z - lz2.position.y) < absf(q2.z - lz2.end.y) else lz2.end.y + ROAD * 0.5
		var d2 := q2.distance_to(Vector3(p.x, 0.0, p.z))
		if d2 < best_d:
			best_d = d2
			best = q2
	return best


## Ngã tư này còn dùng được không (ngã tư giữa công viên hồ đã chìm dưới nước).
func node_open(n: Vector2i) -> bool:
	if n.x < 0 or n.y < 0 or n.x > COLS or n.y > ROWS:
		return false
	for z: Rect2i in closed_zones():
		if n.x > z.position.x and n.x < z.end.x and n.y > z.position.y and n.y < z.end.y:
			return false
	return true


## Đoạn đường giữa hai ngã tư kề nhau còn đi được không (đoạn nằm trong công viên hồ hay khu ngõ ngách thì đã mất).
func edge_open(a: Vector2i, b: Vector2i) -> bool:
	for z: Rect2i in closed_zones():
		if a.x == b.x:
			if z.position.x < a.x and a.x < z.end.x and z.position.y <= mini(a.y, b.y) and maxi(a.y, b.y) <= z.end.y:
				return false
		elif z.position.y < a.y and a.y < z.end.y and z.position.x <= mini(a.x, b.x) and maxi(a.x, b.x) <= z.end.x:
			return false
	return true


## Ngã tư gần nhất (chỉ số i, j).
func nearest_node(p: Vector3) -> Vector2i:
	var n := Vector2i(clampi(roundi(p.x / PX + COLS * 0.5), 0, COLS), clampi(roundi(p.z / PZ + ROWS * 0.5), 0, ROWS))
	if node_open(n):
		return n
	var best := n
	var best_d := 1e9
	for off: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
		var q := n + off
		if node_open(q) and node_pos(q).distance_to(p) < best_d:
			best_d = node_pos(q).distance_to(p)
			best = q
	return best


func node_pos(n: Vector2i) -> Vector3:
	return Vector3(road_x(n.x), 0.0, road_z(n.y))


## Đoạn thẳng a-b có cắt qua công viên hồ không?
func crosses_lake(a: Vector3, b: Vector3) -> bool:
	for k in 13:
		var p := a.lerp(b, k / 12.0)
		if in_closed(p, -1.0):
			return true
	return false


## Đường đi dọc theo lưới đường từ a tới b (danh sách điểm), vòng tránh công viên hồ.
func road_route(a: Vector3, b: Vector3, r: RandomNumberGenerator = null) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var start := nearest_node(a)
	var goal := nearest_node(b)
	var prev: Dictionary = {start: start}
	var queue: Array[Vector2i] = [start]
	var offs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var head := 0
	while head < queue.size() and not prev.has(goal):
		var n := queue[head]
		head += 1
		# ưu tiên bước làm gần đích hơn; có r thì xáo ngẫu nhiên để mỗi lần đi một ngả
		var order := offs.duplicate()
		if r and r.randf() < 0.5:
			order.reverse()
		for off: Vector2i in order:
			var q := n + off
			if node_open(q) and not prev.has(q) and edge_open(n, q):
				prev[q] = n
				queue.append(q)
	var path: Array[Vector2i] = []
	if prev.has(goal):
		var n2 := goal
		while n2 != start:
			path.push_front(n2)
			n2 = prev[n2]
	path.push_front(start)
	for n3 in path:
		out.append(node_pos(n3))
	out.append(Vector3(b.x, 0.0, b.z))
	return out


## Đoạn đường gần điểm p nhất: [ngã tư u, ngã tư v, điểm chiếu của p lên đoạn u-v].
func _nearest_edge(p: Vector3) -> Array:
	var c := Vector2i(clampi(floori(p.x / PX + COLS * 0.5), 0, COLS), clampi(floori(p.z / PZ + ROWS * 0.5), 0, ROWS))
	var best: Array = []
	var best_d := 1e18
	for i in range(c.x - 2, c.x + 3):
		for j in range(c.y - 2, c.y + 3):
			var u := Vector2i(i, j)
			if not node_open(u):
				continue
			for off: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				var v := u + off
				if not node_open(v) or not edge_open(u, v):
					continue
				var pu := node_pos(u)
				var pv := node_pos(v)
				var seg := pv - pu
				var t := clampf((p - pu).dot(seg) / seg.length_squared(), 0.0, 1.0)
				var q := pu + seg * t
				var d := Vector2(p.x - q.x, p.z - q.z).length_squared()
				if d < best_d:
					best_d = d
					best = [u, v, Vector3(q.x, 0.0, q.z)]
	if best.is_empty():
		var n := nearest_node(p)
		best = [n, n, node_pos(n)]
	return best


const _TURN_COST := 45.0
var _adj: Dictionary = {}      # ngã tư -> các hướng đi được (tính một lần)
var _guide_key := []
var _guide_cache: Array[Vector3] = []


## Đường chỉ dẫn cho người chơi (bản đồ, la bàn): đi theo mặt đường từ đúng chỗ đang đứng, ưu tiên ít ngã rẽ
## (mỗi lần rẽ tính thêm 45m), rồi bo tròn các góc cua cho mềm. Kết quả được nhớ lại khi người chơi chưa đi xa.
func guide_route(a: Vector3, b: Vector3) -> Array[Vector3]:
	if _guide_key.size() == 2 and (_guide_key[0] as Vector3).distance_to(a) < 4.0 and (_guide_key[1] as Vector3).distance_to(b) < 1.0:
		var keep: Array[Vector3] = _guide_cache.duplicate()
		keep[0] = Vector3(a.x, 0.0, a.z)
		return keep
	var ea := _nearest_edge(a)
	var eb := _nearest_edge(b)
	var pa: Vector3 = ea[2]
	var pb: Vector3 = eb[2]
	var raw: Array[Vector3] = [Vector3(a.x, 0.0, a.z), pa]
	var same: bool = ea[0] == eb[0] and ea[1] == eb[1]
	if not same:
		# Dijkstra trên (ngã tư, hướng đi vào): rẽ thì cộng thêm phí
		var dist: Dictionary = {}
		var prev: Dictionary = {}
		var open: Array = []
		for n0: Vector2i in [ea[0], ea[1]]:
			var k0 := [n0, Vector2i.ZERO]
			var c0 := pa.distance_to(node_pos(n0))
			if c0 < float(dist.get(k0, 1e18)):
				dist[k0] = c0
				open.append(k0)
		var goal_k: Array = []
		var goal_c := 1e18
		var offs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		while not open.is_empty():
			var bi := 0
			for q in open.size():
				if float(dist[open[q]]) < float(dist[open[bi]]):
					bi = q
			var k: Array = open[bi]
			open.remove_at(bi)
			var cost: float = dist[k]
			if cost >= goal_c:
				break
			var n: Vector2i = k[0]
			if n == eb[0] or n == eb[1]:
				var fin := cost + node_pos(n).distance_to(pb)
				if fin < goal_c:
					goal_c = fin
					goal_k = k
			if not _adj.has(n):
				var ok_offs: Array[Vector2i] = []
				for o2: Vector2i in offs:
					if node_open(n + o2) and edge_open(n, n + o2):
						ok_offs.append(o2)
				_adj[n] = ok_offs
			for off: Vector2i in _adj[n]:
				var m := n + off
				var dir: Vector2i = k[1]
				var c := cost + node_pos(n).distance_to(node_pos(m)) + (_TURN_COST if dir != Vector2i.ZERO and dir != off else 0.0)
				var km := [m, off]
				if c < float(dist.get(km, 1e18)):
					dist[km] = c
					prev[km] = k
					if not open.has(km):
						open.append(km)
		var nodes: Array[Vector3] = []
		var kk: Array = goal_k
		while not kk.is_empty():
			nodes.push_front(node_pos(kk[0]))
			kk = prev.get(kk, [])
		raw.append_array(nodes)
	raw.append(pb)
	raw.append(Vector3(b.x, 0.0, b.z))
	# bỏ các điểm trùng nhau và các điểm nằm thẳng hàng (đi tới rồi quay ngược lại cùng một đoạn)
	var pts: Array[Vector3] = []
	for p in raw:
		if pts.is_empty() or pts[-1].distance_to(p) > 0.5:
			pts.append(p)
	var k2 := 1
	while k2 < pts.size() - 1:
		var d1 := (pts[k2] - pts[k2 - 1]).normalized()
		var d2 := (pts[k2 + 1] - pts[k2]).normalized()
		if d1.dot(d2) < -0.95 or d1.dot(d2) > 0.999:
			pts.remove_at(k2)
			k2 = maxi(1, k2 - 1)
		else:
			k2 += 1
	# bo góc: mỗi chỗ rẽ thay bằng một cung cong bậc hai
	var out: Array[Vector3] = [pts[0]]
	for i2 in range(1, pts.size() - 1):
		var pp := pts[i2]
		var r := minf(20.0, minf(pp.distance_to(pts[i2 - 1]), pp.distance_to(pts[i2 + 1])) * 0.45)
		var p1 := pp + (pts[i2 - 1] - pp).normalized() * r
		var p2 := pp + (pts[i2 + 1] - pp).normalized() * r
		for s2 in 9:
			var t2 := s2 / 8.0
			out.append(p1.lerp(pp, t2).lerp(pp.lerp(p2, t2), t2))
	if pts.size() > 1:
		out.append(pts[-1])
	_guide_key = [a, b]
	_guide_cache = out
	return out


## Điểm này có nằm trên lòng đường không (không phải trong khối nhà)?
func on_road(p: Vector3) -> bool:
	if in_closed(p):
		return false
	for i in COLS + 1:
		if absf(p.x - road_x(i)) < ROAD * 0.5:
			return true
	for j in ROWS + 1:
		if absf(p.z - road_z(j)) < ROAD * 0.5:
			return true
	return false


func building_at(p: Vector3) -> Dictionary:
	var q := Vector2(p.x, p.z)
	for b in buildings:
		if (b.rect as Rect2).has_point(q) and not b.get("ruined", false):
			return b
	return {}
