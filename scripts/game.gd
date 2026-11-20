extends Node
## Trạng thái của người chơi trên máy này: chỉ số sinh tồn, thương tích, túi đồ, trang bị, cài đặt.

signal toast(text: String, kind: String)
signal objective_changed(text: String)
signal inventory_changed
signal hurt(amount: float, kind: String)
signal player_died(reason: String)
signal shake(amount: float)
signal game_won(bad_ending: bool)
signal refuel(amount: float)

const PARTS := ["head", "torso", "arm_l", "arm_r", "leg_l", "leg_r"]
const PART_NAMES := {"head": "Đầu", "torso": "Thân", "arm_l": "Tay trái", "arm_r": "Tay phải", "leg_l": "Chân trái", "leg_r": "Chân phải"}
const INJURY_NAMES := {"bleed": "Chảy máu", "fracture": "Gãy xương", "wound": "Vết thương hở", "infect": "Nhiễm trùng", "pain": "Đau nhức"}
const INJURY_CURE := {"bleed": "Băng gạc / Hộp sơ cứu", "fracture": "Nẹp cố định", "wound": "Cồn sát trùng / Hộp sơ cứu", "infect": "Thuốc kháng sinh", "pain": "Thuốc giảm đau"}
const BASE_CAPACITY := 8.0
const GOD_PASSWORD := "thucgiac"
const DIFFS := {
	"easy": {"name": "Dễ", "damage": 0.6, "drain": 0.7, "sense": 0.75},
	"normal": {"name": "Thường", "damage": 1.0, "drain": 1.0, "sense": 1.0},
	"hard": {"name": "Khó", "damage": 1.45, "drain": 1.35, "sense": 1.3},
}

# --- chỉ số
var hp := 100.0
var food := 100.0
var water := 100.0
var stamina := 100.0
var breath := 100.0
var noise := 0.0
var dead := false
var death_reason := ""
var won := false
var injuries: Array[Dictionary] = []
var painkiller := 0.0
# --- đồ đạc
var inv: Dictionary = {}
var equip := {"head": "", "eyes": "", "body": "", "feet": "", "back": "", "wrist": "", "weapon": ""}
## Đang bật kính nhìn đêm (phím N, phải đeo kính ở ô mắt).
var nv_on := false
## Chương đang chơi (1: về nhà, 2: dưới hầm) và đồ mang sang chương sau. Không bị xoá khi nạp lại màn.
var chapter := 1
var carry: Dictionary = {}
## Đang trong một đoạn hội thoại phụ đề: người chơi bị khoá điều khiển; chơi một mình thì cả cảnh dừng lại.
var talking := false
var flash_boost := 1.0
var coffee := 0.0            # còn bao nhiêu giây tỉnh táo nhờ cà phê (chạy tốn nửa thể lực)
## Thanh công cụ (4 ô, phím 1-4 hoặc lăn chuột) và tay trái (phím F đổi tay). Món trong ô vẫn nằm trong túi.
## Đang vác vật nặng bằng hai tay: "" | "machine" | "body". Vác thì chậm 40%, không nhảy, không đánh.
var carrying := ""
## Bị xúc tu Quỷ Mắt quấn: không đi được, bị giữ ở grab_pos (vẫn đánh được để thoát).
## Thanh tiến độ khi giữ E làm việc gì đó (sửa ống...): 0..1, "" = không hiện.
var hold_label := ""
var hold_prog := 0.0
var grabbed := false
var grab_pos := Vector3.ZERO
## Đã biết mã két sắt bệnh viện (đọc được trong bộ nhớ máy dò).
var safe_code := false
var hotbar: Array = ["", "", "", ""]
var hot_sel := 0
var offhand := ""
var weapon_uses := 0
var wear: Dictionary = {}        # món có độ bền -> số lần đánh còn lại
var money := 350000
var ammo := 0
# --- đạo đức / thống kê
var cruelty := 0.0
var helped := 0
var distance := 0.0
var play_time := 0.0
# --- cảm nhận của quái vật về mình (để hiện trên HUD)
var awareness := 0.0
var sense := ""
var hunted := false
# --- khác
var god := false
var shake_freq := 1.0
var fly := false
var indoors := false
var submerged := false
var difficulty := "normal"
var settings := {"shake": 0.5, "sens": 1.0, "volume": 0.8, "quality": 2, "fov": 75.0, "style": 1}
var objective := "Chuyện gì đang xảy ra ngoài kia?":
	set(value):
		objective = value
		objective_changed.emit(value)


