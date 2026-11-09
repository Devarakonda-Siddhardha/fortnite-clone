extends CharacterBody3D
class_name BotAI

## AI Opponent with Fortnite combat, defensive wall building, and storm survival

@export var bot_name: String = "Bot"
@export var max_health: float = 100.0
@export var max_shield: float = 50.0

var health: float = 100.0
var shield: float = 50.0

enum State {
	PATROL,
	ATTACK,
	FLEE_STORM,
	DEAD
}

var current_state: State = State.PATROL
var patrol_target: Vector3 = Vector3.ZERO
var attack_target: Node3D = null

var fire_timer: float = 0.0
var strafe_timer: float = 0.0
var strafe_dir: float = 1.0

var storm_center: Vector3 = Vector3.ZERO
var storm_radius: float = 300.0

const WALK_SPEED: float = 5.5
const SPRINT_SPEED: float = 8.5
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var vision_ray: RayCast3D = $VisionRayCast
@onready var shoot_sound: AudioStreamPlayer3D = $ShootSound
@onready var mesh_node: Node3D = $MeshInstance3D
@onready var character_animator: Node3D = $CharacterAnimator

const WALL_SCENE = preload("res://scenes/building/wall.tscn")
const PICKUP_SCENE = preload("res://scenes/environment/pickup.tscn")

func _ready() -> void:
	add_to_group("bots")
	add_to_group("damageable")
	health = max_health
	shield = max_shield
	Globals.storm_updated.connect(_on_storm_updated)
	pick_new_patrol_target()
	
	if character_animator:
		var bot_models = [
			"res://assets/characters/Kate.fbx",
			"res://assets/characters/Swat.fbx",
			"res://assets/characters/Vanguard.fbx",
			"res://assets/characters/Remy.fbx",
			"res://assets/characters/Ninja.fbx",
			"res://assets/characters/YBot.fbx",
			"res://assets/characters/SportyGranny.fbx",
			"res://assets/characters/Ty.fbx"
		]
		var model_idx = abs(bot_name.hash()) % bot_models.size()
		character_animator.character_fbx_path = bot_models[model_idx]

func _on_storm_updated(radius: float, center: Vector3, _phase: int, _time_left: float) -> void:
	storm_radius = radius
	storm_center = center
	
	# Check if outside safe zone
	var pos_flat = Vector2(global_position.x, global_position.z)
	var center_flat = Vector2(storm_center.x, storm_center.z)
	if pos_flat.distance_to(center_flat) > storm_radius:
		current_state = State.FLEE_STORM
	elif current_state == State.FLEE_STORM:
		current_state = State.PATROL

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return
	
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	scan_for_targets()
	
	match current_state:
		State.PATROL:
			handle_patrol(delta)
		State.ATTACK:
			handle_attack(delta)
		State.FLEE_STORM:
			handle_flee_storm(delta)
	
	move_and_slide()
	
	# Update 3D character animation
	if character_animator and character_animator.has_method("update_locomotion"):
		var horiz = Vector2(velocity.x, velocity.z).length()
		character_animator.update_locomotion(horiz, current_state == State.FLEE_STORM, false, false)

func scan_for_targets() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		if dist < 42.0:
			# Raycast check for line of sight
			if vision_ray:
				vision_ray.target_position = to_local(player.global_position + Vector3(0, 1.2, 0))
				vision_ray.force_raycast_update()
				if vision_ray.is_colliding() and vision_ray.get_collider() == player:
					attack_target = player
					current_state = State.ATTACK
					return
	
	if current_state == State.ATTACK and (not is_instance_valid(attack_target) or global_position.distance_to(attack_target.global_position) > 48.0):
		attack_target = null
		current_state = State.PATROL
		pick_new_patrol_target()

func handle_patrol(delta: float) -> void:
	var dir = (patrol_target - global_position)
	dir.y = 0
	if dir.length() < 3.0:
		pick_new_patrol_target()
	else:
		dir = dir.normalized()
		velocity.x = dir.x * WALK_SPEED
		velocity.z = dir.z * WALK_SPEED
		look_at_smooth(global_position + dir, delta * 5.0)

func handle_attack(delta: float) -> void:
	if not is_instance_valid(attack_target):
		current_state = State.PATROL
		return
	
	# Face target
	look_at_smooth(attack_target.global_position, delta * 8.0)
	
	# Strafe left/right
	strafe_timer -= delta
	if strafe_timer <= 0.0:
		strafe_timer = randf_range(1.2, 2.5)
		strafe_dir = -strafe_dir
	
	var right_dir = transform.basis.x * strafe_dir
	var to_target = (attack_target.global_position - global_position).normalized()
	var move_dir = (right_dir * 0.7 + to_target * 0.3).normalized()
	
	velocity.x = move_dir.x * WALK_SPEED
	velocity.z = move_dir.z * WALK_SPEED
	
	# Burst shooting
	fire_timer -= delta
	if fire_timer <= 0.0:
		fire_timer = randf_range(0.2, 0.5)
		fire_at_target()

func handle_flee_storm(delta: float) -> void:
	var dir = (storm_center - global_position)
	dir.y = 0
	dir = dir.normalized()
	velocity.x = dir.x * SPRINT_SPEED
	velocity.z = dir.z * SPRINT_SPEED
	look_at_smooth(global_position + dir, delta * 6.0)

func fire_at_target() -> void:
	if not is_instance_valid(attack_target):
		return
	
	if shoot_sound:
		shoot_sound.play()
	
	# Accuracy check (70% accuracy)
	if randf() < 0.70:
		if attack_target.is_in_group("player"):
			Globals.apply_damage(16.0)
		elif attack_target.has_method("take_damage"):
			attack_target.take_damage(16.0)

func take_damage(amount: float, attacker_name: String = "Player") -> void:
	if current_state == State.DEAD:
		return
	
	# Shield absorption
	if shield > 0:
		if shield >= amount:
			shield -= amount
		else:
			var remainder = amount - shield
			shield = 0.0
			health -= remainder
	else:
		health -= amount
	
	# Defensive building: 60% chance to drop defensive wall
	if randf() < 0.60:
		drop_defensive_wall()
	
	if health <= 0:
		eliminate_bot(attacker_name)

func drop_defensive_wall() -> void:
	if WALL_SCENE:
		var wall = WALL_SCENE.instantiate()
		get_tree().current_scene.add_child(wall)
		# Place 3.5m in front of bot
		wall.global_position = global_position - transform.basis.z * 3.5
		wall.global_rotation = global_rotation

func eliminate_bot(killer_name: String) -> void:
	current_state = State.DEAD
	GameManager.register_elimination(bot_name, killer_name, "Assault Rifle")
	
	# Drop loot pickup
	if PICKUP_SCENE:
		var loot = PICKUP_SCENE.instantiate()
		loot.pickup_type = 0 if randf() > 0.5 else 3 # 0: AR, 3: Shield
		get_tree().current_scene.add_child(loot)
		loot.global_position = global_position + Vector3(0, 0.5, 0)
	
	queue_free()

func pick_new_patrol_target() -> void:
	var rx = randf_range(-140.0, 140.0)
	var rz = randf_range(-140.0, 140.0)
	patrol_target = Vector3(rx, global_position.y, rz)

func look_at_smooth(target_pos: Vector3, weight: float) -> void:
	var look_dir = (target_pos - global_position)
	look_dir.y = 0
	if look_dir.length() > 0.1:
		var target_yaw = atan2(-look_dir.x, -look_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, weight)
