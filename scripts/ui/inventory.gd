extends CanvasLayer
## Túi đồ + lục đồ: lưới vật phẩm có biểu tượng, rê chuột xem chi tiết, nhấp đúp để dùng; trang bị, thương tích, chỉ số.

const INK := Color("ebe5d8")
const DIM := Color("9a958b")
const AMBER := Color("e4a03a")
const SLOT := Vector2(74, 74)
const SLOT_NAMES := {"head": "Đầu", "eyes": "Mắt", "body": "Áo", "feet": "Giày", "back": "Balo", "wrist": "Cổ tay", "weapon": "Tay"}

var world: Node
var root: Control
var container_id := -1
var container_items: Array = []
var selected := ""
var selected_from := ""      # "bag" | "container" | "god"

var _title: Label
var _con_title: Label
var _con_grid: GridContainer
var _con_box: VBoxContainer
var _bag_grid: GridContainer
var _god_box: VBoxContainer
var _god_grid: GridContainer
var _detail_icon: TextureRect
var _detail_name: Label
var _detail_desc: Label
var _detail_stats: Label
var _use_btn: Button
var _drop_btn: Button
var _take_btn: Button
var _equip_box: VBoxContainer
var _status: Label
var _tip: PanelContainer
var _tip_text: Label
var opened_frame := -1
var _use_now: Dictionary = {}      # món vừa lấy bằng chuột phải: dùng ngay khi về tới túi


var _pending := false
var _hot_row: HBoxContainer
var _hot_btns: Array[Button] = []
var _hover_id := ""
var storage_mode := false
var _shelter: Node
var _drag_src := ""
var _drag_id := ""
var _drag_from := Vector2.ZERO
var _drag_ghost: TextureRect
var _drop_zone: Panel


func _ready() -> void:
	world = get_parent()
	visible = false
	_build()
	Game.inventory_changed.connect(_refresh)


func is_open() -> bool:
	return visible


## Tủ chứa đồ trong hầm: cột trái là tủ, cột phải là túi. Bấm một món: chuyển một cái. Kéo: chuyển cả chồng.
func open_storage(sh: Node) -> void:
	storage_mode = true
	_shelter = sh
	container_id = -1
	container_items = []
	_show()


func open_bag() -> void:
	storage_mode = false
	container_id = -1
	container_items = []
	_show()


## Lục một chỗ chứa đồ. Nếu trong đó chỉ có đúng một món thì nhặt luôn, không mở bảng.
func open_container(cid: int) -> void:
	container_id = cid
	container_items = []
	_pending = true
	Sfx.play("rummage", -8.0)
	world.loot.open(cid)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _drag_id != "":
		var mp := get_viewport().get_mouse_position()
		if event is InputEventMouseMotion and mp.distance_to(_drag_from) > 14.0:
			_drag_ghost.texture = Items.icon(_drag_id)
			_drag_ghost.visible = true
			_drop_zone.visible = true
			_drag_ghost.position = mp - Vector2(28, 28)
			var vs := get_viewport().get_visible_rect().size
			var out := mp.y > vs.y - 96.0 or mp.x < 30.0 or mp.x > vs.x - 30.0 or mp.y < 30.0
			_drop_zone.modulate = Color(1.3, 1.0, 0.7) if out else Color.WHITE
		elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and storage_mode:
			var dragged := _drag_ghost.visible
			var over_chest := _con_box.get_global_rect().has_point(mp)
			var sid := _drag_id
			var src := _drag_src
			_drag_id = ""
			_drag_ghost.visible = false
			_drop_zone.visible = false
			if not dragged:
				# bấm (không kéo): chuyển một món sang bên kia
				if src == "bag":
					_shelter.deposit(sid, 1)
				else:
					_shelter.withdraw(sid, 1)
			elif src == "bag" and over_chest:
				_shelter.deposit(sid, Game.count(sid))
			elif src == "storage" and not over_chest:
				_shelter.withdraw(sid, int(_shelter.chest_items().get(sid, 0)))
			get_viewport().set_input_as_handled()
			return
		elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var was_dragging := _drag_ghost.visible
			var vs2 := get_viewport().get_visible_rect().size
			var outside := mp.y > vs2.y - 96.0 or mp.x < 30.0 or mp.x > vs2.x - 30.0 or mp.y < 30.0
			var id2 := _drag_id
			_drag_id = ""
			_drag_ghost.visible = false
			_drop_zone.visible = false
			if was_dragging and Game.count(id2) > 0:
				for k in 5:
					if _hot_btns[k].get_global_rect().has_point(mp):
						_put_hot(k, id2)
						get_viewport().set_input_as_handled()
						return
			if was_dragging and outside and Game.count(id2) > 0:
				selected = id2
				selected_from = "bag"
				_drop_selected()
				get_viewport().set_input_as_handled()
				return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_TAB:
		# Tab: luôn là mở/đóng túi đồ, không bao giờ là chuyển ô
		if opened_frame != Engine.get_process_frames():
			close()
		get_viewport().set_input_as_handled()
		return
	if _hover_id != "" and Game.count(_hover_id) > 0:
		for k in 4:
			if event.is_action_pressed("hot_%d" % (k + 1)):
				_put_hot(k, _hover_id)
				get_viewport().set_input_as_handled()
				return
		if event.is_action_pressed("swap_hand"):
			_put_hot(4, _hover_id)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("jump") and storage_mode:
		_shelter.deposit_all()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("jump") and container_id >= 0:
		_take_all()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and opened_frame != Engine.get_process_frames():
		close()
		get_viewport().set_input_as_handled()


