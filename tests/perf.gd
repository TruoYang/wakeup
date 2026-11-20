extends Node
## Đo thời gian khung hình khi có vẽ hình: đứng giữa phố đông dân (Chương 1), quay một vòng.

func _ready() -> void:
	var main: Node3D = (load("res://levels/main.tscn") as PackedScene).instantiate()
	add_child(main)
	for i in 120:
		await get_tree().process_frame
	var p: CharacterBody3D = main.local_player()
	Game.god = true
	Game.fly = true
	var n := 0
	var meshes := get_tree().root.find_children("*", "MeshInstance3D", true, false).size()
	var t0 := Time.get_ticks_usec()
	for i in 360:
		p.rotation.y = i * TAU / 360.0
		await get_tree().process_frame
		n += 1
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / n
	print("PERF %.1f ms/khung hình · %d MeshInstance3D · draw calls %d" % [ms, meshes, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	get_tree().quit()
