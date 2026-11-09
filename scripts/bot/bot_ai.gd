extends CharacterBody3D
class_name BotAI

## Advanced Fortnite Bot AI: Hand-Held Weapons, Defensive Building, Tactical Combat, Healing, and Storm Survival

@export var bot_name: String = "Bot"
@export var max_health: float = 100.0
@export var max_shield: float = 50.0

var health: float = 100.0
var shield: float = 50.0

enum State {
	PATROL,
	ATTACK,
	HEAL,
	FLEE_STORM,
	DEAD
}

var current_state: State = State.PATROL
var patrol_target: Vector3 = Vector3.ZERO
var attack_target: Node3D = null

var fire_timer: float = 0.0
var strafe_timer: float = 0.0
var strafe_dir: float = 1.0
var crouch_dodge_timer: float = 0.0
var is_crouching: bool = false
var heal_timer: float = 0.0

var storm_center: Vector3 = Vector3.ZERO
var storm_radius: float = 300.0

const WALK_SPEED: float = 5.5
const SPRINT_SPEED: float = 8.5
const CROUCH_SPEED: float = 3.2
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var vision_ray: RayCast3D = $VisionRayCast
@onready var shoot_sound: AudioStreamPlayer3D = $ShootSound
@onready var mesh_node: Node3D = $MeshInstance3D
@onready var character_animator: Node3D = $CharacterAnimator

const WALL_SCENE = preload("res://scenes/building/wall.tscn")
const RAMP_SCENE = preload("res://scenes/building/ramp.tscn")
const PICKUP_SCENE = preload("res://scenes/environment/pickup.tscn")
const SFX_BUILD = preload("res://assets/audio/build_place.mp3")
const SFX_DRINK = preload("res://assets/audio/shield_drink.mp3")
const SFX_SHIELD_BREAK = preload("res://assets/audio/shield_break.mp3")

var weapon_model_node: Node3D = null

# Major POI waypoints for strategic bot roaming
const POI_WAYPOINTS: Array[Vector3] = [
	Vector3(-130, 0, -120), # Pleasant Park
	Vector3(40, 0, 60),     # Tilted Towers
	Vector3(130, 0, -40),   # Retail Row
	Vector3(-130, 0, 130),  # Oasis Bay
	Vector3(120, 0, -130),  # Misty Peaks
	Vector3(0, 0, 0)        # Central Plaza
]

func _ready() -> void:
	add_to_group("bots")
	add_to_group("damageable")
	health = max_health
	shield = max_shield
	Globals.storm_updated.connect(_on_storm_updated)
	pick_new_patrol_target()
	
	if character_animator:
		if character_animator.has_signal("character_ready"):
			character_animator.character_ready.connect(_on_character_ready)
		call_deferred("attach_weapon_to_hand")

func _on_character_ready() -> void:
	attach_weapon_to_hand()

func attach_weapon_to_hand() -> void:
	if weapon_model_node and is_instance_valid(weapon_model_node):
		return
	
	if not character_animator:
		return
	
	var hand = character_animator.get_hand_holder() if character_animator.has_method("get_hand_holder") else null
	if not hand:
		# Retry in 0.2s if skeleton is still building
		get_tree().create_timer(0.2).timeout.connect(attach_weapon_to_hand)
		return
	
	var weap_models = [
		"res://assets/models/assault_rifle.glb",
		"res://assets/models/shotgun.glb"
	]
	var chosen_model = weap_models[randi() % weap_models.size()]
	if ResourceLoader.exists(chosen_model):
		var res = load(chosen_model)
		if res is PackedScene:
			weapon_model_node = res.instantiate()
			hand.add_child(weapon_model_node)
			weapon_model_node.scale = Vector3(0.36, 0.36, 0.36)
			weapon_model_node.position = Vector3(0.04, 0.09, 0.03)
			weapon_model_node.rotation_degrees = Vector3(-80, 95, 0)