func _put_hot(k: int, id: String) -> void:
	if k == 4:
		for j in 4:
			if Game.hotbar[j] == id:
				Game.hotbar[j] = ""
		Game.offhand = id
		Game._sync_hand()
		Game.inventory_changed.emit()
	else:
		Game.assign_hot(k, id)
	Sfx.play("ui_click", -8.0)


func _show() -> void:
	visible = true
	opened_frame = Engine.get_process_frames()
	selected = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.play("ui_open", -10.0)
	_refresh()
	_no_focus.call_deferred(root)


func close() -> void:
	visible = false
	storage_mode = false
	_drag_id = ""
	if _drag_ghost:
		_drag_ghost.visible = false
		_drop_zone.visible = false
	_pending = false
	_tip.visible = false
	container_id = -1
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_opened(cid: int, items: Array) -> void:
	if cid == container_id and _pending:
		_pending = false
		if items.size() == 1:
			container_items = items
			_take(items[0])
			if not visible:
				container_id = -1
			return
		if items.is_empty():
			Game.say("Trống không.")
			container_id = -1
			return
		_show()
	if cid == container_id:
		container_items = items
		# các món lấy bằng chuột phải: dùng ngay
		for id: String in _use_now.keys():
			if Game.count(id) > 0:
				Game.use_item(id)
			_use_now.erase(id)
		_refresh()


