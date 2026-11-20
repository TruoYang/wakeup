extends Node3D
## Hiệu ứng hình ảnh: bụi, nổ, mảnh vỡ, hố sụt, vết nứt, cầu lửa, đồ bị ném.

var _dust_mat: StandardMaterial3D
var _fire_mat: StandardMaterial3D
var _dark: StandardMaterial3D
var _craters: Array[Node3D] = []
var _flying: Array[Dictionary] = []


func _ready() -> void:
	_dust_mat = _particle_mat(Color(0.62, 0.56, 0.48, 0.5))
	_fire_mat = _particle_mat(Color(1.0, 0.55, 0.15, 0.9))
	_fire_mat.emission_enabled = true
	_fire_mat.emission = Color(1.0, 0.45, 0.1)
	_fire_mat.emission_energy_multiplier = 4.0
	_dark = StandardMaterial3D.new()
	_dark.albedo_color = Color(0.07, 0.06, 0.05)
	_dark.roughness = 1.0


func _particle_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft_texture()
	return m


var _soft: GradientTexture2D
func _soft_texture() -> Texture2D:
	if _soft == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_soft = GradientTexture2D.new()
		_soft.gradient = g
		_soft.fill = GradientTexture2D.FILL_RADIAL
		_soft.fill_from = Vector2(0.5, 0.5)
		_soft.fill_to = Vector2(1.0, 0.5)
		_soft.width = 64
		_soft.height = 64
	return _soft


func _burst(pos: Vector3, mat: Material, amount: int, life: float, spread: float, speed: float, size: float, gravity := Vector3(0, 0.6, 0), fade := true) -> CPUParticles3D:
	var cam := get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_to(pos) > 160.0:
		return null
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	q.material = mat
	p.mesh = q
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.9
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = spread
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = speed * 0.3
	p.initial_velocity_max = speed
	p.gravity = gravity
	p.damping_min = 1.0
	p.damping_max = 2.5
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size * 1.4
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.35))
	curve.add_point(Vector2(1, 1.0))
	p.scale_amount_curve = curve
	if fade:
		var grad := Gradient.new()
		grad.set_color(0, Color(1, 1, 1, 1))
		grad.set_color(1, Color(1, 1, 1, 0))
		p.color_ramp = grad
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(life + 0.5).timeout.connect(p.queue_free)
	return p


func dust(pos: Vector3, size: float) -> void:
	_burst(pos + Vector3(0, 0.3, 0), _dust_mat, int(8 + size * 5), 1.4 + size * 0.25, size * 0.5, 1.5 + size * 0.7, 0.8 + size * 0.45)


func explosion(pos: Vector3, radius: float) -> void:
	_burst(pos + Vector3(0, 0.5, 0), _fire_mat, 26, 0.55, radius * 0.25, radius * 2.4, radius * 0.5, Vector3(0, 2.0, 0))
	_burst(pos + Vector3(0, 0.8, 0), _dust_mat, 22, 2.6, radius * 0.4, radius * 1.2, radius * 0.7, Vector3(0, 1.2, 0))
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.25)
	l.light_energy = 9.0
	l.omni_range = radius * 5.0
	add_child(l)
	l.global_position = pos + Vector3(0, 1.2, 0)
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.5)
	tw.tween_callback(l.queue_free)
	crater(pos, radius * 0.45, true)


func debris(pos: Vector3, count: int) -> void:
	var m := Mats.get_mat("asphalt")
	for i in count:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(randf_range(0.3, 1.0), randf_range(0.15, 0.4), randf_range(0.3, 0.9))
		mi.mesh = b
		mi.material_override = m
		add_child(mi)
		var a := randf() * TAU
		var r := randf_range(2.5, 6.5)
		mi.global_position = pos + Vector3(cos(a) * r, b.size.y * 0.4, sin(a) * r)
		mi.rotation = Vector3(randf_range(-0.4, 0.4), randf() * TAU, randf_range(-0.4, 0.4))
		get_tree().create_timer(90.0).timeout.connect(mi.queue_free)


