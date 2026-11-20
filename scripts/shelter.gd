extends Node3D
## Chương 2 "Dưới hầm": sinh tồn trong hầm trú ẩn cùng vợ con cho tới ngày cứu hộ đến.
## Ban ngày: chia khẩu phần ăn uống, thuốc men. Ban đêm: một chuyện xảy ra ở cửa hầm (ai đó gõ cửa, có thật là người không?),
## rồi mỗi người chọn ngủ tới sáng hoặc cầm đèn pin ra phố tìm đồ. Cả thành phố mất điện: chỉ còn đèn pin và ánh trăng.
##
## Chơi chung: máy chủ phòng giữ toàn bộ trạng thái (kho, gia đình, sự kiện) và gửi cho mọi máy hai lần mỗi giây.
## Chủ phòng chia khẩu phần trong cuốn sổ (ai cũng nhìn thấy sổ); chuyện ở cửa hầm thì cả phòng bỏ phiếu;
## ban đêm có thể tách đội: người ra ngoài lúc về phải gõ cửa, và không phải tiếng gõ nào cũng là người thật.

const HUNGER_WORDS := ["no", "hơi đói", "đói", "đói lả", "kiệt sức vì đói"]
const THIRST_WORDS := ["đủ nước", "khát", "rất khát", "khát nguy kịch"]
const MIMICS := ["ong_tu_gia", "tieng_tre_khoc", "may_phat", "dem_cuoi"]
const REAL_VISITORS := ["me_con", "ong_tu_that", "y_ta", "ba_sau", "linh_dao_ngu", "con_muc", "thao_tra_on"]
const MORNING_IDS := ["linh_bi_tim"]
const NEEDS_MAI := ["tieng_tre_khoc", "m_ba_ngoai", "m_nuoc_la"]
const NEEDS_NA := ["m_bup_be", "m_cau_hoi", "con_muc"]
## Những tác động rơi vào từng người chơi (máu, túi đồ) chứ không vào kho chung.
const PERSONAL := ["hp", "bleed", "bag", "bag_clear", "bag_half", "bag_food", "bag_food_one", "cruelty", "noise"]

var world: Node3D
var city: City
var ui: CanvasLayer
var rng := RandomNumberGenerator.new()
var active := false

var day := 1
var phase := "day"            # day | morning_event | event | choose | ending
## Tủ chứa đồ trong hầm: các món đồ thật (id -> số lượng). Mỗi món ăn / món uống tính là một phần.
var storage: Dictionary = {}
var food: int:
	get:
		return _cat_count("food")
	set(v):
		_cat_set("food", v)
var water: int:
	get:
		return _cat_count("drink")
	set(v):
		_cat_set("drink", v)
const GENERIC := {"food": ["mitom", "cahop", "banhquy", "luongkho"], "drink": ["nuocsuoi"]}
var meds := {"khangsinh": 0, "giamdau": 1, "bang": 2}
var family: Array = []
var guests: Array = []
var flags: Dictionary = {}
var morale := 60
var rescue_day := 8
var schedule: Dictionary = {}          # ngày -> [mã sự kiện]
var used: Array = []
var log_lines: Array = []
var rationed := false

# thứ đang hiện cho cả phòng
var panel := "none"            # none | journal | event | rations | choose
var journal: Dictionary = {}   # {title, body, button}
var plan: Dictionary = {}      # cuốn sổ chia khẩu phần: {id người: {eat, drink, med}}
var votes: Dictionary = {}     # phiếu ở cửa hầm: {mã máy: số lựa chọn}
var night: Dictionary = {}     # đêm nay mỗi người làm gì: {mã máy: "?" | "sleep" | "out"}
var knock: Dictionary = {}     # có tiếng gõ cửa hầm: {from, name, real}
var sites: Array = []          # điểm chạm trán ngoài phố đêm nay: [{id, pos, done}]

var current_id := ""
var current: Dictionary = {}
var current_text := ""
var current_done := false
var disabled: Array = []
var _queue: Array = []
var _pending_morning := ""
var _event_kind := ""          # night | morning | outside
var _local_event := false      # sự kiện ngoài phố: chỉ máy này thấy và tự quyết

var origin := Vector3.ZERO     # tâm sàn hầm
var exit_pos := Vector3.ZERO   # lối chui ra/vào trên mặt đất (nhà đã sập, lối ra nằm trước cửa)
var outside := false           # người chơi của máy này đang ở ngoài phố
var _spots: Array[Dictionary] = []
var _people: Dictionary = {}
var _site_nodes: Dictionary = {}
var _stock_node: Node3D
var _tally: Label3D
var ended := false
var _push_t := 0.0
var _fake_t := 90.0
var _render_key := ""
var _knock_wait := 0.0
# --- cốt truyện chương 2 (bản mới)
var mission := ""               # việc của chuyến ra ngoài đêm nay: loot | medicine | machine | pipe | help
var _pending_out := ""
var _pending_fight := 0
var _pending_sleep := false
var _ambush_p := 0.0
var _ambush_t := -1.0
var pipe_broken := false
var pipe_pos := Vector3.ZERO
var machine := {"state": "none", "pos": Vector3.ZERO, "carrier": 0}   # none | tower | carried | ground | placed
var bomb_day := -1              # sáng ngày này quân đội thả bom
var help := {}                  # cảnh cứu người: {pos, ids, done}
var _machine_node: Node3D
var _pipe_node: Node3D
var _victim: Node3D
const STAND := Vector3(-3.0, 0.0, -1.2)      # bệ đặt máy phát trong hầm (so với tâm sàn)


func setup(w: Node3D) -> void:
	world = w
	city = w.city
	rng.seed = int(Time.get_ticks_usec())
	rescue_day = 99
	family = [
		{"id": "me", "name": "Bạn", "hunger": 0, "thirst": 0, "sick": false, "sick_days": 0, "alive": true, "peer": 1},
		{"id": "mai", "name": "Mai", "hunger": 0, "thirst": 0, "sick": false, "sick_days": 0, "alive": true, "peer": 0},
		{"id": "na", "name": "Bé Na", "hunger": 0, "thirst": 0, "sick": false, "sick_days": 0, "alive": true, "peer": 0},
	]
	origin = Vector3(city.home_pos.x, -9.0, city.home_pos.z)
	# nắp hầm nằm trong nhà (giữa đống đổ nát của căn nhà đã sập); ống thông khí ở sân sau
	exit_pos = Vector3(city.hatch_pos.x, City.BASE, city.hatch_pos.z)
	_build_bunker()
	pipe_pos = city.home_back
	visible = false
	ui = (load("res://scripts/ui/shelter_ui.gd") as GDScript).new()
	ui.name = "ShelterUI"
	ui.layer = 6
	world.add_child(ui)
	ui.call("setup", self)


func _cat_count(cat: String) -> int:
	var n := 0
	for id: String in storage:
		if Items.get_def(id).get("cat", "") == cat:
			n += int(storage[id])
	return n


## Đặt số phần ăn/uống trong tủ: thêm món phổ thông, hoặc bớt đi những món "rẻ" nhất trước.
func _cat_set(cat: String, v: int) -> void:
	var diff := maxi(0, v) - _cat_count(cat)
	var gens: Array = GENERIC[cat]
	var k := 0
	while diff > 0:
		var id: String = gens[k % gens.size()]
		storage[id] = int(storage.get(id, 0)) + 1
		diff -= 1
		k += 1
	if diff < 0:
		var ids: Array = storage.keys().filter(func(i: String) -> bool: return Items.get_def(i).get("cat", "") == cat)
		ids.sort_custom(func(a: String, b: String) -> bool: return float(Items.get_def(a).get("food" if cat == "food" else "water", 0)) < float(Items.get_def(b).get("food" if cat == "food" else "water", 0)))
		for id2: String in ids:
			while diff < 0 and int(storage.get(id2, 0)) > 0:
				storage[id2] = int(storage[id2]) - 1
				diff += 1
			if int(storage.get(id2, 0)) <= 0:
				storage.erase(id2)


## Mọi thứ trong tủ (kể cả thuốc) để hiện lên bảng tủ chứa.
func chest_items() -> Dictionary:
	var out := storage.duplicate()
	for id: String in meds:
		if int(meds[id]) > 0:
			out[id] = int(out.get(id, 0)) + int(meds[id])
	return out


## Cất n món từ túi vào tủ.
func deposit(id: String, n: int) -> void:
	n = mini(n, Game.count(id))
	if n <= 0 or Items.get_def(id).has("quest"):
		return
	Game.remove_item(id, n)
	if Game.equip.get("weapon", "") == id and Game.count(id) <= 0:
		Game.equip.weapon = ""
	Sfx.play("pickup", -8.0)
	if is_host():
		_srv_deposit({id: n})
	else:
		_srv_deposit.rpc_id(1, {id: n})


func deposit_all() -> void:
	var d: Dictionary = {}
	for id: String in Game.inv.keys():
		if Items.get_def(id).has("quest") or id == "denpin" or Game.equip.get("weapon", "") == id:
			continue
		d[id] = Game.count(id)
	for id2: String in d:
		Game.inv.erase(id2)
	Game.inventory_changed.emit()
	if d.is_empty():
		return
	Sfx.play("pickup", -6.0)
	if is_host():
		_srv_deposit(d)
	else:
		_srv_deposit.rpc_id(1, d)


@rpc("any_peer", "reliable")
func _srv_deposit(d: Dictionary) -> void:
	if not is_host():
		return
	for id: String in d:
		var n := clampi(int(d[id]), 0, 999)
		if id in meds:
			meds[id] = int(meds[id]) + n
		else:
			storage[id] = int(storage.get(id, 0)) + n
	_push()


## Lấy n món từ tủ vào túi.
func withdraw(id: String, n: int) -> void:
	if not Game.can_carry(id):
		Game.say("Túi quá nặng.", "bad")
		return
	if is_host():
		_srv_withdraw(id, n)
	else:
		_srv_withdraw.rpc_id(1, id, n)


@rpc("any_peer", "reliable")
func _srv_withdraw(id: String, n: int) -> void:
	if not is_host():
		return
	var have := int(meds.get(id, 0)) if id in meds else int(storage.get(id, 0))
	n = clampi(n, 0, have)
	if n <= 0:
		return
	if id in meds:
		meds[id] = have - n
	else:
		storage[id] = have - n
		if int(storage[id]) <= 0:
			storage.erase(id)
	var pid := multiplayer.get_remote_sender_id()
	if pid == 0:
		_cl_give(id, n)
	else:
		_cl_give.rpc_id(pid, id, n)
	_push()


@rpc("authority", "reliable")
func _cl_give(id: String, n: int) -> void:
	Game.inv[id] = Game.count(id) + n
	Game.inventory_changed.emit()
	Sfx.play("pickup", -8.0)


func is_host() -> bool:
	return multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id()


func my_member() -> Dictionary:
	for f: Dictionary in family:
		if int(f.get("peer", 0)) == my_id():
			return f
	return {}


func _peers() -> Array:
	var out: Array = []
	for f: Dictionary in family:
		if int(f.get("peer", 0)) > 0:
			out.append(int(f.peer))
	return out


## Chủ phòng bắt đầu chương 2.
# ------------------------------------------------------------------ đèn yếu ở các điểm nhiệm vụ (đêm mất điện)
var _mlights: Array = []        # [{light, base, kind}]
var _blink: MeshInstance3D


func _add_mlight(pos: Vector3, color: Color, rng_m: float, energy: float, kind: String) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.omni_range = rng_m
	l.light_energy = energy
	l.omni_attenuation = 1.4
	l.shadow_enabled = false
	add_child(l)
	l.global_position = pos
	_mlights.append({"light": l, "base": energy, "kind": kind, "ph": randf() * TAU})


## Dựng một lần khi Chương 2 bật trên máy này. Chỉ là ánh sáng le lói, đủ để nhận ra chỗ cần tới từ xa:
## đèn khẩn cấp đỏ chập chờn ở bệnh viện, đèn bão ở trường, đèn máy phát ở biệt phủ, đèn xanh thiết bị trong phòng máy,
## đèn đỏ cảnh báo máy bay nhấp nháy trên đỉnh tháp phát sóng, biển "LỐI THOÁT" xanh ở đại siêu thị.
func _build_mission_lights() -> void:
	for lm: Dictionary in city.landmarks:
		var p: Vector3 = lm.pos
		match str(lm.name):
			"BỆNH VIỆN":
				_add_mlight(p + Vector3(0, 4.5, 0), Color("ff4a3a"), 14.0, 1.6, "flicker")
				_add_mlight(p + Vector3(0, 17.5, 0), Color("ff3a2a"), 22.0, 2.4, "flicker")      # đèn khẩn cấp trên mái
			"TRƯỜNG HỌC":
				_add_mlight(p + Vector3(0, 2.6, 0), Color("ffb45a"), 10.0, 1.2, "flame")
			"BIỆT PHỦ":
				_add_mlight(p + Vector3(0, 3.2, 0), Color("ffd890"), 11.0, 1.1, "steady")
			"ĐẠI SIÊU THỊ":
				_add_mlight(p + Vector3(0, 3.0, 0), Color("5aff8a"), 12.0, 1.0, "steady")
	if city.hospital_safe_cid >= 0:
		_add_mlight((city.containers[city.hospital_safe_cid].pos as Vector3) + Vector3(0, 1.8, 0.6), Color("ff5a4a"), 6.0, 0.9, "flicker")
	if city.radio_pos != Vector3.ZERO:
		_add_mlight(city.radio_pos + Vector3(0, 2.2, 0), Color("6aff9a"), 8.0, 1.0, "steady")
		_add_mlight(city.tower_pos + Vector3(0, City.TOWER_H + 1.0, 0), Color("ff2a1a"), 32.0, 6.0, "blink")
		_blink = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.7
		sm.height = 1.4
		_blink.mesh = sm
		var bm := StandardMaterial3D.new()
		bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bm.albedo_color = Color("ff2a1a")
		_blink.material_override = bm
		add_child(_blink)
		_blink.global_position = city.tower_pos + Vector3(0, City.TOWER_H + 0.8, 0)


