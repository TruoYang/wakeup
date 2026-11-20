extends Node
## Đăng ký phím điều khiển khi game khởi động (đổi phím ở đây).

const KEYS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"sprint": [KEY_SHIFT],
	"crouch": [KEY_C],
	"jump": [KEY_SPACE],
	"interact": [KEY_E],
	"toggle_view": [KEY_V],
	"inventory": [KEY_TAB],
	"map": [KEY_M],
	"pause": [KEY_ESCAPE],
	"throw": [KEY_Q],
	"flashlight": [KEY_L],
	"nightvision": [KEY_N],
	"fly": [KEY_G],
	"ride": [],
	"swap_hand": [KEY_F],
	"hot_1": [KEY_1],
	"hot_2": [KEY_2],
	"hot_3": [KEY_3],
	"hot_4": [KEY_4],
	"map_zoom": [KEY_Z],
}


func _enter_tree() -> void:
	for action: String in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: int in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	InputMap.add_action("attack")
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", mb)
	InputMap.add_action("use_off")
	var mr := InputEventMouseButton.new()
	mr.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("use_off", mr)
	# Tab chỉ dùng để mở/đóng túi đồ: bỏ chức năng chuyển ô (focus) mặc định của giao diện
	for ui_act: String in ["ui_focus_next", "ui_focus_prev"]:
		if InputMap.has_action(ui_act):
			InputMap.action_erase_events(ui_act)
