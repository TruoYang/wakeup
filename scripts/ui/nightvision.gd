extends CanvasLayer
## Lớp phủ kính nhìn đêm (chỉ trên máy người đeo). Phần khuếch đại ánh sáng thật nằm ở weather.gd.

var _rect: ColorRect
var _mat: ShaderMaterial


func _ready() -> void:
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/nightvision.gdshader")
	_rect.material = _mat
	add_child(_rect)
	visible = false


func _process(_delta: float) -> void:
	# tháo kính ra thì tự tắt
	if Game.nv_on and not Items.get_def(str(Game.equip.get("eyes", ""))).has("nightvision"):
		Game.nv_on = false
	visible = Game.nv_on and not Game.dead
	if visible:
		_mat.set_shader_parameter("t", Time.get_ticks_msec() * 0.001)