func _update_mission_lights() -> void:
	if _mlights.is_empty():
		_build_mission_lights()
	var on: bool = world.weather.blackout and world.darkness() > 0.3
	var t := Time.get_ticks_msec() * 0.001
	for m: Dictionary in _mlights:
		var l: OmniLight3D = m.light
		l.visible = on
		if not on:
			continue
		var e: float = m.base
		match str(m.kind):
			"flicker":
				# đèn khẩn cấp sắp hết điện: lúc sáng lúc tắt
				var f := sin(t * 7.3 + float(m.ph)) * sin(t * 2.1 + float(m.ph) * 2.0)
				e *= 0.15 if f > 0.55 else (0.75 + 0.25 * sin(t * 31.0))
			"flame":
				e *= 0.8 + 0.2 * sin(t * 9.0 + float(m.ph)) * sin(t * 4.3)
			"blink":
				e *= 1.0 if fposmod(t, 1.6) < 0.35 else 0.0
		l.light_energy = e
	if _blink:
		_blink.visible = on and fposmod(t, 1.6) < 0.35


func start() -> void:
	if not Game.equip.has("eyes"):
		Game.equip["eyes"] = ""
	if not is_host():
		return
	if not Game.carry.is_empty():
		Game.inv = (Game.carry.inv as Dictionary).duplicate()
		Game.equip = (Game.carry.equip as Dictionary).duplicate()
		Game.ammo = int(Game.carry.ammo)
		Game.carry = {}
	else:
		Game.inv = {"dienthoai": 1, "xabeng": 1, "donghotay": 1}
	Game.inv["denpin"] = 1                 # đèn pin pin vô hạn, ai cũng có
	Game.offhand = "denpin"                # cầm sẵn ở tay trái: chuột phải bật/tắt
	storage = {"mitom": 2, "cahop": 1, "banhquy": 1, "luongkho": 1, "nuocsuoi": 5, "binhnuoc": 1}
	Game.inventory_changed.emit()
	(family[0] as Dictionary).name = Net.my_name if Net.is_online() else "Bạn"
	for pid: int in Net.players.keys():
		if pid != 1:
			_add_player_member(pid)
	world.weather.hour = 10.0
	_cl_activate.rpc()
	log_lines = ["Ngôi nhà đã sập xuống trên đầu. Cả nhà còn sống, dưới hầm.", "Trong hầm có %d phần đồ ăn và %d phần nước. Mỗi người mỗi ngày ăn uống đủ thì hết một phần mỗi thứ." % [food, water]]
	_morning()


func _add_player_member(pid: int) -> void:
	for f: Dictionary in family:
		if int(f.get("peer", 0)) == pid:
			return
	family.append({"id": "p%d" % pid, "name": str(Net.players.get(pid, "Bạn đồng hành")), "hunger": 0, "thirst": 0, "sick": false, "sick_days": 0, "alive": true, "peer": pid})
	food += 2
	water += 2


func on_player_joined(pid: int) -> void:
	if not active or not is_host() or pid == 1:
		return
	_add_player_member(pid)
	night[pid] = "sleep" if phase == "choose" else "?"
	_cl_activate.rpc_id(pid)
	_push()


func on_player_left(pid: int) -> void:
	if not active or not is_host():
		return
	family = family.filter(func(f: Dictionary) -> bool: return int(f.get("peer", 0)) != pid)
	votes.erase(pid)
	night.erase(pid)
	if int(knock.get("from", 0)) == pid:
		knock = {}
	_check_night_done()
	_push()


## Mọi máy: bật chương 2 (mất điện, vợ con đã xuống hầm, nhà đã sập, người chơi xuống hầm).
@rpc("authority", "reliable", "call_local")
func _cl_activate() -> void:
	if active:
		return
	active = true
	visible = true
	Game.chapter = 2
	world.stage = 4
	if not is_host():
		Game.inv = {"dienthoai": 1, "denpin": 1}
		Game.offhand = "denpin"
		Game.inventory_changed.emit()
	Game.flash_boost = 1.8
	world.weather.blackout = true
	for n: Dictionary in world.npcs.list:
		if n.kind == "wife" or n.kind == "child":
			(n.node as Node3D).visible = false
			n.pos = Vector3(0, -200, 0)
			n.alive = false
			n["hidden"] = true          # vợ con đang ở dưới hầm: bản ngoài phố ẩn hẳn
	for b in city.buildings:
		if b.kind == "home" and b.get("damage", "") != "collapse":
			city.damage_building(int(b.id), "collapse", 1)
	_to_bunker()


func _to_bunker() -> void:
	outside = false
	var p: CharacterBody3D = world.local_player()
	if p:
		var k := float(my_id() % 5)
		p.global_position = origin + Vector3(1.6 - k * 0.5, 0.1, 1.2 - k * 0.3)
		p.velocity = Vector3.ZERO
		p.rotation.y = 0.6


@rpc("authority", "reliable", "call_local")
func _cl_place_bunker() -> void:
	_to_bunker()


@rpc("authority", "reliable", "call_local")
func _cl_say(text: String, kind: String) -> void:
	Game.say(text, kind)


@rpc("authority", "reliable", "call_local")
func _cl_fade(text: String) -> void:
	ui.call("fade", text)


@rpc("authority", "reliable", "call_local")
func _cl_dialogue(lines: Array) -> void:
	world.dialogue.play(lines)


# ------------------------------------------------------------------ đồng bộ trạng thái
func pack() -> Dictionary:
	return {"day": day, "phase": phase, "storage": storage, "meds": meds, "family": family, "guests": guests, "flags": flags.keys(),
		"morale": morale, "rescue_day": rescue_day, "rationed": rationed, "panel": panel, "journal": journal, "plan": plan, "votes": votes,
		"night": night, "knock": knock, "sites": sites, "cur": "" if _local_event else current_id, "text": current_text, "done": current_done,
		"disabled": disabled, "kind": _event_kind, "ended": ended,
		"mission": mission, "pipe": pipe_broken, "machine": machine, "bomb": bomb_day, "help": help}


func _push() -> void:
	if is_host() and active:
		if world.online_peers() > 0:
			_cl_state.rpc(pack())
		_after_state()


@rpc("authority", "reliable")
func _cl_state(d: Dictionary) -> void:
	day = d.day
	phase = d.phase
	storage = d.storage
	meds = d.meds
	family = d.family
	guests = d.guests
	flags = {}
	for k: String in d.flags:
		flags[k] = true
	morale = d.morale
	rescue_day = d.rescue_day
	rationed = d.rationed
	panel = d.panel
	journal = d.journal
	plan = d.plan
	votes = d.votes
	night = d.night
	knock = d.knock
	sites = d.sites
	ended = d.ended
	mission = d.mission
	pipe_broken = d.pipe
	machine = d.machine
	bomb_day = d.bomb
	help = d.help
	if not _local_event:
		current_id = d.cur
		current = ShelterEvents.EVENTS.get(current_id, {})
		current_text = d.text
		current_done = d.done
		disabled = d.disabled
		_event_kind = d.kind
	_after_state()


## Sau mỗi lần trạng thái đổi (ở mọi máy): dựng lại những gì nhìn thấy, mở đúng bảng.
func _after_state() -> void:
	_sync_story_nodes()
	if world.inv_ui.is_open() and world.inv_ui.storage_mode:
		world.inv_ui._refresh()
	_refresh_room()
	_update_objective()
	_sync_sites()
	var me := my_member()
	if not me.is_empty() and not me.alive and not Game.dead and not Game.god:
		Game.die("Bạn đã kiệt sức dưới hầm.")
	_render()


func _render() -> void:
	if _local_event or outside or ended:
		return
	var want := panel
	if not knock.is_empty() and night.get(my_id(), "?") != "out":
		want = "knock"
	elif panel == "choose" and str(night.get(my_id(), "?")) != "?":
		want = "wait"
	var key := var_to_str([want, journal, current_id, current_text, current_done, disabled, votes, plan, knock, night, food, water, meds])
	if key == _render_key:
		return
	_render_key = key
	match want:
		"journal":
			ui.call("show_journal", journal.title, journal.body, str(journal.button) if is_host() else "", ack_journal)
		"event":
			ui.call("show_event")
		"rations":
			ui.call("show_rations")
		"choose":
			ui.call("show_night_choice")
		"knock":
			ui.call("show_knock", str(knock.name))
		"wait":
			ui.call("show_wait")
		_:
			ui.call("close_all")


# ------------------------------------------------------------------ dựng căn hầm
func _build_bunker() -> void:
	var node := Node3D.new()
	node.name = "Bunker"
	add_child(node)
	var mb := MeshBuilder.new(node)
	var o := origin
	var wall := Color(0.78, 0.77, 0.74)
	mb.box("concrete", o + Vector3(0, -0.15, 0), Vector3(7.6, 0.3, 6.6), Color(0.7, 0.69, 0.66))
	mb.box("concrete", o + Vector3(0, 2.75, 0), Vector3(7.6, 0.3, 6.6), wall)
	mb.box("concrete", o + Vector3(-3.65, 1.3, 0), Vector3(0.3, 2.6, 6.6), wall)
	mb.box("concrete", o + Vector3(3.65, 1.3, 0), Vector3(0.3, 2.6, 6.6), wall)
	mb.box("concrete", o + Vector3(0, 1.3, -3.15), Vector3(7.6, 2.6, 0.3), wall)
	mb.box("concrete", o + Vector3(0, 1.3, 3.15), Vector3(7.6, 2.6, 0.3), wall)
	# thang lên cửa hầm
	for sx: float in [-0.3, 0.3]:
		mb.box("metal", o + Vector3(2.6 + sx, 1.3, 2.85), Vector3(0.06, 2.6, 0.06), Color(0.6, 0.62, 0.66), 0)
	for i in 8:
		mb.box("metal", o + Vector3(2.6, 0.25 + i * 0.32, 2.85), Vector3(0.6, 0.04, 0.05), Color(0.6, 0.62, 0.66), 0)
	mb.box("rust", o + Vector3(2.6, 2.58, 2.5), Vector3(1.0, 0.06, 0.9), Color(0.5, 0.52, 0.56), 0)
	# bàn + đài + đèn bão
	mb.box("wood", o + Vector3(-1.6, 0.72, -2.4), Vector3(1.6, 0.06, 0.8), Color(0.7, 0.6, 0.46))
	for lx: float in [-0.7, 0.7]:
		for lz: float in [-0.3, 0.3]:
			mb.box("wood", o + Vector3(-1.6 + lx, 0.36, -2.4 + lz), Vector3(0.07, 0.7, 0.07), Color(0.6, 0.5, 0.38), 0)
	mb.box("dark", o + Vector3(-2.1, 0.86, -2.5), Vector3(0.34, 0.2, 0.16), Color(0.25, 0.24, 0.22), 0)        # radio
	mb.box("emit", o + Vector3(-2.02, 0.9, -2.415), Vector3(0.08, 0.05, 0.01), Color(0.9, 0.6, 0.2), 0)
	mb.box("metal", o + Vector3(-2.24, 1.2, -2.5), Vector3(0.012, 0.5, 0.012), Color(0.7, 0.7, 0.72), 0)
	mb.box("rust", o + Vector3(-1.1, 0.84, -2.35), Vector3(0.12, 0.18, 0.12), Color(0.5, 0.45, 0.4), 0)        # đèn bão
	mb.box("emit", o + Vector3(-1.1, 0.9, -2.35), Vector3(0.07, 0.09, 0.07), Color(1.0, 0.75, 0.4), 0)
	mb.box("wood", o + Vector3(-1.6, 0.25, -1.75), Vector3(1.2, 0.06, 0.3), Color(0.62, 0.52, 0.4))            # ghế băng
	# kệ đồ sát tường đông
	for y: float in [0.35, 0.95, 1.55]:
		mb.box("wood", o + Vector3(3.2, y, -0.6), Vector3(0.5, 0.05, 2.6), Color(0.66, 0.56, 0.42), 0)
	for z: float in [-1.9, 0.7]:
		mb.box("wood", o + Vector3(3.2, 0.9, z), Vector3(0.5, 1.8, 0.06), Color(0.6, 0.5, 0.38), 0)
	mb.collider(o + Vector3(3.2, 0.9, -0.6), Vector3(0.5, 1.8, 2.6), "wood", 1)
	# ba chỗ nằm
	for i in 3:
		var bx := -2.9 + i * 1.05
		mb.box("wood", o + Vector3(bx, 0.12, 2.0), Vector3(0.9, 0.12, 1.9), Color(0.62, 0.52, 0.4))
		mb.box("flat", o + Vector3(bx, 0.21, 2.1), Vector3(0.84, 0.06, 1.5), [Color("7a8ab0"), Color("b07a8a"), Color("e0b84a")][i], 0)
		mb.box("flat", o + Vector3(bx, 0.24, 1.25), Vector3(0.6, 0.08, 0.32), Color(0.92, 0.9, 0.84), 0)
	# can nước, thùng phuy, chăn màn treo
	mb.box("paint", o + Vector3(3.0, 0.4, 1.9), Vector3(0.6, 0.8, 0.6), Color(0.35, 0.55, 0.8))
	mb.box("flat", o + Vector3(-3.45, 1.5, 0.4), Vector3(0.03, 0.9, 1.4), Color(0.86, 0.84, 0.78), 0)          # bảng vẽ của bé Na
	mb.commit(200.0)
	var lamp := OmniLight3D.new()
	lamp.position = o + Vector3(-1.1, 1.5, -2.0)
	lamp.light_color = Color("ffc98a")
	lamp.light_energy = 1.6
	lamp.omni_range = 9.0
	lamp.shadow_enabled = true
	add_child(lamp)
	var fill := OmniLight3D.new()
	fill.position = o + Vector3(1.5, 2.2, 1.0)
	fill.light_color = Color("ffe0b8")
	fill.light_energy = 0.5
	fill.omni_range = 8.0
	add_child(fill)
	_stock_node = Node3D.new()
	add_child(_stock_node)
	_tally = Label3D.new()
	_tally.position = o + Vector3(-3.43, 1.6, 0.4)
	_tally.rotation.y = PI * 0.5
	_tally.pixel_size = 0.004
	_tally.font_size = 64
	_tally.modulate = Color(0.25, 0.22, 0.2)
	_tally.outline_size = 0
	add_child(_tally)
	_spots = [
		{"id": "table", "pos": o + Vector3(-1.5, 0.85, -2.3), "label": "Chia khẩu phần hôm nay"},
		{"id": "radio", "pos": o + Vector3(-2.1, 0.9, -2.5), "label": "Nghe radio"},
		{"id": "shelf", "pos": o + Vector3(3.1, 1.0, -0.6), "label": "Mở tủ chứa đồ"},
		{"id": "ladder", "pos": o + Vector3(2.6, 1.3, 2.7), "label": "Cửa hầm"},
		{"id": "wall", "pos": o + Vector3(-3.4, 1.5, 0.4), "label": "Xem lại sổ ghi của ngày hôm nay"},
	]
	_person("mai", "Mai", Color("b0607a"), Color("3a3a48"), 1.0, o + Vector3(-0.6, 0.0, -1.6), 2.6)
	_person("na", "Bé Na", Color("f0c040"), Color("5a6a9a"), 0.62, o + Vector3(-2.9, 0.0, 0.4), 1.2)
	_refresh_room()


