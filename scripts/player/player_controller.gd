extends CharacterBody3D
class_name PlayerController

## Fortnite-Style Third-Person Character Controller
## Implements: Walk, Sprint, Slide, Crouch, Jump, Glider, Battle Bus drop, Skydive, 360 Camera Look, and ADS/Sniper Scoping

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
var is_on_battle_bus: bool = false
var is_skydiving: bool = false
var is_aiming: bool = false

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
@onready var character_animator: CharacterAnimator = $CharacterAnimator
@onready var sfx_glider: AudioStream = preload("res://assets/audio/glider_open.mp3")

var default_spring_offset: Vector3 = Vector3(0.55, 0.2, 0.0)
var default_spring_length: float = 2.8
var default_fov: float = 75.0

var skydive_audio: AudioStreamPlayer = null

# Mantle detection raycasts
@onready var mantle_chest_ray: RayCast3D = $MantleChestRay
@onready var mantle_head_ray: RayCast3D = $MantleHeadRay

var normal_height: float = 1.9
var crouch_height: float = 1.2
var mouse_released_by_esc: bool = false
var touch_look_index: int = -1
var touch_look_sens: float = 0.0035

func _ready() -> void:
	if spring_arm:
		spring_arm.add_excluded_object(get_rid())
		spring_arm.collision_mask = 1
	
	GameManager.match_started.connect(_on_match_started)
	GameManager.return_to_lobby.connect(_on_return_to_lobby)
	
	call_deferred("_connect_battle_bus")
	
	if not GameManager.is_in_match:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if glider_mesh:
		glider_mesh.visible = false
	if mesh_instance:
		mesh_instance.visible = false

func _connect_battle_bus() -> void:
	var bus = get_tree().get_first_node_in_group("battle_bus")
	if not bus:
		bus = get_parent().get_node_or_null("BattleBus")
	if bus and bus.has_signal("player_dropped"):
		bus.player_dropped.connect(_on_battle_bus_drop)

func _on_match_started() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	is_on_battle_bus = true
	is_skydiving = false
	is_gliding = false
	is_aiming = false
	visible = false
	velocity = Vector3.ZERO
	Globals.reset_player_stats()
	if character_animator:
		character_animator.setup_character()

func _on_battle_bus_drop(drop_pos: Vector3, forward_dir: Vector3) -> void:
	is_on_battle_bus = false
	is_skydiving = true
	is_gliding = false
	is_aiming = false
	visible = true
	global_position = drop_pos
	velocity = forward_dir * 14.0 + Vector3(0, -20.0, 0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if camera:
		camera.current = true
	if glider_mesh:
		glider_mesh.visible = false
	
	if not skydive_audio:
		skydive_audio = AudioStreamPlayer.new()
		skydive_audio.stream = preload("res://assets/audio/skydive_wind.mp3")
		skydive_audio.volume_db = -3.0
		add_child(skydive_audio)
	skydive_audio.play()

func _on_return_to_lobby() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	global_position = Vector3(0, 5.0, 0)
	velocity = Vector3.ZERO
	is_on_battle_bus = false
	is_skydiving = false
	is_gliding = false
	is_aiming = false
	visible = true
	if glider_mesh:
		glider_mesh.visible = false
	if skydive_audio and skydive_audio.playing:
		skydive_audio.stop()
	Globals.scoping_changed.emit(false, false)

func _input(event: InputEvent) -> void:
	if not GameManager.is_in_match or is_on_battle_bus:
		return
	
	# Auto-recapture mouse if user clicks inside window during match
	if event is InputEventMouseButton and event.pressed:
		mouse_released_by_esc = false
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# ESC toggles mouse cursor
	if event.is_action_pressed("ui_cancel"):
		mouse_released_by_esc = not mouse_released_by_esc
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if mouse_released_by_esc else Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return
	
	# Mobile touchscreen 360-degree camera look
	if event is InputEventScreenTouch:
		if event.position.x > get_viewport().get_visible_rect().size.x * 0.38:
			if event.pressed:
				if touch_look_index == -1:
					touch_look_index = event.index
			else:
				if event.index == touch_look_index:
					touch_look_index = -1
	
	if event is InputEventScreenDrag and event.index == touch_look_index:
		var sens = touch_look_sens
		if is_aiming:
			sens *= 0.4 if Globals.active_slot == 3 else 0.7
		rotate_y(-event.relative.x * sens)
		camera_pivot.rotate_x(-event.relative.y * sens)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, -deg_to_rad(85.0), deg_to_rad(85.0))
	
	# Full 360-degree mouse look
	if event is InputEventMouseMotion and not mouse_released_by_esc:
		var sens = mouse_sensitivity
		if is_aiming:
			sens *= 0.4 if Globals.active_slot == 3 else 0.7
		rotate_y(-event.relative.x * sens)
		camera_pivot.rotate_x(-event.relative.y * sens)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, -deg_to_rad(85.0), deg_to_rad(85.0))
	
	# Slot switching (Pickaxe: F, Weapons: 1-5)
	var new_slot = -1
	if event.is_action_pressed("slot_pickaxe"):
		new_slot = 0
	elif event.is_action_pressed("slot_1"):
		new_slot = 1
	elif event.is_action_pressed("slot_2"):
		new_slot = 2
	elif event.is_action_pressed("slot_3"):
		new_slot = 3
	elif event.is_action_pressed("slot_4"):
		new_slot = 4
	elif event.is_action_pressed("slot_5"):
		new_slot = 5
	
	if new_slot >= 0:
		Globals.active_slot = new_slot
		Globals.is_building_mode = false
		if is_aiming:
			Globals.scoping_changed.emit(true, Globals.active_slot == 3)