func _ready() -> void:
	load_settings()
	inventory_changed.connect(_hot_clean)


# ------------------------------------------------------------------ thanh công cụ
## Món nên tự đặt lên thanh công cụ khi nhặt (vũ khí, súng, đồ ném, đèn pin, máy dò).
func hot_worthy(id: String) -> bool:
	var d := Items.get_def(id)
	return d.has("weapon") or d.has("gun") or d.has("throwable") or d.has("light") or d.has("scan")


## Đặt món vào ô i (bỏ khỏi ô khác/tay trái nếu đang ở đó). id rỗng: làm trống ô.
func assign_hot(i: int, id: String) -> void:
	if i < 0 or i > 3:
		return
	if id != "":
		for k in 4:
			if hotbar[k] == id:
				hotbar[k] = ""
		if offhand == id:
			offhand = ""
	hotbar[i] = id
	_sync_hand()
	inventory_changed.emit()


func auto_hot(id: String) -> void:
	if not hot_worthy(id) or hotbar.has(id) or offhand == id:
		return
	for k in 4:
		if hotbar[k] == "":
			hotbar[k] = id
			_sync_hand()
			return


func select_hot(i: int) -> void:
	hot_sel = posmod(i, 4)
	_sync_hand()
	inventory_changed.emit()


## Phím F: đổi món ở tay phải (ô đang chọn) với tay trái.
func swap_hand() -> void:
	var main_id: String = hotbar[hot_sel]
	hotbar[hot_sel] = offhand
	offhand = main_id
	_sync_hand()
	inventory_changed.emit()


func _sync_hand() -> void:
	var id: String = hotbar[hot_sel]
	if equip.weapon != id:
		equip.weapon = id
		var d := Items.get_def(id)
		weapon_uses = int(wear.get(id, d.get("dur", 0)))


## Bỏ khỏi thanh công cụ những món không còn trong túi.
func _hot_clean() -> void:
	for k in 4:
		if hotbar[k] != "" and count(hotbar[k]) <= 0:
			hotbar[k] = ""
	if offhand != "" and count(offhand) <= 0:
		offhand = ""
	_sync_hand()


func reset() -> void:
	grabbed = false
	nv_on = false
	hp = 100.0
	food = 82.0
	water = 76.0
	stamina = 100.0
	breath = 100.0
	noise = 0.0
	dead = false
	death_reason = ""
	won = false
	injuries.clear()
	painkiller = 0.0
	inv = {"dienthoai": 1, "nuocsuoi": 1}
	equip = {"head": "", "eyes": "", "body": "", "feet": "", "back": "", "wrist": "", "weapon": ""}
	weapon_uses = 0
	wear = {}
	carrying = ""
	safe_code = false
	hotbar = ["", "", "", ""]
	hot_sel = 0
	offhand = ""
	flash_boost = 1.0
	coffee = 0.0
	talking = false
	money = 350000
	ammo = 0
	cruelty = 0.0
	helped = 0
	distance = 0.0
	play_time = 0.0
	awareness = 0.0
	sense = ""
	hunted = false
	god = false
	fly = false
	objective = "Chuyện gì đang xảy ra ngoài kia?"
	inventory_changed.emit()


## Phong cách hình ảnh: true = vẽ tay, false = tả thực.
func toon() -> bool:
	return int(settings.get("style", 1)) == 1


func diff() -> Dictionary:
	return DIFFS[difficulty]


## Cảnh đang dừng vì hội thoại (chỉ khi chơi một mình).
func frozen() -> bool:
	return talking and not Net.is_online()


func say(text: String, kind := "") -> void:
	toast.emit(text, kind)