func _person(id: String, _nm: String, shirt: Color, pants: Color, scl: float, pos: Vector3, yaw: float) -> void:
	# gia đình: model low-poly góc cạnh (bé Na: áo vàng, quần jean, giày đỏ; Mai: áo hồng, quần sẫm, dép nâu)
	var lp := LowPolyHumanoid.new()
	lp.female = true
	var h: Humanoid = lp
	if id == "na":
		lp.child = true
		lp.hem_color = Color("e9a62a")
		add_child(h)
		scl = 0.72
		h.setup(Color("f2d23a"), Color("4f7fb8"), Color("e2b48c"))
	else:
		lp.shoe_color = Color("8a6a58")
		lp.sole_color = Color("5a4438")
		lp.roll_cuffs = false
		add_child(h)
		h.setup(Color("d77a8c") if id == "mai" else shirt, Color("34343e") if id == "mai" else pants, Color("e0b08a"))
	h.scale = Vector3.ONE * scl
	h.position = pos
	h.rotation.y = yaw
	_people[id] = h


## Cập nhật những thứ nhìn thấy trong hầm: đồ trên kệ theo số lượng thật, vạch đếm ngày, người ốm nằm, khách ở nhờ.
func _refresh_room() -> void:
	for c in _stock_node.get_children():
		c.queue_free()
	var o := origin
	# đồ thật trong tủ, bày lên ba tầng kệ (tối đa 30 món)
	var shown_n := 0
	var ids := storage.keys()
	ids.sort()
	for id: String in ids:
		for j in int(storage[id]):
			if shown_n >= 30:
				break
			var m := ItemModels.make(id)
			m.scale = Vector3.ONE * 1.4
			m.position = o + Vector3(3.2, 0.38 + (shown_n / 10) * 0.6, -1.75 + (shown_n % 10) * 0.25)
			_stock_node.add_child(m)
			shown_n += 1
	var k := 0
	for id: String in meds:
		for j in mini(int(meds[id]), 3):
			var m3 := ItemModels.make(id)
			m3.scale = Vector3.ONE * 1.5
			m3.position = o + Vector3(-1.9 + k * 0.22, 0.76, -2.2)
			_stock_node.add_child(m3)
			k += 1
	_tally.text = "|".repeat(day)
	for f: Dictionary in family:
		if int(f.get("peer", 0)) > 0:
			continue
		var h: Humanoid = _people.get(f.id)
		if h == null:
			continue
		h.visible = f.alive
		var lying: bool = f.sick or int(f.hunger) >= 3 or int(f.thirst) >= 3
		h.play_dead(lying)
		if lying:
			h.position = origin + (Vector3(-1.85, 0.3, 2.0) if f.id == "mai" else Vector3(-0.8, 0.3, 2.0))
		else:
			h.position = origin + (Vector3(-0.6, 0.0, -1.6) if f.id == "mai" else Vector3(-2.9, 0.0, 0.4))
	# khách ở nhờ
	var gi := 0
	for g: Dictionary in guests:
		var gid: String = g.id
		if not _people.has(gid):
			var dog: bool = g.kind == "dog"
			var small: bool = g.kind == "kid"
			if dog:
				_people[gid] = _make_dog()
			else:
				_person(gid, g.name, Color.from_hsv(float(hash(gid) % 100) / 100.0, 0.35, 0.7), Color(0.2, 0.2, 0.24), 0.7 if small else 1.0, Vector3.ZERO, 0.0)
		if dog_kind(g):
			(_people[gid] as Node3D).position = origin + Vector3(2.2, 0.0, 2.0)      # nằm canh ngay chân thang
			(_people[gid] as Node3D).rotation.y = PI
		else:
			(_people[gid] as Node3D).position = origin + Vector3(0.6 + (gi % 3) * 0.9, 0.0, -2.4 + (gi / 3) * 1.0)
		(_people[gid] as Node3D).visible = true
		gi += 1
	for pid: String in _people:
		if pid in ["mai", "na"]:
			continue
		if guest(pid).is_empty():
			(_people[pid] as Node3D).visible = false


func dog_kind(g: Dictionary) -> bool:
	return g.get("kind", "") == "dog"


## Con Mực: chó đen, gầy, nằm sấp hai chân trước duỗi ra, đầu ngẩng nhìn về cửa hầm.
func _make_dog() -> Node3D:
	var n := Node3D.new()
	add_child(n)
	var c := "1f1c1a"
	ItemModels._part(n, "box", Vector3(0.26, 0.22, 0.62), Vector3(0, 0.16, 0), c)              # thân
	ItemModels._part(n, "box", Vector3(0.2, 0.2, 0.24), Vector3(0, 0.36, 0.36), c)              # đầu
	ItemModels._part(n, "box", Vector3(0.12, 0.1, 0.16), Vector3(0, 0.31, 0.53), "2a2623")      # mõm
	ItemModels._part(n, "box", Vector3(0.05, 0.1, 0.04), Vector3(-0.07, 0.49, 0.32), c, Vector3(0, 0, 0.25))
	ItemModels._part(n, "box", Vector3(0.05, 0.1, 0.04), Vector3(0.07, 0.49, 0.32), c, Vector3(0, 0, -0.25))
	for sx: float in [-0.09, 0.09]:
		ItemModels._part(n, "box", Vector3(0.07, 0.06, 0.3), Vector3(sx, 0.04, 0.42), c)        # chân trước duỗi
		ItemModels._part(n, "box", Vector3(0.09, 0.12, 0.2), Vector3(sx * 1.6, 0.07, -0.22), c)  # chân sau co
	ItemModels._part(n, "box", Vector3(0.04, 0.04, 0.3), Vector3(0.1, 0.06, -0.42), c, Vector3(0, 0.6, 0))   # đuôi
	ItemModels._part(n, "sph", Vector3(0.015, 0.015, 0.015), Vector3(-0.05, 0.4, 0.485), "e8c070")
	ItemModels._part(n, "sph", Vector3(0.015, 0.015, 0.015), Vector3(0.05, 0.4, 0.485), "e8c070")
	return n


# ------------------------------------------------------------------ truy vấn
func member(id: String) -> Dictionary:
	for f: Dictionary in family:
		if f.id == id:
			return f
	return {}


func alive(id: String) -> bool:
	return member(id).get("alive", false)


func guest(id: String) -> Dictionary:
	for g: Dictionary in guests:
		if g.id == id:
			return g
	return {}


func status_of(f: Dictionary) -> String:
	if not f.alive:
		return "đã mất"
	var parts: Array[String] = []
	parts.append(HUNGER_WORDS[mini(int(f.hunger), 4)])
	parts.append(THIRST_WORDS[mini(int(f.thirst), 3)])
	if f.sick:
		parts.append("ĐANG SỐT (ngày thứ %d)" % (int(f.sick_days) + 1))
	if f.get("special", false):
		parts.append("LÊN CƠN, cần lọ thuốc đặc trị (hạn cuối: hết ngày 4)")
	return ", ".join(parts)


func summary() -> String:
	var t := "Ngày %d  ·  Đồ ăn %d  ·  Nước %d  ·  Chăn %d" % [day, food, water, int(storage.get("chan", 0))]
	if bomb_day > 0:
		t += "  ·  Bom rơi sau %d ngày" % maxi(0, bomb_day - day)
	return t


## Số người cần nuôi (người chơi + vợ con còn sống).
func people() -> int:
	var n := 0
	for f: Dictionary in family:
		if f.alive:
			n += 1
	return n


## Cần tích trữ bao nhiêu để trụ 7 ngày dưới bom: mỗi người mỗi ngày 2 ăn + 2 nước (khó: 3 + 3), mỗi người 1 chăn.
func need_counts() -> Dictionary:
	var per := 3 if Game.difficulty == "hard" else 2
	var n := people()
	return {"food": 7 * per * n, "water": 7 * per * n, "chan": n}


func stock_ok() -> bool:
	var nd := need_counts()
	return food >= int(nd.food) and water >= int(nd.water) and int(storage.get("chan", 0)) >= int(nd.chan)


func has_item(id: String) -> bool:
	if Game.count(id) > 0 or Game.equip.get("weapon", "") == id:
		return true
	return id == "sungluc" and not guest("khoa").is_empty()


func need_ok(need: Dictionary) -> bool:
	for k: String in need:
		var v: Variant = need[k]
		match k:
			"food":
				if food < int(v): return false
			"water":
				if water < int(v): return false
			"item", "bag_item":
				if not has_item(str(v)): return false
			"weapon":
				if Game.equip.get("weapon", "") == "":
					var any := false
					for id: String in Game.inv:
						if Items.get_def(id).has("weapon"):
							any = true
					if not any: return false
			"bag_food_any":
				if _bag_food_ids().is_empty(): return false
			"low_food":
				if food > people(): return false
			"guest":
				if guest(str(v)).is_empty(): return false
			"flag":
				if not flags.has(str(v)): return false
	return true


func need_text(need: Dictionary) -> String:
	var out: Array[String] = []
	for k: String in need:
		match k:
			"food": out.append("cần %d phần đồ ăn trong kho" % int(need[k]))
			"water": out.append("cần %d phần nước trong kho" % int(need[k]))
			"item", "bag_item": out.append("cần " + Items.item_name(str(need[k])))
			"weapon": out.append("cần một thứ vũ khí")
			"bag_food_any": out.append("cần đồ ăn trong túi")
	return ", ".join(out)


func _bag_food_ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in Game.inv:
		if Items.get_def(id).has("food") and Items.get_def(id).get("cat", "") == "food" and Game.count(id) > 0:
			out.append(id)
	return out


# ------------------------------------------------------------------ tác động của một kết cục
## Tác động vào kho, gia đình, mạch truyện (chỉ máy chủ phòng). actor: 0 = cả phòng (chuyện ở cửa hầm), còn lại = mã máy người gặp chuyện.
func apply_fx(fx: Dictionary, actor := 0) -> void:
	var personal: Dictionary = {}
	for k: String in fx:
		var v: Variant = fx[k]
		if k in PERSONAL:
			if k == "bleed" and int(meds.get("bang", 0)) > 0:
				meds.bang = int(meds.bang) - 1
				log_lines.append("Vết thương được băng lại ngay (hết một cuộn băng).")
			else:
				personal[k] = v
			continue
		match k:
			"food":
				food = maxi(0, food + int(v))
			"water":
				water = maxi(0, water + int(v))
			"med":
				for id: String in v:
					meds[id] = maxi(0, int(meds.get(id, 0)) + int(v[id]))
			"morale":
				morale = clampi(morale + int(v), 0, 100)
			"hurt":
				var f := member(str(v))
				if not f.is_empty() and f.alive:
					f.sick = true
			"kill":
				var f2 := member(str(v))
				if not f2.is_empty():
					f2.alive = false
			"guest":
				if guest(str(v.id)).is_empty():
					guests.append({"id": v.id, "name": v.name, "kind": v.kind, "days": 0})
			"unguest":
				guests = guests.filter(func(g: Dictionary) -> bool: return g.id != str(v))
			"flag":
				flags[str(v)] = true
			"rescue":
				rescue_day = maxi(day + 1, rescue_day + int(v))
			"go_out":
				_pending_out = str(v)
			"fight":
				_pending_fight = int(v)
			"ambush":
				_ambush_p = float(v)
			"pipe":
				pipe_broken = true
			"sleep":
				_pending_sleep = true
			"later":
				var d := day + int(v["in"])
				if not schedule.has(d):
					schedule[d] = []
				(schedule[d] as Array).append(str(v.ev))
	if not personal.is_empty():
		_cl_personal.rpc(personal, actor)


## Phần rơi vào từng người: máu, vết thương, túi đồ.
@rpc("authority", "reliable", "call_local")
func _cl_personal(fx: Dictionary, actor: int) -> void:
	var mine := actor == my_id() or (actor == 0 and is_host())
	var hit := actor == my_id() or (actor == 0 and not outside)
	apply_personal(fx, mine, hit)


