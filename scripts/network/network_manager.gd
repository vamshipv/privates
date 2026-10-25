extends Node

signal player_connected(peer_id: int, player_info: Dictionary)
signal player_disconnected(peer_id: int)
signal server_disconnected
signal chat_message_received(sender_name: String, message: String, peer_id: int)

const DEFAULT_PORT: int = 7777
const MAX_CLIENTS: int = 16

var peer: ENetMultiplayerPeer = null
var local_username: String = "Homie"
var local_player_color: Color = Color(0.2, 0.6, 1.0)
var players: Dictionary = {} # peer_id -> { "name": String, "color": Color }

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host_game(port: int = DEFAULT_PORT, username: String = "Host") -> Error:
	local_username = username.strip_edges()
	if local_username.is_empty():
		local_username = "Host"
	local_player_color = Color.from_hsv(randf(), 0.7, 0.95)
	
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, MAX_CLIENTS)
	if error != OK:
		push_error("Failed to create server on port %d: %s" % [port, error])
		return error
	
	multiplayer.multiplayer_peer = peer
	players[1] = {
		"name": local_username,
		"color": local_player_color
	}
	player_connected.emit(1, players[1])
	print("[Network] Hosting game on port %d as '%s'" % [port, local_username])
	return OK

func join_game(address: String = "127.0.0.1", port: int = DEFAULT_PORT, username: String = "Guest") -> Error:
	local_username = username.strip_edges()
	if local_username.is_empty():
		local_username = "Guest_" + str(randi() % 999)
	local_player_color = Color.from_hsv(randf(), 0.7, 0.95)
	
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, port)
	if error != OK:
		push_error("Failed to connect to %s:%d: %s" % [address, port, error])
		return error
	
	multiplayer.multiplayer_peer = peer
	print("[Network] Connecting to %s:%d as '%s'..." % [address, port, local_username])
	return OK

func disconnect_game() -> void:
	if peer:
		peer.close()
		peer = null
	multiplayer.multiplayer_peer = null
	players.clear()

func _on_peer_connected(id: int) -> void:
	print("[Network] Peer connected: %d" % id)
	if multiplayer.is_server():
		# Send current players dictionary to the newly joined peer
		_sync_players.rpc_id(id, players)

func _on_peer_disconnected(id: int) -> void:
	print("[Network] Peer disconnected: %d" % id)
	if players.has(id):
		players.erase(id)
	player_disconnected.emit(id)

func _on_connected_to_server() -> void:
	var my_id = multiplayer.get_unique_id()
	print("[Network] Connected to server successfully! My ID: %d" % my_id)
	_register_player.rpc_id(1, local_username, local_player_color)

func _on_connection_failed() -> void:
	push_error("[Network] Failed to connect to server.")
	disconnect_game()

func _on_server_disconnected() -> void:
	print("[Network] Server disconnected.")
	disconnect_game()
	server_disconnected.emit()

@rpc("any_peer", "call_remote", "reliable")
func _register_player(username: String, color: Color) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	players[sender_id] = {
		"name": username,
		"color": color
	}
	# Broadcast updated roster to all peers
	_sync_players.rpc(players)
	player_connected.emit(sender_id, players[sender_id])

@rpc("authority", "call_remote", "reliable")
func _sync_players(roster: Dictionary) -> void:
	players = roster
	for pid in players:
		player_connected.emit(pid, players[pid])

func send_chat(message: String) -> void:
	var msg = message.strip_edges()
	if msg.is_empty():
		return
	var my_id = multiplayer.get_unique_id()
	_receive_chat.rpc(local_username, msg, my_id)

@rpc("any_peer", "call_local", "reliable")
func _receive_chat(sender_name: String, message: String, peer_id: int) -> void:
	chat_message_received.emit(sender_name, message, peer_id)
