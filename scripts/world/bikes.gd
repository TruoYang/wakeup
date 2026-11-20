extends Node3D
## Xe máy: lên xe (E), xuống xe (F). Nhanh nhưng rất ồn và tốn xăng.

var city: City
var world: Node
var list: Array[Dictionary] = []     # {node, pos, yaw, fuel, rider}


## wreck = xe hỏng: cháy đen, không lái được.
static func make_model(wreck := false) -> Node3D:
	var n := Node3D.new()
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.08, 0.09)
	dark.roughness = 0.6
	var body := StandardMaterial3D.new()
	body.albedo_color = Color(0.09, 0.08, 0.08) if wreck else Color(0.75, 0.12, 0.1)
	body.roughness = 0.9 if wreck else 0.35
	body.metallic = 0.0 if wreck else 0.3
	var chrome := StandardMaterial3D.new()
	chrome.albedo_color = Color(0.14, 0.12, 0.11) if wreck else Color(0.75, 0.76, 0.78)
	chrome.metallic = 0.2 if wreck else 0.9
	chrome.roughness = 0.25
	for wz: float in [-0.62, 0.62]:
		var w := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.3
		c.bottom_radius = 0.3
		c.height = 0.1
		c.radial_segments = 14
		c.material = dark
		w.mesh = c
		w.rotation.z = PI * 0.5
		w.position = Vector3(0, 0.3, wz)
		n.add_child(w)
	var parts := [
		[Vector3(0.24, 0.3, 0.9), Vector3(0, 0.55, 0.0), body],      # thân
		[Vector3(0.3, 0.1, 0.7), Vector3(0, 0.78, -0.12), dark],     # yên
		[Vector3(0.2, 0.34, 0.2), Vector3(0, 0.75, 0.45), body],     # cổ
		[Vector3(0.6, 0.05, 0.05), Vector3(0, 1.0, 0.5), chrome],    # tay lái
		[Vector3(0.07, 0.5, 0.07), Vector3(0, 0.55, 0.6), chrome],   # phuộc
		[Vector3(0.16, 0.14, 0.1), Vector3(0, 0.9, 0.62), chrome],   # đèn
		[Vector3(0.08, 0.08, 0.5), Vector3(0.14, 0.32, -0.5), chrome],   # ống xả
	]
	for p: Array in parts:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = p[0]
		b.material = p[2]
		mi.mesh = b
		mi.position = p[1]
		n.add_child(mi)
	return n


func setup(c: City, w: Node) -> void:
	city = c
	world = w
	var k := 0
	for b in c.bikes:
		var broken: bool = b.get("broken", false)
		var node := make_model(broken)
		node.position = b.pos
		add_child(node)
		if broken:
			# xe hỏng: nằm đổ, cháy đen, bốc khói hoặc còn cháy
			node.rotation = Vector3(0, b.yaw, 1.45)
			node.position.y += 0.18
			k += 1
			if k % 3 == 0:
				w.fx.burning(b.pos + Vector3(0, 0.4, 0))
			else:
				w.fx.smoke(b.pos + Vector3(0, 0.4, 0))
		else:
			# xe còn chạy được: dựng thẳng, đèn pha còn sáng
			node.rotation = Vector3(0, b.yaw, 0.12)
			var lamp := OmniLight3D.new()
			lamp.light_color = Color(1.0, 0.92, 0.7)
			lamp.light_energy = 0.9
			lamp.omni_range = 3.5
			lamp.position = Vector3(0, 0.9, 0.8)
			lamp.distance_fade_enabled = true
			lamp.distance_fade_begin = 40.0
			node.add_child(lamp)
			var glow := MeshInstance3D.new()
			var gm := SphereMesh.new()
			gm.radius = 0.07
			gm.height = 0.14
			var em := StandardMaterial3D.new()
			em.albedo_color = Color(1, 0.95, 0.7)
			em.emission_enabled = true
			em.emission = Color(1.0, 0.9, 0.6)
			em.emission_energy_multiplier = 4.0
			gm.material = em
			glow.mesh = gm
			glow.position = Vector3(0, 0.9, 0.68)
			node.add_child(glow)
		list.append({"node": node, "pos": b.pos, "yaw": b.yaw, "fuel": b.fuel, "rider": 0, "broken": broken})


func index_near(pos: Vector3, reach: float) -> int:
	for i in list.size():
		if list[i].rider == 0 and not list[i].broken and ((list[i].pos as Vector3) + Vector3(0, 0.6, 0)).distance_to(pos) < reach:
			return i
	return -1


func mount(idx: int) -> void:
	if multiplayer.is_server():
		_srv_mount(idx)
	else:
		_srv_mount.rpc_id(1, idx)


@rpc("any_peer", "reliable")
func _srv_mount(idx: int) -> void:
	if not multiplayer.is_server() or idx < 0 or idx >= list.size() or list[idx].rider != 0 or list[idx].broken:
		return
	var sender := multiplayer.get_remote_sender_id()
	_cl_mounted.rpc(idx, sender if sender != 0 else 1)


@rpc("authority", "reliable", "call_local")
func _cl_mounted(idx: int, pid: int) -> void:
	list[idx].rider = pid
	(list[idx].node as Node3D).visible = false
	if pid == multiplayer.get_unique_id():
		var p: CharacterBody3D = world.local_player()
		if p:
			p.start_riding(idx, float(list[idx].fuel))


func dismount(idx: int, pos: Vector3, yaw: float, fuel: float) -> void:
	if multiplayer.is_server():
		_srv_dismount(idx, pos, yaw, fuel)
	else:
		_srv_dismount.rpc_id(1, idx, pos, yaw, fuel)


@rpc("any_peer", "reliable")
func _srv_dismount(idx: int, pos: Vector3, yaw: float, fuel: float) -> void:
	if multiplayer.is_server() and idx >= 0 and idx < list.size():
		_cl_dismounted.rpc(idx, pos, yaw, clampf(fuel, 0.0, 100.0))


@rpc("authority", "reliable", "call_local")
func _cl_dismounted(idx: int, pos: Vector3, yaw: float, fuel: float) -> void:
	var b: Dictionary = list[idx]
	b.rider = 0
	b.pos = pos
	b.yaw = yaw
	b.fuel = fuel
	var n: Node3D = b.node
	n.visible = true
	n.position = pos
	n.rotation = Vector3(0, yaw, 0.12)


## Người rời phòng khi đang ngồi xe: trả xe lại chỗ cũ.
func release_rider(pid: int) -> void:
	for i in list.size():
		if list[i].rider == pid:
			_cl_dismounted.rpc(i, list[i].pos, list[i].yaw, list[i].fuel)


func sync_to(pid: int) -> void:
	for i in list.size():
		if list[i].broken:
			continue
		if list[i].rider != 0:
			_cl_mounted.rpc_id(pid, i, list[i].rider)
		else:
			_cl_dismounted.rpc_id(pid, i, list[i].pos, list[i].yaw, list[i].fuel)