func apply_personal(fx: Dictionary, mine: bool, hit: bool) -> void:
	for k: String in fx:
		var v: Variant = fx[k]
		match k:
			"hp":
				if hit and not Game.god:
					Game.hp = maxf(1.0, Game.hp + float(v))      # bị thương nặng nhưng không chết ngay tại chỗ
			"bleed":
				if hit and not Game.god:
					Game.add_injury("arm_l", "bleed")
					Game.say("Bạn đang chảy máu và trong hầm không còn băng gạc.", "bad")
			"cruelty":
				if mine:
					Game.add_cruelty(float(v))
			"bag":
				if mine:
					for id2: String in v:
						var n := int(v[id2])
						if n > 0:
							if Items.get_def(id2).has("ammo"):
								Game.ammo += int(Items.get_def(id2).ammo) * n
							else:
								Game.inv[id2] = Game.count(id2) + n
						else:
							Game.remove_item(id2, -n)
					Game.inventory_changed.emit()
			"bag_clear":
				if mine:
					for id3: String in Game.inv.keys():
						if not Items.get_def(id3).has("quest") and Game.equip.get("weapon", "") != id3:
							Game.inv.erase(id3)
					Game.inventory_changed.emit()
			"bag_half":
				if mine:
					var i := 0
					for id4: String in Game.inv.keys():
						if Items.get_def(id4).has("quest"):
							continue
						i += 1
						if i % 2 == 0:
							Game.inv.erase(id4)
					Game.inventory_changed.emit()
			"bag_food":
				if mine:
					for id5 in _bag_food_ids():
						Game.inv.erase(id5)
					Game.inventory_changed.emit()
			"bag_food_one":
				if mine:
					var ids := _bag_food_ids()
					if not ids.is_empty():
						Game.remove_item(ids[0], 1)
			"noise":
				if mine and world.local_player():
					world.emit_noise(world.local_player().global_position, 1.0)


# ------------------------------------------------------------------ sự kiện
func _eligible(id: String) -> bool:
	if used.has(id) or not ShelterEvents.EVENTS.has(id):
		return false
	var e: Dictionary = ShelterEvents.EVENTS[id]
	if e.has("need") and not need_ok(e.need):
		return false
	if id in NEEDS_MAI and not alive("mai"):
		return false
	if id in NEEDS_NA and not alive("na"):
		return false
	if id == "con_muc" and not guest("muc").is_empty():
		return false
	return true


## kind: night | morning (cả phòng, do máy chủ mở) hoặc outside (chỉ máy này).
func open_event(id: String, kind: String) -> void:
	current_id = id
	current = ShelterEvents.EVENTS[id]
	current_text = current.text
	if current.get("beg", false):
		current_text = ShelterEvents.BEG_TEXTS[rng.randi() % ShelterEvents.BEG_TEXTS.size()]
	current_done = false
	disabled = []
	votes = {}
	_event_kind = kind
	_local_event = kind == "outside"
	if _local_event:
		ui.call("show_event")
		return
	used.append(id)
	if kind == "night":
		if id == "dem_cuoi" and not alive("mai"):
			current_text = "Chúng đến tất cả cùng một lúc.\n\nGiọng ông Tư. Giọng người mẹ bế con. Giọng anh Dũng. Và giọng của Mai, rõ ràng, dịu dàng, vọng xuống từ bên trên.\n\n— Mở cửa đi anh. Em về rồi đây."
		if not guest("muc").is_empty():
			if id in MIMICS:
				current_text += "\n\n[Con Mực lùi khỏi chân thang, lông dựng ngược, gầm gừ trong cổ họng.]"
			elif id in REAL_VISITORS:
				current_text += "\n\n[Con Mực ngửi ngửi khe cửa rồi vẫy đuôi.]"
	panel = "event"
	_push()


func _pick_outcome(ch: Dictionary) -> Dictionary:
	var outs: Array = ch.out
	var pick: Dictionary = outs[0]
	if outs.size() > 1:
		var r := rng.randf()
		for o: Dictionary in outs:
			r -= float(o.get("p", 1.0))
			if r <= 0.0:
				pick = o
				break
	return pick


## Người chơi bấm một lựa chọn. Chuyện ngoài phố thì tự quyết; chuyện ở cửa hầm thì là một lá phiếu.
func vote(i: int) -> void:
	if _local_event:
		_choose_local(i)
	elif is_host():
		_srv_vote(i)
	else:
		_srv_vote.rpc_id(1, i)


@rpc("any_peer", "reliable")
func _srv_vote(i: int) -> void:
	if not is_host() or current_id == "" or current_done or i < 0 or i >= (current.choices as Array).size() or disabled.has(i):
		return
	var pid := multiplayer.get_remote_sender_id()
	if pid == 0:
		pid = 1
	var ch: Dictionary = current.choices[i]
	if ch.has("need") and not need_ok(ch.need):
		return
	if ch.get("info", false):
		choose(i)                     # dò xét thì ai bấm cũng được, cả phòng cùng thấy kết quả
		return
	votes[pid] = i
	var all := true
	for p: int in _peers():
		if not votes.has(p):
			all = false
	if all:
		var tally: Dictionary = {}
		for p2: int in votes:
			tally[votes[p2]] = int(tally.get(votes[p2], 0)) + 1
		var best_n := 0
		for c: int in tally:
			best_n = maxi(best_n, int(tally[c]))
		var tied: Array = []
		for c2: int in tally:
			if int(tally[c2]) == best_n:
				tied.append(c2)
		var best: int = tied[0]
		if tied.size() > 1:
			# hoà phiếu: mỗi người theo phương án hoà tung một con xúc xắc, ai cao điểm nhất thì theo người đó (bằng nhau thì tung lại)
			var lines: Array[String] = []
			var top := -1
			var guard := 0
			while top < 0 and guard < 10:
				guard += 1
				lines.clear()
				var hi := 0
				var winners: Array = []
				for p: int in votes:
					if not tied.has(votes[p]):
						continue
					var roll := rng.randi_range(1, 6)
					lines.append("%s %d" % [member_of_peer(p).get("name", "?"), roll])
					if roll > hi:
						hi = roll
						winners = [votes[p]]
					elif roll == hi and not winners.has(votes[p]):
						winners.append(votes[p])
				if winners.size() == 1:
					top = winners[0]
			best = top if top >= 0 else tied[rng.randi() % tied.size()]
			_cl_say.rpc("Hoà phiếu, tung xúc xắc: %s." % ", ".join(lines), "")
		choose(best)
	else:
		_push()


## Máy chủ chốt một lựa chọn của sự kiện chung.
func choose(i: int) -> void:
	if not is_host() or current_done or i < 0 or i >= (current.choices as Array).size() or disabled.has(i):
		return
	var ch: Dictionary = current.choices[i]
	if ch.has("need") and not need_ok(ch.need):
		return
	var pick := _pick_outcome(ch)
	if ch.get("info", false):
		disabled.append(i)
		current_text += "\n\n———\n" + str(pick.t)
		_push()
		return
	current_done = true
	votes = {}
	current_text = str(pick.t)
	apply_fx(pick.get("fx", {}), 0)
	if current.has("after"):
		apply_fx(current.after, 0)
	log_lines.append("%s: %s" % [current.title, str(ch.t).to_lower()])
	_push()


## Chuyện ngoài phố: người gặp tự quyết trên máy mình; phần ảnh hưởng tới kho chung thì gửi về máy chủ.
func _choose_local(i: int) -> void:
	if current_done or i < 0 or i >= (current.choices as Array).size() or disabled.has(i):
		return
	var ch: Dictionary = current.choices[i]
	if ch.has("need") and not need_ok(ch.need):
		return
	var pick := _pick_outcome(ch)
	if ch.get("info", false):
		disabled.append(i)
		current_text += "\n\n———\n" + str(pick.t)
		ui.call("show_event")
		return
	current_done = true
	current_text = str(pick.t)
	var fx: Dictionary = pick.get("fx", {})
	var shared: Dictionary = {}
	var personal: Dictionary = {}
	for k: String in fx:
		if k in PERSONAL:
			personal[k] = fx[k]
		else:
			shared[k] = fx[k]
	apply_personal(personal, true, true)
	var line := "%s: %s" % [current.title, str(ch.t).to_lower()]
	if is_host():
		_srv_shared(shared, line)
	else:
		_srv_shared.rpc_id(1, shared, line)
	ui.call("show_event")


@rpc("any_peer", "reliable")
func _srv_shared(fx: Dictionary, line: String) -> void:
	if not is_host():
		return
	apply_fx(fx, 0)
	log_lines.append(line)
	_push()


## Bấm "Tiếp tục" sau khi một sự kiện đã ngã ngũ (sự kiện chung: chỉ chủ phòng).
func continue_after_event() -> void:
	if not current_done:
		return
	if _local_event:
		_local_event = false
		current_id = ""
		_render_key = ""
		ui.call("close_all")
		return
	if not is_host():
		return
	current_id = ""
	if _event_kind == "morning":
		phase = "day"
		panel = "none"
		_push()
		return
	panel = "none"
	if _pending_fight > 0:
		_start_fight()
		return
	if _pending_out != "":
		_start_outing(_pending_out)
		return
	if _pending_sleep:
		_pending_sleep = false
		_next_day()
		return
	if not _queue.is_empty():
		open_event(_queue.pop_front(), "night")
		return
	open_event("dem_nay", "night")


# ------------------------------------------------------------------ vòng ngày đêm
func _morning() -> void:
	if bomb_day > 0 and day >= bomb_day:
		_bomb_ending()
		return
	if day >= 14 and bomb_day < 0:
		_lost_ending()
		return
	if people() == 0:
		return
	phase = "day"
	rationed = false
	night = {}
	knock = {}
	sites = []
	_pending_morning = ""
	if day == 2 and alive("na") and not flags.has("na_cured"):
		member("na")["special"] = true
		log_lines.append("Bé Na thở rít cả đêm: cơn bệnh cũ của con trở lại. Chỉ lọ thuốc đặc trị mới cắt được, mà lọ thuốc không còn trong cặp.")
	for id: String in schedule.get(day, []):
		if id in MORNING_IDS and _eligible(id):
			_pending_morning = id

	var text := ""
	for l: String in log_lines:
		text += "• " + l + "\n"
	text += "\n"
	for f: Dictionary in family:
		text += "%s: %s\n" % [f.name, status_of(f)]
	if not guests.is_empty():
		text += "Ở nhờ: " + ", ".join(guests.map(func(g: Dictionary) -> String: return str(g.name))) + "\n"
	text += "\nTrong kho: %d phần đồ ăn, %d phần nước, %d vỉ kháng sinh.\n" % [food, water, int(meds.get("khangsinh", 0))]
	if bomb_day > 0:
		var nd := need_counts()
		text += "Máy phát đã bật. Quân đội thả bom sau %d ngày. Cần tích trữ: %d/%d đồ ăn, %d/%d nước, %d/%d chăn." % [bomb_day - day, food, nd.food, water, nd.water, int(storage.get("chan", 0)), nd.chan]
	elif str(machine.state) != "none":
		text += "Máy phát tín hiệu đang ở %s." % {"tower": "trạm phát sóng", "ground": "ngoài phố, chỗ bạn đặt xuống", "carried": "trên vai"}.get(str(machine.state), "?")
	log_lines = []
	journal = {"title": "NGÀY %d" % day, "body": text, "button": "Bắt đầu ngày mới"}
	panel = "journal"
	_push()


func ack_journal() -> void:
	if not is_host() or panel != "journal":
		ui.call("close_all")
		return
	panel = "none"
	if _pending_morning != "":
		phase = "morning_event"
		var id := _pending_morning
		_pending_morning = ""
		open_event(id, "morning")
	else:
		_cl_say.rpc("Chủ phòng tới bàn để chia khẩu phần. Nghe radio, nói chuyện với vợ con nếu muốn." if Net.is_online() else "Tới bàn để chia khẩu phần. Nghe radio, nói chuyện với vợ con nếu muốn.", "")
		_push()
	if day == 1 and not flags.has("_intro"):
		flags["_intro"] = true
		_cl_dialogue.rpc(["Mai: Mình xuống được rồi… Cả nhà còn đủ cả.", "Mai: Đồ ăn với nước chỉ đủ vài ngày thôi anh ạ. Ban ngày ở dưới này, đêm xuống mới ra ngoài được.", "Bé Na: Bố ơi, cặp sách của con đâu rồi? Con để quên ở trường à…", {"who": "", "text": "Không ai trả lời con. Lúc ấy chưa ai nghĩ tới lọ thuốc trong cái cặp."}])
	elif day == 2 and not flags.has("_day2") and alive("na") and not flags.has("na_cured"):
		flags["_day2"] = true
		_cl_dialogue.rpc(["Bé Na: Bố ơi… con khó thở…", "Mai: Con lên cơn rồi. Thuốc của con ở trong cặp, cặp để ở tủ khoá trên trường.", "Mai: Tủ khoá bằng sắt, tay không thì không cạy được đâu. Anh tìm cái xà beng: nhà bác Tư có một cái, phòng giáo viên ở trường chắc cũng có.", "Mai: Hoặc… mấy cái biệt phủ nhà giàu hay có máy dò đồ. Nghe nói bệnh viện cất thuốc này trong két.", "Mai: Con chỉ cầm cự được tới hết ngày thứ tư thôi anh."])
	elif day == 5 and not flags.has("_radio5"):
		flags["_radio5"] = true
		_cl_dialogue.rpc(["Radio: …rè… đây là Bộ chỉ huy quân sự thành phố… rè…", "Radio: Ai còn nghe được: tại trạm phát sóng phía nam hồ có một máy phát tín hiệu dã chiến.", "Radio: Mang máy về chỗ trú ẩn và bật lên. Chúng tôi sẽ biết các bạn ở đâu.", "Radio: Cảnh báo: có một thứ đang bám trên tháp phát sóng. Nó nhìn thấy mọi thứ chuyển động. Chỉ đi vào ban đêm.", "Mai: Anh… mình phải lấy cái máy đó."])


