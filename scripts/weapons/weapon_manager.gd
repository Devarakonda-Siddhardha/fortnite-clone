extends Node
class_name WeaponManager

## Handles weapons, pickaxe harvesting, weak points, audio SFX, held 3D models, and combat raycasting

@export var player: CharacterBody3D
@export var raycast: RayCast3D

# Audio Streams
var sfx_ar: AudioStream = preload("res://assets/audio/assault_rifle.wav")
var sfx_shotgun: AudioStream = preload("res://assets/audio/shotgun.wav")
var sfx_sniper: AudioStream = preload("res://assets/audio/sniper_rifle.wav")
var sfx_pistol: AudioStream = preload("res://assets/audio/pistol.wav")

# ElevenLabs Sound Effects
var sfx_pickaxe_swing: AudioStream = preload("res://assets/audio/pickaxe_swing.mp3")
var sfx_pickaxe_hit: AudioStream = preload("res://assets/audio/pickaxe_hit.mp3")
var sfx_weakpoint_hit: AudioStream = preload("res://assets/audio/weakpoint_hit.mp3")
var sfx_shield_drink: AudioStream = preload("res://assets/audio/shield_drink.mp3")
var sfx_medkit_use: AudioStream = preload("res://assets/audio/medkit_use.mp3")

var audio_player: AudioStreamPlayer = null

# Held weapon visual representation
var weapon_holder: Node3D = null
var current_weapon_model: Node3D = null
var default_weapon_pos: Vector3 = Vector3(0.28, -0.24, -0.55)

# Weapon stats
var fire_cooldown: float = 0.0

# Harvesting Weak Point State
var active_harvest_target: Node3D = null
var weak_point_position: Vector3 = Vector3.ZERO
var weak_point_active: bool = false
var weak_point_timer: float = 0.0

func _ready() -> void:
	if not player:
		player = get_parent() as CharacterBody3D
	if not raycast and player:
		raycast = player.get_node_or_null("CameraPivot/SpringArm3D/Camera3D/WeaponRayCast")
	
	audio_player = AudioStreamPlayer.new()
	audio_player.name = "WeaponAudioPlayer"
	add_child(audio_player)
	
	call_deferred("setup_held_weapon")

func setup_held_weapon() -> void:
	if not player:
		return
	var cam = player.get_node_or_null("CameraPivot/SpringArm3D/Camera3D")
	if cam:
		weapon_holder = Node3D.new()
		weapon_holder.name = "HeldWeaponHolder"
		cam.add_child(weapon_holder)
		weapon_holder.position = default_weapon_pos
		Globals.active_slot_changed.connect(_on_slot_changed)
		update_held_weapon(Globals.active_slot)

func _on_slot_changed(slot_idx: int) -> void:
	update_held_weapon(slot_idx)

func update_held_weapon(slot_idx: int) -> void:
	if not weapon_holder:
		return
	if current_weapon_model:
		current_weapon_model.queue_free()
		current_weapon_model = null
	
	var glb_path = ""
	var model_scale = Vector3(0.35, 0.35, 0.35)
	var rot_deg = Vector3(0, 180, 0)
	
	match slot_idx:
		0:
			glb_path = "res://assets/models/pickaxe.glb"
			model_scale = Vector3(0.4, 0.4, 0.4)
			rot_deg = Vector3(-15, 140, 20)
		1:
			glb_path = "res://assets/models/assault_rifle.glb"
			model_scale = Vector3(0.32, 0.32, 0.32)
			rot_deg = Vector3(0, 180, 0)
		2:
			glb_path = "res://assets/models/shotgun.glb"
			model_scale = Vector3(0.32, 0.32, 0.32)
			rot_deg = Vector3(0, 180, 0)
		3:
			glb_path = "res://assets/models/sniper_rifle.glb"
			model_scale = Vector3(0.32, 0.32, 0.32)
			rot_deg = Vector3(0, 180, 0)
		4:
			glb_path = "res://assets/models/shield_potion.glb"
			model_scale = Vector3(0.3, 0.3, 0.3)
			rot_deg = Vector3(0, 0, 0)
		5:
			glb_path = "res://assets/models/med_kit.glb"
			model_scale = Vector3(0.3, 0.3, 0.3)
			rot_deg = Vector3(0, 0, 0)
	
	if ResourceLoader.exists(glb_path):
		var res = load(glb_path)
		if res is PackedScene:
			current_weapon_model = res.instantiate()
			weapon_holder.add_child(current_weapon_model)
			current_weapon_model.scale = model_scale
			current_weapon_model.rotation_degrees = rot_deg

func _process(delta: float) -> void:
	if fire_cooldown > 0.0:
		fire_cooldown -= delta
	
	if weak_point_active:
		weak_point_timer -= delta
		if weak_point_timer <= 0.0 or not is_instance_valid(active_harvest_target):
			weak_point_active = false
	
	# Smoothly return weapon holder to default position after recoil kick
	if weapon_holder:
		weapon_holder.visible = not Globals.is_building_mode
		weapon_holder.position = weapon_holder.position.lerp(default_weapon_pos, delta * 15.0)
	
	# Only fire weapons/pickaxe when NOT in building mode
	if not Globals.is_building_mode:
		var is_automatic = (Globals.active_slot == 1)
		var trigger_pressed = Input.is_action_pressed("fire") if is_automatic else Input.is_action_just_pressed("fire")
		if trigger_pressed and fire_cooldown <= 0.0:
			trigger_primary_action()