func _on_storm_updated(radius: float, center: Vector3, _phase: int, _time_left: float) -> void:
	storm_radius = radius
	storm_center = center
	
	var pos_flat = Vector2(global_position.x, global_position.z)
	var center_flat = Vector2(storm_center.x, storm_center.z)
	if pos_flat.distance_to(center_flat) > storm_radius - 12.0:
		current_state = State.FLEE_STORM
	elif current_state == State.FLEE_STORM:
		current_state = State.PATROL

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return
	
	if not is_on_floor():
		if global_position.y > 15.0:
			velocity.y = max(-5.5, velocity.y - gravity * 0.25 * delta)
		else:
			velocity.y -= gravity * delta
	
	scan_for_targets()
	
	match current_state:
		State.PATROL:
			handle_patrol(delta)
		State.ATTACK:
			handle_attack(delta)
		State.HEAL:
			handle_heal(delta)
		State.FLEE_STORM:
			handle_flee_storm(delta)
	
	move_and_slide()
	
	# Update 3D character animation
	if character_animator and character_animator.has_method("update_locomotion"):
		var horiz = Vector2(velocity.x, velocity.z).length()
		var in_air_gliding = not is_on_floor() and global_position.y > 8.0
		var is_aim = (current_state == State.ATTACK)
		var is_fleeing = (current_state == State.FLEE_STORM)
		character_animator.update_locomotion(horiz, is_fleeing, false, in_air_gliding, is_aim, 1)

func scan_for_targets() -> void:
	if current_state == State.HEAL or current_state == State.DEAD:
		return
	
	var player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		if dist < 45.0:
			if vision_ray:
				vision_ray.target_position = to_local(player.global_position + Vector3(0, 1.2, 0))
				vision_ray.force_raycast_update()
				if vision_ray.is_colliding() and vision_ray.get_collider() == player:
					attack_target = player
					current_state = State.ATTACK
					return
	
	if current_state == State.ATTACK and (not is_instance_valid(attack_target) or global_position.distance_to(attack_target.global_position) > 52.0):
		attack_target = null
		current_state = State.PATROL
		pick_new_patrol_target()

func handle_patrol(delta: float) -> void:
	var dir = (patrol_target - global_position)
	dir.y = 0
	if dir.length() < 4.0:
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
	
	# Tactical strafing left & right
	strafe_timer -= delta
	if strafe_timer <= 0.0:
		strafe_timer = randf_range(1.2, 2.4)
		strafe_dir = -strafe_dir
		# 30% chance to crouch dodge during firefight
		is_crouching = (randf() < 0.35)
	
	var right_dir = transform.basis.x * strafe_dir
	var to_target = (attack_target.global_position - global_position).normalized()
	var move_dir = (right_dir * 0.75 + to_target * 0.25).normalized()
	
	var move_speed = CROUCH_SPEED if is_crouching else WALK_SPEED
	velocity.x = move_dir.x * move_speed
	velocity.z = move_dir.z * move_speed
	
	# Jump dodge occasionally if on floor
	if is_on_floor() and randf() < 0.015:
		velocity.y = 6.5
	
	# Burst shooting
	fire_timer -= delta
	if fire_timer <= 0.0:
		fire_timer = randf_range(0.22, 0.45)
		fire_at_target()

func handle_heal(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, delta * 10.0)
	velocity.z = move_toward(velocity.z, 0, delta * 10.0)
	
	heal_timer -= delta
	if heal_timer <= 0.0:
		# Finish heal
		shield = min(max_shield, shield + 50.0)
		health = min(max_health, health + 25.0)
		current_state = State.ATTACK if is_instance_valid(attack_target) else State.PATROL

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
		shoot_sound.pitch_scale = randf_range(0.95, 1.05)
		shoot_sound.play()
	
	# Realistic spread (70% accuracy at mid range)
	var dist = global_position.distance_to(attack_target.global_position)
	var hit_chance = clamp(0.85 - (dist / 60.0) * 0.35, 0.45, 0.85)
	if randf() < hit_chance:
		var dmg = randf_range(16.0, 24.0)
		if attack_target.is_in_group("player"):
			Globals.apply_damage(dmg)
		elif attack_target.has_method("take_damage"):
			attack_target.take_damage(dmg, bot_name)

