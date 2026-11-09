extends CharacterBody3D
class_name PlayerController

## Fortnite-Style Third-Person Character Controller
## Implements: Walk, Sprint, Slide, Crouch, Jump, Glider, Mantle, and Camera Rig

# Movement Constants
const WALK_SPEED: float = 6.0
const SPRINT_SPEED: float = 9.5
const CROUCH_SPEED: float = 3.5
const SLIDE_SPEED: float = 12.0
const JUMP_VELOCITY: float = 8.5
const GLIDE_FALL_SPEED: float = -3.5

# Gravity
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# States
var is_sprinting: bool = false
var is_crouching: bool = false
var is_sliding: bool = false
var slide_timer: float = 0.0
var is_gliding: bool = false

# Camera Control
@export var mouse_sensitivity: float = 0.0025
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var glider_mesh: Node3D = $GliderMesh
@onready var weapon_raycast: RayCast3D = $CameraPivot/SpringArm3D/Camera3D/WeaponRayCast
@onready var building_system: Node3D = $BuildingSystem

# Mantle detection raycasts
@onready var mantle_chest_ray: RayCast3D = $MantleChestRay
@onready var mantle_head_ray: RayCast3D = $MantleHeadRay

var normal_height: float = 2.0
var crouch_height: float = 1.2

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if glider_mesh:
		glider_mesh.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Rotate body horizontally (Yaw)
		rotate_y(-event.relative.x * mouse_sensitivity)
		# Rotate camera vertically (Pitch)
		camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, -deg_to_rad(75.0), deg_to_rad(75.0))
	
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Slot switching (Pickaxe: F, Weapons: 1-5)
	if event.is_action_pressed("slot_pickaxe"):
		Globals.active_slot = 0
		Globals.is_building_mode = false
	elif event.is_action_pressed("slot_1"):
		Globals.active_slot = 1
		Globals.is_building_mode = false
	elif event.is_action_pressed("slot_2"):
		Globals.active_slot = 2
		Globals.is_building_mode = false
	elif event.is_action_pressed("slot_3"):
		Globals.active_slot = 3
		Globals.is_building_mode = false
	elif event.is_action_pressed("slot_4"):
		Globals.active_slot = 4
		Globals.is_building_mode = false
	elif event.is_action_pressed("slot_5"):
		Globals.active_slot = 5
		Globals.is_building_mode = false

func _physics_process(delta: float) -> void:
	handle_crouch_and_slide(delta)
	handle_jump_and_glider(delta)
	handle_movement(delta)
	handle_mantle()
	move_and_slide()

func handle_crouch_and_slide(delta: float) -> void:
	if Input.is_action_just_pressed("crouch"):
		if is_sprinting and is_on_floor() and not is_sliding:
			# Start Slide
			is_sliding = true
			slide_timer = 1.0
			is_crouching = true
		else:
			is_crouching = not is_crouching
			is_sliding = false
	
	if is_sliding:
		slide_timer -= delta
		if slide_timer <= 0.0 or not is_on_floor():
			is_sliding = false
	
	# Interpolate collision height
	var target_h = crouch_height if is_crouching else normal_height
	var shape = collision_shape.shape as CapsuleShape3D
	if shape:
		shape.height = lerp(shape.height, target_h, delta * 12.0)
		collision_shape.position.y = shape.height / 2.0
	
	if mesh_instance:
		var target_scale_y = 0.6 if is_crouching else 1.0
		mesh_instance.scale.y = lerp(mesh_instance.scale.y, target_scale_y, delta * 12.0)
		mesh_instance.position.y = 0.6 if is_crouching else 1.0

func handle_jump_and_glider(delta: float) -> void:
	if is_on_floor():
		is_gliding = false
		if glider_mesh:
			glider_mesh.visible = false
		
		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
			is_crouching = false
			is_sliding = false
	else:
		# Toggle Glider in air
		if Input.is_action_just_pressed("jump") and velocity.y < 0.0:
			is_gliding = not is_gliding
			if glider_mesh:
				glider_mesh.visible = is_gliding
		
		# Apply gravity
		if is_gliding:
			velocity.y = max(GLIDE_FALL_SPEED, velocity.y - (gravity * 0.25 * delta))
		else:
			velocity.y -= gravity * delta

func handle_movement(delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	is_sprinting = Input.is_action_pressed("sprint") and not is_crouching and input_dir.y < 0.0
	
	var current_speed = WALK_SPEED
	if is_sliding:
		current_speed = SLIDE_SPEED
	elif is_sprinting:
		current_speed = SPRINT_SPEED
	elif is_crouching:
		current_speed = CROUCH_SPEED
	elif is_gliding:
		current_speed = SPRINT_SPEED * 1.2
	
	if direction:
		velocity.x = lerp(velocity.x, direction.x * current_speed, delta * 10.0)
		velocity.z = lerp(velocity.z, direction.z * current_speed, delta * 10.0)
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed * delta * 8.0)
		velocity.z = move_toward(velocity.z, 0, current_speed * delta * 8.0)

func handle_mantle() -> void:
	# Mantle: Chest hits obstacle but Head ray is clear
	if not is_on_floor() and velocity.y > -2.0:
		if mantle_chest_ray and mantle_chest_ray.is_colliding():
			if mantle_head_ray and not mantle_head_ray.is_colliding():
				# Pull character up
				velocity.y = 6.0
				velocity += -transform.basis.z * 3.0
