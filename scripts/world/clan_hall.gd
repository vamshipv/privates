extends Node3D

@onready var environment_slot: Node3D = $EnvironmentSlot

const ROOM_LARGE_SCENE = preload("res://assets/environment/room-large.glb")
const GATE_SCENE = preload("res://assets/environment/gate.glb")
const GATE_DOOR_SCENE = preload("res://assets/environment/gate-door.glb")

func _ready() -> void:
	_setup_clan_hall_environment()

func _setup_clan_hall_environment() -> void:
	for child in environment_slot.get_children():
		child.queue_free()
		
	# Instantiate room-large.glb scaled by 4x to make a huge grand hall (80m x 80m x 17m)
	var room = ROOM_LARGE_SCENE.instantiate()
	room.name = "RoomLargeMesh"
	room.scale = Vector3(4.0, 4.0, 4.0)
	environment_slot.add_child(room)
	
	# Scaled entrance gates at the north and south grand archways
	var gate_north = GATE_SCENE.instantiate()
	gate_north.position = Vector3(0, 0, -40.0)
	gate_north.scale = Vector3(4.0, 4.0, 4.0)
	environment_slot.add_child(gate_north)
	
	var door_north = GATE_DOOR_SCENE.instantiate()
	door_north.position = Vector3(0, 0, -39.8)
	door_north.scale = Vector3(4.0, 4.0, 4.0)
	environment_slot.add_child(door_north)
	
	var gate_south = GATE_SCENE.instantiate()
	gate_south.position = Vector3(0, 0, 40.0)
	gate_south.rotation.y = PI
	gate_south.scale = Vector3(4.0, 4.0, 4.0)
	environment_slot.add_child(gate_south)
	
	print("[ClanHall] Scaled room-large.glb by 4x. Grand 80m x 80m Clan Hall ready!")