func _process(delta: float) -> void:
	if not GameManager.is_in_match or is_on_battle_bus:
		return
	
	handle_scoping(delta)

func handle_scoping(delta: float) -> void:
	# Check if holding RMB or Mobile Aim button (Aim Down Sights / Sniper Scope)
	var wants_aim = (Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Globals.mobile_aim) and not Globals.is_building_mode and not is_skydiving
	if wants_aim != is_aiming:
		is_aiming = wants_aim
		var is_sniper = (Globals.active_slot == 3)
		Globals.scoping_changed.emit(is_aiming, is_sniper)
	
	var target_fov: float = default_fov
	var target_spring_len: float = default_spring_length
	var target_offset: Vector3 = default_spring_offset
	
	if is_aiming:
		if Globals.active_slot == 3: # Sniper Rifle: high zoom & center view
			target_fov = 18.0
			target_spring_len = 0.3
			target_offset = Vector3(0.0, 0.1, 0.0)
			if character_animator:
				character_animator.visible = false
		else: # Assault Rifle, Shotgun: tight shoulder ADS
			target_fov = 48.0
			target_spring_len = 1.7
			target_offset = Vector3(0.48, 0.15, 0.0)
			if character_animator:
				character_animator.visible = true
	else:
		if character_animator and not is_on_battle_bus:
			character_animator.visible = true
	
	if camera:
		camera.fov = lerp(camera.fov, target_fov, delta * 14.0)
	if spring_arm:
		spring_arm.spring_length = lerp(spring_arm.spring_length, target_spring_len, delta * 14.0)
		spring_arm.position = spring_arm.position.lerp(target_offset, delta * 14.0)

func _physics_process(delta: float) -> void:
	if not GameManager.is_in_match or is_on_battle_bus:
		if character_animator and character_animator.has_method("update_locomotion"):
			character_animator.update_locomotion(0.0, false, false, false, false, Globals.active_slot, false)
		return
	
	handle_crouch_and_slide(delta)
	handle_jump_and_glider(delta)
	handle_movement(delta)
	handle_mantle()
	move_and_slide()
	
	# Update 3D character animation
	if character_animator and character_animator.has_method("update_locomotion"):
		var horiz_speed = Vector2(velocity.x, velocity.z).length()
		var in_air = not is_on_floor()
		character_animator.update_locomotion(horiz_speed, is_sprinting, is_sliding, in_air and is_gliding, is_aiming, Globals.active_slot, in_air and is_skydiving and not is_gliding)

func handle_crouch_and_slide(delta: float) -> void:
	if is_skydiving:
		return
	
	var crouch_pressed = Input.is_action_just_pressed("crouch") or Globals.mobile_crouch_pressed
	Globals.mobile_crouch_pressed = false
	
	if crouch_pressed:
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

