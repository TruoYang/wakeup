extends Monster
## Quỷ Mắt: một khối thịt bám trên tháp phát sóng (chỉ thức dậy ở Chương 2). Thả xuống nhiều xúc tu, đầu mỗi xúc tu
## là một con mắt rọi đèn xuống sân trạm, quét qua quét lại.
## - Nó chỉ thấy thứ ĐANG CHUYỂN ĐỘNG trong vệt sáng: đứng im hoặc ngồi im thì vệt sáng lướt qua mà không thấy.
##   Vác máy phát tín hiệu (máy kêu bíp) hoặc bật đèn pin thì đứng im cũng bị thấy. Mái nhà, tường che được.
## - Thấy rồi thì con mắt bám theo; đuổi kịp thì quấn lấy người, nhấc lên khỏi mặt đất và siết dần.
##   Người bị quấn làm rơi máy đang vác. Đập vào xúc tu đủ số lần (hoặc bắn) thì nó nhả ra, rụt lên tháp,
##   một lúc sau mới thả xuống lại. Đồng đội đập/bắn cũng được.
## - Chơi một mình: ít xúc tu hơn, quét chậm hơn, vệt sáng nhỏ hơn, phải nhìn lâu hơn mới chắc, đuổi chậm hơn, siết nhẹ hơn.

const BODY_H := 44.0
const EYE_UP := 9.0           # mắt treo cao hơn vệt sáng trên mặt đất
const LIFT := 2.4             # nhấc người lên cao chừng này (rơi xuống không bị thương)
const ST_SWEEP := 0
const ST_TRACK := 1
const ST_GRAB := 2
const ST_RETRACT := 3

var awake := false
## Mỗi xúc tu: {g: điểm vệt sáng trên đất, st, holder, grip (số cú đập còn lại), t (đồng hồ trạng thái),
## a (cảnh giác 0..1), who (người đang bị nhìn), base_y (độ cao mặt đất chỗ quấn), ph: pha quét}
var tents: Array = []
var _hurt_t := 0.0
var _anchor := Vector3.ZERO

# hình ảnh
var _body: Node3D
var _tvis: Array = []          # mỗi xúc tu: {segs: [MeshInstance3D], eye: Node3D, light: SpotLight3D, g: Vector3 (vị trí hiển thị)}
var _mat_flesh: Material
var _held_by_me := false
var _drape: Array = []          # các xúc tu không mắt quấn quanh tháp (chỉ để nhìn)
var _hinted := false
var _pit_eyes: Array = []        # mắt nhỏ trong các hốc trên thân
var _blink: Array = []          # mỗi xúc tu: [mí trên, mí dưới, thời điểm chớp tới]


func solo() -> bool:
	return mgr.world.online_peers() == 0


func n_tents() -> int:
	return 4 if solo() else 7


func spot_r() -> float:
	return 4.6 if solo() else 6.2


func sweep_r() -> float:
	return 34.0 if solo() else 42.0


