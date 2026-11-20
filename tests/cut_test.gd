extends Node
func _ready() -> void:
	Game.chapter = 1
	var main: Node3D = (load("res://levels/main.tscn") as PackedScene).instantiate()
	add_child(main)
	for i in 30:
		await get_tree().process_frame
	var homes := 0
	for b in main.city.buildings:
		if b.kind == "home":
			homes += 1
			print("home: ", b.id, " door ", b.door, " rect ", b.rect)
	print("số nhà 'home': ", homes)
	var t0 := Time.get_ticks_msec()
	main.end_ui.visibility_changed.connect(func() -> void: print("màn kết hiện sau %.1f giây" % ((Time.get_ticks_msec() - t0) / 1000.0)))
	main._apply_stage(3, true)
	await get_tree().create_timer(16.0).timeout
	var home: Dictionary = {}
	for b in main.city.buildings:
		if b.kind == "home":
			home = b
	print("nhà đã sập: ", home.get("damage", ""), " · màn kết: ", main.end_ui.is_open())
	get_tree().quit()
