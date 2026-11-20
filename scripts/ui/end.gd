extends CanvasLayer
## Màn hình kết thúc: thắng (đoàn tụ, có hai kết cục theo độ tàn nhẫn) hoặc chết khi chơi đơn.

var _next: Button
var world: Node
var root: Control
var _title: Label
var _story: Label
var _stats: Label
var _again: Button


func _ready() -> void:
	world = get_parent()
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.make()
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.04, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(680, 0)
	col.add_theme_constant_override("separation", 16)
	center.add_child(col)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 56)
	col.add_child(_title)
	_story = Label.new()
	_story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_story.add_theme_font_size_override("font_size", 16)
	_story.add_theme_color_override("font_color", Color("d6d0c4"))
	col.add_child(_story)
	_stats = Label.new()
	_stats.add_theme_font_size_override("font_size", 14)
	_stats.add_theme_color_override("font_color", Color("e4a03a"))
	col.add_child(_stats)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	_again = Button.new()
	_again.text = "↻  Chơi lại"
	_again.theme_type_variation = "Primary"
	_again.custom_minimum_size = Vector2(160, 44)
	_again.pressed.connect(func() -> void: world.restart())
	row.add_child(_again)
	var menu := Button.new()
	menu.text = "Về màn hình chính"
	menu.custom_minimum_size = Vector2(200, 44)
	menu.pressed.connect(func() -> void: world.back_to_menu())
	row.add_child(menu)
	_next = Button.new()
	_next.text = "▶  Chơi tiếp Chương 2: Dưới hầm"
	_next.theme_type_variation = "Primary"
	_next.custom_minimum_size = Vector2(300, 44)
	_next.visible = false
	_next.pressed.connect(func() -> void:
		Game.carry = {"inv": Game.inv.duplicate(), "equip": Game.equip.duplicate(), "ammo": Game.ammo}
		Game.chapter = 2
		Net.mode = Net.Mode.SOLO
		world.restart())
	row.add_child(_next)
	row.move_child(_next, 0)
	Game.game_won.connect(_on_won)


func is_open() -> bool:
	return visible


func _stat_text() -> String:
	var t := int(Game.play_time)
	return "Thời gian: %d:%02d   ·   Quãng đường: %dm   ·   Tàn nhẫn: %d/100   ·   Đã giúp: %d người" % [t / 60, t % 60, int(Game.distance), int(Game.cruelty), Game.helped]


func _show() -> void:
	visible = true
	_stats.text = _stat_text()
	_again.visible = not Net.is_online()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Màn kết tuỳ biến (chương 2).
func show_custom(title: String, story: String, bad: bool) -> void:
	_title.text = title
	_title.add_theme_color_override("font_color", Color("cf4a3b") if bad else Color("86b47f"))
	_story.text = story
	_show()
	_stats.text = ""


func _on_won(bad: bool) -> void:
	if Game.chapter == 2:
		return
	_next.visible = not Net.is_online()
	if bad:
		_title.text = "VỀ ĐẾN NHÀ"
		_title.add_theme_color_override("font_color", Color("cf4a3b"))
		_story.text = "Cửa hầm bật mở. Vợ bạn ôm con lùi lại một bước khi thấy bạn — áo bạn dính máu không phải của bạn.\n\nBạn đã về đến nhà. Nhưng người bước xuống hầm đêm nay không còn là người rời nhà sáng nay nữa. Đứa bé không dám nhìn vào mắt bạn."
	else:
		_title.text = "ĐOÀN TỤ"
		_title.add_theme_color_override("font_color", Color("86b47f"))
		_story.text = "Cửa hầm bật mở. Trong ánh đèn pin yếu ớt, vợ bạn ôm con lao tới. Cả nhà ôm nhau trong im lặng, phía trên mặt đất vẫn rung lên từng nhịp.\n\nĐêm nay mọi người còn sống. Ngày mai sẽ phải tìm đường rời thành phố.\n\nHẾT CHƯƠNG 1"
	_show()


func show_death() -> void:
	_title.text = "BẠN ĐÃ CHẾT"
	_title.add_theme_color_override("font_color", Color("cf4a3b"))
	_story.text = Game.death_reason + "\n\nGia đình bạn vẫn đang chờ dưới hầm."
	_show()