func build() -> void:
	mname = "Quỷ Mắt"
	state = "dormant"
	visible = false
	# thịt sẫm đỏ tía, hơi phát sáng (như có mạch máu dưới da) để ban đêm vẫn nhìn ra hình thù
	# thịt loang lổ tím bầm, mạch máu đỏ nổi, ướt nhớt; hơi phát sáng để ban đêm còn nhìn ra hình thù
	_mat_flesh = MonsterMesh.flesh(Color("4a2232"), Color("7a3848"), Color("c02838"), {"bump": 0.9, "wetness": 0.75, "vein_amount": 0.75, "scale": 0.22, "pulse": 0.03, "glow": 0.18})
	var mat_vein := StandardMaterial3D.new()
	mat_vein.albedo_color = Color("a0303a")
	mat_vein.emission_enabled = true
	mat_vein.emission = Color("c0303a")
	mat_vein.emission_energy_multiplier = 1.2
	_body = Node3D.new()
	add_child(_body)
	# khối thịt lớn ôm lấy thân tháp (bề ngang gần 20m)
	var lumps := [[Vector3.ZERO, 7.5], [Vector3(5.5, 3.0, 2.0), 5.0], [Vector3(-5.0, -2.0, 3.0), 5.5], [Vector3(1.0, -5.5, -3.5), 4.8],
		[Vector3(-2.5, 5.0, -3.0), 4.4], [Vector3(4.0, -3.5, 4.5), 4.0], [Vector3(-6.0, 2.5, -2.0), 3.8], [Vector3(2.0, 6.5, 2.5), 3.4]]
	for l: Array in lumps:
		var mi := MeshInstance3D.new()
		mi.mesh = MonsterMesh.blob(Vector3.ONE * float(l[1]), 300 + int(l[1] * 10.0), 0.14, 0.35)     # u bướu sần sùi
		mi.material_override = _mat_flesh
		mi.position = l[0]
		_body.add_child(mi)
	# mạch máu đỏ nổi trên da
	var vr := RandomNumberGenerator.new()
	vr.seed = 77
	for v in 18:
		var vm := MeshInstance3D.new()
		var cm0 := CylinderMesh.new()
		cm0.top_radius = 0.18
		cm0.bottom_radius = 0.25
		cm0.height = vr.randf_range(4.0, 8.0)
		cm0.radial_segments = 6
		vm.mesh = cm0
		vm.material_override = mat_vein
		var dir := Vector3(vr.randf_range(-1, 1), vr.randf_range(-1, 1), vr.randf_range(-1, 1)).normalized()
		vm.position = dir * 7.2
		vm.rotation = Vector3(vr.randf() * TAU, vr.randf() * TAU, 0)
		_body.add_child(vm)
	# HỐC: hàng chục lỗ sâu hoắm lỗ chỗ trên da (miệng hốc đen ngòm, viền thịt sưng tấy), vài hốc có mắt nhỏ bên trong
	var hole_mat := StandardMaterial3D.new()
	hole_mat.albedo_color = Color(0.05, 0.0, 0.01)
	hole_mat.roughness = 0.2
	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = Color("5e2232")
	rim_mat.roughness = 0.35
	rim_mat.emission_enabled = true
	rim_mat.emission = Color("6a1a28")
	rim_mat.emission_energy_multiplier = 0.15
	var hr := RandomNumberGenerator.new()
	hr.seed = 913
	for hidx in 120:
		var lp: Array = lumps[hr.randi() % lumps.size()]
		var dn := Vector3(hr.randf_range(-1, 1), hr.randf_range(-1, 0.7), hr.randf_range(-1, 1)).normalized()
		var rr: float = float(lp[1])
		var rh := hr.randf_range(0.5, 1.25) * (1.0 if hidx % 5 != 0 else 1.7)
		var hole_root := Node3D.new()
		hole_root.position = (lp[0] as Vector3) + dn * rr * 0.985
		hole_root.quaternion = Quaternion(Vector3.UP, dn)
		_body.add_child(hole_root)
		var pit := MeshInstance3D.new()
		var pc := CylinderMesh.new()
		pc.top_radius = rh
		pc.bottom_radius = rh * 0.35
		pc.height = rh * 1.6
		pc.radial_segments = 9
		pc.cap_top = false
		pit.mesh = pc
		pit.material_override = hole_mat
		pit.position = Vector3(0, -rh * 0.75, 0)
		hole_root.add_child(pit)
		var rim := MeshInstance3D.new()
		var tm2 := TorusMesh.new()
		tm2.inner_radius = rh * 0.96
		tm2.outer_radius = rh * 1.3
		tm2.rings = 10
		tm2.ring_segments = 6
		rim.mesh = tm2
		rim.material_override = rim_mat
		rim.scale = Vector3(1.0, 0.5, 1.0)
		hole_root.add_child(rim)
		if hidx % 9 == 4:
			# mắt nhỏ nằm sâu trong hốc, đảo qua đảo lại
			var pe := _make_eye(rh * 0.6, false)
			pe.position = Vector3(0, -rh * 0.35, 0)
			pe.rotation = Vector3(-PI * 0.5, 0, 0)
			hole_root.add_child(pe)
			_pit_eyes.append(pe)
	# nhiều con mắt mọc trên thân, nhìn đủ mọi hướng
	var body_eyes := [[Vector3(0, -2.0, 7.0), 2.6], [Vector3(5.5, 0.5, 5.0), 1.6], [Vector3(-5.5, -1.5, 5.5), 1.8], [Vector3(-3.0, -5.5, 4.5), 1.2],
		[Vector3(6.5, -2.5, -2.5), 1.5], [Vector3(-7.0, 1.0, -2.0), 1.4], [Vector3(1.5, 4.0, 6.0), 1.1], [Vector3(0.5, -4.0, -6.5), 1.7]]
	for be: Array in body_eyes:
		var ey := _make_eye(be[1])
		ey.position = be[0]
		_body.add_child(ey)
		ey.look_at_from_position(be[0], (be[0] as Vector3) * 2.0 + Vector3(0, -6.0, 0), Vector3.UP)
	# xúc tu không có mắt: quấn quanh thân tháp, rủ xuống, đung đưa
	for j in 10:
		var dsegs: Array = []
		for k2 in 14:
			var dseg := MeshInstance3D.new()
			var dcm := CylinderMesh.new()
			dcm.top_radius = lerpf(1.3, 0.25, k2 / 13.0)
			dcm.bottom_radius = lerpf(1.3, 0.25, (k2 + 1) / 13.0)
			dcm.height = 1.0
			dcm.radial_segments = 8
			dseg.mesh = dcm
			dseg.material_override = _mat_flesh
			dseg.top_level = true
			add_child(dseg)
			dsegs.append(dseg)
		_drape.append(dsegs)
	for i in 7:
		tents.append({"g": Vector3.ZERO, "st": ST_SWEEP, "holder": 0, "grip": 0, "t": 0.0, "a": 0.0, "who": 0, "base_y": 0.0, "ph": i * 1.37})
		var segs: Array = []
		for k in 16:
			var seg := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = lerpf(1.9, 0.5, k / 15.0)
			cm.bottom_radius = lerpf(1.9, 0.5, (k + 1) / 15.0)
			cm.height = 1.0
			cm.radial_segments = 8
			seg.mesh = cm
			seg.material_override = _mat_flesh
			seg.top_level = true
			add_child(seg)
			segs.append(seg)
		var eye := _make_eye(1.15, true)
		eye.top_level = true
		add_child(eye)
		var light := SpotLight3D.new()
		light.light_color = Color(1.0, 0.86, 0.72)
		light.light_energy = 9.0
		light.spot_range = 22.0
		light.spot_attenuation = 0.4
		light.shadow_enabled = false
		eye.add_child(light)
		# khúc cuối quấn quanh người: một đoạn thõng xuống từ mắt và ba vòng cuộn
		var coil := Node3D.new()
		coil.top_level = true
		coil.visible = false
		add_child(coil)
		var drop := MeshInstance3D.new()
		var dm := CylinderMesh.new()
		dm.top_radius = 0.32
		dm.bottom_radius = 0.26
		dm.height = 1.8
		drop.mesh = dm
		drop.material_override = _mat_flesh
		drop.position = Vector3(0.0, 1.95, 0.0)
		coil.add_child(drop)
		for r in 3:
			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.3
			tm.outer_radius = 0.56
			ring.mesh = tm
			ring.material_override = _mat_flesh
			ring.position = Vector3(0.0, 0.25 + r * 0.42, 0.0)
			ring.rotation = Vector3(0.18 * (1 if r % 2 == 0 else -1), r * 0.9, 0.12)
			coil.add_child(ring)
		# vệt sáng nhìn thấy được: hình nón mờ từ mắt xuống và vòng sáng trên mặt đất
		var cone := MeshInstance3D.new()
		var cn := CylinderMesh.new()
		cn.top_radius = 0.35
		cn.bottom_radius = 1.0
		cn.height = 1.0
		cn.radial_segments = 20
		cn.cap_top = false
		cn.cap_bottom = false
		cone.mesh = cn
		cone.material_override = _beam_mat(0.07)
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cone.top_level = true
		add_child(cone)
		var disc := MeshInstance3D.new()
		var dc := CylinderMesh.new()
		dc.top_radius = 1.0
		dc.bottom_radius = 1.0
		dc.height = 0.04
		dc.radial_segments = 28
		disc.mesh = dc
		disc.material_override = _beam_mat(0.22)
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		disc.top_level = true
		add_child(disc)
		_tvis.append({"segs": segs, "eye": eye, "light": light, "g": Vector3.ZERO, "coil": coil, "cone": cone, "disc": disc})