## Chủ phòng mở cuốn sổ chia khẩu phần: cả phòng cùng thấy.
func open_rations() -> void:
	if not is_host() or phase != "day":
		return
	plan = {}
	for f: Dictionary in family:
		if f.alive:
			plan[f.id] = {"eat": false, "drink": false, "med": false}
	panel = "rations"
	_push()


func set_plan(id: String, key: String, on: bool) -> void:
	if not is_host() or not plan.has(id):
		return
	plan[id][key] = on
	_push()


func close_rations() -> void:
	if is_host() and panel == "rations":
		panel = "none"
		_push()


## Chia xong thì trời tối.
func confirm_rations(p: Dictionary) -> void:
	if not is_host() or phase != "day":
		return
	for f: Dictionary in family:
		if not f.alive:
			continue
		var q: Dictionary = p.get(f.id, {})
		if q.get("eat", false) and food > 0:
			food -= 1
			f.hunger = 0
		else:
			f.hunger = int(f.hunger) + 1
		if q.get("drink", false) and water > 0:
			water -= 1
			f.thirst = 0
		else:
			f.thirst = int(f.thirst) + 1
		if q.get("med", false) and f.sick and not f.get("special", false) and int(meds.get("khangsinh", 0)) > 0:
			meds.khangsinh = int(meds.khangsinh) - 1
			f.sick = false
			f.sick_days = 0
			log_lines.append("%s uống kháng sinh, đến sáng đã hạ sốt." % f.name)
	rationed = true
	_night()


func _night() -> void:
	phase = "event"
	panel = "none"
	world.weather.hour = 21.0
	_queue = []
	_pending_out = ""
	_pending_fight = 0
	_pending_sleep = false
	for id: String in schedule.get(day, []):
		if not (id in MORNING_IDS) and _eligible(id):
			_queue.append(id)
	var scripted: String = ShelterEvents.NIGHT_SCRIPT.get(day, "")
	if scripted == "thuoc_dac_tri" and (flags.has("na_cured") or not alive("na")):
		scripted = ""
	if scripted == "may_phat_tin_hieu" and str(machine.state) != "none":
		scripted = ""
	if scripted != "":
		_queue.push_front(scripted)
	elif day in ShelterEvents.RANDOM_NIGHTS:
		var pool: Array = ShelterEvents.NIGHT_POOL.filter(_eligible)
		if not pool.is_empty():
			_queue.append(pool[rng.randi() % pool.size()])
	if _queue.is_empty():
		_queue = ["dem_nay"]
	_push()
	_cl_fade.rpc("ĐÊM THỨ %d" % day)
	get_tree().create_timer(1.7).timeout.connect(func() -> void:
		Sfx.play("door", -2.0)
		open_event(_queue.pop_front(), "night"))


## Bọn cướp phá cửa xông xuống hầm: đánh thời gian thực tới khi chúng gục hết.
func _start_fight() -> void:
	var n := _pending_fight
	_pending_fight = 0
	phase = "fight"
	panel = "none"
	world.monsters.spawn_robbers(origin + Vector3(2.4, 0.15, 2.0), n, 0.6, true)
	_cl_say.rpc("Chúng xông xuống thang! Cầm vũ khí lên mà đánh!", "bad")
	_push()


## Cả nhóm cùng leo lên (không tách nhau). Đêm kết thúc khi mọi người đã chui xuống hầm, hoặc khi trời sáng.
func _start_outing(m: String) -> void:
	_pending_out = ""
	mission = m
	phase = "out"
	panel = "none"
	night = {}
	for p: int in _peers():
		night[p] = "out"
	if flags.has("radio_may") and str(machine.state) == "none":
		machine = {"state": "tower", "pos": city.radio_pos + Vector3(0, 0.05, 0), "carrier": 0}
	sites = []
	_spawn_sites()
	if sites.size() > 2:
		sites = sites.slice(0, 2)
	if m == "help":
		var hp := exit_pos
		for attempt in 40:
			var q := city.road_point(rng)
			var dq := q.distance_to(exit_pos)
			if dq > 22.0 and dq < 45.0:
				hp = q
				break
		var rs: Array = world.monsters.spawn_robbers(hp + Vector3(1.5, 0.1, 0), 2, 1.5)
		help = {"pos": hp, "ids": rs.map(func(r: Monster) -> int: return world.monsters.list.find(r)), "done": false}
	else:
		help = {}
	_ambush_t = rng.randf_range(35.0, 90.0) if rng.randf() < _ambush_p else -1.0
	_ambush_p = 0.0
	_push()
	_cl_go_out.rpc(m)


@rpc("authority", "reliable", "call_local")
func _cl_go_out(m: String) -> void:
	mission = m
	_go_out_local()


## Đêm nay mình làm gì: "sleep" hoặc "out".
func night_pick(what: String) -> void:
	if phase != "choose":
		return
	if what == "out":
		_go_out_local()
	else:
		ui.call("close_all")
	if is_host():
		_srv_night(what)
	else:
		_srv_night.rpc_id(1, what)


@rpc("any_peer", "reliable")
func _srv_night(what: String) -> void:
	if not is_host() or phase != "choose":
		return
	var pid := multiplayer.get_remote_sender_id()
	if pid == 0:
		pid = 1
	night[pid] = "out" if what == "out" else "sleep"
	if what == "out" and sites.is_empty():
		_spawn_sites()
		_fake_t = rng.randf_range(70.0, 150.0)
	_check_night_done()
	_push()


func _check_night_done() -> void:
	if not is_host() or phase != "out":
		return
	for p: int in night:
		if night[p] != "sleep":
			return
	_next_day()


func _go_out_local() -> void:
	outside = true
	ui.call("close_all")
	var me := my_member()
	Game.food = [88.0, 66.0, 46.0, 28.0, 12.0][mini(int(me.get("hunger", 0)), 4)]
	Game.water = [86.0, 58.0, 34.0, 14.0][mini(int(me.get("thirst", 0)), 3)]
	var p: CharacterBody3D = world.local_player()
	p.global_position = exit_pos + Vector3(0, 0.4, 0)
	p.velocity = Vector3.ZERO
	_update_objective()
	Game.say("Thành phố mất điện. Chỉ còn đèn pin (chuột phải) và ánh trăng. Xong việc thì chui xuống hầm (E ở lối ra), trước khi trời sáng.", "bad")
	if flags.has("hua_tim_me") and not flags.has("da_tim_me"):
		Game.say("Đã hứa với Mai sẽ ghé nhà mẹ cô ấy ở khu tập thể phía bắc.")


## Giữ tên cũ cho bài kiểm thử và giao diện.
func sleep_till_morning() -> void:
	night_pick("sleep")


func go_out() -> void:
	night_pick("out")


## Người ở ngoài về tới cửa hầm: gõ cửa. Có người bên trong thì họ quyết định mở hay không.
func return_home() -> void:
	if not outside or _knock_wait > 0.0:
		return
	_knock_wait = 0.8
	if is_host():
		_srv_knock()
	else:
		_srv_knock.rpc_id(1)


@rpc("any_peer", "reliable")
func _srv_knock() -> void:
	if not is_host() or phase != "out":
		return
	var rp := multiplayer.get_remote_sender_id()
	_let_in(rp if rp != 0 else 1)


func member_of_peer(pid: int) -> Dictionary:
	for f: Dictionary in family:
		if int(f.get("peer", 0)) == pid:
			return f
	return {}


func _let_in(pid: int) -> void:
	night[pid] = "sleep"
	if pid == my_id():
		_cl_enter()
	else:
		_cl_enter.rpc_id(pid)
	_check_night_done()
	_push()


@rpc("authority", "reliable")
func _cl_enter() -> void:
	_to_bunker()
	_render_key = ""
	Game.say("Bạn chui xuống hầm. Nắp hầm đóng lại sau lưng.", "good")
	_render()


## Người trong hầm trả lời tiếng gõ.
func answer_knock(open: bool) -> void:
	if is_host():
		_srv_answer(open)
	else:
		_srv_answer.rpc_id(1, open)


@rpc("any_peer", "reliable")
func _srv_answer(open: bool) -> void:
	if not is_host() or knock.is_empty():
		return
	var k := knock
	knock = {}
	if k.real:
		if open:
			_let_in(int(k.from))
			return
		_cl_say.rpc_id(int(k.from), "Bên dưới không ai mở cửa. Họ sợ bạn không phải là bạn. Gõ lại lần nữa, hoặc gọi cho họ nghe đúng giọng mình.", "bad")
	elif open:
		# mở nhầm cho một kẻ nhại
		apply_fx({"hp": -30, "bleed": true, "food": -1, "morale": -10, "flag": "biet_ke_nhai"}, 0)
		_cl_say.rpc("Nắp hầm vừa hé, thứ đứng ngoài không phải %s. Nó chỉ có giọng của %s." % [k.name, k.name], "bad")
	else:
		_cl_say.rpc("Tiếng gõ ngừng. Một lúc sau, giọng \"%s\" lặp lại đúng câu vừa nãy, từ phía đầu ngõ." % k.name, "")
	_push()


func _next_day() -> void:
	sites = []
	knock = {}
	mission = ""
	help = {}
	# ống thông khí chưa sửa: cả nhà ngạt suốt đêm
	if pipe_broken:
		pipe_broken = false
		apply_fx({"hp": -30, "hurt": "mai", "morale": -12}, 0)
		log_lines.append("Ống thông khí không được sửa. Cả nhà ngạt thở suốt đêm, Mai đổ bệnh.")
	# xác kẻ cướp để trong hầm
	var corpses := 0
	for m: Monster in world.monsters.list:
		if m.kind != "robber":
			continue
		if m.state == "dead" and in_bunker(m.global_position):
			corpses += 1
		elif m.state != "dormant":
			m.state = "dormant"              # ngoài phố: xác bị kéo đi, kẻ còn sống đã bỏ đi
			m.global_position = Vector3(0, -200, 0)
			m.set("carrier", 0)
	if corpses > 0:
		morale = maxi(0, morale - 6 * corpses)
		log_lines.append("Mùi tử khí bốc lên từ góc hầm (%d cái xác). Bé Na không chịu ăn. Phải vác ra ngoài." % corpses)
	day += 1
	# hạn cuối của lọ thuốc
	var na := member("na")
	if not na.is_empty() and na.alive and na.get("special", false) and day > 4:
		na.alive = false
		morale = maxi(0, morale - 35)
		log_lines.append("Bé Na không qua khỏi cơn bệnh. Lọ thuốc đã không về kịp.")
	var nurse := not guest("hanh").is_empty()
	for f: Dictionary in family:
		if not f.alive:
			continue
		if f.sick:
			if nurse and int(meds.get("khangsinh", 0)) > 0:
				meds.khangsinh = int(meds.khangsinh) - 1
				f.sick = false
				f.sick_days = 0
				log_lines.append("Cô Hạnh cho %s uống kháng sinh trong đêm. Sáng nay đã hạ sốt." % f.name)
			elif not nurse or rng.randf() < 0.5:
				f.sick_days = int(f.sick_days) + 1
		var why := ""
		if int(f.hunger) >= 5:
			why = "vì đói"
		elif int(f.thirst) >= 4:
			why = "vì khát"
		elif f.sick and int(f.sick_days) >= 4:
			why = "vì cơn sốt không có thuốc"
		if why != "":
			f.alive = false
			morale = maxi(0, morale - 30)
			log_lines.append("%s đã không qua khỏi đêm qua, %s." % [f.name, why])
		elif int(f.hunger) >= 3 or int(f.thirst) >= 2:
			log_lines.append("%s đang yếu dần: %s." % [f.name, status_of(f)])
	for g: Dictionary in guests.duplicate():
		g.days = int(g.days) + 1
		if int(g.days) % 2 == 0:
			if g.kind == "dog":
				if food > 0 and int(g.days) % 4 == 0:
					food -= 1
			elif food > 0 and water > 0:
				food -= 1
				water -= 1
			else:
				guests.erase(g)
				morale = maxi(0, morale - 4)
				log_lines.append("%s lặng lẽ rời hầm lúc gần sáng: \"Nhà mình không đủ ăn, tôi không muốn làm gánh nặng.\"" % g.name)
				continue
		if g.kind in ["mother", "kid", "dog"]:
			morale = mini(100, morale + 1)
	phase = "dawn"          # chờ sổ sáng hiện ra rồi mới được chia khẩu phần
	panel = "none"
	world.weather.hour = 10.0
	_push()
	_cl_place_bunker.rpc()
	_cl_fade.rpc("NGÀY %d" % day)
	get_tree().create_timer(1.7).timeout.connect(_morning)


var _pipe_top: Node3D
var _pipe_fallen: Node3D
var _pipe_steam: CPUParticles3D


