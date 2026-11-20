class_name UiTheme
## Giao diện chung cho mọi menu: nút phẳng nền tối, viền mảnh; rê chuột viền hổ phách; nút chính tô hổ phách.

const INK := Color("ebe5d8")
const DIM := Color("9a958b")
const AMBER := Color("e4a03a")
const BG := Color(0.07, 0.08, 0.09, 0.96)

static var _theme: Theme


static func _box(bg: Color, border: Color, width := 1, pad_x := 18, pad_y := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(10)
	s.content_margin_left = pad_x
	s.content_margin_right = pad_x
	s.content_margin_top = pad_y
	s.content_margin_bottom = pad_y
	return s


static func make() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 15
	# --- nút thường
	t.set_stylebox("normal", "Button", _box(Color(0.11, 0.12, 0.13, 0.95), Color(0.92, 0.9, 0.85, 0.22)))
	t.set_stylebox("hover", "Button", _box(Color(0.16, 0.15, 0.13, 0.98), AMBER, 2, 17, 9))
	t.set_stylebox("pressed", "Button", _box(AMBER.darkened(0.15), AMBER, 2, 17, 9))
	t.set_stylebox("disabled", "Button", _box(Color(0.09, 0.1, 0.11, 0.6), Color(0.92, 0.9, 0.85, 0.08)))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), AMBER, 2, 17, 9))
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color("151515"))
	t.set_color("font_disabled_color", "Button", Color(0.6, 0.58, 0.54, 0.6))
	t.set_color("icon_normal_color", "Button", Color.WHITE)
	t.set_font_size("font_size", "Button", 15)
	t.set_constant("h_separation", "Button", 10)
	# --- nút chính (hành động quan trọng nhất trên màn hình)
	t.set_type_variation("Primary", "Button")
	t.set_stylebox("normal", "Primary", _box(AMBER, AMBER, 1, 22, 12))
	t.set_stylebox("hover", "Primary", _box(AMBER.lightened(0.18), Color.WHITE, 2, 21, 11))
	t.set_stylebox("pressed", "Primary", _box(AMBER.darkened(0.2), AMBER, 2, 21, 11))
	t.set_stylebox("focus", "Primary", _box(Color(0, 0, 0, 0), Color.WHITE, 2, 21, 11))
	t.set_color("font_color", "Primary", Color("151515"))
	t.set_color("font_hover_color", "Primary", Color("000000"))
	t.set_color("font_pressed_color", "Primary", Color("000000"))
	t.set_font_size("font_size", "Primary", 17)
	# --- nút nguy hiểm (thoát, về menu)
	t.set_type_variation("Quiet", "Button")
	t.set_stylebox("normal", "Quiet", _box(Color(0, 0, 0, 0), Color(0.92, 0.9, 0.85, 0.12)))
	t.set_color("font_color", "Quiet", DIM)
	# --- ô vật phẩm
	t.set_type_variation("Slot", "Button")
	t.set_stylebox("normal", "Slot", _box(Color(0.1, 0.11, 0.12, 0.9), Color(0.92, 0.9, 0.85, 0.14), 1, 6, 6))
	t.set_stylebox("hover", "Slot", _box(Color(0.18, 0.16, 0.12, 0.95), AMBER, 2, 5, 5))
	t.set_stylebox("pressed", "Slot", _box(Color(0.24, 0.2, 0.12, 1.0), AMBER, 2, 5, 5))
	# --- ô nhập, bảng, thanh trượt
	t.set_stylebox("normal", "LineEdit", _box(Color(0.05, 0.06, 0.07, 0.95), Color(0.92, 0.9, 0.85, 0.22), 1, 12, 9))
	t.set_stylebox("focus", "LineEdit", _box(Color(0.05, 0.06, 0.07, 0.95), AMBER, 2, 11, 8))
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", Color(0.6, 0.58, 0.54, 0.7))
	t.set_stylebox("panel", "PanelContainer", _box(BG, Color(0.92, 0.9, 0.85, 0.16), 1, 14, 12))
	t.set_stylebox("panel", "Panel", _box(Color(0.1, 0.11, 0.12, 0.5), Color(0.92, 0.9, 0.85, 0.08), 1, 0, 0))
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.92, 0.9, 0.85, 0.18)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = AMBER
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_color("font_color", "Label", INK)
	_theme = t
	return t


## Bảng màu bản đồ: tả thực (nền trắng) hoặc vẽ tay (nền giấy, viền mực) theo phong cách đang chọn.
static func map_pal() -> Dictionary:
	if Game.toon():
		return {
			"bg": Color("e6d8ba"), "frame": Color("3a2e2c"), "road": Color("fbf5e6"), "edge": Color("3a2e2c"), "block": Color("f0e4c8"),
			"lake": Color("8ecbe6"), "lake_edge": Color("3a2e2c"), "grass": Color("c3dca0"), "forest": Color("86b56a"), "field": Color("bcdc8c"),
			"slum": Color("dcc6a0"), "site": Color("e6d29c"), "ink": Color("3a2e2c"), "ink_w": 1.3, "centre": Color(0.45, 0.36, 0.3, 0.45), "tree": Color("5f9a4c"),
			"house": Color("f6e7b4"), "ruin": Color("b08a78"), "extra": Color("cdbfa4"),
		}
	return {
		"bg": Color("dfe1e4"), "frame": Color("b9bcc0"), "road": Color("ffffff"), "edge": Color("c9ccd0"), "block": Color("f1efea"),
		"lake": Color("a8d1e6"), "lake_edge": Color("7fb2cc"), "grass": Color("cfe6c3"), "forest": Color("a9cf98"), "field": Color("d6ecc4"),
		"slum": Color("e6dccb"), "site": Color("ece4cf"), "ink": Color(0, 0, 0, 0), "ink_w": 1.0, "centre": Color(0.55, 0.57, 0.6, 0.55), "tree": Color("9cc48a"),
		"house": Color("d4d2cd"), "ruin": Color("b89a8c"), "extra": Color("c2c0ba"),
	}


static func cell_color(cell: Vector2i, pal: Dictionary) -> Color:
	match City.cell_kind(cell):
		"lake": return pal.grass
		"forest": return pal.forest
		"field": return pal.field
		"slum": return pal.slum
		"site": return pal.site
	return pal.block


## Màu một ngôi nhà trên bản đồ.
static func building_color(b: Dictionary, pal: Dictionary) -> Color:
	var col: Color = pal.house
	match b.kind:
		"shop": col = Color(City.SHOPS[b.shop].color).lerp(Color("e8e6e1"), 0.55 if Game.toon() else 0.7)
		"home": col = Color("f2c96a")
		"tu": col = Color("dcd49a")
		"office": col = Color("b9c9dc")
		"tower": col = Color("b4b8be") if not Game.toon() else Color("c2cbe0")
		"mall", "super": col = Color("f0c4bc")
		"restaurant": col = Color("f2dcb4")
		"shack": col = Color("cbb08c")
		"tro": col = Color("e0bfa6")
		"closed": col = pal.house.darkened(0.12)
		"hospital": col = Color("f4d4d0")
		"school", "hall": col = Color("f2dc96")
		"mansion": col = Color("e8dcb8")
		"radio": col = Color("c8ccd4")
	if b.get("ruined", false):
		col = pal.ruin
	elif b.has("damage"):
		col = col.lerp(pal.ruin, 0.6)
	return col
