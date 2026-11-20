extends Node
var results: Array[String] = []
var failed := false
func check(c: bool, w: String) -> void:
	results.append(("OK   " if c else "FAIL ") + w)
	if not c:
		failed = true
func _ready() -> void:
	var main: Node3D = (load("res://levels/main.tscn") as PackedScene).instantiate()
	add_child(main)
	for i in 20:
		await get_tree().process_frame
	var p: CharacterBody3D = main.local_player()
	Game.add_item("gaysat")
	check(Game.hotbar[0] == "gaysat" and Game.equip.weapon == "gaysat", "nhặt gậy sắt: tự vào ô 1 và cầm trên tay")
	Game.add_item("denpin")
	check(Game.hotbar[1] == "denpin" and Game.equip.weapon == "gaysat", "nhặt đèn pin: vào ô 2, tay vẫn cầm gậy")
	Game.select_hot(1)
	check(Game.equip.weapon == "denpin", "bấm 2: cầm đèn pin")
	var before: bool = (p.net_flags & 8) != 0
	p.attack()
	check(((p.net_flags & 8) != 0) != before, "cầm đèn pin, bấm chuột trái: bật/tắt đèn")
	Game.select_hot(2)
	check(Game.equip.weapon == "", "ô trống: tay không")
	Game.select_hot(0)
	Game.swap_hand()
	check(Game.offhand == "gaysat" and Game.equip.weapon == "", "F: chuyển gậy sang tay trái")
	Game.swap_hand()
	check(Game.offhand == "" and Game.equip.weapon == "gaysat", "F lần nữa: chuyển lại tay phải")
	Game.remove_item("gaysat")
	await get_tree().process_frame
	check(Game.hotbar[0] == "" and Game.equip.weapon == "", "vứt gậy: ô 1 trống, tay không")
	main.inv_ui.open_bag()
	await get_tree().process_frame
	await get_tree().process_frame
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_TAB
	ev.keycode = KEY_TAB
	ev.pressed = true
	Input.parse_input_event(ev)
	for i in 4:
		await get_tree().process_frame
	check(not main.inv_ui.is_open(), "Tab lần nữa: đóng túi đồ")
	for r in results:
		print(r)
	print("KẾT QUẢ: ", "THẤT BẠI" if failed else "TẤT CẢ ĐẠT")
	get_tree().quit(1 if failed else 0)