func handle_jump_and_glider(delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if Globals.mobile_move_vector != Vector2.ZERO:
		input_dir = Globals.mobile_move_vector
	
	var jump_pressed = Input.is_action_just_pressed("jump") or Globals.mobile_jump_pressed
	Globals.mobile_jump_pressed = false
	
	if is_on_floor():
		if is_skydiving:
			is_skydiving = false
			if skydive_audio and skydive_audio.playing:
				skydive_audio.stop()
		is_gliding = false
		if glider_mesh:
			glider_mesh.visible = false
			glider_mesh.rotation = glider_mesh.rotation.lerp(Vector3.ZERO, delta * 10.0)
		
		if jump_pressed:
			velocity.y = JUMP_VELOCITY
			is_crouching = false
			is_sliding = false
	else:
		# Auto-open glider if approaching ground during skydiving
		if is_skydiving and global_position.y <= 18.0 and not is_gliding:
			is_gliding = true
			if glider_mesh:
				glider_mesh.visible = true
			if sfx_glider:
				var asp = AudioStreamPlayer.new()
				asp.stream = sfx_glider
				add_child(asp)
				asp.play()
				get_tree().create_timer(1.5).timeout.connect(asp.queue_free)
		
		# Toggle Glider in air
		if jump_pressed and velocity.y < 0.0:
			is_gliding = not is_gliding
			if glider_mesh:
				glider_mesh.visible = is_gliding
			if is_gliding and sfx_glider:
				var asp = AudioStreamPlayer.new()
				asp.stream = sfx_glider
				add_child(asp)
				asp.play()
				get_tree().create_timer(1.5).timeout.connect(asp.queue_free)
		
		# Apply gravity, gliding banking, and terminal velocities
		if is_gliding:
			velocity.y = max(-5.2, velocity.y - (gravity * 0.2 * delta))
			if glider_mesh:
				var target_roll = -input_dir.x * deg_to_rad(24.0)
				var target_pitch = -0.15 if input_dir.y < -0.1 else 0.0
				glider_mesh.rotation.z = lerp_angle(glider_mesh.rotation.z, target_roll, delta * 8.0)
				glider_mesh.rotation.x = lerp_angle(glider_mesh.rotation.x, target_pitch, delta * 6.0)
		elif is_skydiving:
			var target_fall = -22.0
			if Input.is_action_pressed("move_forward") or input_dir.y < -0.5:
				target_fall = -34.0
			elif Input.is_action_pressed("move_backward") or input_dir.y > 0.5:
				target_fall = -16.0
			velocity.y = move_toward(velocity.y, target_fall, gravity * 1.5 * delta)
			if glider_mesh:
				glider_mesh.rotation = glider_mesh.rotation.lerp(Vector3.ZERO, delta * 10.0)
		else:
			velocity.y -= gravity * delta
			if glider_mesh:
				glider_mesh.rotation = glider_mesh.rotation.lerp(Vector3.ZERO, delta * 10.0)

func handle_movement(delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if Globals.mobile_move_vector != Vector2.ZERO:
		input_dir = Globals.mobile_move_vector
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	is_sprinting = (Input.is_action_pressed("sprint") or Globals.mobile_sprint) and not is_crouching and input_dir.y < -0.1
	
	var current_speed = WALK_SPEED
	if is_sliding:
		current_speed = SLIDE_SPEED
	elif is_sprinting:
		current_speed = SPRINT_SPEED
	elif is_crouching:
		current_speed = CROUCH_SPEED
	elif is_gliding:
		current_speed = 17.5
	elif is_skydiving:
		current_speed = 22.0 if (Input.is_action_pressed("move_forward") or input_dir.y < -0.5) else 14.0
	
	if direction:
		velocity.x = lerp(velocity.x, direction.x * current_speed, delta * 10.0)
		velocity.z = lerp(velocity.z, direction.z * current_speed, delta * 10.0)
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed * delta * 8.0)
		velocity.z = move_toward(velocity.z, 0, current_speed * delta * 8.0)

func handle_mantle() -> void:
	if not is_on_floor() and velocity.y > -2.0 and not is_skydiving:
		if mantle_chest_ray and mantle_chest_ray.is_colliding():
			if mantle_head_ray and not mantle_head_ray.is_colliding():
				velocity.y = 6.0
				velocity += -transform.basis.z * 3.0
