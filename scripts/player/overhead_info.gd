extends Node3D

@onready var name_label: Label3D = $NameLabel
@onready var voice_icon: Label3D = $VoiceIcon
@onready var bubble_label: Label3D = $BubbleLabel

var bubble_timer: float = 0.0

func _ready() -> void:
	voice_icon.visible = false
	bubble_label.visible = false
	
	var voice_mgr = get_node_or_null("/root/Main/VoiceManager")
	if voice_mgr:
		voice_mgr.speaking_state_changed.connect(_on_speaking_changed)

func set_username(u_name: String, u_color: Color) -> void:
	if name_label:
		name_label.text = u_name
		name_label.modulate = u_color

func _on_speaking_changed(peer_id: int, is_speaking: bool) -> void:
	var player = get_parent()
	if player and "peer_id" in player and player.peer_id == peer_id:
		voice_icon.visible = is_speaking

func display_bubble(text: String) -> void:
	bubble_label.text = text
	bubble_label.visible = true
	bubble_timer = 4.5

func _process(delta: float) -> void:
	if bubble_timer > 0.0:
		bubble_timer -= delta
		if bubble_timer <= 0.0:
			bubble_label.visible = false