func _beam_mat(alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(1.0, 0.85, 0.6, alpha)
	m.no_depth_test = false
	return m


## Một con mắt: lòng trắng ngả vàng có mạch máu, tròng hổ phách, con ngươi dọc như mắt thú (nhìn theo trục -Z).
## `pod`: mắt ở đầu xúc tu, nằm trong một bọc thịt có mí trên mí dưới (chớp được) thay vì một quả cầu trơn như bóng đèn.
func _make_eye(r: float, pod := false) -> Node3D:
	var root := Node3D.new()
	var white := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	white.mesh = sm
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.78, 0.62, 0.5)
	wm.roughness = 0.08
	wm.emission_enabled = true
	wm.emission = Color(0.42, 0.3, 0.2)
	wm.emission_energy_multiplier = 0.6
	white.material_override = wm
	root.add_child(white)
	var iris := MeshInstance3D.new()
	var im := SphereMesh.new()
	im.radius = r * 0.55
	im.height = r * 1.1
	iris.mesh = im
	var irm := StandardMaterial3D.new()
	irm.albedo_color = Color(0.75, 0.48, 0.08)
	irm.roughness = 0.1
	irm.emission_enabled = true
	irm.emission = Color(0.7, 0.35, 0.05)
	irm.emission_energy_multiplier = 0.9
	iris.material_override = irm
	iris.position = Vector3(0, 0, -r * 0.78)
	iris.scale = Vector3(1.0, 1.0, 0.45)
	root.add_child(iris)
	var pupil := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(r * 0.16, r * 0.8, r * 0.1)
	pupil.mesh = pm
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.01, 0.0, 0.0)
	pmat.roughness = 0.05
	pupil.material_override = pmat
	pupil.position = Vector3(0, 0, -r * 1.02)
	root.add_child(pupil)
	if pod:
		# bọc thịt phía sau con mắt (nối với xúc tu), mí trên và mí dưới phủ hờ
		var back := MeshInstance3D.new()
		back.mesh = MonsterMesh.blob(Vector3(r * 1.45, r * 1.35, r * 1.5), 61, 0.25, 0.5, 0.6)
		back.material_override = _mat_flesh
		back.position = Vector3(0, 0, r * 0.55)
		root.add_child(back)
		var lids: Array = []
		for up: float in [1.0, -1.0]:
			var lid := Node3D.new()
			root.add_child(lid)
			var lm := MeshInstance3D.new()
			var ls := SphereMesh.new()
			ls.radius = r * 1.08
			ls.height = r * 2.16
			ls.is_hemisphere = true
			lm.mesh = ls
			lm.material_override = _mat_flesh
			lm.rotation = Vector3(0.0 if up > 0.0 else PI, 0, 0)
			lid.add_child(lm)
			lid.set_meta("up", up)
			lids.append(lid)
		root.set_meta("lids", lids)
	return root


