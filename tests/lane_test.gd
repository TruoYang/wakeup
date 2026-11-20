extends Node
## Kiểm tra hẻm sau khu dân cư: không đi thẳng một mạch được, nhưng vẫn có đường lách qua (không bị bịt kín).

func _ready() -> void:
	var city := City.new()
	add_child(city)
	city.build(20261111)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := get_viewport().world_3d.direct_space_state
	var straight_blocked := 0
	var passable := 0
	var blocks := 0
	for r in City.ROWS:
		for c in City.COLS:
			var cell := Vector2i(c, r)
			if City.is_commercial(cell) or cell in [City.LAKE_BLOCK, City.OFFICE_BLOCK, City.MALL_BLOCK]:
				continue
			blocks += 1
			var bc := City.block_center(c, r)
			# 1) đi thẳng dọc giữa hẻm từ đầu này tới đầu kia: phải bị chặn
			var q := PhysicsRayQueryParameters3D.create(Vector3(bc.x - City.BW * 0.5 + 2.0, 1.0, bc.z), Vector3(bc.x + City.BW * 0.5 - 2.0, 1.0, bc.z), 3)
			if not space.intersect_ray(q).is_empty():
				straight_blocked += 1
			# 2) vẫn lách qua được: loang trên lưới 1m trong hẻm, xem có nối được hai đầu không
			var x0 := bc.x - City.BW * 0.5 + 2.0
			var z0 := bc.z - 9.0
			var w := int(City.BW - 4.0)
			var d := 18
			var free := []
			for i in w * d:
				var px := x0 + (i % w) + 0.5
				var pz := z0 + (i / w) + 0.5
				var sp := PhysicsShapeQueryParameters3D.new()
				var cap := CapsuleShape3D.new()
				cap.radius = 0.32
				cap.height = 1.7
				sp.shape = cap
				sp.transform = Transform3D(Basis.IDENTITY, Vector3(px, 1.2, pz))
				sp.collision_mask = 3
				free.append(space.intersect_shape(sp, 1).is_empty())
			var seen := {}
			var stack := []
			for k in d:
				if free[k * w + 2]:
					stack.append(k * w + 2)
			var reached := false
			while not stack.is_empty():
				var cur: int = stack.pop_back()
				if seen.has(cur):
					continue
				seen[cur] = true
				if cur % w >= w - 3:
					reached = true
					break
				for off: int in [1, -1, w, -w]:
					var nx := cur + off
					if nx >= 0 and nx < w * d and free[nx] and absi((nx % w) - (cur % w)) <= 1:
						stack.append(nx)
			if reached:
				passable += 1
	print("khối dân cư: %d · hẻm không đi thẳng một mạch được: %d · vẫn lách qua được từ đầu này sang đầu kia: %d · số khối cơi nới: %d" % [blocks, straight_blocked, passable, city.extras.size()])
	get_tree().quit()