# ------------------------------------------------------------------ sinh tồn mỗi khung hình
func _process(delta: float) -> void:
	if dead or won or get_tree().paused or frozen():
		return
	play_time += delta
	if god:
		hp = 100.0
		food = 100.0
		water = 100.0
		stamina = 100.0
		breath = 100.0
		injuries.clear()
		return
	var drain: float = diff().drain
	food = maxf(0.0, food - 0.045 * drain * delta)
	water = maxf(0.0, water - 0.07 * drain * delta)
	painkiller = maxf(0.0, painkiller - delta)
	coffee = maxf(0.0, coffee - delta)
	if food <= 0.0 or water <= 0.0:
		_lose(0.35 * delta, "Bạn kiệt sức vì đói khát.")
	for inj in injuries:
		inj.t += delta
		match inj.type:
			"bleed":
				_lose(0.55 * delta, "Bạn mất quá nhiều máu.")
			"infect":
				_lose(0.22 * delta, "Vết thương nhiễm trùng đã quật ngã bạn.")
			"wound":
				# Vết thương hở để lâu không sát trùng sẽ nhiễm trùng.
				if inj.t > 150.0:
					inj.type = "infect"
					inj.t = 0.0
					say("Vết thương ở %s đã nhiễm trùng. Cần thuốc kháng sinh." % PART_NAMES[inj.part].to_lower(), "bad")
	if hp < 100.0 and food > 60.0 and water > 60.0 and not has_injury("bleed") and not has_injury("infect"):
		hp = minf(100.0, hp + 0.25 * delta)


func _lose(amount: float, reason: String) -> void:
	hp = maxf(0.0, hp - amount)
	if hp <= 0.0:
		die(reason)


func die(reason: String) -> void:
	if dead or god:
		return
	dead = true
	death_reason = reason
	player_died.emit(reason)


func has_injury(type: String, part := "") -> bool:
	for inj in injuries:
		if inj.type == type and (part == "" or inj.part == part or (part == "leg" and inj.part.begins_with("leg")) or (part == "arm" and inj.part.begins_with("arm"))):
			return true
	return false


func add_injury(part: String, type: String) -> void:
	for inj in injuries:
		if inj.part == part and inj.type == type:
			return
	injuries.append({"part": part, "type": type, "t": 0.0})


## Nhận sát thương. kind: slash (cào/cắn), crush (giẫm/đè), burn (lửa), fall (ngã), drown.
func damage(amount: float, kind := "crush", part := "") -> void:
	if dead or god or won:
		return
	amount *= diff().damage
	if part == "":
		part = PARTS[randi() % PARTS.size()] if kind != "fall" else ("leg_l" if randf() < 0.5 else "leg_r")
	var armor := stat("armor")
	if part == "head":
		armor += stat("headArmor")
	elif part.begins_with("leg"):
		armor += stat("legArmor")
	if kind != "drown":
		amount *= 1.0 - clampf(armor, 0.0, 0.85)
	hp = maxf(0.0, hp - amount)
	hurt.emit(amount, kind)
	if kind != "drown":
		Sfx.play("hurt", -4.0)
		shake.emit(clampf(amount / 40.0, 0.15, 1.0))
	if amount >= 8.0 and diff().damage >= 1.0 or amount >= 14.0:
		match kind:
			"slash":
				add_injury(part, "bleed")
				if randf() < 0.5:
					add_injury(part, "wound")
			"crush", "fall":
				if amount >= 18.0 and not part in ["head", "torso"]:
					add_injury(part, "fracture")
				add_injury(part, "pain")
			"burn":
				add_injury(part, "wound")
				add_injury(part, "pain")
	if hp <= 0.0:
		die({"slash": "Bạn bị quái vật xé xác.", "crush": "Bạn bị nghiền nát.", "burn": "Bạn bị thiêu cháy.", "fall": "Bạn ngã quá cao.", "drown": "Bạn chết đuối dưới hồ."}.get(kind, "Bạn đã chết."))


# ------------------------------------------------------------------ túi đồ
func count(id: String) -> int:
	return int(inv.get(id, 0))


func weight() -> float:
	var w := 0.0
	for id: String in inv:
		w += float(Items.get_def(id).get("w", 0.0)) * int(inv[id])
	for slot: String in equip:
		if equip[slot] != "":
			w += float(Items.get_def(equip[slot]).get("w", 0.0)) * 0.5   # đồ đang mặc nhẹ hơn mang vác
	return w