func trigger_primary_action() -> void:
	match Globals.active_slot:
		0:
			swing_pickaxe()
		1:
			shoot_assault_rifle()
		2:
			shoot_shotgun()
		3:
			shoot_sniper()
		4:
			consume_shield_potion()
		5:
			consume_medkit()

func play_sound(stream: AudioStream, pitch_var: float = 0.08) -> void:
	if audio_player and stream:
		audio_player.stream = stream
		audio_player.pitch_scale = randf_range(1.0 - pitch_var, 1.0 + pitch_var)
		audio_player.play()

func apply_recoil(recoil_z: float = 0.08) -> void:
	if weapon_holder:
		weapon_holder.position.z += recoil_z

func swing_pickaxe() -> void:
	fire_cooldown = 0.45 # Cadence
	play_sound(sfx_pickaxe_swing)
	
	# Trigger 3D character swing animation if available
	if player:
		var anim = player.get_node_or_null("CharacterAnimator")
		if anim and anim.has_method("play_action"):
			anim.play_action("swing")
	
	# Visual swing forward punch
	if weapon_holder:
		weapon_holder.position.z -= 0.12
		weapon_holder.rotation_degrees.x += 15.0
		get_tree().create_timer(0.15).timeout.connect(func():
			if is_instance_valid(weapon_holder):
				weapon_holder.rotation_degrees.x = 0.0
		)
	
	if not raycast or not raycast.is_colliding():
		return
	
	var collider = raycast.get_collider()
	var hit_pos = raycast.get_collision_point()
	
	# Check distance (pickaxe reach is ~4.2m)
	if player and player.global_position.distance_to(hit_pos) > 4.2:
		return
	
	var is_weak_point_hit = false
	if weak_point_active and is_instance_valid(active_harvest_target) and collider == active_harvest_target:
		if hit_pos.distance_to(weak_point_position) < 0.75:
			is_weak_point_hit = true
	
	var damage = 20.0
	var material_yield = 4
	if is_weak_point_hit:
		damage = 50.0
		material_yield = 10
		weak_point_active = false
		play_sound(sfx_weakpoint_hit)
	else:
		# Spawn new weak point on target surface
		spawn_weak_point(collider, hit_pos, raycast.get_collision_normal())
		play_sound(sfx_pickaxe_hit)
	
	# Determine material type and give to player
	if collider.is_in_group("tree") or (collider.is_in_group("buildables") and "material_type" in collider and collider.material_type == Globals.MaterialType.WOOD):
		Globals.add_material(Globals.MaterialType.WOOD, material_yield)
	elif collider.is_in_group("rock") or (collider.is_in_group("buildables") and "material_type" in collider and collider.material_type == Globals.MaterialType.STONE):
		Globals.add_material(Globals.MaterialType.STONE, material_yield)
	elif collider.is_in_group("metal") or (collider.is_in_group("buildables") and "material_type" in collider and collider.material_type == Globals.MaterialType.METAL):
		Globals.add_material(Globals.MaterialType.METAL, material_yield)
	else:
		Globals.add_material(Globals.MaterialType.WOOD, material_yield)
	
	# Apply damage
	if collider.has_method("take_damage"):
		if collider.is_in_group("bots"):
			collider.take_damage(damage, "Player")
		else:
			collider.take_damage(damage)

func spawn_weak_point(target: Node3D, surface_pt: Vector3, normal: Vector3) -> void:
	active_harvest_target = target
	var tangent = normal.cross(Vector3.UP)
	if tangent.length() < 0.1:
		tangent = normal.cross(Vector3.RIGHT)
	tangent = tangent.normalized()
	
	weak_point_position = surface_pt + tangent * randf_range(-0.4, 0.4) + Vector3.UP * randf_range(-0.3, 0.3)
	weak_point_active = true
	weak_point_timer = 2.5

func shoot_assault_rifle() -> void:
	fire_cooldown = 0.12 # Automatic
	play_sound(sfx_ar)
	apply_recoil(0.06)
	fire_hitscan_bullet(32.0, 0.35, "Assault Rifle")

func shoot_shotgun() -> void:
	fire_cooldown = 0.75 # Pump shotgun
	play_sound(sfx_shotgun)
	apply_recoil(0.14)
	# 5 pellet burst
	for i in range(5):
		fire_hitscan_bullet(18.0, 1.2, "Pump Shotgun")

func shoot_sniper() -> void:
	fire_cooldown = 1.3 # Bolt action
	play_sound(sfx_sniper)
	apply_recoil(0.20)
	fire_hitscan_bullet(110.0, 0.05, "Sniper Rifle")

func consume_shield_potion() -> void:
	if Globals.player_shield >= 100.0:
		return
	fire_cooldown = 1.2
	play_sound(sfx_shield_drink)
	Globals.player_shield = min(100.0, Globals.player_shield + 50.0)

func consume_medkit() -> void:
	if Globals.player_health >= 100.0:
		return
	fire_cooldown = 2.0
	play_sound(sfx_medkit_use)
	Globals.player_health = 100.0

func fire_hitscan_bullet(damage: float, spread_amount: float, weapon_name: String) -> void:
	if not raycast:
		return
	
	var spread = Vector3(randf_range(-spread_amount, spread_amount), randf_range(-spread_amount, spread_amount), 0)
	var prev_target = raycast.target_position
	raycast.target_position += spread
	raycast.force_raycast_update()
	
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider.has_method("take_damage"):
			if collider.is_in_group("bots"):
				collider.take_damage(damage, "Player")
			else:
				collider.take_damage(damage)
	
	raycast.target_position = prev_target
