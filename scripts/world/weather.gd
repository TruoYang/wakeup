extends Node3D
## Thời gian trong ngày + thời tiết (nắng, nhiều mây, mưa, giông, sương mù). Máy chủ phòng quyết định, các máy khác theo.

const HOUR_SECONDS := 150.0     # 1 giờ trong game = 2,5 phút (một ngày đêm = 1 tiếng chơi)
const KINDS := {
	"clear": {"name": "Trời quang", "cover": 0.32, "fog": 0.0004, "vol": 0.0012, "rain": 0.0, "wind": 0.25, "dim": 1.0},
	"overcast": {"name": "Nhiều mây", "cover": 0.78, "fog": 0.0009, "vol": 0.003, "rain": 0.0, "wind": 0.4, "dim": 0.6},
	"rain": {"name": "Mưa", "cover": 0.95, "fog": 0.0022, "vol": 0.011, "rain": 0.65, "wind": 0.6, "dim": 0.42},
	"storm": {"name": "Giông bão", "cover": 1.0, "fog": 0.003, "vol": 0.014, "rain": 1.0, "wind": 1.0, "dim": 0.3},
	"fog": {"name": "Sương mù", "cover": 0.7, "fog": 0.009, "vol": 0.045, "rain": 0.0, "wind": 0.1, "dim": 0.55},
}

var hour := 7.0            # vào game là buổi sáng
var day := 1
var rainy_day := false     # ngày đầu không mưa; các ngày sau mỗi ngày 30% là ngày mưa
var kind := "clear"
var city: City
var env: Environment
var sun: DirectionalLight3D
var sky_mat: ShaderMaterial
var rain: GPUParticles3D
var water_mat: ShaderMaterial
var rng := RandomNumberGenerator.new()

var _cur := {"cover": 0.4, "fog": 0.0004, "vol": 0.0012, "rain": 0.0, "wind": 0.3, "dim": 1.0}
var _next_change := 70.0
var _sync_t := 0.0
var _flash := 0.0
var _thunder_cd := 8.0
var _lamps_on := false
## Cả thành phố mất điện (chương 2): đèn đường tắt hẳn, đêm tối như mực, trăng thấp chỉ rọi được dọc vài con phố.
var blackout := false
var _base_exposure := 1.1


func setup(c: City, world_seed: int) -> void:
	city = c
	rng.seed = world_seed + 5
	_build_environment()
	_build_rain()
	_apply(1.0)


func kind_name() -> String:
	return KINDS[kind].name


## Buổi trong ngày, ước lượng bằng mắt khi chưa có đồng hồ.
func part_of_day() -> String:
	var h := fposmod(hour, 24.0)
	if h < 4.5: return "Đêm khuya"
	if h < 6.5: return "Rạng sáng"
	if h < 11.0: return "Buổi sáng"
	if h < 13.5: return "Giữa trưa"
	if h < 17.0: return "Buổi chiều"
	if h < 19.5: return "Chập tối"
	return "Ban đêm"


## Ngủ qua đêm: tua tới 6 giờ sáng. (Máy chủ phòng gọi.)
func skip_to_morning() -> void:
	hour = 6.0
	if multiplayer.is_server():
		_new_day()
		_sync.rpc(hour, kind)


func clock_text() -> String:
	var h := int(hour) % 24
	var m := int((hour - floorf(hour)) * 60.0)
	return "%02d:%02d" % [h, m]


## 0 = giữa trưa, 1 = đêm tối.
func darkness() -> float:
	var h := fposmod(hour, 24.0)
	var d := 0.0
	if h >= 19.5 or h < 4.5:
		d = 1.0
	elif h >= 17.0:
		d = (h - 17.0) / 2.5
	elif h < 6.5:
		d = 1.0 - (h - 4.5) / 2.0
	return clampf(d, 0.0, 1.0)


func _build_environment() -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_octaves = 5
	noise.seed = 7
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.noise = noise
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	sky_mat.set_shader_parameter("noise_tex", tex)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_sky_contribution = 0.5
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.tonemap_exposure = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_sun_scatter = 0.3
	env.fog_aerial_perspective = 0.25
	env.fog_sky_affect = 0.2
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_length = 140.0
	env.volumetric_fog_ambient_inject = 0.12
	env.volumetric_fog_sky_affect = 0.3
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 0.94
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_angular_distance = 1.2
	sun.shadow_enabled = true
	sun.shadow_blur = 1.4
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 170.0
	sun.light_volumetric_fog_energy = 1.5
	add_child(sun)
	apply_quality()


