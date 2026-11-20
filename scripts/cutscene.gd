extends CanvasLayer
## Đoạn cắt cảnh: máy quay riêng, hai dải đen trên dưới, dòng chữ thuyết minh, rồi mờ dần về đen.

var world: Node3D
var cam: Camera3D
var _caption: Label
var _black: ColorRect
var _bars: Array[ColorRect] = []
var _shake := 0.0
var _base := Transform3D.IDENTITY
var _t := 0.0
var playing := false


func setup(w: Node3D) -> void:
	world = w
	layer = 7
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.set_anchors_preset(Control.PRESET_TOP_WIDE if i == 0 else Control.PRESET_BOTTOM_WIDE)
		bar.custom_minimum_size = Vector2(0, 0)
		if i == 0:
			bar.offset_bottom = 0.0
		else:
			bar.offset_top = 0.0
		add_child(bar)
		_bars.append(bar)
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 0)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)
	_caption = Label.new()
	_caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_caption.offset_top = -150.0
	_caption.offset_bottom = -96.0
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.add_theme_font_size_override("font_size", 22)
	_caption.add_theme_color_override("font_color", Color("f0ece2"))
	_caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_caption.add_theme_constant_override("outline_size", 8)
	add_child(_caption)
	cam = Camera3D.new()
	cam.far = 700.0
	cam.fov = 58.0
	world.add_child(cam)
	visible = false


func _process(delta: float) -> void:
	if not playing:
		return
	_t += delta
	_shake = maxf(0.0, _shake - delta * 0.7)
	var s := _shake * _shake
	cam.global_transform = _base
	cam.global_position += Vector3(sin(_t * 31.0), sin(_t * 43.0 + 1.0), sin(_t * 37.0 + 2.0)) * s * 0.5
	cam.rotation.z += sin(_t * 29.0) * s * 0.03


func _begin() -> void:
	playing = true
	visible = true
	cam.current = true
	_black.color.a = 0.0
	var tw := create_tween()
	for i in 2:
		tw.parallel().tween_property(_bars[i], "offset_bottom" if i == 0 else "offset_top", 78.0 if i == 0 else -78.0, 0.6)


func say(text: String) -> void:
	_caption.text = text
	_caption.modulate.a = 0.0
	create_tween().tween_property(_caption, "modulate:a", 1.0, 0.35)


func _look(from: Vector3, at: Vector3) -> void:
	_base = Transform3D(Basis.IDENTITY, from).looking_at(at, Vector3.UP)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, false).timeout


## Chương 1 kết thúc: cửa hầm bật mở, vợ con xuống trước, rồi ngôi nhà đổ sập xuống ngay trên cửa hầm.
func play_home_collapse(done: Callable) -> void:
	var city: City = world.city
	var home: Dictionary = {}
	for b in city.buildings:
		if b.kind == "home":
			home = b
	if home.is_empty():
		done.call()
		return
	var door: Vector3 = home.door
	var rc: Rect2 = home.rect
	var mid := Vector3(rc.get_center().x, 0.0, rc.get_center().y)
	var out := (door - mid)
	out.y = 0.0
	out = out.normalized()
	var side := Vector3(out.z, 0, -out.x)
	_begin()
	var from := door + out * 11.0 + side * 6.0 + Vector3(0, 2.2, 0)
	var at := mid + Vector3(0, 4.0, 0)
	_look(from, at)
	say("Cửa hầm bật mở. Mai bế bé Na xuống trước.")
	await _wait(2.4)
	# mặt đất rung: thứ gì đó rất lớn đang bước tới
	Sfx.play_at("titan_groan", mid + Vector3(0, 30.0, 0), 6.0, 90.0)
	_shake = 0.55
	say("Rồi mặt đất rung lên.")
	var tw := create_tween()
	tw.tween_method(func(k: float) -> void: _look(from.lerp(from + out * 7.0 + Vector3(0, 2.5, 0), k), at.lerp(at + Vector3(0, 3.0, 0), k)), 0.0, 1.0, 6.5)
	await _wait(2.2)
	_shake = 0.75
	Sfx.play_at("titan_stomp", mid, 6.0, 80.0)
	await _wait(1.1)
	# ngôi nhà sập
	_shake = 1.25
	city.damage_building(int(home.id), "collapse", 1)
	for k in 5:
		world.fx.dust(mid + Vector3(randf_range(-2.5, 2.5), 1.0 + k * 2.2, randf_range(-5.0, 5.0)), 9.0)
	world.fx.debris(mid, 14)
	Sfx.play_at("explosion", mid + Vector3(0, 2.0, 0), 9.0, 80.0, 0.55)
	say("Ngôi nhà đổ sập xuống ngay trên cửa hầm.")
	await _wait(1.0)
	world.fx.dust(door + out * 2.0 + Vector3(0, 1.0, 0), 10.0)
	_shake = 0.6
	await _wait(2.6)
	say("Dưới lớp gạch vụn, cả nhà vẫn còn sống. Nhưng không còn đường nào quay lên nữa.")
	create_tween().tween_property(_black, "color:a", 1.0, 2.2)
	await _wait(3.4)
	playing = false
	cam.current = false
	visible = false
	done.call()
