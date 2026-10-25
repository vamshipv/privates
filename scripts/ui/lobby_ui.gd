extends Control

@onready var host_btn: Button = $Panel/VBox/HostButton
@onready var join_btn: Button = $Panel/VBox/JoinButton
@onready var name_input: LineEdit = $Panel/VBox/NameInput
@onready var ip_input: LineEdit = $Panel/VBox/IPInput
@onready var port_input: LineEdit = $Panel/VBox/PortInput
@onready var status_label: Label = $Panel/VBox/StatusLabel

var network_mgr: Node = null

func _ready() -> void:
	network_mgr = get_node("/root/Main/NetworkManager")
	host_btn.pressed.connect(_on_host_pressed)
	join_btn.pressed.connect(_on_join_pressed)
	
	network_mgr.player_connected.connect(_on_connected)
	network_mgr.server_disconnected.connect(_on_disconnected)
	
	_check_cli_args()

func _check_cli_args() -> void:
	var args = OS.get_cmdline_user_args()
	if args.is_empty():
		args = OS.get_cmdline_args()
	
	if "--host" in args:
		name_input.text = "Host_Player"
		_on_host_pressed()
	elif "--join" in args:
		show()
		var idx = args.find("--join")
		var target_ip = "127.0.0.1"
		if idx + 1 < args.size() and not args[idx + 1].begins_with("--"):
			target_ip = args[idx + 1]
		name_input.text = "Homie_" + str(randi() % 99)
		ip_input.text = target_ip
		_on_join_pressed()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if visible:
			hide()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			show()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()

func _on_host_pressed() -> void:
	var port = port_input.text.to_int()
	if port <= 0: port = 7777
	var err = network_mgr.host_game(port, name_input.text)
	if err == OK:
		status_label.text = "Hosting on port %d..." % port
		status_label.modulate = Color(0.3, 1.0, 0.4)
		hide()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		status_label.text = "Failed to host: %s" % err
		status_label.modulate = Color(1.0, 0.3, 0.3)

func _on_join_pressed() -> void:
	var ip = ip_input.text.strip_edges()
	if ip.is_empty(): ip = "127.0.0.1"
	var port = port_input.text.to_int()
	if port <= 0: port = 7777
	
	status_label.text = "Connecting to %s:%d..." % [ip, port]
	status_label.modulate = Color(1.0, 0.8, 0.2)
	
	var err = network_mgr.join_game(ip, port, name_input.text)
	if err != OK:
		status_label.text = "Connection error: %s" % err
		status_label.modulate = Color(1.0, 0.3, 0.3)

func _on_connected(_id: int, _info: Dictionary) -> void:
	hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_disconnected() -> void:
	show()
	status_label.text = "Disconnected from server."
	status_label.modulate = Color(1.0, 0.4, 0.4)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
