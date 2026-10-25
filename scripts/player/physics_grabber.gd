extends Node3D
class_name PhysicsGrabber

signal prop_grabbed(prop: Node3D)
signal prop_released(prop: Node3D)

@export var max_reach: float = 3.8
@export var throw_impulse: float = 14.0
@export var hold_distance: float = 2.2
@export var hold_stiffness: float = 24.0
@export var hold_damping: float = 8.0

var held_prop: RigidBody3D = null
var is_rotating_held_prop: bool = false
var held_rotation_euler: Vector3 = Vector3.ZERO

@onready var raycast: RayCast3D = $RayCast3D
@onready var hold_anchor: Marker3D = $HoldAnchor

func _ready() -> void:
	raycast.target_position = Vector3(0, 0, -max_reach)

func _physics_process(delta: float) -> void:
	if not held_prop:
		return
	
	if not is_instance_valid(held_prop):
		held_prop = null
		return

	# Position hold anchor dynamically in front of camera
	hold_anchor.position = Vector3(0, -0.2, -hold_distance)
	var target_pos = hold_anchor.global_position
	
	# Apply spring force to keep prop at hold anchor smoothly
	var current_pos = held_prop.global_position
	var to_target = target_pos - current_pos
	held_prop.linear_velocity = to_target * hold_stiffness - (held_prop.linear_velocity * 0.2)
	
	# Rotation handling
	if not is_rotating_held_prop:
		# Keep current relative orientation
		held_prop.angular_velocity = Vector3.ZERO
		var target_basis = global_transform.basis * Basis.from_euler(held_rotation_euler)
		held_prop.global_basis = held_prop.global_basis.slerp(target_basis, 15.0 * delta)

func handle_input(event: InputEvent) -> void:
	# Rotate held object
	if event.is_action("rotate_item"):
		is_rotating_held_prop = event.is_pressed()

	if is_rotating_held_prop and held_prop and event is InputEventMouseMotion:
		held_rotation_euler.y -= event.relative.x * 0.01
		held_rotation_euler.x -= event.relative.y * 0.01
		return

	if event.is_action_pressed("interact"):
		if held_prop:
			drop_prop()
		else:
			try_grab_prop()

	elif event.is_action_pressed("throw_item") and held_prop:
		throw_prop()

	elif event.is_action_pressed("place_item") and held_prop:
		place_prop_gently()

func try_grab_prop() -> void:
	if not raycast.is_colliding():
		return
	
	var collider = raycast.get_collider()
	if collider is RigidBody3D and collider.is_in_group("interactive_prop"):
		grab_prop(collider)

func grab_prop(prop: RigidBody3D) -> void:
	held_prop = prop
	held_rotation_euler = Vector3.ZERO
	
	if prop.has_method("on_grabbed"):
		prop.on_grabbed(multiplayer.get_unique_id())
	
	prop_grabbed.emit(prop)

func drop_prop() -> void:
	if not held_prop:
		return
	
	var prop = held_prop
	held_prop = null
	
	if prop.has_method("on_released"):
		prop.on_released(Vector3.ZERO, Vector3.ZERO)
	
	prop_released.emit(prop)

func place_prop_gently() -> void:
	if not held_prop:
		return
	
	var prop = held_prop
	held_prop = null
	
	# Zero out velocity so it sits neatly on tables, crates, or floor for precision stacking
	if prop.has_method("on_released"):
		prop.on_released(Vector3(0, -0.5, 0), Vector3.ZERO)
	
	prop_released.emit(prop)

func throw_prop() -> void:
	if not held_prop:
		return
	
	var prop = held_prop
	held_prop = null
	
	var throw_dir = -global_transform.basis.z.normalized()
	var throw_velocity = throw_dir * throw_impulse + Vector3(0, 1.5, 0)
	var random_spin = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))
	
	if prop.has_method("on_released"):
		prop.on_released(throw_velocity, random_spin)
	
	prop_released.emit(prop)