func _ground_y() -> float:
	return City.BASE


## Điểm vệt sáng của xúc tu i khi đang quét: lượn vòng quanh chân tháp, lúc xa lúc gần.
func _sweep_point(i: int, t: float) -> Vector3:
	var ph: float = tents[i].ph
	var w := 0.11 if solo() else 0.17
	var a := ph * 2.3 + t * w * (1.0 if i % 2 == 0 else -1.0)
	var r := sweep_r() * (0.3 + 0.7 * absf(sin(t * w * 0.71 + ph)))
	return city.tower_pos + Vector3(cos(a) * r, 0.0, sin(a) * r) + Vector3(6.0, 0.0, 3.0)


func eye_pos(i: int) -> Vector3:
	var tt: Dictionary = tents[i]
	var g: Vector3 = tt.g
	match int(tt.st):
		ST_GRAB:
			return Vector3(g.x, float(tt.base_y) + LIFT + 3.2, g.z)
		ST_RETRACT:
			return Vector3(g.x, _ground_y() + EYE_UP + minf(1.0, float(tt.t) / 3.0) * 26.0, g.z)
		ST_TRACK:
			return g + Vector3(0, _ground_y() + EYE_UP - 2.5, 0)
	return g + Vector3(0, _ground_y() + EYE_UP, 0)


func active() -> bool:
	return awake


func hunting() -> bool:
	for i in n_tents():
		if int(tents[i].st) in [ST_TRACK, ST_GRAB]:
			return true
	return false


## Chỉ chỗ xúc tu đang quấn người mới đánh trúng được.
func hit_spheres() -> Array:
	var out := []
	for i in n_tents():
		var tt: Dictionary = tents[i]
		if int(tt.st) == ST_GRAB:
			var g: Vector3 = tt.g
			out.append([Vector3(g.x, float(tt.base_y) + LIFT + 1.2, g.z), 1.4])
			out.append([Vector3(g.x, float(tt.base_y) + LIFT + 3.0, g.z), 1.0])
	return out


func _grab_near(attacker: int) -> int:
	var best := -1
	var best_d := 1e9
	var ap: Node3D = mgr.player_by_id(attacker)
	for i in n_tents():
		var tt: Dictionary = tents[i]
		if int(tt.st) != ST_GRAB:
			continue
		if int(tt.holder) == attacker:
			return i
		var d: float = (tt.g as Vector3).distance_to(ap.global_position) if ap else 0.0
		if d < best_d:
			best_d = d
			best = i
	return best