# ------------------------------------------------------------------ dựng giao diện
func _label(text: String, size := 14, color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.make()
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.05, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	root.add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	margin.add_child(page)

	var head := HBoxContainer.new()
	page.add_child(head)
	_title = _label("TÚI ĐỒ", 30)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var close_btn := Button.new()
	close_btn.text = "✕  Đóng  [E]"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(close)
	head.add_child(close_btn)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 28)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(cols)

	# cột trái: thứ đang lục
	_con_box = VBoxContainer.new()
	_con_box.custom_minimum_size = Vector2(330, 0)
	_con_box.add_theme_constant_override("separation", 8)
	cols.add_child(_con_box)
	_con_title = _label("", 13, AMBER)
	_con_box.add_child(_con_title)
	_con_grid = GridContainer.new()
	_con_grid.columns = 4
	_con_box.add_child(_con_grid)
	_take_btn = Button.new()
	_take_btn.text = "Lấy tất cả  [Space]"
	_take_btn.focus_mode = Control.FOCUS_NONE
	_take_btn.theme_type_variation = "Primary"
	_take_btn.pressed.connect(func() -> void:
		if storage_mode:
			_shelter.deposit_all()
		else:
			_take_all())
	_con_box.add_child(_take_btn)

	# cột giữa: túi + kho đồ chế độ thần + chi tiết
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 10)
	cols.add_child(mid)
	mid.add_child(_label("THANH CÔNG CỤ · kéo món vào ô, hoặc trỏ vào món rồi bấm 1-4 (F: tay trái) · bấm ô để bỏ ra", 12, DIM))
	_hot_row = HBoxContainer.new()
	_hot_row.add_theme_constant_override("separation", 8)
	mid.add_child(_hot_row)
	for k in 5:
		var hb := Button.new()
		hb.custom_minimum_size = SLOT
		hb.theme_type_variation = "Slot"
		hb.expand_icon = true
		hb.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hb.focus_mode = Control.FOCUS_NONE
		var kk := k
		hb.pressed.connect(func() -> void:
			if kk == 4:
				Game.offhand = ""
				Game.inventory_changed.emit()
			else:
				Game.assign_hot(kk, ""))
		var tag := _label("F" if k == 4 else str(k + 1), 11, DIM)
		tag.position = Vector2(4, 2)
		hb.add_child(tag)
		_hot_row.add_child(hb)
		_hot_btns.append(hb)
	mid.add_child(_label("VẬT PHẨM · nhấp đúp để dùng", 12, DIM))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mid.add_child(scroll)
	var scroll_box := VBoxContainer.new()
	scroll_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(scroll_box)
	_bag_grid = GridContainer.new()
	_bag_grid.columns = 7
	scroll_box.add_child(_bag_grid)
	_god_box = VBoxContainer.new()
	scroll_box.add_child(_god_box)
	_god_box.add_child(_label("KHO ĐỒ · CHẾ ĐỘ THẦN (nhấp để lấy)", 12, AMBER))
	_god_grid = GridContainer.new()
	_god_grid.columns = 7
	_god_box.add_child(_god_grid)

	var detail := PanelContainer.new()
	detail.custom_minimum_size = Vector2(0, 120)
	mid.add_child(detail)
	var drow := HBoxContainer.new()
	drow.add_theme_constant_override("separation", 14)
	detail.add_child(drow)
	_detail_icon = TextureRect.new()
	_detail_icon.custom_minimum_size = Vector2(96, 96)
	_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	drow.add_child(_detail_icon)
	var dcol := VBoxContainer.new()
	dcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drow.add_child(dcol)
	_detail_name = _label("", 18)
	dcol.add_child(_detail_name)
	_detail_desc = _label("", 13, Color("d6d0c4"))
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dcol.add_child(_detail_desc)
	_detail_stats = _label("", 12, AMBER)
	_detail_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dcol.add_child(_detail_stats)
	var bcol := VBoxContainer.new()
	drow.add_child(bcol)
	_use_btn = Button.new()
	_use_btn.text = "Dùng"
	_use_btn.focus_mode = Control.FOCUS_NONE
	_use_btn.theme_type_variation = "Primary"
	_use_btn.custom_minimum_size = Vector2(110, 36)
	_use_btn.pressed.connect(_use_selected)
	bcol.add_child(_use_btn)
	_drop_btn = Button.new()
	_drop_btn.text = "Vứt"
	_drop_btn.focus_mode = Control.FOCUS_NONE
	_drop_btn.custom_minimum_size = Vector2(110, 36)
	_drop_btn.pressed.connect(_drop_selected)
	bcol.add_child(_drop_btn)

	# cột phải: trang bị + tình trạng
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(300, 0)
	right.add_theme_constant_override("separation", 8)
	cols.add_child(right)
	right.add_child(_label("TRANG BỊ · nhấp để cởi", 12, DIM))
	_equip_box = VBoxContainer.new()
	right.add_child(_equip_box)
	right.add_child(_label("TÌNH TRẠNG", 12, DIM))
	_status = _label("", 13)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_status)
	# ô thông tin bám theo con trỏ khi rê chuột lên vật phẩm
	_tip = PanelContainer.new()
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.visible = false
	_tip.z_index = 50
	root.add_child(_tip)
	_tip_text = _label("", 13)
	_tip_text.custom_minimum_size = Vector2(250, 0)
	_tip_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.add_child(_tip_text)
	# dải "vứt đồ" hiện ra khi đang kéo một món, và hình món đồ bám theo con trỏ
	_drop_zone = Panel.new()
	_drop_zone.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_drop_zone.offset_top = -92.0
	_drop_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drop_zone.visible = false
	root.add_child(_drop_zone)
	var dl := _label("⤓  Thả vào đây (hoặc ra ngoài mép bảng) để vứt xuống đất", 18, AMBER)
	dl.set_anchors_preset(Control.PRESET_FULL_RECT)
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drop_zone.add_child(dl)
	_drag_ghost = TextureRect.new()
	_drag_ghost.custom_minimum_size = Vector2(56, 56)
	_drag_ghost.size = Vector2(56, 56)
	_drag_ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_drag_ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_ghost.modulate = Color(1, 1, 1, 0.85)
	_drag_ghost.visible = false
	root.add_child(_drag_ghost)
	world.loot.opened.connect(_on_opened)
	world.loot.changed.connect(_on_opened)


