extends CanvasLayer
## Hội thoại kiểu phụ đề: tên người nói và lời thoại chạy chữ chậm ở dưới màn hình, không che cảnh.
## Trong lúc nói chuyện cảnh dừng lại (quái vật, đói khát, thời gian đứng yên) nhưng nhân vật vẫn có hoạt ảnh đứng thở.
## Chơi chung thì thế giới không dừng được: chỉ người đang nói chuyện bị khoá điều khiển.
## Bấm E / chuột trái / Space: hiện hết dòng đang chạy; bấm lần nữa: sang dòng sau.

const SPEED := 24.0            # ký tự mỗi giây (chậm, đọc kịp)
const COLORS := {"Mai": "f0a8b8", "Bé Na": "f2d060", "Radio": "8fd0a0", "Bạn": "c8d8f0"}

var active := false
var _lines: Array = []
var _i := 0
var _shown := 0.0
var _done: Callable
var _box: PanelContainer
var _who: Label
var _text: Label
var _hint: Label
var _opened_frame := -1


func _ready() -> void:
	layer = 8
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.make()
	add_child(root)
	_box = PanelContainer.new()
	_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_box.offset_left = 180.0
	_box.offset_right = -180.0
	_box.offset_top = -190.0
	_box.offset_bottom = -64.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.035, 0.045, 0.78)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 26.0
	sb.content_margin_right = 26.0
	sb.content_margin_top = 14.0
	sb.content_margin_bottom = 14.0
	_box.add_theme_stylebox_override("panel", sb)
	root.add_child(_box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_box.add_child(col)
	_who = Label.new()
	_who.add_theme_font_size_override("font_size", 17)
	col.add_child(_who)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 21)
	_text.add_theme_color_override("font_color", Color("f2efe6"))
	_text.add_theme_constant_override("line_spacing", 4)
	_text.custom_minimum_size = Vector2(0, 64)
	col.add_child(_text)
	_hint = Label.new()
	_hint.text = "[E] tiếp"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.add_theme_color_override("font_color", Color("a09a8e"))
	col.add_child(_hint)
	visible = false


## lines: [{who, text}] hoặc ["Tên: lời thoại", ...]. done: gọi khi hết hội thoại.
func play(lines: Array, done := Callable()) -> void:
	if lines.is_empty():
		if done.is_valid():
			done.call()
		return
	if active:
		# đang nói dở mà có đoạn mới: nối tiếp vào sau
		_lines.append_array(lines.map(_norm))
		return
	_lines = lines.map(_norm)
	_done = done
	_i = 0
	active = true
	visible = true
	_opened_frame = Engine.get_process_frames()
	Game.talking = true
	_show_line()


func _norm(l: Variant) -> Dictionary:
	if l is Dictionary:
		return l
	var s := str(l)
	var k := s.find(": ")
	if k > 0 and k < 24:
		return {"who": s.substr(0, k), "text": s.substr(k + 2)}
	return {"who": "", "text": s}


func _show_line() -> void:
	var l: Dictionary = _lines[_i]
	_who.text = str(l.who)
	_who.visible = l.who != ""
	_who.add_theme_color_override("font_color", Color(str(COLORS.get(l.who, "e3a23a"))))
	_text.text = str(l.text)
	_text.visible_characters = 0
	_shown = 0.0
	_hint.modulate.a = 0.0


func _process(delta: float) -> void:
	if not active:
		return
	var total := _text.text.length()
	if _shown < total:
		var before := int(_shown)
		_shown = minf(float(total), _shown + SPEED * delta)
		_text.visible_characters = int(_shown)
		if int(_shown) != before and int(_shown) % 3 == 0:
			Sfx.play("ui_click", -26.0)
	else:
		_text.visible_characters = -1
		_hint.modulate.a = 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.006)


func _input(event: InputEvent) -> void:
	if not active or Engine.get_process_frames() == _opened_frame:
		return
	var go := event.is_action_pressed("interact") or event.is_action_pressed("jump") or event.is_action_pressed("attack")
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		go = true
	if not go:
		return
	get_viewport().set_input_as_handled()
	advance()


## Hiện hết dòng đang chạy, hoặc sang dòng sau, hoặc kết thúc.
func advance() -> void:
	if not active:
		return
	if _shown < _text.text.length():
		_shown = float(_text.text.length())
		_text.visible_characters = -1
		return
	_i += 1
	if _i < _lines.size():
		_show_line()
		return
	active = false
	visible = false
	Game.talking = false
	var cb := _done
	_done = Callable()
	if cb.is_valid():
		cb.call()