## Ống thông khí ở sân sau (gốc ống, đoạn trên, đoạn gãy văng ra, hơi bụi phụt ra khi gãy) và nắp hầm sắt rỉ trong nhà.
func _build_pipe_and_hatch() -> void:
	_pipe_node = Node3D.new()
	add_child(_pipe_node)
	_pipe_node.global_position = pipe_pos
	var steel := "7a7e84"
	ItemModels._part(_pipe_node, "box", Vector3(0.9, 0.12, 0.9), Vector3(0, 0.06, 0), "5a5a58")          # bệ bê tông
	ItemModels._part(_pipe_node, "cyl", Vector3(0.16, 0.9, 0), Vector3(0, 0.55, 0), steel)                # gốc ống
	ItemModels._part(_pipe_node, "cyl", Vector3(0.2, 0.08, 0), Vector3(0, 0.98, 0), "5e6268")             # mặt bích
	_pipe_top = Node3D.new()
	_pipe_node.add_child(_pipe_top)
	ItemModels._part(_pipe_top, "cyl", Vector3(0.16, 1.5, 0), Vector3(0, 1.75, 0), steel)
	ItemModels._part(_pipe_top, "cyl", Vector3(0.26, 0.2, 0.16), Vector3(0, 2.6, 0), "5e6268")              # chụp mũ ống
	_pipe_fallen = Node3D.new()
	_pipe_node.add_child(_pipe_fallen)
	_pipe_fallen.position = Vector3(1.3, 0.16, 0.4)
	_pipe_fallen.rotation = Vector3(0.2, 0.6, PI * 0.5)
	ItemModels._part(_pipe_fallen, "cyl", Vector3(0.16, 1.5, 0), Vector3.ZERO, "6e7278")
	ItemModels._part(_pipe_fallen, "cyl", Vector3(0.26, 0.2, 0.16), Vector3(0, 0.85, 0), "5e6268")
	# miệng ống gãy lởm chởm
	for k in 5:
		var a := k * TAU / 5.0
		ItemModels._part(_pipe_node, "box", Vector3(0.06, 0.12 + 0.06 * (k % 2), 0.03), Vector3(cos(a) * 0.15, 1.08, sin(a) * 0.15), steel, Vector3(0, -a, 0.2))
	_pipe_steam = CPUParticles3D.new()
	_pipe_steam.amount = 24
	_pipe_steam.lifetime = 1.4
	_pipe_steam.direction = Vector3.UP
	_pipe_steam.spread = 18.0
	_pipe_steam.initial_velocity_min = 1.0
	_pipe_steam.initial_velocity_max = 1.8
	_pipe_steam.gravity = Vector3(0, 0.2, 0)
	_pipe_steam.scale_amount_min = 0.4
	_pipe_steam.scale_amount_max = 0.9
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.85, 0.85, 0.85, 0.35)
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = pm
	_pipe_steam.mesh = sm
	_pipe_steam.position = Vector3(0, 1.1, 0)
	_pipe_steam.emitting = false
	_pipe_node.add_child(_pipe_steam)
	# nắp hầm: tấm thép vuông 1,2m màu rỉ sét, viền khung, đinh tán, tay nắm hàn bên ngoài
	var hatch := Node3D.new()
	add_child(hatch)
	hatch.global_position = exit_pos
	var rust := "7a4a2a"
	ItemModels._part(hatch, "box", Vector3(1.4, 0.08, 1.4), Vector3(0, 0.04, 0), "4a3424")
	ItemModels._part(hatch, "box", Vector3(1.2, 0.06, 1.2), Vector3(0, 0.1, 0), rust)
	for k2 in 4:
		var sx := -0.5 if k2 % 2 == 0 else 0.5
		var sz := -0.5 if k2 < 2 else 0.5
		ItemModels._part(hatch, "cyl", Vector3(0.035, 0.03, 0), Vector3(sx, 0.14, sz), "5a3018")             # đinh tán
	ItemModels._part(hatch, "box", Vector3(1.0, 0.025, 0.06), Vector3(0, 0.14, -0.25), "8a5a36")              # gân tăng cứng
	ItemModels._part(hatch, "box", Vector3(1.0, 0.025, 0.06), Vector3(0, 0.14, 0.25), "8a5a36")
	# tay nắm: thanh thép cong hàn hai đầu (mối hàn sần)
	ItemModels._part(hatch, "cyl", Vector3(0.025, 0.14, 0), Vector3(-0.22, 0.2, 0.0), "3a3a3c")
	ItemModels._part(hatch, "cyl", Vector3(0.025, 0.14, 0), Vector3(0.22, 0.2, 0.0), "3a3a3c")
	ItemModels._part(hatch, "cyl", Vector3(0.025, 0.46, 0), Vector3(0, 0.27, 0.0), "3a3a3c", Vector3(0, 0, PI * 0.5))
	for wx: float in [-0.22, 0.22]:
		ItemModels._part(hatch, "sph", Vector3(0.05, 0.03, 0.05), Vector3(wx, 0.14, 0.0), "4a3a30")


var _pipe_hold := 0.0
var _pipe_clank := 0.0
const PIPE_TIME := 5.0


## Giữ E cạnh ống gãy đủ 5 giây thì nối lại được; buông tay hoặc bỏ đi thì làm lại từ đầu.
func _update_pipe_hold(delta: float) -> void:
	if _pipe_hold <= 0.0:
		return
	var p: Node3D = world.local_player()
	var near: bool = p != null and p.global_position.distance_to(pipe_pos) < 3.0
	if not pipe_broken or not near or not Input.is_action_pressed("interact"):
		_pipe_hold = 0.0
		Game.hold_label = ""
		return
	_pipe_hold += delta
	_pipe_clank -= delta
	if _pipe_clank <= 0.0:
		_pipe_clank = 0.7
		Sfx.play_at("metal_hit", pipe_pos + Vector3(0, 0.6, 0), -6.0, 18.0, randf_range(0.8, 1.2))
	Game.hold_label = "Đang nối ống thông khí… (giữ E)"
	Game.hold_prog = _pipe_hold / PIPE_TIME
	if _pipe_hold >= PIPE_TIME:
		_pipe_hold = 0.0
		Game.hold_label = ""
		if is_host():
			_srv_fix_pipe()
		else:
			_srv_fix_pipe.rpc_id(1)


func _process(delta: float) -> void:
	if not active or ended or world == null:
		return
	_update_mission_lights()
	_update_pipe_hold(delta)
	_knock_wait = maxf(0.0, _knock_wait - delta)
	if is_host():
		# dưới hầm thì đồng hồ đứng yên theo giai đoạn; khi có người ra ngoài thì đêm trôi thật
		var anyone_out := night.values().has("out")
		if phase == "day" or phase == "morning_event":
			world.weather.hour = 10.0
		elif phase != "out":
			world.weather.hour = 21.0
		_push_t -= delta
		if _push_t <= 0.0:
			_push_t = 0.5
			if world.online_peers() > 0:
				_cl_state.rpc(pack())
		_story_tick(delta)
	if _machine_node and str(machine.state) == "carried":
		_sync_story_nodes()
	if outside:
		var h: float = world.weather.hour
		if h > 5.0 and h < 12.0 and not flags.has("_warned_dawn"):
			flags["_warned_dawn"] = true
			Game.say("Trời sáng rồi. Ban ngày chúng nhìn rõ hơn nhiều. Về hầm ngay!", "bad")
		_check_sites()
	else:
		flags.erase("_warned_dawn")
		# dưới hầm không đói khát theo giờ: ăn uống tính theo khẩu phần chia mỗi ngày
		Game.food = maxf(Game.food, 40.0)
		Game.water = maxf(Game.water, 40.0)


## Việc theo nhịp của cốt truyện (chỉ máy chủ): hết trận đánh trong hầm, phục kích, cảnh cứu người, trời sáng, máy phát đang được vác.
func _story_tick(delta: float) -> void:
	var mgr: Node = world.monsters
	if phase == "fight" and mgr.robbers_fighting() == 0:
		phase = "event"
		_cl_say.rpc("Bọn cướp gục cả rồi. Đồ của chúng rơi đầy sàn. Mấy cái xác thì phải vác ra ngoài (E).", "good")
		open_event("dem_nay", "night")
		return
	if phase != "out":
		return
	# phục kích: một toán cướp đuổi theo người đi kiếm đồ
	if _ambush_t > 0.0:
		_ambush_t -= delta
		if _ambush_t <= 0.0:
			var outs: Array = []
			for p in mgr.players():
				if not in_bunker(p.global_position):
					outs.append(p)
			if not outs.is_empty():
				var tp: Node3D = outs[rng.randi() % outs.size()]
				var back: Vector3 = tp.global_position + tp.global_transform.basis.z * 16.0
				mgr.spawn_robbers(Vector3(back.x, tp.global_position.y + 0.3, back.z), 2 + rng.randi() % 2, 2.5)
				_cl_say.rpc("Tiếng chân chạy rầm rập phía sau. Một toán người bịt mặt, tay lăm lăm gậy!", "bad")
	# cảnh cứu người: hạ hết bọn cướp thì người ấy tặng đồ
	if not help.is_empty() and not help.get("done", true):
		var left := 0
		for idx: int in help.ids:
			if idx >= 0 and mgr.list[idx].state == "fight":
				left += 1
		if left == 0:
			help["done"] = true
			var hp: Vector3 = help.pos
			for k in 4:
				world.loot.drop(["luongkho", "nuocsuoi", "bang", "cahop"][k], hp + Vector3(cos(k * 1.6) * 1.2, 0.3, sin(k * 1.6) * 1.2))
			morale = mini(100, morale + 8)
			_cl_dialogue.rpc(["Người đàn ông: Cảm ơn… cảm ơn các anh. Tôi tưởng chết rồi.", "Người đàn ông: Đồ của tôi, các anh cầm lấy. Tôi không mang nổi về đâu, chân tôi gãy rồi.", {"who": "", "text": "Ông ta lết vào một mái hiên, vẫy tay bảo bạn đi đi."}])
			_push()
	# máy phát đang được vác: bám theo người vác
	if str(machine.state) == "carried":
		var cp: Node3D = mgr.player_by_id(int(machine.carrier))
		if cp == null:
			machine.state = "ground"
			machine.carrier = 0
		else:
			machine.pos = cp.global_position
	# trời sáng: ai còn ở ngoài thì phải chạy về ngay, và bị thương vì bị phát hiện
	var h: float = world.weather.hour
	if h > 5.5 and h < 12.0:
		for pid: int in night.keys():
			if night[pid] == "out":
				_cl_personal.rpc({"hp": -20}, pid)
				_tell(pid, "Trời sáng. Bạn chạy thục mạng về hầm, bị một thứ gì đó quật trúng trên đường.", "bad")
				_let_in(pid)
				if not is_inside_tree() or phase != "out":
					return


# ------------------------------------------------------------------ máy phát tín hiệu
func machine_action(what: String) -> void:
	if is_host():
		_srv_machine(what)
	else:
		_srv_machine.rpc_id(1, what)


func drop_machine() -> void:
	machine_action("drop")


@rpc("any_peer", "reliable")
func _srv_machine(what: String) -> void:
	if not is_host():
		return
	var pid := multiplayer.get_remote_sender_id()
	if pid == 0:
		pid = 1
	var p: Node3D = world.monsters.player_by_id(pid)
	match what:
		"pick":
			if str(machine.state) in ["tower", "ground"] and p and p.global_position.distance_to(machine.pos) < 3.5:
				machine.state = "carried"
				machine.carrier = pid
				_carry_to(pid, "machine")
				if not flags.has("_machine_taken"):
					flags["_machine_taken"] = true
					_cl_dialogue.rpc(["Máy phát: Bíp… bíp… Thiết bị đã khởi động. Mang về nơi trú ẩn, đặt lên mặt phẳng và giữ nguyên vị trí."])
		"drop":
			if str(machine.state) == "carried" and int(machine.carrier) == pid:
				machine.state = "ground"
				machine.carrier = 0
				if p:
					var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p.global_position + Vector3(0, 1.0, 0), p.global_position + Vector3(0, -3.0, 0), 1))
					machine.pos = (hit.position as Vector3) if not hit.is_empty() else p.global_position
		"place":
			if str(machine.state) == "carried" and int(machine.carrier) == pid and p and in_bunker(p.global_position):
				machine.state = "placed"
				machine.carrier = 0
				machine.pos = origin + STAND + Vector3(0, 0.62, 0)
				_carry_to(pid, "")
				bomb_day = day + 3
				var nd := need_counts()
				_cl_dialogue.rpc(["Máy phát: …tín hiệu đã gửi. Vị trí của các bạn đã được ghi nhận.",
					"Máy phát: Trong 3 ngày tới, không quân sẽ ném bom toàn bộ nội thành để quét sạch các sinh vật. Sau khi bom rơi, không được lên mặt đất trong 7 ngày.",
					"Máy phát: Hãy tích trữ đủ lương thực cho 7 ngày: %d phần ăn, %d phần nước và %d cái chăn cho %d người. Khi đã đủ, báo lại qua thiết bị này." % [nd.food, nd.water, nd.chan, people()],
					"Mai: Ba ngày… Anh ơi, mình phải gom cho đủ."])
		"check":
			if str(machine.state) != "placed":
				return
			if stock_ok():
				_good_ending()
			else:
				var nd2 := need_counts()
				_cl_dialogue.rpc(["Máy phát: Chưa đủ dự trữ. Hiện có %d/%d phần ăn, %d/%d phần nước, %d/%d chăn. Còn %d ngày trước khi ném bom." % [food, nd2.food, water, nd2.water, int(storage.get("chan", 0)), nd2.chan, bomb_day - day]])
	_push()


## Một kẻ cướp vừa gục (máy chủ).
func on_robber_down(_r: Node) -> void:
	_push()


func _tell(pid: int, text: String, kind: String) -> void:
	if pid == my_id():
		Game.say(text, kind)
	else:
		_cl_say.rpc_id(pid, text, kind)


## Điểm mục tiêu để chỉ đường trên bản đồ (theo việc đêm nay).
func objective_point() -> Vector3:
	if not outside:
		return exit_pos
	if Game.carrying == "machine":
		return exit_pos
	if mission == "medicine" and not flags.has("na_cured") and Game.count("thuocdactri") == 0:
		if (Game.safe_code or flags.has("safe_code")) and city.hospital_safe_cid >= 0:
			return city.containers[city.hospital_safe_cid].pos
		for lm: Dictionary in city.landmarks:
			if lm.name == "TRƯỜNG HỌC":
				return lm.pos
	if str(machine.state) in ["tower", "ground"] and (mission == "machine" or flags.has("radio_may")):
		return machine.pos
	if pipe_broken:
		return pipe_pos
	if not help.is_empty() and not help.get("done", true):
		return help.pos
	return exit_pos