func on_melee(attacker: int, stun: float, power: float) -> void:
	var i := _grab_near(attacker)
	if i < 0:
		return
	tents[i].grip = int(tents[i].grip) - (2 if stun * power >= 1.6 else 1)
	mgr.fire(self, "hurt", i)
	if int(tents[i].grip) <= 0:
		_release(i)


func on_shot(attacker: int) -> void:
	var i := _grab_near(attacker)
	if i < 0:
		return
	tents[i].grip = int(tents[i].grip) - 2
	mgr.fire(self, "hurt", i)
	if int(tents[i].grip) <= 0:
		_release(i)


func _release(i: int) -> void:
	var tt: Dictionary = tents[i]
	tt.st = ST_RETRACT
	tt.t = 0.0
	tt.holder = 0
	tt.a = 0.0
	tt.who = 0
	mgr.fire(self, "release", i)


func heard(_pos: Vector3, _loud: float, _source: String) -> void:
	pass


## Người này có đang "chuyển động" trong mắt Quỷ Mắt không (đi lại, vác máy kêu bíp, bật đèn).
func _moving(p: Node3D) -> bool:
	if float(p.net_speed) > 1.0:
		return true
	if (int(p.net_flags) & 8) != 0:
		return true
	var sh: Node = mgr.world.shelter
	if sh and str(sh.machine.get("state", "")) == "carried" and int(sh.machine.get("carrier", 0)) == p.get_multiplayer_authority():
		return true
	return false


func _held(pid: int) -> bool:
	for i in n_tents():
		if int(tents[i].st) == ST_GRAB and int(tents[i].holder) == pid:
			return true
	return false


func server_tick(delta: float) -> void:
	var sh: Node = mgr.world.shelter
	var want: bool = mgr.world.play_time > 2.0 or (sh != null and sh.active)      # cả chương 1 lẫn chương 2
	if want != awake:
		awake = want
		state = "watch" if awake else "dormant"
		if awake:
			global_position = city.tower_pos + Vector3(0, BODY_H, 0)
			for i in tents.size():
				tents[i].g = _sweep_point(i, 0.0)
				tents[i].st = ST_SWEEP
				tents[i].holder = 0
	if not awake:
		return
	_t_all += delta
	var n := n_tents()
	var see_time := 1.6 if solo() else 0.8
	var chase := 4.4 if solo() else 6.0
	var ps: Array = mgr.players()
	aw.clear()
	for i in tents.size():
		var tt: Dictionary = tents[i]
		if i >= n:
			tt.st = ST_RETRACT
			tt.holder = 0
			continue
		tt.t = float(tt.t) + delta
		match int(tt.st):
			ST_SWEEP:
				var sp := _sweep_point(i, _t_all)
				tt.g = (tt.g as Vector3).move_toward(sp, delta * 9.0)
				# ai đang chuyển động trong vệt sáng?
				var seen: Node3D = null
				for p: Node3D in ps:
					var pid: int = p.get_multiplayer_authority()
					if _held(pid):
						continue
					var d := Vector2(p.global_position.x - tt.g.x, p.global_position.z - tt.g.z).length()
					if d < spot_r() and _moving(p) and mgr.clear_line(eye_pos(i), p.global_position + Vector3(0, 1.0, 0)):
						seen = p
				if seen:
					var spid: int = seen.get_multiplayer_authority()
					if int(tt.who) != spid:
						tt.who = spid
						tt.a = 0.0
					tt.a = float(tt.a) + delta / see_time
					aw[spid] = maxf(float(aw.get(spid, 0.0)), float(tt.a))
					sense = "see"
					if float(tt.a) >= 1.0:
						tt.st = ST_TRACK
						tt.t = 0.0
						target_id = spid
						mgr.fire(self, "spot", i)
				else:
					tt.a = maxf(0.0, float(tt.a) - delta * 0.5)
			ST_TRACK:
				var p2: Node3D = mgr.player_by_id(int(tt.who))
				var lost := p2 == null or (int(p2.net_flags) & (4 | 16)) != 0 or _held(int(tt.who))
				if not lost:
					aw[int(tt.who)] = 1.0
					var tgt := Vector3(p2.global_position.x, 0.0, p2.global_position.z)
					tt.g = (tt.g as Vector3).move_toward(tgt, delta * chase)
					var vis: bool = mgr.clear_line(eye_pos(i), p2.global_position + Vector3(0, 1.0, 0))
					tt.a = 1.0 if vis else float(tt.a) - delta / 3.0       # khuất 3 giây (vào nhà) thì mất dấu
					if float(tt.a) <= 0.0 or tgt.distance_to(city.tower_pos) > sweep_r() + 30.0:
						lost = true
					elif Vector2(tgt.x - tt.g.x, tgt.z - tt.g.z).length() < 1.2 and vis:
						tt.st = ST_GRAB
						tt.t = 0.0
						tt.holder = int(tt.who)
						tt.grip = 3 if solo() else 4
						tt.base_y = p2.global_position.y
						tt.g = tgt
						mgr.fire(self, "grab", i)
				if lost:
					tt.st = ST_SWEEP
					tt.a = 0.0
					tt.who = 0
			ST_GRAB:
				var hp: Node3D = mgr.player_by_id(int(tt.holder))
				if hp == null or (int(hp.net_flags) & 4) != 0:
					_release(i)
					continue
				aw[int(tt.holder)] = 1.0
			ST_RETRACT:
				if float(tt.t) > (30.0 if solo() else 22.0):
					tt.st = ST_SWEEP
					tt.t = 0.0
	# siết người đang bị quấn
	_hurt_t -= delta
	if _hurt_t <= 0.0:
		_hurt_t = 1.0
		for i2 in n:
			if int(tents[i2].st) == ST_GRAB:
				var hp2: Node3D = mgr.player_by_id(int(tents[i2].holder))
				if hp2:
					mgr.hurt(hp2, 3.5 if solo() else 5.0, "crush", "torso")