func _no_focus(n: Node) -> void:
	for c in n.get_children():
		if c is Control:
			(c as Control).focus_mode = Control.FOCUS_NONE
		_no_focus(c)


func _slot(id: String, count: int, from: String, price := -1) -> Button:
	var b := Button.new()
	b.custom_minimum_size = SLOT
	b.theme_type_variation = "Slot"
	b.icon = Items.icon(id)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = Items.item_name(id)
	if selected == id and selected_from == from:
		b.modulate = Color(1.25, 1.1, 0.8)
	if count > 1:
		var c := _label("x%d" % count, 12)
		c.position = Vector2(48, 52)
		b.add_child(c)
	if price >= 0:
		var pl := _label(Game.format_money(price), 10, AMBER)
		pl.position = Vector2(4, 2)
		b.add_child(pl)
	b.mouse_entered.connect(func() -> void:
		_hover_id = id if from == "bag" else ""
		_show_tip(id, from))
	b.mouse_exited.connect(func() -> void:
		_hover_id = ""
		_tip.visible = false)
	b.tooltip_text = ""
	b.gui_input.connect(_slot_input.bind(id, from))
	return b


func _slot_input(event: InputEvent, id: String, from: String) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_LEFT and (from == "bag" or from == "storage"):
		# bắt đầu kéo: thả ra ngoài bảng để vứt; ở tủ chứa thì thả sang cột kia để chuyển
		_drag_id = id
		_drag_src = from
		_drag_from = get_viewport().get_mouse_position()
		if storage_mode:
			return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		# Chuột phải: ăn / uống / mặc / cầm NGAY, không cần cất vào túi trước.
		if from == "container":
			_use_now[id] = int(_use_now.get(id, 0)) + 1
			_take(id)
		elif from == "bag":
			Game.use_item(id)
		elif from == "god":
			Game.add_item(id)
			Game.use_item(id)
		_refresh()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	selected = id
	selected_from = from
	match from:
		"container":
			_take(id)
		"god":
			Game.add_item(id)
		"bag":
			if event.double_click:
				Game.use_item(id)
	_refresh()


func _show_tip(id: String, from: String) -> void:
	var d := Items.get_def(id)
	var price := ""
	if from == "container" and _is_paid():
		price = "\nGiá: %s đ" % Game.format_money(int(d.get("p", 0)))
	var verb := "ăn/uống" if d.get("cat", "") in ["food", "drink"] else ("mặc" if d.get("cat", "") == "gear" else "dùng")
	var hint := {"bag": ("Nhấp: cất 1 món vào tủ · Kéo sang tủ: cất cả chồng · Chuột phải: %s" % verb) if storage_mode else ("Nhấp: chọn · Kéo ra ngoài: vứt · Chuột phải: %s" % verb), "storage": "Nhấp: lấy 1 món vào túi · Kéo sang túi: lấy cả chồng", "container": "Nhấp: lấy vào túi · Chuột phải: %s ngay" % verb, "god": "Nhấp: lấy"}.get(from, "") as String
	_tip_text.text = "%s  [%s]\n%s\n%s%s\n%s" % [d.get("n", id), Items.category_name(d.get("cat", "")), d.get("d", ""), Items.describe(id), price, hint]
	_tip.visible = true
	_tip.reset_size()