func capacity() -> float:
	return 999.0 if god else BASE_CAPACITY + stat("cap")


func can_carry(id: String) -> bool:
	return weight() + float(Items.get_def(id).get("w", 0.0)) <= capacity() + 0.001


## Món này nhặt lên là mặc/đeo thẳng lên người (chỗ đó đang trống) chứ không cần chỗ trong túi?
func wears_directly(id: String) -> bool:
	var slot: String = Items.get_def(id).get("slot", "")
	return slot != "" and (equip[slot] == "" or (id == "dongho" and equip.wrist == "donghotay"))


## Nhận được món này không (còn sức mang, hoặc mặc thẳng lên người).
func can_take(id: String) -> bool:
	return can_carry(id) or wears_directly(id)


func add_item(id: String, n := 1, silent := false) -> bool:
	var d := Items.get_def(id)
	if d.is_empty():
		return false
	if d.has("wallet"):
		var cash := 20000 * (1 + randi() % 12)
		money += cash
		say("Nhặt được ví: +%s đ" % format_money(cash), "good")
		return true
	if d.has("ammo"):
		ammo += int(d.ammo) * n
		say("Nhặt băng đạn: %d viên" % ammo, "good")
		inventory_changed.emit()
		return true
	if not can_take(id):
		say("Túi quá nặng. Vứt bớt đồ hoặc tìm balo lớn hơn.", "bad")
		return false
	# Đồ mặc được: nhặt lên là mặc luôn nếu chỗ đó còn trống, không cần cất vào túi rồi mới mặc.
	var slot: String = d.get("slot", "")
	if slot != "" and (equip[slot] == "" or (id == "dongho" and equip.wrist == "donghotay")):
		if equip[slot] != "":
			inv[equip[slot]] = count(equip[slot]) + 1
		equip[slot] = id
		Sfx.play("pickup", -6.0)
		say("Đã %s %s." % ["đeo" if slot == "wrist" or slot == "back" else "mặc", d.n] + (" Quái vật giờ hiện trên bản đồ." if id == "dongho" else ""), "good")
		inventory_changed.emit()
		return true
	inv[id] = count(id) + n
	auto_hot(id)
	if not silent:
		Sfx.play("pickup", -6.0)
	inventory_changed.emit()
	return true


func remove_item(id: String, n := 1) -> void:
	var c := count(id) - n
	if c <= 0:
		inv.erase(id)
	else:
		inv[id] = c
	inventory_changed.emit()


## Tổng chỉ số từ trang bị đang mặc (speed, stealth, armor, headArmor, legArmor, quiet, cap).
func stat(key: String) -> float:
	var total := 0.0
	for slot: String in equip:
		if equip[slot] != "":
			total += float(Items.get_def(equip[slot]).get(key, 0.0))
	if key == "stealth" and equip.body == "":
		total -= 0.12   # áo sơ mi trắng dễ bị thấy
	return total


## Đang đeo đồng hồ (loại nào cũng xem được giờ).
func has_clock() -> bool:
	return equip.wrist != "" or god


## Đang đeo đồng hồ định vị: thấy quái vật trên bản đồ.
func has_watch() -> bool:
	return equip.wrist == "dongho" or god