@rpc("any_peer", "reliable")
func _srv_flag(k: String) -> void:
	if is_host() and k in ["safe_code"]:
		flags[k] = true
		_push()


func _carry_to(pid: int, what: String) -> void:
	if pid == my_id():
		world._cl_carry(what)
	else:
		world._cl_carry.rpc_id(pid, what)


## Vác xác từ trong hầm ra vứt ngoài ngõ.
@rpc("any_peer", "reliable")
func _srv_dump_body() -> void:
	if not is_host():
		return
	var pid := multiplayer.get_remote_sender_id()
	if pid == 0:
		pid = 1
	for m: Monster in world.monsters.list:
		if m.kind == "robber" and int(m.get("carrier")) == pid:
			m.set("carrier", 0)
			m.global_position = exit_pos + Vector3(rng.randf_range(2.0, 5.0), 0.05, rng.randf_range(1.5, 4.0))
			morale = mini(100, morale + 2)
			_carry_to(pid, "")
			_tell(pid, "Bạn vác cái xác lên, vứt ra đầu ngõ rồi quay xuống.", "")
			break
	_push()


@rpc("any_peer", "reliable")
func _srv_fix_pipe() -> void:
	if is_host() and pipe_broken:
		pipe_broken = false
		_cl_say.rpc("Ống thông khí đã được nối lại. Dưới hầm lại có gió.", "good")
		_push()


## Cho bé Na uống lọ thuốc đặc trị.
@rpc("any_peer", "reliable")
func _srv_cure_na() -> void:
	if not is_host():
		return
	var na := member("na")
	if na.is_empty() or not na.alive or not na.get("special", false):
		return
	na["special"] = false
	flags["na_cured"] = true
	morale = mini(100, morale + 15)
	_cl_dialogue.rpc([{"who": "", "text": "Bạn vặn nắp lọ thuốc, đếm từng giọt vào thìa. Bé Na nuốt, nhăn mặt, rồi ho một tràng dài."}, "Mai: Con thở được rồi… anh nghe không, con thở êm rồi.", "Bé Na: Bố ơi… thuốc đắng quá."])
	_push()


func _sync_story_nodes() -> void:
	if not active:
		return
	# máy phát
	if str(machine.state) != "none":
		if _machine_node == null:
			_machine_node = Node3D.new()
			add_child(_machine_node)
			ItemModels._part(_machine_node, "box", Vector3(0.9, 0.55, 0.5), Vector3(0, 0.275, 0), "4a5236")
			ItemModels._part(_machine_node, "box", Vector3(0.36, 0.2, 0.02), Vector3(-0.15, 0.36, 0.26), "203020")
			ItemModels._part(_machine_node, "box", Vector3(0.3, 0.14, 0.022), Vector3(-0.15, 0.36, 0.262), "6fe0a0")
			ItemModels._part(_machine_node, "cyl", Vector3(0.015, 0.9, 0), Vector3(0.35, 1.0, -0.1), "8a9098")
			ItemModels._part(_machine_node, "box", Vector3(0.7, 0.06, 0.06), Vector3(0, 0.6, 0), "2a2c30")
			var lamp := OmniLight3D.new()
			lamp.light_color = Color(0.4, 1.0, 0.6)
			lamp.light_energy = 0.8
			lamp.omni_range = 4.0
			lamp.position = Vector3(0, 0.8, 0.4)
			_machine_node.add_child(lamp)
		var mp: Vector3 = machine.pos
		if str(machine.state) == "carried":
			var cp: Node3D = world.monsters.player_by_id(int(machine.carrier))
			if cp:
				mp = cp.global_position + (-cp.global_transform.basis.z) * 0.55 + Vector3(0, 0.75, 0)
				_machine_node.rotation.y = cp.rotation.y
		_machine_node.global_position = mp
		_machine_node.visible = not (str(machine.state) == "carried" and int(machine.carrier) == my_id() and not (world.local_player() as Node).get("third_person"))
	# ống thông khí cạnh lối ra
	if _pipe_node == null:
		_build_pipe_and_hatch()
	# ống gãy: đoạn trên văng nằm dưới đất, đoạn gốc còn trơ miệng ống; sửa xong thì nối liền
	_pipe_top.visible = not pipe_broken
	_pipe_fallen.visible = pipe_broken
	_pipe_steam.emitting = pipe_broken and outside
	# người bị đánh (cảnh cứu người)
	if not help.is_empty():
		if _victim == null:
			var hv := Humanoid.new()
			add_child(hv)
			hv.setup(Color("6a7a8a"), Color(0.25, 0.25, 0.3), Color("c9956a"))
			hv.play_dead(true)
			_victim = hv
		_victim.visible = true
		_victim.global_position = (help.pos as Vector3) + Vector3(0, 0.05, 0)
	elif _victim:
		_victim.visible = false


func _good_ending() -> void:
	phase = "ending"
	ended = true
	var na := alive("na")
	var mai := alive("mai")
	var lines: Array = ["Máy phát: Đã ghi nhận đủ dự trữ. Ở yên trong hầm. Không mở cửa cho bất kỳ ai cho tới khi có tín hiệu.", {"who": "", "text": "Đêm ấy, bầu trời sáng rực. Mặt đất rung lên không phải vì bước chân của chúng nữa."}]
	var text := "Bảy ngày sau, quân đội cuối cùng cũng tìm thấy căn hầm. Cả nhà mệt mỏi, kiệt quệ, nhưng sức khoẻ vẫn ổn. Mọi người được đưa tới trại tập trung ở ngoại thành.

"
	if not na:
		text = "Bảy ngày sau, quân đội tìm thấy căn hầm. Họ đưa những người còn lại tới trại tập trung. Có một cái chăn nhỏ mà không ai nỡ để lại.

"
	elif not mai:
		text = "Bảy ngày sau, quân đội tìm thấy căn hầm. Bé Na nắm chặt tay bạn suốt đường ra xe, không khóc. Con đã thôi hỏi mẹ đâu từ mấy hôm trước.

"
	text += "Hai năm sau, quân đội đã tiêu diệt hoàn toàn lũ quái vật. Thành phố bắt đầu được dựng lại. Người ta trở về, mở lại hàng quán, trồng lại cây trên những con phố từng sập.

Mọi thứ dần trở lại nhịp sống bình thường."
	if Game.cruelty >= 30.0:
		text += "

Chỉ có điều, mỗi lần nghe ai gõ cửa ban đêm, bạn vẫn giật mình."
	text += "

HẾT"
	_push()
	_cl_dialogue.rpc(lines)
	get_tree().create_timer(9.0).timeout.connect(func() -> void: _cl_ending.rpc("BÌNH YÊN" if na and mai else "CÒN SỐNG", text, not (na and mai)))


func _bomb_ending() -> void:
	phase = "ending"
	ended = true
	var nd := need_counts()
	var text := "Bom rơi đúng sáng ngày thứ %d. Mặt đất rung chuyển suốt hai ngày liền.

Kho dưới hầm chỉ có %d/%d phần ăn, %d/%d phần nước. Sau bom thì không ai còn lên được mặt đất nữa.

Đến ngày thứ năm, cả nhà chia nhau ngụm nước cuối cùng. Khi quân đội mở được cửa hầm, đã quá muộn.

HẾT" % [day, food, nd.food, water, nd.water]
	_push()
	_cl_ending.rpc("KHÔNG KỊP", text, true)


func _lost_ending() -> void:
	phase = "ending"
	ended = true
	var text := "Không ai biết căn hầm của bạn ở đâu. Cái đài cứ rè rè mãi những lời nhắc về trạm phát sóng.

Đồ ăn cạn dần, rồi hết hẳn.

HẾT"
	_push()
	_cl_ending.rpc("BỊ LÃNG QUÊN", text, true)


func _update_objective() -> void:
	if not active:
		return
	if outside:
		var goal := "Tìm đồ rồi chui xuống hầm trước khi trời sáng"
		if Game.carrying == "machine":
			goal = "Vác máy phát về hầm, đặt lên bệ"
		elif mission == "medicine" and not flags.has("na_cured") and Game.count("thuocdactri") == 0:
			goal = "Tìm lọ thuốc của bé Na: tủ khoá ở trường, hoặc két bệnh viện"
		elif mission == "machine" and str(machine.state) in ["tower", "ground"]:
			goal = "Lấy máy phát tín hiệu ở trạm phát sóng"
		elif pipe_broken:
			goal = "Sửa ống thông khí cạnh lối ra hầm"
		elif not help.is_empty() and not help.get("done", true):
			goal = "Cứu người đang bị đánh gần đây"
		Game.objective = goal + "  ·  " + summary()
	elif phase == "day" or phase == "morning_event":
		Game.objective = ("Chia khẩu phần ở bàn  ·  " if not rationed else "") + summary()
	else:
		Game.objective = summary()


# ------------------------------------------------------------------ tương tác trong hầm
func in_bunker(p: Vector3) -> bool:
	return p.y < -5.0 and Vector2(p.x - origin.x, p.z - origin.z).length() < 8.0


func find_interactable(eye: Vector3, from: Vector3, dir: Vector3) -> Dictionary:
	if not active:
		return {}
	if outside:
		if str(machine.state) in ["tower", "ground"] and Game.carrying == "":
			var mp: Vector3 = (machine.pos as Vector3) + Vector3(0, 0.4, 0)
			if eye.distance_to(mp) < 2.6 and dir.dot((mp - from).normalized()) > 0.6:
				return {"type": "shelter", "id": "machine_pick", "pos": mp, "label": "Vác máy phát tín hiệu (rất nặng)"}
		if pipe_broken:
			var pp0 := pipe_pos + Vector3(0, 1.0, 0)
			if eye.distance_to(pp0) < 2.6 and dir.dot((pp0 - from).normalized()) > 0.55:
				return {"type": "shelter", "id": "pipe_fix", "pos": pp0, "label": "Sửa ống thông khí"}
		var hp := exit_pos + Vector3(0, 0.3, 0)
		if eye.distance_to(hp) < 3.2 and dir.dot((hp - from).normalized()) > 0.45:
			return {"type": "shelter", "id": "hatch_down", "pos": hp, "label": "Chui xuống hầm" + (" (mang theo máy phát)" if Game.carrying == "machine" else "")}
		return {}
	if not in_bunker(eye):
		return {}
	var best := {}
	var best_s := 0.82
	var spots := _spots.duplicate()
	if Game.carrying == "machine" or str(machine.state) == "placed":
		spots.append({"id": "stand", "pos": origin + STAND + Vector3(0, 0.8, 0), "label": "Đặt máy phát lên bệ" if Game.carrying == "machine" else "Kiểm tra máy phát tín hiệu"})
	for s in spots:
		var pos: Vector3 = s.pos
		if eye.distance_to(pos) > 2.6:
			continue
		var sc := dir.dot((pos - from).normalized())
		if sc > best_s:
			best_s = sc
			var label: String = s.label
			if s.id == "ladder" and Game.carrying == "body":
				label = "Vác xác lên vứt ngoài ngõ"
			best = {"type": "shelter", "id": s.id, "pos": pos, "label": label}
	for pid: String in _people:
		var h: Node3D = _people[pid]
		if not h.visible:
			continue
		var pp := h.global_position + Vector3(0, (0.9 * h.scale.y) if h is Humanoid else 0.3, 0)
		if eye.distance_to(pp) > 2.6:
			continue
		var sc2 := dir.dot((pp - from).normalized())
		if sc2 > best_s:
			best_s = sc2
			var nm: String = member(pid).get("name", guest(pid).get("name", "?"))
			best = {"type": "shelter", "id": "talk:" + pid, "pos": pp, "label": "Nói chuyện với " + nm}
	return best


func interact(t: Dictionary) -> void:
	var id: String = t.id
	if id == "hatch_down":
		return_home()
	elif id == "machine_pick":
		machine_action("pick")
	elif id == "pipe_fix":
		# phải giữ E liên tục 5 giây (xem _update_pipe_hold)
		_pipe_hold = 0.001
		Sfx.play("metal_hit", -4.0)
	elif id == "stand":
		machine_action("place" if Game.carrying == "machine" else "check")
	elif id == "ladder" and Game.carrying == "body":
		if is_host():
			_srv_dump_body()
		else:
			_srv_dump_body.rpc_id(1)
	elif id == "table":
		if phase != "day":
			Game.say("Hôm nay đã chia khẩu phần rồi.")
		elif is_host():
			open_rations()
		else:
			Game.say("Cuốn sổ chia khẩu phần do chủ phòng giữ. Khi họ mở sổ, bạn sẽ thấy.")
	elif id == "radio":
		Sfx.play("ui_open", -6.0)
		ui.call("show_journal", "RADIO", str(ShelterEvents.RADIO.get(mini(day, 8), "…chỉ còn tiếng rè…")), "Tắt đài", func() -> void: ui.call("close_all"))
	elif id == "shelf":
		world.inv_ui.open_storage(self)
	elif id == "ladder":
		if phase == "choose":
			if str(night.get(my_id(), "?")) == "sleep":
				night_pick("out") if not is_host() else _reopen_choice()
			else:
				ui.call("show_night_choice")
		elif phase == "day":
			Game.say("Ban ngày chúng nhìn thấy quá rõ. Chia khẩu phần xong, đợi đêm xuống rồi hãy tính chuyện ra ngoài.")
	elif id == "wall":
		ui.call("show_journal", "NGÀY %d" % day, family.map(func(f: Dictionary) -> String: return "%s: %s" % [f.name, status_of(f)]).reduce(func(a: String, b: String) -> String: return a + "\n" + b) + "\n\n" + summary() + "\nTinh thần cả nhà: %d/100" % morale, "Đóng", func() -> void: ui.call("close_all"))
	elif id.begins_with("talk:"):
		var who := id.substr(5)
		if who == "na" and member("na").get("special", false) and Game.count("thuocdactri") > 0:
			Game.remove_item("thuocdactri")
			if is_host():
				_srv_cure_na()
			else:
				_srv_cure_na.rpc_id(1)
			return
		Game.say(_talk(who))


