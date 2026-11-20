extends Node
func _ready() -> void:
	add_child((load("res://scenes/menu.tscn") as PackedScene).instantiate())
	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://menu.png")
	get_tree().quit()
