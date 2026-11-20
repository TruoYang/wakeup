extends Node
func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	var city := City.new()
	add_child(city)
	city.build(20261111)
	var shops := {}
	for b in city.buildings:
		if b.kind == "shop":
			shops[b.shop] = shops.get(b.shop, 0) + 1
	var shapes := 0
	for body in city.find_children("Col_*", "StaticBody3D", true, false):
		shapes += body.get_child_count()
	print("dựng thành phố: %d ms · nhà: %d · cửa hàng: %s · chỗ lục đồ: %d · vùng va chạm: %d · đèn: %d" % [Time.get_ticks_msec() - t0, city.buildings.size(), str(shops), city.containers.size(), shapes, city.lamps.size()])
	print("xuất phát: %s · nhà: %s · ông Tư: %s · hồ: %s" % [city.start_pos, city.home_pos, city.tu_pos, city.lake_rect])
	print("thuốc ở tủ khoá: %d · két bệnh viện: %d (mã %s) · trạm phát sóng: %s · công trình: %s" % [city.school_med_cid, city.hospital_safe_cid, city.hospital_safe_code, city.tower_pos, city.landmarks.map(func(l: Dictionary) -> String: return str(l.name))])
	get_tree().quit()