## Kính vỡ: mảnh kính văng ra hai phía rồi rơi xuống, lấp lánh trong chốc lát.
func glass_shatter(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.11, 0.13, 0.012)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.78, 0.9, 0.96, 0.85)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.emission_enabled = true
	gm.emission = Color(0.7, 0.85, 0.95)
	gm.emission_energy_multiplier = 0.5
	gm.cull_mode = BaseMaterial3D.CULL_DISABLED
	bm.material = gm
	p.mesh = bm
	p.amount = 46
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 1.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.9, 0.6, 0.05)
	p.direction = Vector3(0, 0.3, 1)
	p.spread = 180.0
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0, -11.0, 0)
	p.angular_velocity_min = -500.0
	p.angular_velocity_max = 500.0
	p.particle_flag_rotate_y = true
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.6
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(3.0).timeout.connect(p.queue_free)
	# chớp sáng trắng rất ngắn chỗ kính nứt toác
	var flash := OmniLight3D.new()
	flash.light_color = Color(0.85, 0.95, 1.0)
	flash.light_energy = 2.2
	flash.omni_range = 4.0
	add_child(flash)
	flash.global_position = pos
	get_tree().create_tween().tween_property(flash, "light_energy", 0.0, 0.18).finished.connect(flash.queue_free)
	# mảnh vụn nằm lại dưới sàn
	var m := Mats.get_mat("glass")
	for i in 7:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(randf_range(0.08, 0.26), 0.015, randf_range(0.06, 0.2))
		mi.mesh = b
		mi.material_override = m
		add_child(mi)
		mi.global_position = Vector3(pos.x + randf_range(-0.9, 0.9), pos.y, pos.z + randf_range(-0.9, 0.9))
		mi.rotation.y = randf() * TAU
		var floor_hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(mi.global_position, mi.global_position + Vector3(0, -6, 0), 1))
		mi.global_position.y = ((floor_hit.position as Vector3).y + 0.012) if not floor_hit.is_empty() else pos.y - 1.2
		get_tree().create_timer(120.0).timeout.connect(mi.queue_free)


## Cột khói mảnh (xe hỏng).
func smoke(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.material = _particle_mat(Color(0.2, 0.2, 0.2, 0.4))
	p.mesh = q
	p.amount = 8
	p.lifetime = 3.5
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.0
	p.gravity = Vector3(0.3, 0.8, 0.1)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = grad
	p.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 10, 6))
	add_child(p)
	p.global_position = pos


## Đám cháy âm ỉ (xe cháy): lửa, khói đen bốc cao, ánh sáng bập bùng.
func burning(pos: Vector3) -> void:
	for spec: Array in [[_fire_mat, 14, 0.7, 0.5, 2.2, 0.9, Vector3(0, 3.0, 0)], [_particle_mat(Color(0.08, 0.08, 0.08, 0.55)), 16, 4.5, 0.6, 1.4, 2.4, Vector3(0.6, 2.2, 0.2)]]:
		var p := CPUParticles3D.new()
		var q := QuadMesh.new()
		q.material = spec[0]
		p.mesh = q
		p.amount = spec[1]
		p.lifetime = spec[2]
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = spec[3]
		p.direction = Vector3.UP
		p.spread = 20.0
		p.initial_velocity_min = float(spec[4]) * 0.5
		p.initial_velocity_max = spec[4]
		p.gravity = spec[6]
		p.scale_amount_min = float(spec[5]) * 0.6
		p.scale_amount_max = float(spec[5]) * 1.5
		var curve := Curve.new()
		curve.add_point(Vector2(0, 0.4))
		curve.add_point(Vector2(1, 1.0))
		p.scale_amount_curve = curve
		var grad := Gradient.new()
		grad.set_color(0, Color(1, 1, 1, 1))
		grad.set_color(1, Color(1, 1, 1, 0))
		p.color_ramp = grad
		p.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 16, 8))
		add_child(p)
		p.global_position = pos
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.2)
	l.light_energy = 2.5
	l.omni_range = 11.0
	l.distance_fade_enabled = true
	l.distance_fade_begin = 60.0
	add_child(l)
	l.global_position = pos + Vector3(0, 0.8, 0)


func blood(pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.9
	c.bottom_radius = 0.9
	c.height = 0.02
	c.radial_segments = 10
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.32, 0.04, 0.04)
	m.roughness = 0.3
	c.material = m
	mi.mesh = c
	add_child(mi)
	mi.global_position = Vector3(pos.x, 0.025, pos.z)
	mi.scale = Vector3(randf_range(0.8, 1.5), 1.0, randf_range(0.8, 1.5))
	get_tree().create_timer(240.0).timeout.connect(mi.queue_free)


