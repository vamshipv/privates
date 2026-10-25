extends Node
class_name RagdollController

signal ragdoll_state_changed(is_ragdolled: bool)

@export var player: CharacterBody3D
@export var recover_duration: float = 2.5

var is_ragdolled: bool = false
var recover_timer: float = 0.0
var ragdoll_impulse: Vector3 = Vector3.ZERO

func _process(delta: float) -> void:
	if is_ragdolled:
		recover_timer -= delta
		if recover_timer <= 0.0:
			recover_from_ragdoll()

func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_ragdoll"):
		if is_ragdolled:
			recover_from_ragdoll()
		else:
			trigger_ragdoll(Vector3.UP * 3.0 + -player.global_transform.basis.z * 4.0)

func trigger_ragdoll(impulse: Vector3 = Vector3.ZERO) -> void:
	if is_ragdolled:
		return
	
	is_ragdolled = true
	recover_timer = recover_duration
	ragdoll_impulse = impulse
	
	_sync_ragdoll_state.rpc(true, impulse)

func recover_from_ragdoll() -> void:
	if not is_ragdolled:
		return
	
	is_ragdolled = false
	recover_timer = 0.0
	
	_sync_ragdoll_state.rpc(false, Vector3.ZERO)

@rpc("any_peer", "call_local", "reliable")
func _sync_ragdoll_state(state: bool, impulse: Vector3) -> void:
	is_ragdolled = state
	ragdoll_state_changed.emit(state)
	
	var avatar_slot = player.get_node_or_null("AvatarSlot")
	if avatar_slot:
		var physical_bone_sim = avatar_slot.find_child("PhysicalBoneSimulator3D", true, false)
		if physical_bone_sim:
			if state:
				physical_bone_sim.physical_bones_start_simulation()
			else:
				physical_bone_sim.physical_bones_stop_simulation()
		else:
			# Fallback procedural ragdoll tumble on placeholder avatar
			var placeholder_mesh = avatar_slot.get_node_or_null("PlaceholderAvatar")
			if placeholder_mesh:
				if state:
					var tween = create_tween()
					tween.tween_property(placeholder_mesh, "rotation:x", deg_to_rad(-85.0), 0.2)
					tween.parallel().tween_property(placeholder_mesh, "position:y", -0.7, 0.2)
				else:
					var tween = create_tween()
					tween.tween_property(placeholder_mesh, "rotation:x", 0.0, 0.3)
					tween.parallel().tween_property(placeholder_mesh, "position:y", 0.0, 0.3)