func _process(_delta: float) -> void:
	if visible and _tip.visible:
		var m := root.get_local_mouse_position()
		var sz := _tip.size
		var pos := m + Vector2(18, 20)
		pos.x = minf(pos.x, root.size.x - sz.x - 8.0)
		pos.y = minf(pos.y, root.size.y - sz.y - 8.0)
		_tip.position = pos


func _show_detail(id: String, from: String) -> void:
	var d := Items.get_def(id)
	_detail_icon.texture = Items.icon(id)
	_detail_name.text = "%s   [%s]" % [d.get("n", id), Items.category_name(d.get("cat", ""))]
	_detail_desc.text = d.get("d", "")
	var extra := ""
	if from == "container" and _is_paid():
		extra = "  ·  giá %s đ" % Game.format_money(int(d.get("p", 0)))
	_detail_stats.text = Items.describe(id) + extra


func _is_paid() -> bool:
	var con: Dictionary = world.loot.info.get(container_id, {})
	return con.get("shop", false) and world.npcs.owner_present(int(con.get("building", -1)), con.get("pos", Vector3.ZERO)) and not Game.god


func _refresh() -> void:
	if not visible:
		return
	_title.text = "TÚI ĐỒ   %.1f / %d kg   ·   %s đ" % [Game.weight(), int(Game.capacity()), Game.format_money(Game.money)]
	# thứ đang lục
	_con_box.visible = container_id >= 0 or storage_mode
	for c in _con_grid.get_children():
		c.queue_free()
	if storage_mode:
		var items: Dictionary = _shelter.chest_items()
		_con_title.text = "TỦ CHỨA ĐỒ  ·  %d đồ ăn  ·  %d nước" % [_shelter.food, _shelter.water]
		var keys := items.keys()
		keys.sort_custom(func(a: String, b: String) -> bool: return str(Items.get_def(a).get("cat", "")) + a < str(Items.get_def(b).get("cat", "")) + b)
		for id: String in keys:
			_con_grid.add_child(_slot(id, int(items[id]), "storage"))
		if keys.is_empty():
			_con_grid.add_child(_label("Tủ trống.", 13, DIM))
		_take_btn.text = "Chuyển hết túi sang tủ  [Space]"
		_take_btn.visible = true
	elif container_id >= 0:
		_take_btn.text = "Lấy tất cả  [Space]"
		var con: Dictionary = world.loot.info.get(container_id, {})
		var paid := _is_paid()
		_con_title.text = "%s%s" % [str(con.get("name", "")).to_upper(), "  ·  PHẢI TRẢ TIỀN" if paid else ""]
		for id: String in container_items:
			_con_grid.add_child(_slot(id, 1, "container", int(Items.get_def(id).get("p", 0)) if paid else -1))
		if container_items.is_empty():
			_con_grid.add_child(_label("Trống.", 13, DIM))
		_take_btn.visible = not container_items.is_empty() and not paid
	# thanh công cụ
	for k in 5:
		var hid: String = Game.offhand if k == 4 else Game.hotbar[k]
		_hot_btns[k].icon = Items.icon(hid) if hid != "" else null
		_hot_btns[k].tooltip_text = ""
		_hot_btns[k].modulate = Color(1.25, 1.1, 0.8) if k == Game.hot_sel else Color.WHITE
	# túi
	for c in _bag_grid.get_children():
		c.queue_free()
	var ids := Game.inv.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return str(Items.get_def(a).get("cat", "")) + a < str(Items.get_def(b).get("cat", "")) + b)
	for id: String in ids:
		_bag_grid.add_child(_slot(id, Game.count(id), "bag"))
	for i in maxi(0, 14 - ids.size()):
		var empty := Panel.new()
		empty.custom_minimum_size = SLOT
		empty.modulate = Color(1, 1, 1, 0.25)
		_bag_grid.add_child(empty)
	# kho đồ chế độ thần
	_god_box.visible = Game.god
	if Game.god and _god_grid.get_child_count() == 0:
		for id: String in Items.defs:
			if not Items.get_def(id).has("quest"):
				_god_grid.add_child(_slot(id, 1, "god"))
	# trang bị
	for c in _equip_box.get_children():
		c.queue_free()
	for slot: String in ["head", "eyes", "body", "feet", "back", "wrist", "weapon"]:
		var b := Button.new()
		var id: String = Game.equip[slot]
		var default_name := {"body": "Áo sơ mi trắng", "feet": "Giày tây"}.get(slot, "—") as String
		b.text = "%s:  %s" % [SLOT_NAMES[slot], Items.item_name(id) if id != "" else default_name]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.icon = Items.icon(id) if id != "" else null
		b.expand_icon = true
		b.custom_minimum_size = Vector2(0, 38)
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = id == ""
		b.pressed.connect(Game.unequip.bind(slot))
		_equip_box.add_child(b)
	# tình trạng
	var lines := PackedStringArray()
	if Game.injuries.is_empty():
		lines.append("Không có vết thương.")
	for inj in Game.injuries:
		lines.append("• %s ở %s — cần %s" % [Game.INJURY_NAMES[inj.type], Game.PART_NAMES[inj.part].to_lower(), Game.INJURY_CURE[inj.type]])
	lines.append("")
	lines.append("Độ khó: %s" % Game.diff().name)
	lines.append("Tốc độ: %+d%%" % int((Game.speed_factor() - 1.0) * 100))
	lines.append("Khó bị thấy: %+d%%" % int(Game.stat("stealth") * 100))
	lines.append("Giảm sát thương: %d%%" % int(Game.stat("armor") * 100))
	lines.append("Bước chân êm: %d%%" % int(Game.stat("quiet") * 100))
	lines.append("Tàn nhẫn: %d/100" % int(Game.cruelty))
	lines.append("Quãng đường: %dm" % int(Game.distance))
	_status.text = "\n".join(lines)
	# nút chi tiết
	var has := selected != "" and selected_from == "bag" and Game.count(selected) > 0
	_use_btn.disabled = not has
	_drop_btn.disabled = not has or Items.get_def(selected).has("quest")
	if not has:
		_detail_icon.texture = null
		_detail_name.text = "Chưa chọn món nào"
		_detail_desc.text = "Nhấp một lần vào món trong túi để chọn. Rê chuột để xem thông tin."
		_detail_stats.text = ""
	if has:
		var d := Items.get_def(selected)
		_use_btn.text = "Mặc" if d.get("cat", "") == "gear" else ("Cầm" if d.has("weapon") or d.has("throwable") else "Dùng")
		_show_detail(selected, "bag")