## Hố sụt / vết cháy để lại trên mặt đường.
func crater(pos: Vector3, radius: float, scorch := false) -> void:
	var n := Node3D.new()
	add_child(n)
	n.global_position = Vector3(pos.x, 0.02 + _craters.size() * 0.0005, pos.z)
	var disc := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius * 0.8
	c.height = 0.03
	c.radial_segments = 14
	disc.mesh = c
	disc.material_override = _dark
	n.add_child(disc)
	if not scorch:
		var dirt := Mats.get_mat("dirt")
		for i in 11:
			var a := i / 11.0 * TAU + randf() * 0.3
			var mi := MeshInstance3D.new()
			mi.mesh = MonsterMesh.blob(Vector3(0.9, 0.45, 0.7), 90 + i % 4, 0.3, 0.4, 0.5)
			mi.material_override = dirt
			mi.position = Vector3(cos(a) * radius, 0.15, sin(a) * radius)
			mi.rotation.y = a
			mi.scale = Vector3.ONE * randf_range(0.7, 1.3)
			n.add_child(mi)
	_craters.append(n)
	if _craters.size() > 24:
		_craters.pop_front().queue_free()


## Vết nứt toả ra báo trước Thổ Trùng sắp trồi lên.
func cracks(pos: Vector3, radius: float) -> void:
	var n := Node3D.new()
	add_child(n)
	n.global_position = Vector3(pos.x, 0.03, pos.z)
	for i in 9:
		var a := i / 9.0 * TAU + randf() * 0.4
		var len := radius * randf_range(0.6, 1.1)
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.14, 0.02, len)
		mi.mesh = b
		mi.material_override = _dark
		mi.rotation.y = a
		mi.position = Vector3(sin(a), 0, cos(a)) * len * 0.5
		n.add_child(mi)
	n.scale = Vector3(0.2, 1, 0.2)
	var tw := create_tween()
	tw.tween_property(n, "scale", Vector3.ONE, 1.2)
	get_tree().create_timer(40.0).timeout.connect(n.queue_free)


# ------------------------------------------------------------------ vật bay (cầu lửa, đồ ném)
func fireball(start: Vector3, vel: Vector3) -> void:
	var n := Node3D.new()
	add_child(n)
	n.global_position = start
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.55
	s.height = 1.1
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.5, 0.1)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.4, 0.05)
	m.emission_energy_multiplier = 6.0
	s.material = m
	mi.mesh = s
	n.add_child(mi)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.2)
	l.light_energy = 4.0
	l.omni_range = 14.0
	n.add_child(l)
	_flying.append({"n": n, "v": vel, "g": 4.9, "t": 0.0, "fire": true})


func thrown(kind: String, start: Vector3, vel: Vector3) -> void:
	var n := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.1, 0.24, 0.1) if kind == "chai" else Vector3(0.08, 0.16, 0.08)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 0.6, 0.4) if kind == "chai" else Color(0.8, 0.15, 0.1)
	b.material = m
	n.mesh = b
	add_child(n)
	n.global_position = start
	_flying.append({"n": n, "v": vel, "g": 14.0, "t": 0.0, "fire": false})


func stop_fireball_near(pos: Vector3) -> void:
	var best := -1
	var best_d := 30.0
	for i in _flying.size():
		if _flying[i].fire:
			var d: float = (_flying[i].n as Node3D).global_position.distance_to(pos)
			if d < best_d:
				best_d = d
				best = i
	if best >= 0:
		(_flying[best].n as Node3D).queue_free()
		_flying.remove_at(best)


func stop_thrown_near(pos: Vector3) -> void:
	for i in range(_flying.size() - 1, -1, -1):
		if not _flying[i].fire and (_flying[i].n as Node3D).global_position.distance_to(pos) < 6.0:
			(_flying[i].n as Node3D).queue_free()
			_flying.remove_at(i)
			return


func _process(delta: float) -> void:
	for i in range(_flying.size() - 1, -1, -1):
		var f: Dictionary = _flying[i]
		var n: Node3D = f.n
		n.global_position += (f.v as Vector3) * delta
		f.v.y -= float(f.g) * delta
		f.t += delta
		if f.fire and randf() < 0.5:
			_burst(n.global_position, _fire_mat, 3, 0.35, 0.2, 0.6, 0.5, Vector3(0, 1.0, 0))
		if f.t > 9.0 or n.global_position.y < -8.0:
			n.queue_free()
			_flying.remove_at(i)
