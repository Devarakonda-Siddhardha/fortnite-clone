extends Node
class_name WeaponManager

## Handles weapons, pickaxe harvesting, weak points, and combat raycasting

@export var player: CharacterBody3D
@export var raycast: RayCast3D

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

func _process(delta: float) -> void:
	if fire_cooldown > 0.0:
		fire_cooldown -= delta
	
	if weak_point_active:
		weak_point_timer -= delta
		if weak_point_timer <= 0.0 or not is_instance_valid(active_harvest_target):
			weak_point_active = false
	
	# Only fire weapons/pickaxe when NOT in building mode
	if not Globals.is_building_mode:
		if Input.is_action_pressed("fire") and fire_cooldown <= 0.0:
			trigger_primary_action()

func trigger_primary_action() -> void:
	if Globals.active_slot == 0:
		swing_pickaxe()
	else:
		shoot_weapon()

func swing_pickaxe() -> void:
	fire_cooldown = 0.45 # Pickaxe swing cadence
	
	if not raycast or not raycast.is_colliding():
		return
	
	var collider = raycast.get_collider()
	var hit_pos = raycast.get_collision_point()
	
	# Check distance (pickaxe reach is ~3.5m)
	if player.global_position.distance_to(hit_pos) > 4.2:
		return
	
	var is_weak_point_hit = false
	if weak_point_active and is_instance_valid(active_harvest_target) and collider == active_harvest_target:
		if hit_pos.distance_to(weak_point_position) < 0.65:
			is_weak_point_hit = true
	
	var damage = 20.0
	var material_yield = 4
	if is_weak_point_hit:
		damage = 50.0
		material_yield = 10
		weak_point_active = false
	else:
		# Spawn new weak point on the target surface
		spawn_weak_point(collider, hit_pos, raycast.get_collision_normal())
	
	# Determine material type and give to player
	if collider.is_in_group("tree") or (collider.is_in_group("buildables") and "material_type" in collider and collider.material_type == Globals.MaterialType.WOOD):
		Globals.add_material(Globals.MaterialType.WOOD, material_yield)
	elif collider.is_in_group("rock") or (collider.is_in_group("buildables") and "material_type" in collider and collider.material_type == Globals.MaterialType.STONE):
		Globals.add_material(Globals.MaterialType.STONE, material_yield)
	elif collider.is_in_group("metal") or (collider.is_in_group("buildables") and "material_type" in collider and collider.material_type == Globals.MaterialType.METAL):
		Globals.add_material(Globals.MaterialType.METAL, material_yield)
	else:
		Globals.add_material(Globals.MaterialType.WOOD, material_yield)
	
	# Apply damage to destructible / structure
	if collider.has_method("take_damage"):
		collider.take_damage(damage)

func spawn_weak_point(target: Node3D, surface_pt: Vector3, normal: Vector3) -> void:
	active_harvest_target = target
	# Offset slightly along surface tangent
	var tangent = normal.cross(Vector3.UP)
	if tangent.length() < 0.1:
		tangent = normal.cross(Vector3.RIGHT)
	tangent = tangent.normalized()
	
	weak_point_position = surface_pt + tangent * randf_range(-0.4, 0.4) + Vector3.UP * randf_range(-0.3, 0.3)
	weak_point_active = true
	weak_point_timer = 2.5

func shoot_weapon() -> void:
	fire_cooldown = 0.12 # Fast automatic assault rifle
	
	if not raycast:
		return
	
	# Recoil / spread bloom
	var spread = Vector3(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5), 0)
	var prev_target = raycast.target_position
	raycast.target_position += spread
	raycast.force_raycast_update()
	
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		var hit_pos = raycast.get_collision_point()
		
		# Bullet impact
		if collider.has_method("take_damage"):
			collider.take_damage(32.0)
	
	raycast.target_position = prev_target
