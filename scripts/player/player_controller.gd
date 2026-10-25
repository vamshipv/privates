extends CharacterBody3D
class_name PlayerController

@export var walk_speed: float = 6.5
@export var sprint_speed: float = 11.5
@export var jump_velocity: float = 5.5
@export var gravity: float = 12.0
@export var acceleration: float = 16.0
@export var friction: float = 10.0

const CameraRigScript = preload("res://scripts/player/camera_rig.gd")
const PhysicsGrabberScript = preload("res://scripts/player/physics_grabber.gd")
const RagdollControllerScript = preload("res://scripts/player/ragdoll_controller.gd")

var peer_id: int = 1
var player_name: String = "Homie"
var player_color: Color = Color(0.2, 0.6, 1.0)

var target_position: Vector3 = Vector3.ZERO
var target_rotation_y: float = 0.0

@onready var camera_rig: Node3D = $CameraRig
@onready var grabber: Node3D = $CameraRig/FPSAnchor/PhysicsGrabber
@onready var ragdoll_ctrl: Node = $RagdollController
@onready var overhead_info: Node3D = $OverheadInfo
@onready var audio_player_3d: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var avatar_slot: Node3D = $AvatarSlot

var anim_player: AnimationPlayer = null

func _enter_tree() -> void:
	var parts = name.split("_")
	if parts.size() > 1 and parts[1].is_valid_int():
		peer_id = parts[1].to_int()
	set_multiplayer_authority(peer_id)

func _ready() -> void:
	target_position = global_position
	target_rotation_y = rotation.y
	
	# Register with VoiceManager
	var voice_mgr = get_node_or_null("/root/Main/VoiceManager")
	if voice_mgr:
		voice_mgr.register_player_audio(peer_id, audio_player_3d)
	
	_setup_animated_character()
	
	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		camera_rig.camera_mode_changed.connect(_on_camera_mode_changed)
	else:
		camera_rig.camera.current = false
		camera_rig.process_mode = Node.PROCESS_MODE_DISABLED
		grabber.process_mode = Node.PROCESS_MODE_DISABLED

func setup_player(id: int, p_name: String, p_color: Color) -> void:
	peer_id = id
	player_name = p_name
	player_color = p_color
	set_multiplayer_authority(id)
	
	if overhead_info and overhead_info.has_method("set_username"):
		overhead_info.set_username(player_name, player_color)
	
	_apply_avatar_color(player_color)

func _setup_animated_character() -> void:
	var idle_fbx_path = "res://assets/characters/Animations/idle.fbx"
	if not ResourceLoader.exists(idle_fbx_path):
		print("[Player] No idle.fbx found, keeping fallback avatar.")
		return
		
	var idle_res = load(idle_fbx_path)
	if not (idle_res is PackedScene):
		return
		
	var anim_rig = idle_res.instantiate()
	anim_rig.name = "AnimatedRig"
	
	var skel = anim_rig.find_child("Skeleton3D", true, false) as Skeleton3D
	anim_player = anim_rig.find_child("AnimationPlayer", true, false) as AnimationPlayer
	
	# Attach character mesh if characterMedium.fbx exists
	var char_fbx_path = "res://assets/characters/characterMedium.fbx"
	if ResourceLoader.exists(char_fbx_path) and skel:
		var char_res = load(char_fbx_path)
		if char_res is PackedScene:
			var char_node = char_res.instantiate()
			var char_mesh = char_node.find_child("characterMedium", true, false) as MeshInstance3D
			if char_mesh:
				# Apply colormap texture
				var colormap_path = "res://assets/environment/Textures/colormap.png"
				if ResourceLoader.exists(colormap_path):
					var colormap_tex = load(colormap_path) as Texture2D
					if colormap_tex:
						var mat = StandardMaterial3D.new()
						mat.albedo_texture = colormap_tex
						mat.roughness = 0.5
						char_mesh.material_override = mat
				
				# Reparent mesh to the animated skeleton
				char_mesh.owner = null
				char_mesh.reparent(skel)
				char_mesh.skeleton = NodePath("..")
	
	# Load run and jump animations into the AnimationPlayer
	if anim_player:
		var anim_lib = anim_player.get_animation_library("")
		if anim_lib:
			var run_path = "res://assets/characters/Animations/run.fbx"
			if ResourceLoader.exists(run_path):
				var run_res = load(run_path)
				if run_res is PackedScene:
					var run_node = run_res.instantiate()
					var run_ap = run_node.find_child("AnimationPlayer", true, false) as AnimationPlayer
					if run_ap and run_ap.has_animation("Root|Run"):
						anim_lib.add_animation("Root|Run", run_ap.get_animation("Root|Run"))
			
			var jump_path = "res://assets/characters/Animations/jump.fbx"
			if ResourceLoader.exists(jump_path):
				var jump_res = load(jump_path)
				if jump_res is PackedScene:
					var jump_node = jump_res.instantiate()
					var jump_ap = jump_node.find_child("AnimationPlayer", true, false) as AnimationPlayer
					if jump_ap and jump_ap.has_animation("Root|Jump"):
						anim_lib.add_animation("Root|Jump", jump_ap.get_animation("Root|Jump"))
		
		# Call play("idle") directly as requested!
		if anim_player.has_animation("Root|Idle"):
			anim_player.play("Root|Idle")
			print("[Player] AnimationPlayer successfully playing 'Root|Idle'!")
		elif anim_player.get_animation_list().size() > 0:
			anim_player.play(anim_player.get_animation_list()[0])
	
	# Remove fallback placeholder
	var placeholder = avatar_slot.get_node_or_null("PlaceholderAvatar")
	if placeholder:
		placeholder.queue_free()
		
	avatar_slot.add_child(anim_rig)

