extends RigidBody3D
class_name NetworkedProp

@export var prop_name: String = "Physics Object"
@export var damage_threshold_speed: float = 8.0

var is_held: bool = false
var holding_peer_id: int = 0
var target_pos: Vector3
var target_basis: Basis
var sync_timer: float = 0.0
const SYNC_INTERVAL: float = 0.04 # 25 Hz network sync

func _ready() -> void:
	add_to_group("interactive_prop")
	target_pos = global_position
	target_basis = global_basis
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		# Sync transform when moving or held
		if is_held or linear_velocity.length_squared() > 0.02 or angular_velocity.length_squared() > 0.02:
			sync_timer += delta
			if sync_timer >= SYNC_INTERVAL:
				sync_timer = 0.0
				_sync_transform.rpc(global_position, global_basis, linear_velocity, angular_velocity)
	else:
		# Interpolate transform on remote peers
		if not is_held:
			global_position = global_position.lerp(target_pos, 15.0 * delta)
			global_basis = global_basis.slerp(target_basis, 15.0 * delta)

func on_grabbed(peer_id: int) -> void:
	_rpc_request_grab.rpc(peer_id)

func on_released(lin_vel: Vector3, ang_vel: Vector3) -> void:
	_rpc_request_release.rpc(global_position, global_basis, lin_vel, ang_vel)

@rpc("any_peer", "call_local", "reliable")
func _rpc_request_grab(peer_id: int) -> void:
	is_held = true
	holding_peer_id = peer_id
	set_multiplayer_authority(peer_id)
	freeze = false

@rpc("any_peer", "call_local", "reliable")
func _rpc_request_release(pos: Vector3, b_basis: Basis, lin_vel: Vector3, ang_vel: Vector3) -> void:
	is_held = false
	holding_peer_id = 0
	global_position = pos
	global_basis = b_basis
	linear_velocity = lin_vel
	angular_velocity = ang_vel
	target_pos = pos
	target_basis = b_basis
	# Revert authority to server if server is available
	if multiplayer.is_server():
		set_multiplayer_authority(1)

@rpc("any_peer", "call_remote", "unreliable")
func _sync_transform(pos: Vector3, b_basis: Basis, lin_vel: Vector3, ang_vel: Vector3) -> void:
	if not is_multiplayer_authority():
		target_pos = pos
		target_basis = b_basis
		linear_velocity = lin_vel
		angular_velocity = ang_vel

func _on_body_entered(body: Node) -> void:
	# Check if hit a player with high velocity to trigger dynamic ragdoll
	if linear_velocity.length() > damage_threshold_speed:
		if body.has_method("trigger_ragdoll"):
			body.trigger_ragdoll(linear_velocity * 0.5)