## Mức đồ hoạ: 0 thấp, 1 vừa, 2 cao.
var _post: MeshInstance3D


func apply_quality() -> void:
	var q := int(Game.settings.quality)
	var toon: bool = Game.toon()
	RenderingServer.global_shader_parameter_set("toon_style", 1.0 if toon else 0.0)
	Mats.apply_style()
	if _post == null:
		_post = MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(2, 2)
		_post.mesh = qm
		var pm := ShaderMaterial.new()
		pm.shader = load("res://shaders/toon_post.gdshader")
		pm.render_priority = -128        # vẽ trước kính, nước, mưa để chúng không bị che mất
		_post.material_override = pm
		_post.extra_cull_margin = 16000.0
		_post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_post.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
		add_child(_post)
	_post.visible = toon
	(_post.material_override as ShaderMaterial).set_shader_parameter("radius", 3 if q >= 1 else 2)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC if toon else Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.92 if toon else 1.1
	_base_exposure = env.tonemap_exposure
	env.adjustment_contrast = 1.0 if toon else 1.06
	env.adjustment_saturation = 1.12 if toon else 0.94
	env.volumetric_fog_enabled = q >= 2 and not toon
	env.ssao_enabled = q >= 1
	env.ssao_radius = 1.6
	env.ssao_intensity = 1.0 if toon else 2.2
	env.glow_enabled = q >= 1
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if q >= 1 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 170.0 if q >= 2 else (110.0 if q == 1 else 70.0)
	# Vẽ tay: nét viền cần đọc bộ đệm độ sâu, không dùng chung được với MSAA; nét mực và nét cọ đã che răng cưa.
	get_viewport().msaa_3d = Viewport.MSAA_2X if q >= 1 and not toon else Viewport.MSAA_DISABLED
	get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	# Vẽ tay: khử răng cưa theo thời gian để mép nét không nhấp nháy khi di chuyển.
	get_viewport().use_taa = toon and q >= 1
	get_viewport().scaling_3d_scale = 1.0 if q >= 1 else 0.8
	for cell in rain_cells:
		cell.amount = 110 if q >= 2 else (70 if q == 1 else 40)


const RAIN_CELL := 6.0
const RAIN_GRID := 7
var rain_cells: Array[GPUParticles3D] = []
var _rain_ray := PhysicsRayQueryParameters3D.new()
var _rain_check := 0


## Mưa chia thành lưới ô 6m quanh người chơi; ô nào có mái hay sàn che phía trên thì tắt, nên mưa không rơi vào trong nhà.
func _build_rain() -> void:
	_rain_ray.collision_mask = 1
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(RAIN_CELL * 0.5, 0.5, RAIN_CELL * 0.5)
	pm.direction = Vector3(0.0, -1, 0.0)
	pm.spread = 2.0
	pm.initial_velocity_min = 24.0
	pm.initial_velocity_max = 30.0
	pm.gravity = Vector3(0, -6, 0)
	var q := QuadMesh.new()
	q.size = Vector2(0.025, 0.7)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.75, 0.8, 0.86, 0.32)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.billboard_keep_scale = true
	q.material = m
	for i in RAIN_GRID * RAIN_GRID:
		var p := GPUParticles3D.new()
		p.amount = 110
		p.lifetime = 0.75
		p.local_coords = false
		p.visibility_aabb = AABB(Vector3(-4, -26, -4), Vector3(8, 30, 8))
		p.process_material = pm
		p.draw_pass_1 = q
		p.emitting = false
		add_child(p)
		rain_cells.append(p)
	rain = rain_cells[0]


## Có mái, sàn hay mặt đường che phía trên điểm này không?
func _sheltered(p: Vector3, top: float) -> bool:
	_rain_ray.from = Vector3(p.x, top, p.z)
	_rain_ray.to = Vector3(p.x, p.y + 0.3, p.z)
	return not get_viewport().world_3d.direct_space_state.intersect_ray(_rain_ray).is_empty()


