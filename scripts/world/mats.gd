class_name Mats
## Vật liệu dùng chung. Texture ảnh thật (CC0, ambientCG) phủ theo toạ độ thế giới nên không cần UV.

const SCALE := {
	"asphalt": 0.22, "sidewalk": 0.4, "concrete": 0.22, "plaster": 0.22, "paint": 0.2, "brick": 0.4,
	"grass": 0.3, "dirt": 0.25, "roof": 0.5, "wood": 0.6, "metal": 0.5, "tile": 0.42, "rust": 0.4, "rock": 0.25,
}
## Loại bề mặt (tiếng bước chân) theo vật liệu.
const SURFACE := {
	"asphalt": "asphalt", "sidewalk": "concrete", "concrete": "concrete", "plaster": "concrete", "paint": "concrete",
	"brick": "concrete", "grass": "grass", "dirt": "dirt", "roof": "tile", "wood": "wood", "metal": "metal",
	"tile": "tile", "rust": "metal", "rock": "dirt", "flat": "concrete", "dark": "concrete", "glass": "tile", "emit": "metal",
}

## Màu nền của từng chất liệu ở phong cách vẽ tay (màu trên tường nhà vẫn do màu đỉnh quyết định).
const TOON_COLOR := {
	"asphalt": "7f8a96", "sidewalk": "dccfb8", "concrete": "dedad0", "plaster": "ffffff", "paint": "ffffff", "brick": "cf9078",
	"grass": "a2b87c", "dirt": "bf9f70", "roof": "d2623f", "wood": "b08a62", "metal": "bac6d0", "tile": "f2eee2", "rust": "a8705a", "rock": "9ca4a2",
}

static var _cache: Dictionary = {}


static var _tex_cache: Dictionary = {}


## Nạp texture kèm đủ các mức thu nhỏ (mipmap): thiếu mipmap thì bề mặt ở xa bị lấm tấm, nhấp nháy.
static func tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var src: Texture2D = load(path)
	var img := src.get_image()
	if img.is_compressed():
		img.decompress()
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex_cache[path] = t
	return t


## Bản "vẽ tay" của một texture: nhoè thành các mảng màu mềm như màu nước.
static func toon_tex(path: String) -> Texture2D:
	var k := path + "#toon"
	if _tex_cache.has(k):
		return _tex_cache[k]
	var src: Texture2D = load(path)
	var img := src.get_image()
	if img.is_compressed():
		img.decompress()
	img.resize(6, 6, Image.INTERPOLATE_LANCZOS)
	img.convert(Image.FORMAT_RGB8)
	# giữ lại độ loang sáng tối của ảnh gốc, còn màu thì lấy màu nền vẽ tay
	var key := path.get_file().get_slice("_", 0)
	var base := Color(String(TOON_COLOR.get(key, "ffffff")))
	var mean := 0.0
	for y in 6:
		for x in 6:
			mean += img.get_pixel(x, y).get_luminance()
	mean = maxf(mean / 36.0, 0.01)
	for y in 6:
		for x in 6:
			var v := clampf(img.get_pixel(x, y).get_luminance() / mean, 0.86, 1.12)
			img.set_pixel(x, y, Color(minf(base.r * v, 1.0), minf(base.g * v, 1.0), minf(base.b * v, 1.0)))
	img.resize(96, 96, Image.INTERPOLATE_CUBIC)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex_cache[k] = t
	return t


## Đổi mọi vật liệu đã tạo sang phong cách hiện tại (vẽ tay / tả thực).
static func apply_style() -> void:
	for key: String in _cache:
		_style(_cache[key], key)


static func _style(m: StandardMaterial3D, key: String) -> void:
	var toon: bool = Game.toon()
	if SCALE.has(key):
		if toon:
			m.albedo_texture = toon_tex("res://assets/tex/%s_color.jpg" % key)
			m.normal_enabled = false
			m.roughness_texture = null
			m.roughness = 1.0
			m.metallic = 0.0
			m.metallic_specular = 0.0
			if key == "asphalt":
				m.albedo_color = Color.WHITE
		else:
			if key == "asphalt":
				m.albedo_color = Color(0.5, 0.5, 0.52)
			m.albedo_texture = tex("res://assets/tex/%s_color.jpg" % key)
			m.normal_enabled = true
			m.normal_texture = tex("res://assets/tex/%s_normal.jpg" % key)
			m.roughness_texture = tex("res://assets/tex/%s_rough.jpg" % key)
			m.metallic = 0.6 if key == "metal" or key == "rust" else 0.0
			m.metallic_specular = 0.5
	elif key != "glass" and key != "emit":
		m.metallic_specular = 0.0 if toon else 0.5


static func get_mat(key: String) -> Material:
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	if SCALE.has(key):
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * float(SCALE[key])
		m.normal_scale = 0.45
		if key == "asphalt":
			m.albedo_color = Color(0.5, 0.5, 0.52)
	elif key == "glass":
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.55, 0.7, 0.78, 0.28)
		m.roughness = 0.05
		m.metallic = 0.3
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	elif key == "emit":
		m.emission_enabled = true
		m.emission = Color.WHITE
		m.emission_energy_multiplier = 1.4
		m.albedo_color = Color.WHITE
		m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		m.emission_texture = null
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	elif key == "dark":
		m.roughness = 0.6
	else:
		m.roughness = 0.85
	_style(m, key)
	_cache[key] = m
	return m
