extends Node
## Chạy dài: người chơi bị đưa đi khắp thành phố trong khi quái vật, dân thường, thời tiết, phá nhà đều hoạt động. Mục đích: bắt lỗi phát sinh khi chơi lâu.

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var main: Node3D = (load("res://levels/main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.home_known = true      # bỏ qua đoạn nhân vật suy nghĩ lúc Thủy Quái trồi lên (dừng cảnh khi chơi một mình)
	for i in 20:
		await get_tree().physics_frame
	var p: CharacterBody3D = main.local_player()
	var city: City = main.city
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	main.play_time = 26.0
	var deaths := 0
	var hunted_frames := 0
	var clip_frames := 0
	var max_ms := 0.0
	Input.action_press("move_forward")
	for f in 10800:
		var t0 := Time.get_ticks_usec()
		await get_tree().physics_frame
		max_ms = maxf(max_ms, (Time.get_ticks_usec() - t0) / 1000.0)
		if f % 420 == 0:
			var q := city.road_point(rng)
			p.global_position = q + Vector3(0, 0.3, 0)
			p.rotation.y = rng.randf() * TAU
			Input.action_press("sprint") if f % 840 == 0 else Input.action_release("sprint")
		if f % 2400 == 1200:
			main.weather.hour = 22.0 if main.weather.hour < 20.0 else 9.0
			main.weather.set_kind(["rain", "storm", "fog", "clear"][(f / 2400) % 4])
		if Game.hunted:
			hunted_frames += 1
		if Game.dead:
			deaths += 1
			Game.reset()
		# đầu Săn Mồi có nằm trong nhà nào không?
		if f % 10 == 0:
			for m: Monster in main.monsters.list:
				if m.kind == "stalker":
					var nose: Vector3 = m.global_position + m.forward() * 10.5 + Vector3(0, 3.0, 0)
					if not city.building_at(nose).is_empty():
						clip_frames += 1
	Input.action_release("move_forward")
	var titan: Monster = main.monsters.list[0]
	print("DỰNG LẠI: ", main.city.rebuild_ms)
	print("SOAK xong: 3 phút game · chết %d lần · bị săn %d khung hình · nhà bị phá %d · dân còn sống %d/%d · Thủy Quái %s ở %s · khung hình chậm nhất %.0f ms · số lần mũi Săn Mồi nằm trong nhà: %d" % [deaths, hunted_frames, main._damaged.size(), main.civs.alive_count(), main.civs.list.size(), titan.state, titan.global_position.round(), max_ms, clip_frames])
	get_tree().quit()
