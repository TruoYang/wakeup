extends Node
## Đồ trên kệ giữ nguyên chỗ: lấy một món thì các món khác không xê dịch.

func _ready() -> void:
	var main: Node3D = (load("res://levels/main.tscn") as PackedScene).instantiate()
	add_child(main)
	for i in 20:
		await get_tree().physics_frame
	var loot: Node = main.loot
	var p: CharacterBody3D = main.local_player()
	Game.god = true
	# tìm một kệ có từ 4 món trở lên
	var cid := -1
	for c: int in loot.info:
		var con: Dictionary = loot.info[c]
		if con.has("shelf") and loot._items_of(c).size() >= 4:
			cid = c
			break
	var ok := cid >= 0
	p.global_position = (loot.info[cid].pos as Vector3) + Vector3(0, 0.3, 2.5)
	for i in 60:
		await get_tree().physics_frame
	var before := {}
	for e: Dictionary in loot.shown.get(cid, []):
		before[e.node.get_instance_id()] = [e.item, (e.node as Node3D).global_position]
	var items: Array = loot._items_of(cid).duplicate()
	var take_item: String = items[1]
	loot.take(cid, take_item)
	for i in 20:
		await get_tree().physics_frame
	var after: Array = loot.shown.get(cid, [])
	# các món còn lại: vị trí phải trùng với một vị trí cũ của cùng loại món
	var moved := 0
	var old_pos: Array = before.values()
	for e2: Dictionary in after:
		var found := false
		for op: Array in old_pos:
			if op[0] == e2.item and (op[1] as Vector3).distance_to((e2.node as Node3D).global_position) < 0.01:
				found = true
		if not found:
			moved += 1
	print("kệ %d: %d món trước, %d món sau, %d món bị xê dịch" % [cid, before.size(), after.size(), moved])
	ok = ok and after.size() == before.size() - 1 and moved == 0
	print("KẾT QUẢ: ", "TẤT CẢ ĐẠT" if ok else "THẤT BẠI")
	get_tree().quit(0 if ok else 1)