func _update_rain_cells(amount: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var raining := amount > 0.08
	var base := Vector3(snappedf(cam.global_position.x, RAIN_CELL), cam.global_position.y, snappedf(cam.global_position.z, RAIN_CELL))
	var half := (RAIN_GRID - 1) * 0.5
	var top := base.y + 13.0
	# mỗi khung hình kiểm tra lại một phần số ô để nhẹ máy
	for k in 12:
		_rain_check = (_rain_check + 1) % rain_cells.size()
		var i := _rain_check
		var cx := base.x + ((i % RAIN_GRID) - half) * RAIN_CELL
		var cz := base.z + ((i / RAIN_GRID) - half) * RAIN_CELL
		var cell := rain_cells[i]
		cell.global_position = Vector3(cx, top, cz)
		var open := raining
		if open:
			# ô chỉ mưa khi cả tâm và bốn góc đều trống phía trên
			for off: Vector2 in [Vector2.ZERO, Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				if _sheltered(Vector3(cx + off.x * RAIN_CELL * 0.5, base.y - 1.2, cz + off.y * RAIN_CELL * 0.5), top + 0.4):
					open = false
					break
		cell.emitting = open
		cell.amount_ratio = clampf(amount, 0.15, 1.0)


func _process(delta: float) -> void:
	if city == null:
		return
	var prev_hour := hour
	if not Game.frozen():
		hour = fposmod(hour + delta / HOUR_SECONDS, 24.0)
	if multiplayer.is_server() and prev_hour < 5.0 and hour >= 5.0:
		_new_day()
	if multiplayer.is_server():
		_next_change -= delta
		if _next_change <= 0.0:
			_next_change = rng.randf_range(80.0, 170.0)
			# sương mù chỉ 10%
			var weights := {"clear": 55.0, "overcast": 35.0, "fog": 10.0}
			if rainy_day:
				weights = {"rain": 50.0, "storm": 20.0, "overcast": 20.0, "fog": 10.0}
			var total := 0.0
			for k: String in weights:
				total += float(weights[k]) * (0.35 if k == kind else 1.0)
			var r := rng.randf() * total
			var pick: String = weights.keys()[0]
			for k2: String in weights:
				r -= float(weights[k2]) * (0.35 if k2 == kind else 1.0)
				if r <= 0.0:
					pick = k2
					break
			set_kind(pick)
		_sync_t += delta
		if _sync_t > 4.0:
			_sync_t = 0.0
			_sync.rpc(hour, kind)
	_apply(minf(1.0, delta * 0.12))
	_update_rain(delta)


## Sang ngày mới: gieo xem hôm nay có mưa không (30%).
func _new_day() -> void:
	day += 1
	rainy_day = rng.randf() < 0.3
	if not rainy_day and kind in ["rain", "storm"]:
		set_kind("overcast")


func set_kind(k: String) -> void:
	kind = k
	if multiplayer.is_server():
		_sync.rpc(hour, kind)
		if is_inside_tree() and Game.play_time > 5.0:
			Game.say("Thời tiết: %s" % kind_name())


@rpc("authority", "reliable")
func _sync(h: float, k: String) -> void:
	if absf(fposmod(h - hour + 12.0, 24.0) - 12.0) > 0.05:
		hour = h
	if k != kind:
		kind = k
		Game.say("Thời tiết: %s" % kind_name())


func _apply(blend: float) -> void:
	var target: Dictionary = KINDS[kind]
	for k: String in _cur:
		_cur[k] = lerpf(float(_cur[k]), float(target[k]), blend)
	var h := fposmod(hour, 24.0)
	var dark := darkness()
	# Mặt trời: mọc 5h30, lặn 18h30; ban đêm là ánh trăng yếu.
	var day_t := clampf((h - 5.5) / 13.0, 0.0, 1.0)
	var elev := sin(day_t * PI)
	var is_day := h > 5.5 and h < 18.5
	var azim := lerpf(100.0, -100.0, day_t)    # mọc đằng đông (+X), lặn đằng tây
	if is_day:
		sun.rotation_degrees = Vector3(-maxf(4.0, elev * 68.0), azim, 0)
	else:
		# Ban đêm nguồn sáng chính là mặt trăng: mọc đằng đông lúc chập tối, lặn đằng tây lúc gần sáng.
		var night_t := fposmod(h - 18.5, 24.0) / 11.0
		sun.rotation_degrees = Vector3(-maxf(14.0, sin(night_t * PI) * 62.0), lerpf(110.0, -110.0, night_t), 0)
	var warm := Color("ffb070").lerp(Color("fff0dc"), clampf(elev * 1.6, 0.0, 1.0))
	var dim: float = _cur.dim
	sun.light_color = warm if is_day else Color("a9bfee")
	sun.light_energy = (maxf(0.12, elev) * 2.3 * dim if is_day else 0.62 * lerpf(0.35, 1.0, dim)) + _flash * 3.0
	sky_mat.set_shader_parameter("moon", 0.0 if is_day else 1.0)
	sky_mat.set_shader_parameter("stars", dark * clampf(1.0 - float(_cur.cover) * 1.1, 0.0, 1.0))
	sun.light_volumetric_fog_energy = 1.5 if is_day else 0.4
	# Trời
	var day_top := Color("2a4a78").lerp(Color("6a7480"), 1.0 - dim)
	var day_hor := Color("b8c8d8").lerp(Color("8a8f94"), 1.0 - dim)
	var dusk_top := Color("28304a")
	var dusk_hor := Color("d8743a").lerp(Color("70625a"), 1.0 - dim)
	var night_top := Color("05070c")
	var night_hor := Color("10141c")
	var dusk_w := clampf(1.0 - absf(elev - 0.12) * 5.0, 0.0, 1.0) if is_day else 0.0
	var toon: bool = Game.toon()
	if toon:
		# bảng màu vẽ tay: trời xanh trong, hoàng hôn hồng cam, đêm màu chàm
		day_top = Color("2a78d2").lerp(Color("6f8196"), 1.0 - dim)
		day_hor = Color("c4e6f8").lerp(Color("a3b0bb"), 1.0 - dim)
		dusk_top = Color("46509c")
		dusk_hor = Color("ffac64").lerp(Color("8a7480"), 1.0 - dim)
		night_top = Color("0a1438")
		night_hor = Color("1f3f72")
	var top := day_top.lerp(dusk_top, dusk_w).lerp(night_top, dark)
	var hor := day_hor.lerp(dusk_hor, dusk_w).lerp(night_hor, dark)
	sky_mat.set_shader_parameter("top_color", top)
	sky_mat.set_shader_parameter("horizon_color", hor)
	sky_mat.set_shader_parameter("ground_color", hor.darkened(0.6))
	sky_mat.set_shader_parameter("cloud_light", (warm if is_day else Color("5a6478")).lerp(Color("9a9da2"), 1.0 - dim) * lerpf(1.0, 0.18, dark))
	sky_mat.set_shader_parameter("cloud_dark", Color("2c313a").lerp(Color("14161a"), 1.0 - dim) * lerpf(1.0, 0.25, dark))
	if toon:
		var cl := Color("ffffff").lerp(Color("ffd2a0"), dusk_w).lerp(Color("b4bcc6"), 1.0 - dim).lerp(Color("6f8fc4"), dark)
		var cd := Color("aab6e4").lerp(Color("8a5f9e"), dusk_w).lerp(Color("5c6474"), 1.0 - dim).lerp(Color("1c2f66"), dark)
		sky_mat.set_shader_parameter("cloud_light", cl)
		sky_mat.set_shader_parameter("cloud_dark", cd)
	sky_mat.set_shader_parameter("cover", _cur.cover)
	sky_mat.set_shader_parameter("speed", 0.003 + float(_cur.wind) * 0.01)
	sky_mat.set_shader_parameter("energy", 1.0 + _flash * 2.0)
	env.ambient_light_color = Color("c4c8cc").lerp(Color("3a4a6a"), dark)
	env.ambient_light_energy = lerpf(0.7, 0.75, dark) * lerpf(0.8, 1.0, dim) + _flash
	env.fog_light_color = hor.lerp(Color("b9a590"), 0.3) * lerpf(1.0, 0.5, dark)
	env.fog_density = _cur.fog
	if toon:
		env.ambient_light_color = Color("cdd8f4").lerp(Color("3c5694"), dark)
		env.ambient_light_energy = lerpf(0.55, 0.62, dark) * lerpf(0.85, 1.0, dim) + _flash
		if is_day:
			sun.light_energy *= 0.72
		env.fog_light_color = hor * lerpf(1.0, 0.6, dark)
	env.volumetric_fog_density = _cur.vol
	env.volumetric_fog_albedo = Color("d8d4cc").lerp(Color("707888"), dark)
	# Dưới nước: đục và xanh
	if Game.submerged:
		env.fog_density = 0.12
		env.fog_light_color = Color("12383c")
		env.volumetric_fog_density = 0.08
		env.volumetric_fog_albedo = Color("1a4a4a")
	# Đèn đường
	var on := dark > 0.45 and not blackout
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	if blackout and dark > 0.3:
		# Trăng treo rất thấp phía đông: chỉ những đoạn phố chạy đông-tây không bị nhà che mới có vệt trăng;
		# phố bắc-nam, ngõ hẹp, sân trong, gầm cầu chìm hẳn trong bóng tối. Không còn ánh sáng hắt từ trời.
		var k := clampf((dark - 0.3) / 0.5, 0.0, 1.0)
		sun.rotation_degrees = Vector3(-11.0, 84.0, 0)
		sun.light_color = Color("8fa8e0")
		sun.light_energy = lerpf(sun.light_energy, 0.55, k)
		env.ambient_light_color = Color("0c1428")
		env.ambient_light_energy = lerpf(env.ambient_light_energy, 0.004, k)
		env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED if k > 0.5 else Environment.REFLECTION_SOURCE_SKY
		env.fog_light_color = env.fog_light_color.lerp(Color("04060c"), k)
		env.volumetric_fog_albedo = env.volumetric_fog_albedo.lerp(Color("10141c"), k)
		sky_mat.set_shader_parameter("top_color", top.lerp(Color("01020a"), k))
		sky_mat.set_shader_parameter("horizon_color", hor.lerp(Color("070c1c"), k))
		sky_mat.set_shader_parameter("ground_color", Color("010204"))
		sky_mat.set_shader_parameter("cloud_light", Color("2a3654").lerp(Color("2a3654"), k))
		sky_mat.set_shader_parameter("cloud_dark", Color("070a14"))
	# kính nhìn đêm (chỉ ảnh hưởng máy người đeo): khuếch đại chút ánh sáng còn sót lại
	env.tonemap_exposure = _base_exposure
	if Game.nv_on:
		env.ambient_light_color = Color(0.55, 0.7, 0.6)
		env.ambient_light_energy = maxf(env.ambient_light_energy, 0.32)
		env.tonemap_exposure = 2.6
		env.fog_density = minf(env.fog_density, 0.002)
	if on != _lamps_on:
		_lamps_on = on
		for l in city.lamp_lights:
			l.visible = on
			l.light_energy = 2.4 if on else 0.0
	if water_mat:
		water_mat.set_shader_parameter("rain", _cur.rain)


func _update_rain(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var amount: float = _cur.rain
	_update_rain_cells(amount)
	# Âm thanh: ngoài trời nghe mưa rơi, trong nhà nghe mưa gõ mái.
	var inside := Game.indoors
	var under := Game.submerged
	Sfx.loop("rain_loop", 0.0 if under else amount * (0.25 if inside else 0.8))
	Sfx.loop("rain_roof_loop", 0.0 if under else amount * (0.6 if inside else 0.0))
	Sfx.loop("wind_loop", 0.0 if under else float(_cur.wind) * (0.2 if inside else 0.5))
	Sfx.loop("underwater_loop", 0.7 if under else 0.0)
	_flash = maxf(0.0, _flash - delta * 5.0)
	if kind == "storm":
		_thunder_cd -= delta
		if _thunder_cd <= 0.0:
			_thunder_cd = randf_range(7.0, 22.0)
			_flash = 1.0
			get_tree().create_timer(randf_range(0.4, 2.2)).timeout.connect(func() -> void: Sfx.play("thunder_%d" % (1 + randi() % 2), -3.0 if not Game.indoors else -9.0))
