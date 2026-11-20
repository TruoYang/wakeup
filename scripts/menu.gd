extends Control
## Màn hình chính: chơi một mình, mở phòng, vào phòng.

const WORLD := "res://levels/main.tscn"

@onready var name_edit: LineEdit = %NameEdit
@onready var address_edit: LineEdit = %AddressEdit
@onready var status: Label = %Status
@onready var addresses: Label = %Addresses


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	theme = UiTheme.make()
	(%SoloButton as Button).theme_type_variation = "Primary"
	(%QuitButton as Button).theme_type_variation = "Quiet"
	(%SoloButton as Button).text = "▶  Chơi một mình"
	(%HostButton as Button).text = "Mở phòng chơi chung (tối đa 4 người)"
	name_edit.text = Net.my_name
	address_edit.text = Net.address
	status.text = Net.last_error
	Net.last_error = ""
	var ips := Net.local_addresses()
	addresses.text = "Địa chỉ máy này (đọc cho bạn bè khi mở phòng): " + (", ".join(ips) if ips.size() > 0 else "không tìm thấy")
	# Chương 2 (chơi một mình): sinh tồn dưới hầm trú ẩn
	var ch2 := Button.new()
	ch2.text = "▶  Chương 2: Dưới hầm (chơi một mình)"
	ch2.custom_minimum_size = (%SoloButton as Button).custom_minimum_size
	(%SoloButton as Button).get_parent().add_child(ch2)
	(%SoloButton as Button).get_parent().move_child(ch2, (%SoloButton as Button).get_index() + 1)
	ch2.pressed.connect(func() -> void:
		Game.chapter = 2
		Game.carry = {}
		_start(Net.Mode.SOLO))
	(%SoloButton as Button).text = "▶  Chương 1: Về nhà (chơi một mình)"
	%SoloButton.pressed.connect(func() -> void:
		Game.chapter = 1
		_start(Net.Mode.SOLO))
	var host2 := Button.new()
	host2.text = "Mở phòng chơi chung Chương 2: Dưới hầm"
	host2.custom_minimum_size = (%HostButton as Button).custom_minimum_size
	(%HostButton as Button).get_parent().add_child(host2)
	(%HostButton as Button).get_parent().move_child(host2, (%HostButton as Button).get_index() + 1)
	host2.pressed.connect(func() -> void:
		Game.chapter = 2
		Game.carry = {}
		_start(Net.Mode.HOST))
	(%HostButton as Button).text = "Mở phòng chơi chung Chương 1 (tối đa 4 người)"
	%HostButton.pressed.connect(func() -> void: Game.chapter = 1)
	if OS.get_cmdline_user_args().has("ch2"):
		Game.chapter = 2
		_start.call_deferred(Net.Mode.SOLO)
	%HostButton.pressed.connect(_start.bind(Net.Mode.HOST))
	%JoinButton.pressed.connect(_start.bind(Net.Mode.JOIN))
	%QuitButton.pressed.connect(get_tree().quit)
	address_edit.text_submitted.connect(func(_t: String) -> void: _start(Net.Mode.JOIN))
	# Dùng khi kiểm thử: `-- solo` vào thẳng game.
	if OS.get_cmdline_user_args().has("solo"):
		_start.call_deferred(Net.Mode.SOLO)


func _start(mode: Net.Mode) -> void:
	var n := name_edit.text.strip_edges()
	Net.my_name = n if n != "" else "Người chơi"
	if mode == Net.Mode.JOIN:
		var addr := address_edit.text.strip_edges()
		if addr == "":
			status.text = "Nhập địa chỉ của chủ phòng trước."
			return
		Net.address = addr
	Net.mode = mode
	get_tree().change_scene_to_file(WORLD)
