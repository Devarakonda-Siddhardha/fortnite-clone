extends Node3D
class_name StormSystem

## Fortnite-Style Shrinking Storm System (5 Phases, HP Damage, Visual Barrier)

@export var current_phase: int = 1
@export var current_radius: float = 300.0
@export var target_radius: float = 300.0
@export var current_center: Vector3 = Vector3.ZERO
@export var target_center: Vector3 = Vector3.ZERO

var phase_duration: float = 60.0
var phase_timer: float = 60.0
var dps: float = 1.0 # Damage per second

# 5 Phase Radius targets
const PHASE_RADII = [300.0, 200.0, 120.0, 60.0, 20.0]
const PHASE_DPS = [1.0, 2.0, 3.0, 5.0, 10.0]

@onready var storm_mesh: MeshInstance3D = $StormMesh

var damage_tick_timer: float = 0.0

func _ready() -> void:
	start_phase(1)

func start_phase(phase: int) -> void:
	current_phase = phase
	if phase - 1 < PHASE_RADII.size():
		target_radius = PHASE_RADII[phase - 1]
		dps = PHASE_DPS[phase - 1]
	else:
		target_radius = 5.0
		dps = 10.0
	
	phase_duration = 45.0
	phase_timer = phase_duration
	
	# Randomize new center within current safe circle
	if phase > 1:
		var max_offset = current_radius - target_radius
		if max_offset > 0:
			var rand_angle = randf() * TAU
			var rand_dist = randf() * max_offset * 0.7
			target_center = current_center + Vector3(cos(rand_angle) * rand_dist, 0, sin(rand_angle) * rand_dist)

func _process(delta: float) -> void:
	phase_timer -= delta
	if phase_timer <= 0.0:
		start_phase(current_phase + 1)
	
	# Shrink storm radius and shift center smoothly
	current_radius = lerp(current_radius, target_radius, delta * 0.1)
	current_center = current_center.lerp(target_center, delta * 0.1)
	
	# Update visual cylinder scale
	if storm_mesh:
		storm_mesh.global_position = current_center
		storm_mesh.scale = Vector3(current_radius * 2.0, 80.0, current_radius * 2.0)
	
	# Damage check every 1 second
	damage_tick_timer += delta
	if damage_tick_timer >= 1.0:
		damage_tick_timer = 0.0
		check_storm_damage()
	
	# Broadcast update to UI / Minimap
	Globals.storm_updated.emit(current_radius, current_center, current_phase, max(0.0, phase_timer))

func check_storm_damage() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var player_pos_flat = Vector3(player.global_position.x, 0, player.global_position.z)
		var storm_center_flat = Vector3(current_center.x, 0, current_center.z)
		var dist = player_pos_flat.distance_to(storm_center_flat)
		
		if dist > current_radius:
			# Player is in the storm! Direct HP damage bypasses shield
			Globals.apply_damage(dps, true)