var _t_all := 0.0


func extra() -> Variant:
	var tl := []
	for tt: Dictionary in tents:
		tl.append([tt.g, tt.st, tt.holder, tt.base_y, tt.t, tt.a])
	return [awake, tl]


func set_extra(v: Variant) -> void:
	awake = bool(v[0])
	for i in mini(tents.size(), (v[1] as Array).size()):
		var e: Array = v[1][i]
		var tt: Dictionary = tents[i]
		tt.g = e[0]
		tt.st = int(e[1])
		tt.holder = int(e[2])
		tt.base_y = float(e[3])
		tt.t = float(e[4])
		tt.a = float(e[5])


func event(ev: String, arg: Variant) -> void:
	match ev:
		"spot":
			var e: Vector3 = (_tvis[int(arg)].eye as Node3D).global_position
			Sfx.play_at("titan_groan", e, 2.0, 50.0, 1.6)
		"grab":
			var e2: Vector3 = (_tvis[int(arg)].eye as Node3D).global_position
			Sfx.play_at("titan_roar", e2, 0.0, 60.0, 1.8)
			mgr.shake_from(e2, 0.35, 30.0, 2.0)
		"hurt":
			var e3: Vector3 = (_tvis[int(arg)].eye as Node3D).global_position
			Sfx.play_at("hit", e3, 2.0, 20.0, 0.7)
		"release":
			var e4: Vector3 = (_tvis[int(arg)].eye as Node3D).global_position
			Sfx.play_at("titan_groan", e4, 2.0, 50.0, 1.3)


