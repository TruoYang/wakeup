class_name MonsterLeg
extends Node3D
## Một chân hai đốt có khớp gối: tự bước theo thân (đặt chân, nhấc chân theo cung) và báo khi chân chạm đất.

signal planted(pos: Vector3)

var hip_local := Vector3.ZERO      # vị trí hông so với thân
var rest_local := Vector3.ZERO     # chỗ chân muốn đặt so với thân (trên mặt đất)
var l1 := 1.0
var l2 := 1.0
var stride := 1.0
var step_time := 0.4
var lift := 0.6
var group := 0                     # hai nhóm chân bước xen kẽ
var knee_dir := Vector3.UP         # hướng gối gập (không gian thân)
var ground_y := 0.0
## Tuỳ chọn: hàm chọn chỗ đặt chân (nhận điểm muốn đặt, trả về điểm thật sự đặt), ví dụ để tránh giẫm vào nhà.
var place: Callable
var _goal := Vector3.ZERO          # chỗ đã chọn cho bước đang đi (đã qua `place`)
var _off := 0.0                    # chỗ đặt lệch khỏi chỗ muốn bao xa (để khỏi bước lại liên tục)

var foot := Vector3.ZERO
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _t := 1.0
var _upper: Node3D
var _lower: Node3D
var _ready_done := false


func build(upper_mesh: Mesh, lower_mesh: Mesh, mat: Material, foot_mesh: Mesh = null, foot_mat: Material = null) -> void:
	top_level = true
	_upper = Node3D.new()
	add_child(_upper)
	MonsterMesh.add(_upper, upper_mesh, mat)
	_lower = Node3D.new()
	add_child(_lower)
	MonsterMesh.add(_lower, lower_mesh, mat)
	if foot_mesh:
		MonsterMesh.add(_lower, foot_mesh, foot_mat if foot_mat else mat, Vector3(0, -l2, 0))


func stepping() -> bool:
	return _t < 1.0


## body: biến đổi của thân; velocity: vận tốc thân; allow: nhóm chân này có được bước lúc này không.
func update(delta: float, body: Transform3D, velocity: Vector3, allow: bool) -> void:
	var want := body * rest_local + velocity * step_time * 0.9
	want.y = ground_y
	if not _ready_done:
		_ready_done = true
		foot = want
		_to = want
	if _t < 1.0:
		_t = minf(1.0, _t + delta / step_time)
		_to = _to.lerp(_goal if place.is_valid() else want, 0.2)
		var k := _t * _t * (3.0 - 2.0 * _t)
		foot = _from.lerp(_to, k)
		foot.y = lerpf(_from.y, _to.y, k) + sin(_t * PI) * lift
		if _t >= 1.0:
			foot = _to
			planted.emit(foot)
	elif allow and foot.distance_to(want) > stride + _off:
		_from = foot
		_goal = place.call(want) if place.is_valid() else want
		_goal.y = want.y
		_off = Vector2(_goal.x - want.x, _goal.z - want.z).length()
		_to = _goal
		_t = 0.0
	# IK hai đốt
	var hip := body * hip_local
	var to_foot := foot - hip
	var dist := clampf(to_foot.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.01)
	var dir := to_foot.normalized()
	var a := acos(clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0))
	var pole := (body.basis * knee_dir)
	var side := dir.cross(pole).normalized()
	if side.length() < 0.5:
		side = dir.cross(Vector3.RIGHT).normalized()
	var bend := side.cross(dir).normalized()
	var knee := hip + dir * cos(a) * l1 + bend * sin(a) * l1
	_aim(_upper, hip, knee)
	_aim(_lower, knee, hip + dir * dist)


## Đặt đốt chân: gốc ở `from`, trục -Y hướng về `to`.
func _aim(node: Node3D, from: Vector3, to: Vector3) -> void:
	var y := (from - to).normalized()
	var x := y.cross(Vector3.FORWARD)
	if x.length() < 0.1:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y).normalized()
	node.global_transform = Transform3D(Basis(x, y, z), from)
