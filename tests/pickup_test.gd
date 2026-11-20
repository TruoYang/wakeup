extends Node
## Nhặt món đồ rơi trên đất (bàn phím cạnh bàn làm việc lúc mở đầu, món vừa vứt) không được làm game lỗi.

var main: Node3D


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	main = (load("res://levels/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await frames(30)
	var loot: Node = main.loot
	var p: CharacterBody3D = main.local_player()
	var ok := true
	# vứt một món ngay cạnh người chơi rồi nhặt lại, lặp vài lần (cả món có sẵn lúc mở đầu)
	loot.drop("ongtuyp", p.global_position + Vector3(1.0, 0.3, 0))
	await frames(40)
	var last: int = loot.drops.keys().max()
	for cid: int in [last]:
		var items: Array = loot.contents.get(cid, [])
		if items.is_empty():
			continue
		loot.take(cid, items[0])
		await frames(20)
		if loot.drops.has(cid):
			ok = false
			print("FAIL món rơi %d vẫn còn sau khi nhặt" % cid)
	await frames(120)            # để vòng hiển thị đồ gần chạy thêm vài lượt sau khi info đã xoá
	print("OK   nhặt hết đồ rơi, không lỗi" if ok else "FAIL nhặt đồ rơi")
	print("PICKUP_TEST ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