## Dùng / mặc / cầm một món trong túi.
func use_item(id: String) -> void:
	if count(id) <= 0 or dead:
		return
	var d := Items.get_def(id)
	match d.get("cat", ""):
		"food", "drink":
			food = clampf(food + float(d.get("food", 0)), 0.0, 100.0)
			water = clampf(water + float(d.get("water", 0)), 0.0, 100.0)
			stamina = clampf(stamina + float(d.get("stam", 0)), 0.0, 100.0)
			if d.has("coffee"):
				coffee = float(d.coffee)
				say("Tỉnh táo hẳn. Trong 4 phút tới chạy đỡ mệt hơn.", "good")
			remove_item(id)
			Sfx.play("eat" if d.cat == "food" else "drink", -5.0)
			say("Đã dùng %s" % d.n, "good")
		"med":
			_treat(id, d)
		"gear":
			var slot: String = d.slot
			var old: String = equip[slot]
			remove_item(id)
			equip[slot] = id
			if old != "":
				inv[old] = count(old) + 1
			Sfx.play("ui_open", -6.0)
			say("Đã mặc %s" % d.n, "good")
			inventory_changed.emit()
		"tool":
			if d.has("weapon") or d.has("throwable") or d.has("gun") or d.has("light") or d.has("scan"):
				# cầm lên tay: đặt vào ô đang chọn của thanh công cụ (đang cầm rồi thì bỏ xuống)
				if hotbar[hot_sel] == id:
					assign_hot(hot_sel, "")
				else:
					assign_hot(hot_sel, id)
					say("Đang cầm %s" % d.n)
			elif d.has("fuel"):
				var p := get_tree().get_first_node_in_group("world")
				var rider: Node = p.local_player() if p else null
				if rider and rider.riding_bike():
					rider._on_refuel(float(d.fuel))
					remove_item(id)
				else:
					say("Phải đang ngồi trên xe máy mới đổ xăng được.")
			elif d.has("lore"):
				say(str(Items.lore[randi() % Items.lore.size()]))
			elif d.has("clock"):
				var wd := get_tree().get_first_node_in_group("world")
				if wd:
					say("Bây giờ là %s." % wd.weather.clock_text())
			elif d.has("watch"):
				say("Đồng hồ định vị: quái vật hiện trên bản đồ nhỏ.")
			elif d.has("radar"):
				say("Điện thoại mất sóng. Bản đồ (M) vẫn dùng được.")


func unequip(slot: String) -> void:
	var id: String = equip[slot]
	if id == "":
		return
	equip[slot] = ""
	if slot != "weapon":
		inv[id] = count(id) + 1
	inventory_changed.emit()


func _treat(id: String, d: Dictionary) -> void:
	var kind: String = d.treat
	var cured := false
	match kind:
		"bleed":
			cured = _cure("bleed")
		"fracture":
			cured = _cure("fracture")
		"infect":
			cured = _cure("infect")
		"clean":
			cured = _cure("wound")
		"pain":
			cured = _cure("pain")
			painkiller = 120.0
			cured = true
		"kit":
			var a := _cure("bleed", true)
			var b := _cure("wound", true)
			hp = minf(100.0, hp + float(d.get("heal", 0)))
			cured = a or b or true
	if not cured:
		say("Bạn không có vết thương nào cần %s." % d.n.to_lower())
		return
	remove_item(id)
	Sfx.play("bandage", -4.0)
	say("Đã dùng %s" % d.n, "good")


func _cure(type: String, all := false) -> bool:
	var found := false
	for i in range(injuries.size() - 1, -1, -1):
		if injuries[i].type == type:
			injuries.remove_at(i)
			found = true
			if not all:
				break
	return found


## Hệ số tốc độ do thương tích, cân nặng, trang bị.
func speed_factor() -> float:
	var f := 1.0 + stat("speed")
	if has_injury("fracture", "leg"):
		f *= 0.62
	if has_injury("pain") and painkiller <= 0.0:
		f *= 0.9
	if weight() > capacity() * 0.85:
		f *= 0.88
	if food < 15.0 or water < 15.0:
		f *= 0.85
	if carrying != "":
		f *= 0.6
	return f


func can_sprint() -> bool:
	return stamina > 1.0 and not has_injury("fracture", "leg")


func add_cruelty(amount: float, why := "") -> void:
	cruelty = clampf(cruelty + amount, 0.0, 100.0)
	if why != "":
		say(why, "bad")


static func format_money(v: int) -> String:
	var s := str(v)
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


# ------------------------------------------------------------------ cài đặt
func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k: String in settings:
		cfg.set_value("settings", k, settings[k])
	cfg.set_value("settings", "difficulty", difficulty)
	cfg.set_value("settings", "name", Net.my_name)
	cfg.save("user://settings.cfg")
	apply_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		for k: String in settings:
			settings[k] = cfg.get_value("settings", k, settings[k])
		difficulty = cfg.get_value("settings", "difficulty", difficulty)
		Net.my_name = cfg.get_value("settings", "name", Net.my_name)
	apply_settings()


func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(float(settings.volume), 0.0001, 1.0)))
