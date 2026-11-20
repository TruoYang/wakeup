extends Node
## Mạng co-op: một người mở phòng (máy chủ), tối đa 4 người.
## Chơi đơn dùng chung code: coi như phòng chỉ có một người.

signal player_joined(id: int)
signal player_left(id: int)
signal players_changed
signal connection_failed
signal server_closed

enum Mode { SOLO, HOST, JOIN }

const PORT := 24680
const MAX_PLAYERS := 4

var mode := Mode.SOLO
var address := "127.0.0.1"
var my_name := "Người chơi"
## id -> tên. Máy chủ giữ bản gốc và gửi cho mọi người.
var players: Dictionary = {}
var last_error := ""


func _ready() -> void:
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func solo() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players = {1: my_name}
	players_changed.emit()


func host() -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS - 1)
	if err != OK:
		last_error = "Không mở được phòng (cổng %d đang bận?)." % PORT
		return err
	multiplayer.multiplayer_peer = peer
	players = {1: my_name}
	players_changed.emit()
	return OK


func join(addr: String) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(addr.strip_edges(), PORT)
	if err != OK:
		last_error = "Địa chỉ không hợp lệ."
		return err
	multiplayer.multiplayer_peer = peer
	players = {}
	return OK


func leave() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players = {}
	mode = Mode.SOLO


func is_online() -> bool:
	return mode != Mode.SOLO


## Các địa chỉ IPv4 của máy này (LAN, Radmin, Hamachi, Tailscale...) để đọc cho bạn bè.
func local_addresses() -> PackedStringArray:
	var out := PackedStringArray()
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
			out.append(a)
	return out


func _on_connected() -> void:
	_register.rpc_id(1, my_name)


func _on_connection_failed() -> void:
	last_error = "Không kết nối được tới phòng."
	leave()
	connection_failed.emit()


func _on_server_disconnected() -> void:
	last_error = "Chủ phòng đã đóng phòng."
	leave()
	server_closed.emit()


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	players.erase(id)
	_sync_players.rpc(players)
	players_changed.emit()
	player_left.emit(id)


@rpc("any_peer", "reliable")
func _register(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	players[id] = player_name.substr(0, 20)
	_sync_players.rpc(players)
	players_changed.emit()
	player_joined.emit(id)


@rpc("authority", "reliable")
func _sync_players(list: Dictionary) -> void:
	players = list
	players_changed.emit()
