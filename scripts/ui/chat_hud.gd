extends Control

@onready var chat_log: RichTextLabel = $ChatPanel/VBox/ChatLog
@onready var chat_input: LineEdit = $ChatPanel/VBox/ChatInput
@onready var member_count_label: Label = $TopBar/MemberCountLabel
@onready var voice_status_label: Label = $TopBar/VoiceStatusLabel

var network_mgr: Node = null
var voice_mgr: Node = null

func _ready() -> void:
	network_mgr = get_node("/root/Main/NetworkManager")
	voice_mgr = get_node("/root/Main/VoiceManager")
	
	network_mgr.chat_message_received.connect(_on_chat_received)
	network_mgr.player_connected.connect(_on_roster_changed)
	network_mgr.player_disconnected.connect(_on_roster_changed)
	
	if voice_mgr:
		voice_mgr.speaking_state_changed.connect(_on_speaking_changed)
	
	chat_input.text_submitted.connect(_on_input_submitted)
	_update_member_count()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_chat"):
		if not chat_input.has_focus():
			chat_input.grab_focus()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_viewport().set_input_as_handled()
		else:
			_unfocus_chat()
	
	elif event.is_action_pressed("ui_cancel") and chat_input.has_focus():
		_unfocus_chat()
		get_viewport().set_input_as_handled()

func _on_input_submitted(text: String) -> void:
	if not text.strip_edges().is_empty():
		network_mgr.send_chat(text)
		chat_input.clear()
	_unfocus_chat()

func _unfocus_chat() -> void:
	chat_input.release_focus()
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_chat_received(sender_name: String, message: String, peer_id: int) -> void:
	var time_str = Time.get_time_string_from_system()
	var color_hex = "4fa3e3"
	if network_mgr.players.has(peer_id):
		color_hex = network_mgr.players[peer_id].color.to_html(false)
	
	var formatted = "[color=#888][%s][/color] [b][color=#%s]%s:[/color][/b] %s\n" % [time_str, color_hex, sender_name, message]
	chat_log.append_text(formatted)
	
	# Show overhead bubble on player instance
	var players_container = get_node_or_null("/root/Main/Players")
	if players_container:
		var p_node = players_container.get_node_or_null("Player_" + str(peer_id))
		if p_node and p_node.has_method("show_chat_bubble"):
			p_node.show_chat_bubble(message)

func _on_roster_changed(_id: int = 0, _info: Dictionary = {}) -> void:
	_update_member_count()

func _update_member_count() -> void:
	var count = network_mgr.players.size()
	member_count_label.text = "Clan Hall: %d Homies Online" % count

func _on_speaking_changed(peer_id: int, is_speaking: bool) -> void:
	if peer_id == multiplayer.get_unique_id():
		if is_speaking:
			voice_status_label.text = "🎙️ Mic: Broadcasting"
			voice_status_label.modulate = Color(0.3, 1.0, 0.4)
		else:
			voice_status_label.text = "🎙️ Mic: Idle (Hold V)"
			voice_status_label.modulate = Color(0.8, 0.8, 0.8)
