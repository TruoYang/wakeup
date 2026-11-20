extends Node
## Chụp ảnh nhiều cảnh để xem thử hình ảnh (dùng khi kiểm tra tự động).

var main: Node3D
var p: CharacterBody3D


func wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(file: String) -> void:
	await wait(3)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://%s.png" % file)
	print("shot ", file)


func view(pos: Vector3, look_at_pos: Vector3) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	var d := look_at_pos - (pos + Vector3(0, 1.6, 0))
	p.rotation.y = atan2(-d.x, -d.z)
	p.pitch = atan2(d.y, Vector2(d.x, d.z).length())
	p.head.rotation.x = p.pitch


func mon(kind: String) -> Monster:
	for m: Monster in main.monsters.list:
		if m.kind == kind:
			return m
	return null


func _ready() -> void:
	var only := ""
	for a in OS.get_cmdline_user_args():
		only = a
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if only.contains("ch2") or only == "people":
		Game.chapter = 2
		Game.carry = {}
		Net.mode = Net.Mode.SOLO
	main = (load("res://levels/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await wait(20)
	p = main.local_player()
	var city: City = main.city
	Game.god = true
	Game.fly = true
	main.hud.toasts.clear()
	var sets := {
		"office": func() -> void:
			Game.fly = false
			await wait(30)
			await shot("01_office"),
		"forest": func() -> void:
			var fr := City.zone_rect(City.FOREST_ZONE)
			view(Vector3(fr.position.x + 30.0, 0.3, fr.position.y + 34.0), Vector3(fr.get_center().x, 2.5, fr.get_center().y))
			await wait(40)
			await shot("21_forest"),
		"field": func() -> void:
			var pr := City.zone_rect(City.PARK_ZONE)
			view(Vector3(pr.end.x - 100.0, 14.0, pr.position.y - 6.0), Vector3(pr.end.x - 50.0, 0.0, pr.get_center().y))
			await wait(40)
			await shot("22_field"),
		"site": func() -> void:
			var cp := city.crane_pos
			view(cp + Vector3(-44.0, 1.0, 26.0), cp + Vector3(-6.0, 22.0, 0))
			await wait(40)
			await shot("23_site")
			view(cp + Vector3(-1.6, City.CRANE_H + 0.5, 0.5), cp + Vector3(-60.0, 10.0, -30.0))
			await wait(40)
			await shot("24_crane_top"),
		"slum": func() -> void:
			var hzr := City.zone_rect(City.HOODS[0])
			var sc := Vector3(hzr.get_center().x, 0, hzr.get_center().y)
			view(Vector3(sc.x, 105.0, sc.z + 45.0), Vector3(sc.x, 0.0, sc.z - 4.0))
			await wait(40)
			await shot("25_slum_above")
			var tro_n := 0
			for b0 in city.buildings:
				if b0.kind == "tro":
					tro_n += 1
			print("số dãy trọ: ", tro_n)
			for b in city.buildings:
				if b.kind == "tro":
					var dr: Vector3 = b.door
					var bo: Vector3 = b.origin
					var out := (dr - bo).normalized()
					var along := Vector3(out.z, 0, -out.x)
					view(bo + out * 5.5 + along * (float(b.w) * 0.5 + 1.0) + Vector3(0, 0.1, 0), bo - out * 2.0 + Vector3(0, 2.0, 0))
					break
			Game.fly = false
			await wait(40)
			await shot("26_slum_lane")
			Game.fly = true,
		"lakepark": func() -> void:
			var lz := City.zone_rect(City.LAKE_ZONE)
			view(Vector3(lz.position.x + 4.0, 12.0, lz.end.y + 4.0), Vector3(lz.get_center().x, 0.0, lz.get_center().y))
			await wait(40)
			await shot("27_lake_park"),
		"ride": func() -> void:
			Game.fly = false
			view(Vector3(City.road_x(5) + 3.0, 0.3, City.road_z(1) + 2.0), Vector3(City.road_x(5) + 60.0, 1.6, City.road_z(1) + 2.0))
			await wait(20)
			p.start_riding(0, 50.0)
			await wait(30)
			await shot("28_ride")
			p.riding = -1
			Game.fly = true,
		"crawler": func() -> void:
			var cr := mon("crawler")
			main.monsters.set_physics_process(false)
			p.fp_arms.visible = false
			var base := Vector3(City.road_x(5) + 7.5, 0.0, City.road_z(2) + 2.4)
			cr.global_position = base
			cr.yaw = 0.3
			cr.state = "chase"
			cr.speed_now = 4.0
			var c2 := Camera3D.new()
			add_child(c2)
			c2.global_position = base + Vector3(-4.5, 3.6, 3.0)
			c2.look_at(base + Vector3(0, 0.8, 0))
			c2.current = true
			main.hud.visible = false
			for i in 40:
				cr.visual_tick(0.016)
				await wait(1)
			await shot("29_crawler")
			for i in 13:
				cr.visual_tick(0.016)
				await wait(1)
			await shot("29b_crawler")
			c2.global_position = base + Vector3(0.5, 1.2, 5.0)
			c2.look_at(base + Vector3(0, 0.6, 0))
			await wait(3)
			await shot("29c_crawler_front")
			# dựng nghiêng bám tường (khi vào nhà): đo khối bao để biết có chạm trần không
			cr.wall_mode = true
			for i in 90:
				cr.visual_tick(0.016)
				await wait(1)
			var bb := AABB()
			var first := true
			for mi: Node in cr.find_children("*", "MeshInstance3D", true, false):
				var g := (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
				bb = g if first else bb.merge(g)
				first = false
			print("WALL top=%.2f bottom=%.2f width_x=%.2f width_z=%.2f" % [bb.end.y - base.y, bb.position.y - base.y, bb.size.x, bb.size.z])
			c2.global_position = base + Vector3(0.0, 1.6, 6.0)
			c2.look_at(base + Vector3(0, 1.4, 0))
			await wait(3)
			await shot("29d_crawler_wall")
			cr.wall_mode = false
			# ban đêm, chỉ có đèn pin
			main.weather.hour = 22.0
			main.weather.kind = "clear"
			for i in 60:
				main.weather._apply(0.2)
			p._set_flag(8, true)
			c2.global_position = base + Vector3(0.5, 1.4, 7.0)
			c2.look_at(base + Vector3(0, 1.0, 0))
			for i in 90:
				cr.visual_tick(0.016)
				await wait(1)
			await shot("29e_crawler_night")
			p._set_flag(8, false)
			main.weather.hour = 10.0
			for i in 60:
				main.weather._apply(0.2)
			# Thổ Trùng vọt lên
			var wm := mon("worm")
			var wp := base + Vector3(30.0, 0, 0)
			wm.event("erupt", [wp, wp + Vector3(28.0, 0, 0)])
			c2.global_position = wp + Vector3(14.0, 6.0, 40.0)
			c2.look_at(wp + Vector3(14.0, 8.0, 0))
			for i in 55:
				wm.visual_tick(0.016)
				await wait(1)
			await shot("30_worm_breach")
			c2.queue_free()
			p.camera.current = true
			main.hud.visible = true
			main.monsters.set_physics_process(true),
		"bigmap": func() -> void:
			Game.add_item("dongho")
			await shot("29_start_noguide")
			main.map_ui.open()
			await wait(10)
			await shot("30_map_noguide")
			main.map_ui.close()
			main.home_known = true
			Game.objective = "Về nhà, tìm vợ con"
			Game.fly = false
			await wait(30)
			await shot("31_start_guide")
			main.map_ui.open()
			await wait(10)
			await shot("32_map_guide")
			main.map_ui.zoom = 0.85
			main.map_ui.center = Vector2((p.global_position.x + main.city.home_pos.x) * 0.5, (p.global_position.z + main.city.home_pos.z) * 0.5)
			await wait(5)
			await shot("33_map_guide_all")
			main.map_ui.close(),
		"ch2bunker": func() -> void:
			var sh: Node3D = main.shelter
			Game.fly = false
			sh.ui.close_all()
			sh.food = 7
			sh.water = 8
			sh.meds.khangsinh = 2
			sh.apply_fx({"guest": {"id": "muc", "name": "Con Mực", "kind": "dog"}})
			view(sh.origin + Vector3(2.4, 0.1, 2.2), sh.origin + Vector3(-1.6, 1.0, -1.8))
			await wait(60)
			await shot("40_bunker")
			view(sh.origin + Vector3(-2.6, 0.1, -2.0), sh.origin + Vector3(3.0, 1.0, 0.6))
			await wait(30)
			await shot("41_bunker_shelf")
			sh.ack_journal()
			sh.open_event("ong_tu_gia", "night")
			sh.choose(0)
			await wait(10)
			await shot("42_event")
			sh.ui.close_all()
			sh.current_id = ""
			sh.phase = "day"
			sh.ui.show_rations()
			await wait(10)
			await shot("43_rations")
			sh.ui.close_all(),
		"ch2fight": func() -> void:
			var sh: Node3D = main.shelter
			Game.fly = false
			sh.ui.close_all()
			sh.ack_journal()
			main.dialogue.visible = false
			sh.machine = {"state": "placed", "pos": sh.origin + sh.STAND, "carrier": 0}
			sh._sync_story_nodes()
			main.monsters.spawn_robbers(sh.origin + Vector3(2.4, 0.15, 2.0), 3, 0.6, true)
			view(sh.origin + Vector3(-2.2, 0.1, -2.4), sh.origin + Vector3(2.4, 1.0, 2.0))
			await wait(40)
			await shot("48_bunker_robbers")
			view(sh.origin + Vector3(0.6, 0.1, 1.2), sh.origin + sh.STAND + Vector3(0, 0.6, 0))
			await wait(20)
			await shot("49_signal_machine"),
		"ch2tower": func() -> void:
			var sh: Node3D = main.shelter
			Game.fly = false
			sh.ui.close_all()
			sh.ack_journal()
			main.dialogue.visible = false
			sh.phase = "choose"
			sh.go_out()
			main.hud.toasts.clear()
			await wait(30)
			var te: Monster = mon("towereye")
			var tp: Vector3 = main.city.tower_pos
			view(tp + Vector3(30.0, 0.3, 26.0), tp + Vector3(0, 26.0, 0))
			await wait(180)
			await shot("50_tower_night")
			Game.fly = true
			view(tp + Vector3(38.0, 22.0, 46.0), tp + Vector3(4.0, 0.0, 4.0))
			await wait(10)
			await shot("51_tower_beam")
			Game.fly = false
			Game.god = false
			view(tp + Vector3(10.0, 0.3, 8.0), tp + Vector3(10.0, 6.0, 0.0))
			te.tents[0].st = 2
			te.tents[0].holder = 1
			te.tents[0].base_y = City.BASE
			te.tents[0].t = 3.0
			te.tents[0].g = Vector3(tp.x + 10.0, 0, tp.z + 8.0)
			p.set_third_person(true)
			await wait(60)
			await shot("52_tower_grab")
			# cận cảnh thân Quỷ Mắt: các hốc, mắt trong hốc, xúc tu
			var te2: Node3D = mon("towereye")
			var c4 := Camera3D.new()
			add_child(c4)
			c4.global_position = te2.global_position + Vector3(14.0, -6.0, 16.0)
			c4.look_at(te2.global_position + Vector3(0, -2.0, 0))
			c4.current = true
			main.hud.visible = false
			p.fp_arms.visible = false
			await wait(10)
			await shot("52b_tower_body")
			c4.global_position = te2.global_position + Vector3(6.0, -22.0, 22.0)
			c4.look_at(te2.global_position + Vector3(0, -24.0, 0))
			await wait(6)
			await shot("52c_tower_tentacles"),
		"people": func() -> void:
			var sh: Node3D = main.shelter
			Game.fly = false
			sh.ui.close_all()
			sh.ack_journal()
			main.dialogue.visible = false
			main.hud.visible = false
			view(sh.origin + Vector3(0.2, 0.1, 1.0), sh.origin + Vector3(-0.6, 1.2, -1.6))
			await wait(40)
			var mai: Node3D = sh._people["mai"]
			var fw: Vector3 = mai.global_transform.basis.z
			view(mai.global_position + fw * 1.1 + Vector3(0, -0.15, 0), mai.global_position + Vector3(0, 1.35, 0))
			await wait(10)
			await shot("53_people_close")
			var na: Node3D = sh._people["na"]
			var fw2: Vector3 = na.global_transform.basis.z
			var c2 := Camera3D.new()
			add_child(c2)
			c2.global_position = na.global_position + fw2 * 2.1 + Vector3(0, 0.75, 0)
			c2.look_at(na.global_position + Vector3(0, 0.62, 0))
			c2.current = true
			main.hud.visible = false
			await wait(10)
			await shot("53b_na")
			c2.global_position = na.global_position + fw2.rotated(Vector3.UP, 0.8) * 2.1 + Vector3(0, 0.75, 0)
			c2.look_at(na.global_position + Vector3(0, 0.62, 0))
			await wait(3)
			await shot("53c_na_side")
			c2.queue_free()
			p.camera.current = true
			main.hud.visible = true
			var rb: Monster = mon("robber")
			main.monsters.spawn_robbers(sh.origin + Vector3(1.0, 0.15, 0.6), 1, 0.1, true)
			rb.set_physics_process(false)
			main.monsters.set_physics_process(false)
			rb.visible = true
			rb.state = "fight"
			await wait(5)
			var rf: Vector3 = rb.global_transform.basis.z
			view(rb.global_position + rf * 1.3 + Vector3(0, -0.1, 0), rb.global_position + Vector3(0, 1.2, 0))
			await wait(10)
			await shot("55_robber_close")
			for i in 24:
				rb.body.animate(1.0 / 60.0, 4.0, false, false)
				await wait(1)
			await shot("55b_robber_walk")
			for i in 30:
				rb.body.animate(1.0 / 60.0, 0.0, true, false)
				await wait(1)
			await shot("55c_robber_crouch")
			view(sh.origin + Vector3(1.6, 0.1, 2.2), sh.origin + Vector3(-1.5, 0.9, -0.6))
			await wait(20)
			await shot("54_people_room")
			main.hud.visible = true,
		"ch2hands": func() -> void:
			var sh: Node3D = main.shelter
			Game.fly = false
			sh.ui.close_all()
			sh.ack_journal()
			sh.phase = "choose"
			sh.go_out()
			main.hud.toasts.clear()
			await wait(30)
			for i in 60:
				if main.dialogue.active:
					main.dialogue.advance()
				await wait(2)
			sh.ui.close_all()
			view(Vector3(City.road_x(12) + 1.0, 0.3, City.road_z(5) + 8.0), Vector3(City.road_x(12) + 1.0, 1.4, City.road_z(5) + 60.0))
			Game.offhand = ""
			Game.add_item("denpin", 1, true)
			Game.assign_hot(0, "denpin")
			Game.select_hot(0)
			p._set_flag(8, true)
			await wait(30)
			print("DBG ui_open=", main.ui_open(), " energy=", p.light.light_energy)
			await shot("56_hand_flashlight_right")
			Game.add_item("gaysat", 1, true)
			Game.assign_hot(1, "gaysat")
			Game.select_hot(1)
			Game.offhand = "denpin"
			Game.inventory_changed.emit()
			await wait(30)
			await shot("57_hand_flashlight_left_bar")
			Game.assign_hot(2, "")
			Game.select_hot(2)
			Game.offhand = ""
			Game.inventory_changed.emit()
			p._set_flag(8, false)
			await wait(30)
			await shot("58_hands_empty"),
		"ch2nv": func() -> void:
			var sh: Node3D = main.shelter
			Game.fly = false
			sh.ui.close_all()
			sh.ack_journal()
			sh.phase = "choose"
			sh.go_out()
			await wait(30)
			for i in 60:
				if main.dialogue.active:
					main.dialogue.advance()
				await wait(2)
			sh.ui.close_all()
			main.hud.toasts.clear()
			p._set_flag(8, false)
			view(Vector3(City.road_x(12) + 1.0, 0.3, City.road_z(5) + 8.0), Vector3(City.road_x(12) + 1.0, 1.4, City.road_z(5) + 60.0))
			await wait(20)
			await shot("59_nv_off")
			Game.equip["eyes"] = "kinhdem"
			Game.nv_on = true
			await wait(30)
			await shot("60_nv_on")
			Game.nv_on = false
			Game.fly = true
			var hosp := Vector3.ZERO
			for lm: Dictionary in main.city.landmarks:
				if lm.name == "BỆNH VIỆN":
					hosp = lm.pos
			view(hosp + Vector3(30.0, 18.0, 40.0), hosp + Vector3(0, 3.0, 0))
			await wait(30)
			await shot("61_hospital_night_light")
			var tp: Vector3 = main.city.tower_pos
			view(tp + Vector3(90.0, 30.0, 110.0), tp + Vector3(0, 40.0, 0))
			for i in 120:
				await wait(1)
				if Time.get_ticks_msec() % 1600 < 300:
					break
			await shot("62_tower_far_blink"),
		"ch2pipe": func() -> void:
			var sh: Node3D = main.shelter
			Game.fly = false
			sh.ui.close_all()
			sh.ack_journal()
			for i in 60:
				if main.dialogue.active:
					main.dialogue.advance()
				await wait(2)
			sh.phase = "choose"
			sh.go_out()
			sh.pipe_broken = true
			main.weather.blackout = false
			main.weather.hour = 15.0
			await wait(30)
			main.hud.toasts.clear()
			p.fp_arms.visible = false
			var c2 := Camera3D.new()
			add_child(c2)
			c2.global_position = sh.exit_pos + Vector3(1.6, 1.9, 2.4)
			c2.look_at(sh.exit_pos + Vector3(0, 0.1, 0))
			c2.current = true
			main.hud.visible = false
			await wait(20)
			await shot("70_hatch_inside_home")
			c2.global_position = sh.pipe_pos + Vector3(2.8, 1.8, 2.8)
			c2.look_at(sh.pipe_pos + Vector3(0, 0.6, 0))
			await wait(20)
			await shot("71_broken_pipe")
			c2.global_position = sh.exit_pos + Vector3(-6.0, 12.0, 9.0)
			c2.look_at(sh.exit_pos + Vector3(0, 0, -2.0))
			await wait(10)
			await shot("72_home_ruin_above")
			c2.queue_free()
			p.camera.current = true
			main.hud.visible = true,
		"ch2night": func() -> void:
			var sh: Node3D = main.shelter
			Game.fly = false
			sh.ui.close_all()
			sh.phase = "choose"
			sh.go_out()
			main.hud.toasts.clear()
			await wait(90)
			view(Vector3(City.road_x(12) + 2.0, 0.3, City.road_z(5) + 1.0), Vector3(City.road_x(12) + 60.0, 2.0, City.road_z(5) + 1.0))
			await wait(60)
			await shot("44_night_moon_street")
			view(Vector3(City.road_x(12) + 1.0, 0.3, City.road_z(5) + 8.0), Vector3(City.road_x(12) + 1.0, 2.0, City.road_z(5) + 60.0))
			await wait(60)
			await shot("45_night_dark_street")
			p._set_flag(8, true)
			await wait(40)
			await shot("46_night_flashlight")
			var site: Dictionary = sh._sites[0]
			for s2: Dictionary in sh._sites:
				if s2.id == "o_dot_lua":
					site = s2
			sh._sites.map(func(x: Dictionary) -> void: x.done = true)
			view((site.pos as Vector3) + Vector3(9.0, 0.3, 4.0), (site.pos as Vector3) + Vector3(0, 1.0, 0))
			await wait(60)
			await shot("47_night_site"),
		"drops": func() -> void:
			Game.fly = false
			var base := Vector3(City.road_x(5) + 3.0, 0.3, City.road_z(1) + 2.0)
			var ids := ["banphim", "nuocsuoi", "mitom", "socuu", "xabeng", "balophuot", "mubaohiem", "giaythethao", "chao", "sungtruong", "canxang", "banhchung", "khangsinh", "ongtuyp"]
			for i in ids.size():
				main.loot.drop(ids[i], base + Vector3(1.6 + (i % 7) * 0.75, 0.3, -1.2 + (i / 7) * 1.3))
			await wait(20)
			view(base + Vector3(0.2, 0.0, 2.2), base + Vector3(4.0, 0.2, -0.6))
			await wait(40)
			await shot("48_drops"),
		"cutscene": func() -> void:
			Engine.time_scale = 0.02
			main._apply_stage(3, true)
			await get_tree().create_timer(1.2 / 0.02, true, false, true).timeout
			await shot("50_cut_before")
			await get_tree().create_timer(5.2 / 0.02 - 60.0, true, false, true).timeout
			await shot("51_cut_collapse")
			await get_tree().create_timer(1.6 / 0.02, true, false, true).timeout
			await shot("52_cut_after")
			Engine.time_scale = 1.0,
		"dialogue": func() -> void:
			Game.fly = false
			var wi := -1
			for i in main.npcs.list.size():
				if main.npcs.list[i].kind == "wife":
					wi = i
			var wp: Vector3 = main.npcs.list[wi].pos
			view(wp + Vector3(1.6, 0.05, 1.2), wp + Vector3(0, 1.45, 0))
			await wait(40)
			main._talk_family(wi)
			main.dialogue.advance()
			main.dialogue.advance()
			await get_tree().create_timer(2.6).timeout
			await shot("60_dialogue")
			while main.dialogue.active:
				main.dialogue.advance()
			Game.fly = true,
		"lake2": func() -> void:
			var lz := city.lake_rect
			var lc := lz.get_center()
			view(Vector3(lc.x - 10.0, 55.0, lz.end.y + 40.0), Vector3(lc.x, 0.0, lc.y))
			await wait(50)
			await shot("70_lake_air")
			var isl := city.island.get_center()
			Game.fly = false
			view(Vector3(isl.x - 2.0, City.BASE + 0.1, lz.end.y - 3.0), Vector3(isl.x + 2.0, 2.5, isl.y))
			await wait(50)
			await shot("71_lake_bridge")
			Game.fly = true,
		"closedrow": func() -> void:
			Game.fly = false
			for b in city.buildings:
				if b.kind == "closed" and not b.has("yaw") and float(b.s) > 0.0 and int(b.floors) >= 3:
					var dr: Vector3 = b.door
					view(dr + Vector3(-9.0, 0.1, 9.0), dr + Vector3(6.0, 2.5, 0.0))
					break
			await wait(50)
			await shot("72_closed_row")
			Game.fly = true,
		"hoodair": func() -> void:
			var hz := City.zone_rect(City.HOODS[6])
			view(Vector3(hz.get_center().x - 20.0, 70.0, hz.end.y + 50.0), Vector3(hz.get_center().x, 0.0, hz.get_center().y))
			await wait(50)
			await shot("73_hood_air"),
		"rail": func() -> void:
			var rl: Rail = city.rail
			var st: Dictionary = rl.stations[2]
			var f: Dictionary = rl.frame(st.s)
			var c: Vector3 = f.p
			var t: Vector3 = f.t
			var n: Vector3 = f.n * float(st.side)
			Game.fly = false
			view(c + n * 16.0 - t * 30.0 + Vector3(0, City.BASE + 0.1, 0), c + Vector3(0, 9.0, 0))
			await wait(50)
			await shot("80_station_street")
			view(c + n * 6.2 + t * 2.0 + Vector3(0, Rail.DECK_Y + 0.7, 0), c + t * 40.0 + Vector3(0, Rail.DECK_Y + 1.0, 0))
			await wait(50)
			await shot("81_platform")
			var tr: Dictionary = rl.trains[1]
			var ft: Dictionary = rl.frame(float(tr.s) - 22.0)
			view((ft.p as Vector3) - (ft.n as Vector3) * 2.0 + Vector3(0, Rail.DECK_Y + 0.4, 0), (rl.frame(float(tr.s) + 10.0).p as Vector3) + Vector3(0, Rail.DECK_Y + 2.0, 0))
			await wait(50)
			await shot("82_train")
			var g: Vector2 = rl.gaps[0]
			var fg: Dictionary = rl.frame(g.x - 12.0)
			view((fg.p as Vector3) + Vector3(0, Rail.DECK_Y + 0.4, 0), (rl.frame(g.y + 20.0).p as Vector3) + Vector3(0, Rail.DECK_Y - 4.0, 0))
			await wait(50)
			await shot("83_gap")
			Game.fly = true
			var corner: Dictionary = rl.frame(rl.stations[3].s + 150.0)
			view((corner.p as Vector3) + Vector3(-60.0, 70.0, -40.0), (corner.p as Vector3) + Vector3(0, 8.0, 30.0))
			await wait(50)
			await shot("84_rail_air"),
		"landmarks": func() -> void:
			var names := {}
			for lm: Dictionary in city.landmarks:
				names[str(lm.name)] = lm.pos
			var shots := [["BỆNH VIỆN", Vector3(0.0, 55.0, -75.0), "90_hospital"], ["TRƯỜNG HỌC", Vector3(-20.0, 26.0, 60.0), "91_school"],
				["ĐẠI SIÊU THỊ", Vector3(10.0, 40.0, 95.0), "92_bigsuper"], ["TRẠM PHÁT SÓNG", Vector3(30.0, 22.0, 60.0), "93_radio"], ["BIỆT PHỦ", Vector3(0.0, 40.0, 70.0), "94_mansion"]]
			for sh: Array in shots:
				var lp: Vector3 = names.get(sh[0], Vector3.ZERO)
				view(lp + (sh[1] as Vector3), lp + Vector3(0, 8.0 if sh[0] != "TRẠM PHÁT SÓNG" else 20.0, 0))
				await wait(50)
				await shot(sh[2])
			Game.fly = false
			p.fp_arms.visible = false
			# bên trong đại siêu thị: tầng trệt nhìn về giếng thang cuốn, rồi tầng 2
			var sp: Vector3 = names["ĐẠI SIÊU THỊ"]
			var sb: Dictionary = {}
			for bd: Dictionary in city.buildings:
				if bd.kind == "super" and bd.get("landmark", false):
					sb = bd
			view(city._to_world(sb, Vector3(-4.0, 0.2, -20.0)), city._to_world(sb, Vector3(-12.0, 3.0, -40.0)))
			await wait(70)
			await shot("95_bigsuper_inside")
			Game.fly = true
			view(city._to_world(sb, Vector3(0.0, 7.4, -30.0)), city._to_world(sb, Vector3(-12.0, 9.0, -50.0)))
			await wait(70)
			await shot("95b_bigsuper_floor2")
			Game.fly = false
			# bệnh viện: hành lang và phòng bệnh trong toà cánh
			for bd2: Dictionary in city.buildings:
				if bd2.kind == "hospital" and bd2.get("part", "") == "wing":
					view(city._to_world(bd2, Vector3(0.0, 3.8, -3.0)), city._to_world(bd2, Vector3(0.0, 5.0, -18.0)))
					await wait(60)
					await shot("97_hospital_corridor")
					view(city._to_world(bd2, Vector3(-1.2, 3.8, -4.0)), city._to_world(bd2, Vector3(-7.0, 4.6, -6.0)))
					await wait(40)
					await shot("98_hospital_room")
					break
			# biệt phủ: hành lang tầng 2
			for bd3: Dictionary in city.buildings:
				if bd3.kind == "mansion":
					view(city._to_world(bd3, Vector3(-15.0, 3.9, -14.0)), city._to_world(bd3, Vector3(10.0, 5.2, -14.0)))
					await wait(60)
					await shot("99_mansion_inside")
					break
			# trạm nghiên cứu bên trong
			var rp: Vector3 = city.radio_pos
			view(rp + Vector3(0, 0.1, 8.5), rp + Vector3(0, 1.5, -5.0))
			await wait(50)
			await shot("93b_radio_inside")
			Game.fly = true,
		"street": func() -> void:
			view(Vector3(City.road_x(2) - 20.0, 0.3, City.road_z(1) + 3.0), Vector3(City.road_x(2) + 40.0, 6.0, City.road_z(1)))
			await wait(40)
			await shot("02_street"),
		"commerce": func() -> void:
			var cc := City.block_center(3, 0)
			view(Vector3(City.road_x(3), 26.0, City.road_z(1) + 2.0), Vector3(cc.x + 6.0, 10.0, cc.z))
			await wait(40)
			await shot("18_commerce"),
		"lane": func() -> void:
			var lc2 := City.block_center(6, 1)
			view(Vector3(lc2.x - 6.0, 46.0, lc2.z + 30.0), Vector3(lc2.x, 0.0, lc2.z))
			await wait(40)
			await shot("19_lane_above")
			view(Vector3(lc2.x - City.BW * 0.5 + 3.0, City.BASE + 0.1, lc2.z + 1.0), Vector3(lc2.x, 1.6, lc2.z))
			Game.fly = false
			await wait(40)
			await shot("20_lane_walk")
			Game.fly = true,
		"lake": func() -> void:
			var lc := city.lake_rect.get_center()
			view(Vector3(lc.x - 30.0, 3.5, lc.y - 20.0), Vector3(lc.x, 0.0, lc.y))
			await wait(40)
			await shot("03_lake"),
		"under": func() -> void:
			var lc := city.lake_rect.get_center()
			view(Vector3(lc.x - 6.0, -3.6, lc.y), Vector3(lc.x + 10.0, -3.0, lc.y + 4.0))
			Game.submerged = true
			await wait(30)
			await shot("04_underwater"),
		"shop": func() -> void:
			for b in city.buildings:
				if b.kind == "shop" and b.shop == "grocery":
					var o: Vector3 = b.origin
					var s: float = b.s
					view(Vector3(o.x, o.y + 0.05, o.z + s * 7.0), Vector3(o.x, 2.2, o.z))
					await wait(30)
					await shot("05_shop_front")
					Game.fly = false
					view(Vector3(o.x, o.y + 0.05, o.z - s * 1.2), Vector3(o.x + s * 1.5, 1.2, o.z - s * 6.0))
					await wait(60)
					await shot("06_shop_inside")
					# trỏ thẳng vào một món trên kệ: phải có viền sáng và nhãn "Nhặt / Mua"
					var best: Dictionary = {}
					var bd := 1e9
					for cid: int in main.loot.shown:
						for e: Dictionary in main.loot.shown[cid]:
							var d: float = (e.node as Node3D).global_position.distance_to(p.global_position)
							if d < bd and d > 1.2:
								bd = d
								best = e
					if not best.is_empty():
						var ip: Vector3 = (best.node as Node3D).global_position
						var stand := ip + (p.global_position - ip).normalized() * 1.3
						stand.y = o.y + 0.05
						view(stand, ip + Vector3(0, 0.07, 0))
						await wait(30)
						await shot("06b_shop_pick")
					Game.fly = true
					break,
		"titan": func() -> void:
			var t := mon("titan")
			main.play_time = 40.0
			for i in 700:
				if main.dialogue.active:
					main.dialogue.advance()
				await get_tree().physics_frame
			view(city.road_project(t.global_position + t.forward() * 120.0) + Vector3(0, 6.0, 0), t.global_position + Vector3(0, 34.0, 0))
			await wait(30)
			await shot("07_titan")
			# nhìn ngang từ vỉa hè: chân có đặt lên mặt đường, có xuyên vào nhà hai bên không
			var ct := Camera3D.new()
			add_child(ct)
			ct.far = 900.0
			main.hud.visible = false
			p.fp_arms.visible = false
			for k in 3:
				for i2 in 240:
					if main.dialogue.active:
						main.dialogue.advance()
					await get_tree().physics_frame
				var sidev: Vector3 = t.forward().cross(Vector3.UP).normalized()
				ct.global_position = t.global_position - t.forward() * 60.0 + sidev * 30.0 + Vector3(0, 26.0, 0)
				ct.look_at(t.global_position + Vector3(0, 14.0, 0))
				ct.current = true
				await wait(4)
				await shot("07b_titan_legs_%d" % k),
		"stalker": func() -> void:
			var st := mon("stalker")
			st.set_physics_process(false)
			main.monsters.set_physics_process(false)
			st.mover.global_position = Vector3(City.road_x(3), 0.2, City.road_z(1))
			st.global_position = st.mover.global_position
			for i in 30:
				st.visual_tick(0.016)
			view(st.global_position + Vector3(11.0, -0.2, 14.0), st.global_position + Vector3(0, 3.6, 0))
			await wait(20)
			for i in 10:
				st.visual_tick(0.016)
			await shot("08_stalker"),
		"grub": func() -> void:
			var g := mon("grub")
			var mid: Vector3 = g.segs[6].global_position
			view(city.road_project(g.global_position + g.forward() * 34.0) + Vector3(0, 3.0, 0), mid)
			await wait(30)
			await shot("09_grub"),
		"flyer": func() -> void:
			var f := mon("flyer")
			view(f.global_position + Vector3(9.0, -6.0, 12.0), f.global_position)
			await wait(10)
			await shot("10_flyer"),
		"stairs": func() -> void:
			for b in city.buildings:
				if b.kind == "house" and b.floors >= 3 and b.s > 0.0 and not b.has("yaw"):
					var o: Vector3 = b.origin
					view(Vector3(o.x - 1.2, o.y + 0.05, o.z - 3.0), Vector3(o.x + 1.6, 3.2, o.z - 11.0))
					await wait(30)
					await shot("15_stairs")
					main.weather.kind = "storm"
					for i in 80:
						main.weather._apply(0.2)
					view(Vector3(o.x + 0.3, o.y + 0.05, o.z - 5.0), Vector3(o.x - 1.0, 1.6, o.z + 4.0))
					await wait(140)
					await shot("16_rain_from_inside")
					break,
		"swing": func() -> void:
			# các pha của cú đánh: tay không (đấm) và cầm gậy (vụt). Đóng băng nhịp giảm _swing để chụp đúng pha.
			Game.fly = false
			main.hud.visible = false
			view(Vector3(City.road_x(5) + 2.0, 0.3, City.road_z(2) + 2.0), Vector3(City.road_x(5) + 2.0, 1.4, City.road_z(2) - 30.0))
			for wpn: String in ["", "gaysat"]:
				if wpn != "":
					Game.add_item(wpn, 1, true)
					Game.assign_hot(1, wpn)
					Game.select_hot(1)
					Game.inventory_changed.emit()
				await wait(20)
				for ph: float in [0.0, 0.22, 0.42, 0.7]:
					p._swing = 1.0 - ph
					p.set_process(false)
					p.set_physics_process(false)
					p._update_hands(0.0)
					await wait(2)
					await shot("60_swing_%s_%02d" % [wpn if wpn != "" else "fist", int(ph * 100)])
					p.set_process(true)
					p.set_physics_process(true),
		"lineup": func() -> void:
			# xếp hàng các nhân vật low-poly để duyệt: người chơi, Mai, bé Na, kẻ cướp, đồng nghiệp nam, đồng nghiệp nữ
			var base := Vector3(City.road_x(5) + 2.0, 0.2, City.road_z(2) + 2.0)
			var cfg := [
				{"long": true, "shirt": Color("e9e4d8"), "pants": Color("3a4350"), "shoe": Color("34302e")},
				{"female": true, "shirt": Color("d77a8c"), "pants": Color("34343e"), "shoe": Color("8a6a58")},
				{"female": true, "child": true, "shirt": Color("f2d23a"), "pants": Color("4f7fb8"), "shoe": Color("c8323a")},
				{"hood": true, "long": true, "shirt": Color("2c3a30"), "pants": Color(0.15, 0.15, 0.17), "shoe": Color("2a2624")},
				{"long": true, "shirt": Color("b8c8e8"), "pants": Color("3a3a40"), "shoe": Color("2c2a2a")},
				{"female": true, "shirt": Color("dfe3ea"), "pants": Color("3a3a40"), "shoe": Color("2c2a2a")},
			]
			var hs: Array = []
			for i in cfg.size():
				var c: Dictionary = cfg[i]
				var h := LowPolyHumanoid.new()
				h.female = c.get("female", false)
				h.child = c.get("child", false)
				if c.get("hood", false):
					h.hair_style = "hood"
				h.sleeves = "long" if c.get("long", false) else "short"
				h.shoe_color = c.shoe
				h.roll_cuffs = h.child
				if h.child:
					h.hem_color = Color("e9a62a")
				add_child(h)
				h.setup(c.shirt, c.pants, Color("e0b08a"))
				h.scale = Vector3.ONE * (0.72 if h.child else 1.0)
				h.global_position = base + Vector3(i * 1.1, 0, 0)
				hs.append(h)
			var c3 := Camera3D.new()
			add_child(c3)
			c3.global_position = base + Vector3(2.75, 1.3, 5.6)
			c3.look_at(base + Vector3(2.75, 0.95, 0))
			c3.current = true
			main.hud.visible = false
			p.fp_arms.visible = false
			for k in 20:
				for h2: LowPolyHumanoid in hs:
					h2.animate(0.016, 0.0, false, false)
				await wait(1)
			await shot("59_lineup")
			for k in 24:
				for h2: LowPolyHumanoid in hs:
					h2.animate(0.016, 3.0, false, false)
				await wait(1)
			await shot("59b_lineup_walk"),
		"night": func() -> void:
			main.weather.hour = 21.5
			main.weather.kind = "rain"
			for i in 60:
				main.weather._apply(0.2)
			view(Vector3(City.road_x(2) - 20.0, 0.3, City.road_z(1) + 3.0), Vector3(City.road_x(2) + 40.0, 6.0, City.road_z(1)))
			p._set_flag(8, true)
			await wait(60)
			await shot("11_night_rain"),
		"ui": func() -> void:
			Game.god = false
			Game.fly = false
			Game.add_item("banhmi", 2, true)
			Game.add_item("bang", 1, true)
			Game.add_item("chao", 1, true)
			Game.add_item("aokhoac", 1, true)
			Game.add_item("dongho", 1, true)
			Game.say("Chủ tiệm bỏ chạy khỏi cửa hàng!")
			Game.say("Đã đeo Đồng hồ định vị. Quái vật giờ hiện trên bản đồ.", "good")
			await wait(5)
			await shot("17_hud")
			Game.use_item("chao")
			Game.damage(20.0, "slash", "arm_l")
			Game.damage(22.0, "crush", "leg_r")
			main.inv_ui.open_bag()
			await wait(10)
			await shot("12_inventory")
			main.inv_ui.close()
			main.map_ui.open()
			await wait(10)
			await shot("13_map")
			main.map_ui.close()
			main.pause_ui.open()
			get_tree().paused = false
			await wait(10)
			await shot("14_pause")
			main.pause_ui.close(),
	}
	for k: String in sets:
		if only == "" or only.split(",").has(k):
			await sets[k].call()
	get_tree().quit()
