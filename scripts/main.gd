extends Node3D

@export var player_scene: PackedScene = preload("res://scenes/player/player.tscn")
@export var crate_scene: PackedScene = preload("res://scenes/objects/stackable_crate.tscn")
@export var ball_scene: PackedScene = preload("res://scenes/objects/physics_ball.tscn")

@onready var network_mgr: Node = $NetworkManager
@onready var voice_mgr: Node = $VoiceManager
@onready var players_container: Node3D = $Players
@onready var props_container: Node3D = $Props
@onready var lobby_ui: Control = $UI/LobbyUI
@onready var chat_hud: Control = $UI/ChatHUD

func _ready() -> void:
	network_mgr.player_connected.connect(_on_player_connected)
	network_mgr.player_disconnected.connect(_on_player_disconnected)
	network_mgr.server_disconnected.connect(_on_server_disconnected)
	
	# Always spawn interactive physics props in the hall
	_spawn_initial_props()
	
	# Determine if running via CLI join flag or local immediate play
	var args = OS.get_cmdline_user_args()
	if args.is_empty():
		args = OS.get_cmdline_args()
	
	if "--join" in args:
		# Let LobbyUI handle the CLI join connection
		print("[Main] Detected --join CLI argument, awaiting connection...")
	else:
		# Auto-start in Local Play / Host mode so the user immediately enters the 3D room!
		print("[Main] Starting in Local Clan Hall mode...")
		_start_local_session()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if network_mgr and is_instance_valid(network_mgr):
			network_mgr.disconnect_game()

func _start_local_session() -> void:
	# Spawn local player immediately so the camera, movement, and physics are active instantly
	var local_id = 1
	var local_name = "Homie"
	var local_color = Color(0.2, 0.65, 1.0)
	
	var player_node_name = "Player_%d" % local_id
	if not players_container.has_node(player_node_name):
		var player = player_scene.instantiate()
		player.name = player_node_name
		player.position = Vector3(0, 0.5, 4.0)
		players_container.add_child(player)
		player.setup_player(local_id, local_name, local_color)
		print("[Main] Local player spawned at (0, 0.5, 4.0). Camera & physics ready!")
	
	# Hide lobby overlay so 3D environment is immediately visible
	if lobby_ui:
		lobby_ui.hide()
	
	# Capture mouse for instant gameplay
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _spawn_initial_props() -> void:
	# Clear any previous props
	for c in props_container.get_children():
		c.queue_free()
		
	# Stackable wooden crates neatly arranged on the table and floor
	var crate_positions = [
		Vector3(-0.6, 0.8, 0.0),
		Vector3(0.6, 0.8, 0.0),
		Vector3(0.0, 1.5, 0.0),
		Vector3(3.5, 0.4, 2.0),
		Vector3(3.5, 1.1, 2.0),
		Vector3(4.2, 0.4, 2.0),
		Vector3(-4.0, 0.4, 2.5),
		Vector3(-4.0, 1.1, 2.5)
	]
	
	for i in range(crate_positions.size()):
		var crate = crate_scene.instantiate()
		crate.name = "Crate_%d" % i
		crate.position = crate_positions[i]
		props_container.add_child(crate)
	
	# Bouncy sports balls for kicking and throwing
	var ball_positions = [
		Vector3(0.0, 0.8, 0.8),
		Vector3(-2.0, 0.4, 2.0),
		Vector3(2.5, 0.4, -2.0)
	]
	
	for j in range(ball_positions.size()):
		var ball = ball_scene.instantiate()
		ball.name = "Ball_%d" % j
		ball.position = ball_positions[j]
		props_container.add_child(ball)
	print("[Main] Initialized stackable crates and physics balls.")

func _on_player_connected(peer_id: int, info: Dictionary) -> void:
	var player_node_name = "Player_" + str(peer_id)
	if players_container.has_node(player_node_name):
		var existing = players_container.get_node(player_node_name)
		existing.setup_player(peer_id, info.name, info.color)
		return
	
	var player = player_scene.instantiate()
	player.name = player_node_name
	var spawn_pos = Vector3(randf_range(-2.5, 2.5), 0.5, randf_range(3.0, 5.0))
	player.position = spawn_pos
	players_container.add_child(player)
	player.setup_player(peer_id, info.name, info.color)
	print("[Main] Spawned network player '%s' for '%s'" % [player_node_name, info.name])

func _on_player_disconnected(peer_id: int) -> void:
	var player_node_name = "Player_" + str(peer_id)
	if players_container.has_node(player_node_name):
		var p_node = players_container.get_node(player_node_name)
		voice_mgr.unregister_player_audio(peer_id)
		p_node.queue_free()
		print("[Main] Removed player node '%s'" % player_node_name)

func _on_server_disconnected() -> void:
	for child in players_container.get_children():
		child.queue_free()
	# Fall back to local player
	_start_local_session()