func visual_tick(delta: float) -> void:
	visible = awake
	# người chơi trên máy này có đang bị quấn không
	var me := multiplayer.get_unique_id()
	var held := -1
	if awake:
		for i in n_tents():
			if int(tents[i].st) == ST_GRAB and int(tents[i].holder) == me:
				held = i
	if held >= 0:
		var tt: Dictionary = tents[held]
		var lift := minf(1.0, float(tt.t) / 1.5) * LIFT
		Game.grab_pos = Vector3((tt.g as Vector3).x, float(tt.base_y) + lift, (tt.g as Vector3).z)
		if not _held_by_me:
			_held_by_me = true
			Game.grabbed = true
			if Game.carrying != "":
				mgr.world.drop_carry()
			Game.say("Xúc tu quấn lấy bạn! Đập vào nó (chuột trái) để thoát!", "bad")
	elif _held_by_me:
		_held_by_me = false
		Game.grabbed = false
		Game.say("Nó nhả ra rồi! Chạy vào chỗ có mái che!", "good")
	if not awake:
		return
	# ở xa (quá 320m) thì không cập nhật hình (hàng trăm khúc xúc tu, đèn rọi): ẩn hẳn cho nhẹ máy
	var cam := get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_to(city.tower_pos) > 320.0:
		visible = false
		return
	if not _hinted:
		var lp: Node3D = mgr.player_by_id(me)
		if lp and lp.global_position.distance_to(city.tower_pos) < sweep_r() + 25.0:
			_hinted = true
			Game.say("Những con mắt trên tháp rọi đèn quét khắp sân. Chúng chỉ thấy thứ đang chuyển động: vệt sáng lướt tới thì đứng im. Vác máy kêu bíp hay bật đèn pin thì đứng im cũng vô ích.", "bad")
	var tsec := Time.get_ticks_msec() * 0.001
	_body.rotation = Vector3(sin(tsec * 0.4) * 0.05, tsec * 0.05, cos(tsec * 0.33) * 0.05)
	_body.scale = Vector3.ONE * (1.0 + sin(tsec * 1.3) * 0.03)
	var anchor := global_position + Vector3(0, -5.0, 0)
	# xúc tu không mắt: từ thân vòng xuống quanh chân tháp rồi buông thõng, đung đưa chậm
	for j in _drape.size():
		var ang := j * TAU / _drape.size() + sin(tsec * 0.2 + j) * 0.15
		var r0 := global_position + Vector3(cos(ang), -0.3, sin(ang)) * 6.0
		var tip := city.tower_pos + Vector3(cos(ang + 0.9) * (6.0 + (j % 3) * 3.0), 6.0 + (j % 4) * 5.0 + sin(tsec * 0.6 + j * 1.7) * 2.0, sin(ang + 0.9) * (6.0 + (j % 3) * 3.0))
		var c1 := (r0 + tip) * 0.5 + Vector3(cos(ang - 0.7), 0, sin(ang - 0.7)) * (9.0 + sin(tsec * 0.45 + j) * 2.0) + Vector3(0, -4.0, 0)
		var prev2 := r0
		var dsegs: Array = _drape[j]
		for k3 in dsegs.size():
			var t3 := float(k3 + 1) / dsegs.size()
			var p3 := r0.lerp(c1, t3).lerp(c1.lerp(tip, t3), t3)
			p3 += Vector3(cos(ang + 1.57), 0, sin(ang + 1.57)) * sin(t3 * 8.0 - tsec * 1.4 + j * 2.1) * 1.1 * t3
			var dseg: MeshInstance3D = dsegs[k3]
			var d3 := p3 - prev2
			var ln3 := maxf(0.05, d3.length())
			dseg.global_position = (prev2 + p3) * 0.5
			var up3 := d3 / ln3
			var side3 := up3.cross(Vector3.FORWARD if absf(up3.z) < 0.9 else Vector3.RIGHT).normalized()
			dseg.global_transform.basis = Basis(side3, up3 * (ln3 * 1.1), side3.cross(up3))
			prev2 = p3
	# mắt trong hốc: đảo qua đảo lại, mỗi con một nhịp
	for pi in _pit_eyes.size():
		var pe: Node3D = _pit_eyes[pi]
		pe.rotation = Vector3(-PI * 0.5 + sin(tsec * 0.9 + pi * 2.1) * 0.5, cos(tsec * 0.7 + pi) * 0.5, 0)
	for i in _tvis.size():
		var tv: Dictionary = _tvis[i]
		var on := i < n_tents()
		# mí mắt: mở hờ, thỉnh thoảng chớp (nhắm nhanh rồi mở); đang đuổi / quấn người thì trợn to
		var lids: Array = (tv.eye as Node3D).get_meta("lids", [])
		var bl := fmod(tsec * (0.23 + i * 0.03) + i * 0.37, 1.0)
		var shut := clampf(1.0 - absf(bl - 0.5) * 22.0, 0.0, 1.0)
		var wide := 1.25 if int(tents[i].st) in [ST_TRACK, ST_GRAB] else 0.85
		for lid: Node3D in lids:
			lid.rotation.x = float(lid.get_meta("up")) * wide * (1.0 - shut)
		(tv.eye as Node3D).visible = on
		(tv.cone as Node3D).visible = on
		(tv.disc as Node3D).visible = on
		(tv.coil as Node3D).visible = on and (tv.coil as Node3D).visible
		for seg: MeshInstance3D in tv.segs:
			seg.visible = on
		if not on:
			continue
		var target := eye_pos(i)
		tv.g = (tv.g as Vector3).lerp(target, minf(1.0, delta * 6.0)) if (tv.g as Vector3) != Vector3.ZERO else target
		var e: Vector3 = tv.g
		# xúc tu: đường cong từ thân xuống mắt, võng ra ngoài, lượn nhẹ
		var root := anchor + Vector3(cos(i * 0.9), 0, sin(i * 0.9)) * 5.0
		var mid := (root + e) * 0.5
		var out := Vector3(e.x - root.x, 0, e.z - root.z).normalized() * 9.0
		var ctrl := mid + out + Vector3(sin(tsec * 0.9 + i) * 2.0, 4.0, cos(tsec * 0.7 + i) * 2.0)
		var wig := Vector3(e.z - root.z, 0, root.x - e.x).normalized()
		var prev := root
		var segs: Array = tv.segs
		for k in segs.size():
			var t := float(k + 1) / segs.size()
			var p := root.lerp(ctrl, t).lerp(ctrl.lerp(e, t), t)
			# uốn lượn như xúc tu bạch tuộc: sóng chạy dọc thân, mạnh ở giữa, êm ở hai đầu
			p += wig * (sin(t * 9.0 - tsec * 2.3 + i * 1.3) * 1.6 * sin(t * PI))
			p.y += cos(t * 7.0 - tsec * 1.9 + i) * 0.9 * sin(t * PI)
			var seg: MeshInstance3D = segs[k]
			var d := p - prev
			var ln := maxf(0.05, d.length())
			seg.global_position = (prev + p) * 0.5
			var up := d / ln
			var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
			seg.global_transform.basis = Basis(side, up * (ln * 1.08), side.cross(up))
			prev = p
		# con mắt nhìn xuống chỗ vệt sáng / người bị quấn
		var eye: Node3D = tv.eye
		eye.global_position = e
		var look := Vector3(tents[i].g.x, _ground_y(), tents[i].g.z)
		if int(tents[i].st) == ST_GRAB:
			look = Vector3(tents[i].g.x, float(tents[i].base_y) + LIFT + 1.0, tents[i].g.z)
		if int(tents[i].st) == ST_RETRACT:
			look = e + Vector3(0, -1, 0.01)
		if e.distance_to(look) > 0.1:
			eye.look_at(look, Vector3.UP if absf((look - e).normalized().y) < 0.98 else Vector3.FORWARD)
		var coil: Node3D = tv.coil
		coil.visible = int(tents[i].st) == ST_GRAB
		if coil.visible:
			var lift := minf(1.0, float(tents[i].t) / 1.5) * LIFT
			coil.global_position = Vector3(tents[i].g.x, float(tents[i].base_y) + lift + 0.75, tents[i].g.z)
		var light: SpotLight3D = tv.light
		light.visible = int(tents[i].st) != ST_RETRACT
		var h := maxf(1.0, e.distance_to(look))
		light.spot_range = h + 6.0
		light.spot_angle = rad_to_deg(atan(spot_r() / h))
		# ánh nhìn như phát quang sinh học: vàng xanh bệnh hoạn khi quét, đỏ khi đã thấy
		light.light_color = Color(0.86, 0.95, 0.62) if int(tents[i].st) == ST_SWEEP else Color(1.0, 0.3, 0.22)
		var beam_on := int(tents[i].st) in [ST_SWEEP, ST_TRACK]
		var cone: MeshInstance3D = tv.cone
		var disc: MeshInstance3D = tv.disc
		cone.visible = false          # không vẽ hình nón ánh sáng (trông như cái đèn); chỉ còn ánh rọi trên mặt đất
		disc.visible = beam_on
		if beam_on:
			var ground := Vector3(look.x, _ground_y() + 0.05, look.z)
			var dv := e - ground
			var hh := maxf(0.5, dv.length())
			var upv := dv / hh
			var sidev := upv.cross(Vector3.FORWARD if absf(upv.z) < 0.9 else Vector3.RIGHT).normalized()
			cone.global_transform = Transform3D(Basis(sidev * spot_r(), upv * hh, sidev.cross(upv) * spot_r()), (e + ground) * 0.5)
			disc.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3(spot_r(), 1.0, spot_r())), ground)
			var col := Color(0.85, 0.9, 0.55) if int(tents[i].st) == ST_SWEEP else Color(1.0, 0.3, 0.22)
			(cone.material_override as StandardMaterial3D).albedo_color = Color(col, 0.07)
			(disc.material_override as StandardMaterial3D).albedo_color = Color(col, 0.04 + 0.3 * float(tents[i].a))