func _talk(pid: String) -> String:
	var f := member(pid)
	if pid == "mai":
		if f.sick: return "Mai: 'Em không sao… anh lo cho con trước đi.' Cô ấy đang sốt."
		if int(f.hunger) >= 3: return "Mai: 'Em chịu được. Phần của em anh cứ để cho con.'"
		if alive("na") and member("na").sick: return "Mai: 'Con nóng lắm anh ạ. Phải có kháng sinh. Nhà thuốc ngoài phố chắc còn.'"
		if not alive("na"): return "Mai ngồi ôm cái chăn của con. Cô ấy không nghe thấy bạn."
		if morale < 30: return "Mai: 'Em không biết mình cầm cự vì cái gì nữa.'"
		if alive("na") and member("na").get("special", false): return "Mai: 'Lọ thuốc của con ở trong tủ khoá ở trường. Hoặc bệnh viện, nhưng ở đó người ta cất thuốc trong két.'"
		if bomb_day > 0: return "Mai: 'Còn %d ngày nữa là bom rơi. Phải gom đủ đồ ăn, nước, chăn cho cả nhà.'" % maxi(0, bomb_day - day)
		return "Mai: 'Đêm nay ai gõ cửa cũng phải hỏi cho kỹ, anh nhé. Đài bảo có thứ giả tiếng người.'"
	if pid == "na":
		if f.get("special", false): return "Bé Na thở rít từng hơi, môi tím tái. Phải có lọ thuốc đặc trị. (Mang lọ thuốc về rồi nói chuyện với con.)"
		if f.sick: return "Bé Na mê man, môi khô nứt. Con gọi 'bố ơi' trong cơn sốt."
		if int(f.hunger) >= 2: return "Bé Na: 'Bố ơi con đói.' Rồi con im, như sợ làm bạn buồn."
		return ["Bé Na: 'Bố ơi, trực thăng có chở được bạn Thỏ không?'", "Bé Na đang vẽ lên tường bằng mẩu gạch: ba người và một ngôi nhà có ống khói.", "Bé Na: 'Hôm nào hết quái vật bố cho con đi công viên nha.'"][day % 3]
	var g := guest(pid)
	match str(g.get("kind", "")):
		"nurse": return "Cô Hạnh: 'Có kháng sinh là tôi cho cháu uống ngay. Anh cứ để trên bàn.'"
		"fixer": return "Ông Tư: 'Chú đừng mở cửa cho ai gọi tên chú mà không trả lời được câu hỏi. Bác thấy tận mắt rồi.'"
		"soldier": return "Khoa: 'Có tôi ở đây, bọn cướp không dám làm gì đâu. Còn mấy thứ kia thì súng cũng chỉ đuổi được thôi.'"
		"mother": return "Chị Thảo: 'Em trông bé Na cho, anh chị cứ lo việc khác.'"
		"kid": return "Thằng Tí chia cho bé Na nửa cái bánh nó giấu trong ba lô siêu nhân."
		"dog": return "Con Mực vẫy đuôi, rồi lại quay mặt ra phía cửa hầm canh."
	return "…"


func _reopen_choice() -> void:
	ui.call("show_night_choice")


## Cất đồ ăn, nước, thuốc từ túi vào kho hầm (kho chung nằm ở máy chủ phòng). Trả về lời báo.
func store_from_bag() -> String:
	var f := 0
	var w := 0
	var m: Dictionary = {}
	for id: String in Game.inv.keys():
		var d := Items.get_def(id)
		var n := Game.count(id)
		if n <= 0:
			continue
		if d.get("cat", "") == "food":
			f += n * maxi(1, int(round(float(d.get("food", 25)) / 28.0)))
			Game.inv.erase(id)
		elif d.get("cat", "") == "drink":
			w += n * maxi(1, int(d.get("uses", 1)))
			Game.inv.erase(id)
		elif id in ["khangsinh", "giamdau", "bang"]:
			m[id] = int(m.get(id, 0)) + n
			Game.inv.erase(id)
	Game.inventory_changed.emit()
	if f + w + m.size() == 0:
		return "Trong túi không có đồ ăn, nước hay thuốc để cất."
	if is_host():
		_srv_store(f, w, m)
	else:
		_srv_store.rpc_id(1, f, w, m)
	Sfx.play("pickup", -4.0)
	var mn := 0
	for k: String in m:
		mn += int(m[k])
	return "Đã cất vào kho: +%d phần đồ ăn, +%d phần nước, +%d thuốc." % [f, w, mn]


@rpc("any_peer", "reliable")
func _srv_store(f: int, w: int, m: Dictionary) -> void:
	if not is_host():
		return
	food += clampi(f, 0, 99)
	water += clampi(w, 0, 99)
	for k: String in m:
		meds[k] = int(meds.get(k, 0)) + clampi(int(m[k]), 0, 99)
	_push()


# ------------------------------------------------------------------ chạm trán ngoài phố
func _spawn_sites() -> void:
	sites = []
	var pool: Array = ShelterEvents.OUTSIDE_POOL.filter(_eligible)
	pool.shuffle()
	var home := city.home_pos
	for k in mini(3, pool.size()):
		var id: String = pool[k]
		var pos := Vector3.ZERO
		if id == "o_ong_ba":
			for b in city.buildings:
				var c: Vector2 = (b.rect as Rect2).get_center()
				var d := Vector2(c.x - home.x, c.y - home.z).length()
				if b.kind == "house" and not b.has("damage") and not b.has("yaw") and d > 45.0 and d < 150.0 and rng.randf() < 0.2:
					pos = Vector3(c.x, City.BASE + 0.05, c.y)
					break
		if pos == Vector3.ZERO:
			for attempt in 60:
				var rp := city.road_point(rng)
				var d2 := rp.distance_to(home)
				if d2 > 55.0 and d2 < 190.0 and not city._near_underground(rp, 5.0):
					pos = rp + Vector3(rng.randf_range(-3.0, 3.0), 0.02, rng.randf_range(-3.0, 3.0))
					break
		if pos == Vector3.ZERO:
			continue
		used.append(id)
		sites.append({"id": id, "pos": pos, "done": false})
	if flags.has("hua_tim_me") and not flags.has("da_tim_me"):
		var hz := City.zone_rect(City.HOODS[1])
		sites.append({"id": "o_me_mai", "pos": Vector3(hz.get_center().x, City.BASE + 0.05, hz.end.y + 4.0), "done": false})


## Dựng (hoặc dọn) hình ảnh các điểm chạm trán theo danh sách máy chủ gửi.
func _sync_sites() -> void:
	var keep: Dictionary = {}
	for s: Dictionary in sites:
		keep[s.id] = true
		if not _site_nodes.has(s.id):
			_site_nodes[s.id] = _make_site(s.id, s.pos)
	for id: String in _site_nodes.keys():
		if not keep.has(id):
			(_site_nodes[id] as Node).queue_free()
			_site_nodes.erase(id)


func _make_site(id: String, pos: Vector3) -> Node3D:
	var node := Node3D.new()
	add_child(node)
	node.global_position = pos
	var n_people: int = {"o_dot_lua": 3, "o_ong_ba": 2, "o_nguoi_ket": 0, "o_xe_hang": 1, "o_dua_be": 1, "o_nguoi_linh": 1, "o_me_mai": 1}.get(id, 1)
	for i in n_people:
		var h := Humanoid.new()
		node.add_child(h)
		var soldier := id == "o_nguoi_linh"
		h.setup(Color("4a5a3a") if soldier else Color.from_hsv(float((hash(id) + i * 37) % 100) / 100.0, 0.3, 0.55), Color(0.2, 0.2, 0.24), Color("d9a679"))
		var a := i * TAU / maxf(1.0, n_people) + 0.4
		h.position = Vector3(cos(a), 0, sin(a)) * (1.3 if n_people > 1 else 0.0)
		h.rotation.y = -a - PI * 0.5
		if id == "o_dua_be":
			h.scale = Vector3.ONE * 0.7
		if id in ["o_ong_ba", "o_nguoi_linh", "o_dua_be"]:
			h.animate(0.016, 0.0, true, false)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 1.0, 0)
	light.omni_range = 13.0 if id == "o_dot_lua" else 6.0
	light.light_energy = 3.2 if id == "o_dot_lua" else 1.1
	light.light_color = Color("ff9a4a") if id == "o_dot_lua" else Color("ffd9a0")
	node.add_child(light)
	if id == "o_dot_lua":
		var drum := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.32
		cm.bottom_radius = 0.3
		cm.height = 0.9
		drum.mesh = cm
		drum.position.y = 0.45
		node.add_child(drum)
	elif id == "o_xe_hang":
		var cart := ItemModels.make("canxang")
		cart.scale = Vector3.ONE * 3.0
		cart.position = Vector3(0.9, 0.2, 0)
		node.add_child(cart)
	return node


func _check_sites() -> void:
	if current_id != "" or ui.call("is_open"):
		return
	var p: CharacterBody3D = world.local_player()
	if p == null:
		return
	for s: Dictionary in sites:
		var r := 7.5 if s.id == "o_dot_lua" else 4.2
		if not s.done and p.global_position.distance_to(s.pos) < r and ShelterEvents.EVENTS.has(s.id):
			s.done = true
			if is_host():
				_srv_site_done(str(s.id))
			else:
				_srv_site_done.rpc_id(1, str(s.id))
			open_event(s.id, "outside")
			return


@rpc("any_peer", "reliable")
func _srv_site_done(id: String) -> void:
	if not is_host():
		return
	for s: Dictionary in sites:
		if s.id == id:
			s.done = true
	_push()


# ------------------------------------------------------------------ kết thúc
func _ending() -> void:
	phase = "ending"
	ended = true
	var mai := alive("mai")
	var na := alive("na")
	var title := "ĐƯỢC CỨU"
	var bad := false
	var text := "Sáng ngày thứ %d, tiếng cánh quạt trực thăng làm rung cả nắp hầm. Lần này không phải giọng nói nào bắt chước: là tiếng giày đinh, tiếng bộ đàm, và ánh nắng.\n\n" % day
	if mai and na:
		text += "Bạn bế bé Na lên trước. Mai lên sau, nheo mắt vì chói. Ba người đứng giữa con ngõ nát bươm, còn nguyên vẹn.\n\n"
	elif mai or na:
		title = "CÒN LẠI HAI NGƯỜI"
		text += "Hai người leo lên khỏi hầm. Người lính đưa tay đỡ, liếc nhìn xuống căn hầm phía sau bạn rồi không hỏi gì cả.\n\n" + ("Bé Na nắm chặt tay bạn, không khóc. Con đã thôi hỏi mẹ đâu từ mấy hôm trước.\n\n" if na else "Mai ôm cái chăn nhỏ vào ngực suốt đường ra trực thăng.\n\n")
	else:
		title = "MỘT MÌNH"
		bad = true
		text += "Bạn leo lên khỏi hầm, một mình. Người lính hỏi còn ai dưới đó không. Bạn không trả lời được.\n\n"
	for g: Dictionary in guests:
		match str(g.kind):
			"fixer": text += "Ông Tư được dìu lên cáng. Ông vẫn nắm cái vòng cổ của con Mực.\n"
			"nurse": text += "Cô Hạnh không lên trực thăng: cô xin ở lại theo đội y tế vào các khu phố bên trong.\n"
			"mother": text += "Chị Thảo bế bé Bin đi ngay sau bạn. Thằng bé vẫy tay chào cái hầm.\n"
			"kid": text += "Thằng Tí đeo ba lô siêu nhân, hỏi chú phi công có thấy bố mẹ nó không.\n"
			"soldier": text += "Khoa bước lên, tự chìa hai tay ra. Viên chỉ huy nhìn cậu ta, rồi nhìn gia đình bạn, và chỉ nói: \"Lên máy bay đi.\"\n"
			"dog": text += "Con Mực nhảy lên trực thăng trước tất cả mọi người.\n"
	if flags.has("ong_tu_mat"):
		text += "Trước hiên nhà vẫn còn tấm chăn phủ lên một người. Bạn nói với người lính tên của ông.\n"
	if flags.has("phao_hieu"):
		text += "Bạn đưa tấm thẻ bài cho viên chỉ huy. \"Trung sĩ Lâm đã giữ ngã tư đó bốn ngày.\" Ông ta bỏ mũ xuống.\n"
	if Game.cruelty >= 25.0:
		text += "\nTrực thăng bay qua một căn nhà nhỏ. Bạn nhận ra nó. Bạn quay mặt đi.\n"
		bad = bad or Game.cruelty >= 50.0
	text += "\nTinh thần cả nhà: %d/100  ·  Số người bạn cho ở nhờ còn lại: %d" % [morale, guests.size()]
	text += "\n\nHẾT CHƯƠNG 2"
	panel = "none"
	_push()
	_cl_ending.rpc(title, text, bad)


@rpc("authority", "reliable", "call_local")
func _cl_ending(title: String, text: String, bad: bool) -> void:
	ended = true
	ui.call("close_all")
	Game.won = true
	Sfx.stop_all_loops()
	Sfx.play("win", -3.0)
	world.end_ui.call("show_custom", title, text, bad)