func _take(id: String) -> void:
	if container_id < 0:
		return
	var d := Items.get_def(id)
	if _is_paid() and Game.money < int(d.get("p", 0)):
		Game.say("Không đủ tiền: %s giá %s đ." % [d.n, Game.format_money(int(d.p))], "bad")
		return
	if not Game.can_take(id) and not d.has("wallet") and not d.has("ammo"):
		Game.say("Túi quá nặng. Vứt bớt đồ hoặc tìm balo lớn hơn.", "bad")
		return
	world.loot.take(container_id, id)


func _take_all() -> void:
	for id: String in container_items.duplicate():
		_take(id)


func _use_selected() -> void:
	if selected != "" and Game.count(selected) > 0:
		Game.use_item(selected)
		_refresh()


func _drop_selected() -> void:
	if selected == "" or Game.count(selected) <= 0:
		return
	var p: CharacterBody3D = world.local_player()
	if p == null:
		return
	if Game.equip.weapon == selected and Game.count(selected) <= 1:
		Game.equip.weapon = ""
	Game.remove_item(selected)
	var fwd := -p.global_transform.basis.z
	world.loot.drop(selected, p.global_position + fwd * 0.9 + Vector3(0, 0.35, 0))
	Sfx.play("ui_click", -6.0)
	_refresh()
