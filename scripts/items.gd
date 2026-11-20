extends Node
## Bảng vật phẩm, biểu tượng và bảng rơi đồ (đọc từ data/items.json).

var defs: Dictionary = {}
var loot: Dictionary = {}
var lore: Array = []
var _icons: Dictionary = {}


func _ready() -> void:
	var f := FileAccess.open("res://data/items.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	defs = data.ITEMS
	loot = data.LOOT
	lore = data.LORE


func get_def(id: String) -> Dictionary:
	return defs.get(id, {})


func item_name(id: String) -> String:
	return get_def(id).get("n", id)


## Đường dẫn biểu tượng của món đồ. Tên file trùng tên thiết bị dành riêng của Windows (con, prn, aux, nul...) thì
## không mở được trên Windows ("cồn" có mã "con"), nên các món đó dùng tiền tố item_.
static func icon_path(id: String) -> String:
	var reserved := ["con", "prn", "aux", "nul", "com1", "com2", "com3", "lpt1", "lpt2"]
	return "res://assets/icons/%s%s.png" % ["item_" if id.to_lower() in reserved else "", id]


func icon(id: String) -> Texture2D:
	if not _icons.has(id):
		var path := Items.icon_path(id)
		_icons[id] = load(path) if ResourceLoader.exists(path) else null
	return _icons[id]


func category_name(cat: String) -> String:
	return {"food": "ĂN", "drink": "UỐNG", "med": "Y TẾ", "tool": "DỤNG CỤ", "gear": "TRANG BỊ"}.get(cat, cat.to_upper())


## Mô tả ngắn các chỉ số của vật phẩm.
func describe(id: String) -> String:
	var d := get_def(id)
	var parts := PackedStringArray()
	if d.has("food"): parts.append("%+d no" % int(d.food))
	if d.has("water"): parts.append("%+d nước" % int(d.water))
	if d.has("heal"): parts.append("+%d máu" % int(d.heal))
	if d.has("stam"): parts.append("+%d sức" % int(d.stam))
	if d.has("treat"): parts.append({"bleed": "cầm máu", "fracture": "nẹp gãy xương", "pain": "giảm đau", "infect": "trị nhiễm trùng", "clean": "sát trùng vết thương", "kit": "cầm máu + sát trùng"}.get(d.treat, ""))
	if d.has("weapon") and not d.has("gun"): parts.append("vũ khí · %d lần đánh" % int(d.weapon))
	if d.has("gun"): parts.append("súng · cần băng đạn")
	if d.has("armor"): parts.append("-%d%% sát thương" % int(d.armor * 100))
	if d.has("headArmor"): parts.append("bảo vệ đầu %d%%" % int(d.headArmor * 100))
	if d.has("legArmor"): parts.append("bảo vệ chân %d%%" % int(d.legArmor * 100))
	if d.has("stealth"): parts.append("khó bị thấy %+d%%" % int(d.stealth * 100))
	if d.has("speed") and d.speed != 0: parts.append("tốc độ %+d%%" % int(d.speed * 100))
	if d.has("quiet"): parts.append("bước êm %d%%" % int(d.quiet * 100))
	if d.has("cap"): parts.append("+%dkg sức chứa" % int(d.cap))
	if d.has("watch"): parts.append("hiện quái vật trên bản đồ")
	if d.has("clock"): parts.append("xem giờ chính xác")
	if d.has("pry"): parts.append("cạy được cửa hầm")
	parts.append("%.1fkg" % float(d.get("w", 0)))
	return " · ".join(parts)


## Rút `count` món từ bảng `table` (máy chủ gọi).
func roll(table: String, count: int, rng: RandomNumberGenerator) -> Array:
	var t: Array = loot.get(table, loot.house)
	var total := 0.0
	for e: Array in t:
		total += float(e[1])
	var out := []
	for i in count:
		var r := rng.randf() * total
		for e: Array in t:
			r -= float(e[1])
			if r <= 0.0:
				out.append(e[0])
				break
	return out