func _apply_avatar_color(col: Color) -> void:
	var placeholder = avatar_slot.get_node_or_null("PlaceholderAvatar")
	if placeholder and is_instance_valid(placeholder):
		var visor = placeholder.get_node_or_null("Visor") as MeshInstance3D
		if visor and is_instance_valid(visor):
			var cur_mat = visor.get_surface_override_material(0)
			if cur_mat:
				var mat = cur_mat.duplicate() as StandardMaterial3D
				mat.albedo_color = col
				mat.emission = col
				visor.set_surface_override_material(0, mat)

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	
	if ragdoll_ctrl.is_ragdolled:
		ragdoll_ctrl.handle_input(event)
		return
	
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_rig.handle_mouse_input(event)
	
	grabber.handle_input(event)
	ragdoll_ctrl.handle_input(event)
	
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		_process_local_player(delta)
	else:
		_process_remote_player(delta)
	_update_animation_state()

func _process_local_player(delta: float) -> void:
	if ragdoll_ctrl.is_ragdolled:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		_sync_state.rpc(global_position, rotation.y, velocity, true)
		return

	# Add gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Get input vector
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	
	var cam_yaw = camera_rig.yaw
	var forward = Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
	var right = Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
	var direction = (forward * -input_dir.y + right * input_dir.x).normalized()
	
	var is_sprinting = Input.is_action_pressed("sprint")
	var target_speed = sprint_speed if is_sprinting else walk_speed
	
	if direction != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, direction.x * target_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * target_speed, acceleration * delta)
		if camera_rig.is_first_person:
			rotation.y = cam_yaw
		else:
			var target_rot = atan2(direction.x, direction.z)
			rotation.y = lerp_angle(rotation.y, target_rot, 12.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)
		if camera_rig.is_first_person:
			rotation.y = cam_yaw

	move_and_slide()
	_sync_state.rpc(global_position, rotation.y, velocity, false)

func _process_remote_player(delta: float) -> void:
	global_position = global_position.lerp(target_position, 16.0 * delta)
	rotation.y = lerp_angle(rotation.y, target_rotation_y, 16.0 * delta)

func _update_animation_state() -> void:
	if anim_player == null or not is_instance_valid(anim_player):
		return
		
	var h_speed = Vector2(velocity.x, velocity.z).length()
	
	if not is_on_floor():
		if anim_player.has_animation("Root|Jump") and anim_player.current_animation != "Root|Jump":
			anim_player.play("Root|Jump")
	elif h_speed > 0.4:
		if anim_player.has_animation("Root|Run") and anim_player.current_animation != "Root|Run":
			anim_player.play("Root|Run")
	else:
		if anim_player.has_animation("Root|Idle") and anim_player.current_animation != "Root|Idle":
			anim_player.play("Root|Idle")

@rpc("any_peer", "call_remote", "unreliable")
func _sync_state(pos: Vector3, rot_y: float, vel: Vector3, _ragdolled: bool) -> void:
	target_position = pos
	target_rotation_y = rot_y
	velocity = vel

func _on_camera_mode_changed(_is_fps: bool) -> void:
	# In FPS, keep avatar visible so player can look down at head/body/hands
	pass

func show_chat_bubble(text: String) -> void:
	if overhead_info and overhead_info.has_method("display_bubble"):
		overhead_info.display_bubble(text)