func take_damage(amount: float, attacker_name: String = "Player") -> void:
	if current_state == State.DEAD:
		return
	
	var player = get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		attack_target = player
		if current_state != State.FLEE_STORM:
			current_state = State.ATTACK
	
	# Shield absorption
	if shield > 0:
		if shield >= amount:
			shield -= amount
		else:
			var remainder = amount - shield
			shield = 0.0
			health -= remainder
			play_sound(SFX_SHIELD_BREAK)
	else:
		health -= amount
	
	# Defensive building: 75% chance to drop defensive wall
	if randf() < 0.75:
		drop_defensive_wall()
	
	# Low HP tactic: Retreat & Heal below 45 HP
	if health < 45.0 and current_state != State.HEAL and randf() < 0.65:
		start_healing()
	
	if health <= 0:
		eliminate_bot(attacker_name)

func drop_defensive_wall() -> void:
	if not WALL_SCENE:
		return
	
	var wall = WALL_SCENE.instantiate()
	get_tree().current_scene.add_child(wall)
	
	# Place wall 3.2m in front of bot facing threat
	var wall_pos = global_position - transform.basis.z * 3.2
	wall.global_position = Vector3(wall_pos.x, global_position.y, wall_pos.z)
	wall.global_rotation = global_rotation
	play_sound(SFX_BUILD)
	
	# 35% chance to also place a ramp behind the wall for high ground
	if randf() < 0.35 and RAMP_SCENE:
		var ramp = RAMP_SCENE.instantiate()
		get_tree().current_scene.add_child(ramp)
		var ramp_pos = global_position - transform.basis.z * 1.5
		ramp.global_position = Vector3(ramp_pos.x, global_position.y, ramp_pos.z)
		ramp.global_rotation = global_rotation

func start_healing() -> void:
	current_state = State.HEAL
	heal_timer = 2.5
	play_sound(SFX_DRINK)
	if character_animator and character_animator.has_method("play_action_animation"):
		character_animator.play_action_animation("drink", 2.4)

func play_sound(stream: AudioStream) -> void:
	if not stream:
		return
	var asp = AudioStreamPlayer3D.new()
	asp.stream = stream
	asp.max_distance = 45.0
	add_child(asp)
	asp.play()
	get_tree().create_timer(3.0).timeout.connect(asp.queue_free)

func eliminate_bot(killer_name: String) -> void:
	current_state = State.DEAD
	GameManager.register_elimination(bot_name, killer_name, "Assault Rifle")
	
	# Drop loot pickup
	if PICKUP_SCENE:
		var loot = PICKUP_SCENE.instantiate()
		loot.pickup_type = 0 if randf() > 0.5 else 3
		get_tree().current_scene.add_child(loot)
		loot.global_position = global_position + Vector3(0, 0.6, 0)
	
	queue_free()

func pick_new_patrol_target() -> void:
	# 60% chance to patrol toward a major POI
	if randf() < 0.6 and POI_WAYPOINTS.size() > 0:
		var wp = POI_WAYPOINTS[randi() % POI_WAYPOINTS.size()]
		var offset = Vector3(randf_range(-30, 30), 0, randf_range(-30, 30))
		patrol_target = wp + offset
	else:
		var rx = randf_range(-160.0, 160.0)
		var rz = randf_range(-160.0, 160.0)
		patrol_target = Vector3(rx, global_position.y, rz)

func look_at_smooth(target_pos: Vector3, weight: float) -> void:
	var look_dir = (target_pos - global_position)
	look_dir.y = 0
	if look_dir.length() > 0.1:
		var target_yaw = atan2(-look_dir.x, -look_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, weight)
