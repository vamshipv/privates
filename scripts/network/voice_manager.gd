extends Node

signal speaking_state_changed(peer_id: int, is_speaking: bool)

const CHUNK_SIZE: int = 512
const SAMPLE_RATE: int = 22050
const SILENCE_THRESHOLD: float = 0.015

var record_bus_index: int = -1
var capture_effect: AudioEffectCapture = null
var is_transmitting: bool = false
var push_to_talk: bool = true
var is_muted: bool = false
var local_is_speaking: bool = false
var silence_timer: float = 0.0

# Map of peer_id to their AudioStreamPlayer3D
var player_audio_players: Dictionary = {}

func _ready() -> void:
	record_bus_index = AudioServer.get_bus_index("Record")
	if record_bus_index != -1 and AudioServer.get_bus_effect_count(record_bus_index) > 0:
		capture_effect = AudioServer.get_bus_effect(record_bus_index, 0) as AudioEffectCapture
		if capture_effect:
			print("[Voice] AudioEffectCapture initialized on bus 'Record'")
	else:
		push_warning("[Voice] Could not find AudioEffectCapture on 'Record' bus.")

func register_player_audio(peer_id: int, audio_player: AudioStreamPlayer3D) -> void:
	player_audio_players[peer_id] = audio_player
	print("[Voice] Registered 3D audio player for peer %d" % peer_id)

func unregister_player_audio(peer_id: int) -> void:
	if player_audio_players.has(peer_id):
		player_audio_players.erase(peer_id)

func _process(delta: float) -> void:
	if capture_effect == null or is_muted:
		return
	
	if not multiplayer.has_multiplayer_peer():
		return
		
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return

	# Handle Push-To-Talk or Voice Activity
	var ptt_active = Input.is_action_pressed("push_to_talk")
	if push_to_talk:
		is_transmitting = ptt_active
	else:
		is_transmitting = true

	if not is_transmitting:
		if local_is_speaking:
			_set_speaking(false)
		capture_effect.clear_buffer()
		return

	var available = capture_effect.get_frames_available()
	if available >= CHUNK_SIZE:
		var buffer: PackedVector2Array = capture_effect.get_buffer(CHUNK_SIZE)
		var mono_data: PackedFloat32Array = PackedFloat32Array()
		mono_data.resize(CHUNK_SIZE)
		
		var max_amp: float = 0.0
		for i in range(CHUNK_SIZE):
			var sample: float = (buffer[i].x + buffer[i].y) * 0.5
			mono_data[i] = sample
			var abs_sample = absf(sample)
			if abs_sample > max_amp:
				max_amp = abs_sample
		
		if max_amp > SILENCE_THRESHOLD or ptt_active:
			_set_speaking(true)
			silence_timer = 0.3
			var my_id = multiplayer.get_unique_id()
			_transmit_voice.rpc(my_id, mono_data)
		else:
			if silence_timer > 0.0:
				silence_timer -= delta
			elif local_is_speaking:
				_set_speaking(false)

func _set_speaking(state: bool) -> void:
	if local_is_speaking != state:
		local_is_speaking = state
		var my_id = multiplayer.get_unique_id()
		_notify_speaking.rpc(my_id, state)
		speaking_state_changed.emit(my_id, state)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _transmit_voice(sender_id: int, audio_data: PackedFloat32Array) -> void:
	if not player_audio_players.has(sender_id):
		return
	
	var player_3d: AudioStreamPlayer3D = player_audio_players[sender_id]
	if not player_3d.playing:
		player_3d.play()
	
	var playback = player_3d.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	
	var to_fill = playback.get_frames_available()
	var count = mini(audio_data.size(), to_fill)
	if count > 0:
		var stereo_frames = PackedVector2Array()
		stereo_frames.resize(count)
		for i in range(count):
			var val = audio_data[i]
			stereo_frames[i] = Vector2(val, val)
		playback.push_buffer(stereo_frames)

@rpc("any_peer", "call_local", "reliable")
func _notify_speaking(peer_id: int, is_speaking: bool) -> void:
	speaking_state_changed.emit(peer_id, is_speaking)
