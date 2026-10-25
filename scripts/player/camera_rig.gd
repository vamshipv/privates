extends Node3D
class_name CameraRig

signal camera_mode_changed(is_first_person: bool)

@export var mouse_sensitivity: float = 0.0025
@export var min_pitch: float = -85.0
@export var max_pitch: float = 85.0

# Third-person camera spring arm configuration
@export var default_tps_distance: float = 3.2
@export var min_tps_distance: float = 1.0
@export var max_tps_distance: float = 5.0
@export var tps_shoulder_offset: Vector3 = Vector3(0.45, 0.2, 0.0)

var is_first_person: bool = false
var pitch: float = 0.0
var yaw: float = 0.0

@onready var fps_anchor: Node3D = $FPSAnchor
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

func _ready() -> void:
	spring_arm.spring_length = default_tps_distance
	set_first_person(false)

func handle_mouse_input(event: InputEventMouseMotion) -> void:
	yaw -= event.relative.x * mouse_sensitivity
	pitch -= event.relative.y * mouse_sensitivity
	pitch = clampf(pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
	
	rotation.y = yaw
	fps_anchor.rotation.x = pitch
	spring_arm.rotation.x = pitch

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_camera"):
		toggle_perspective()
		get_viewport().set_input_as_handled()
	
	# Mouse wheel zoom to transition seamlessly between TPS and FPS
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if not is_first_person:
				spring_arm.spring_length = maxf(spring_arm.spring_length - 0.4, 0.0)
				if spring_arm.spring_length < 0.6:
					set_first_person(true)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if is_first_person:
				set_first_person(false)
				spring_arm.spring_length = 1.2
			else:
				spring_arm.spring_length = minf(spring_arm.spring_length + 0.4, max_tps_distance)

func toggle_perspective() -> void:
	set_first_person(not is_first_person)

func set_first_person(fps: bool) -> void:
	is_first_person = fps
	if is_first_person:
		if camera.get_parent() != fps_anchor:
			camera.reparent(fps_anchor)
		camera.transform = Transform3D.IDENTITY
	else:
		if camera.get_parent() != spring_arm:
			camera.reparent(spring_arm)
		camera.transform = Transform3D.IDENTITY
		spring_arm.spring_length = default_tps_distance
	camera_mode_changed.emit(is_first_person)

func get_active_camera() -> Camera3D:
	return camera

func get_forward_vector() -> Vector3:
	return -camera.global_transform.basis.z
