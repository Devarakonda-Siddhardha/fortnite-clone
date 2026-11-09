extends Node3D
class_name BuildingSystem

## Fortnite 4m-Grid Snapping Building System with Turbo Build & Blueprint Hologram

@export var wall_scene: PackedScene = preload("res://scenes/building/wall.tscn")
@export var floor_scene: PackedScene = preload("res://scenes/building/floor.tscn")
@export var ramp_scene: PackedScene = preload("res://scenes/building/ramp.tscn")
@export var roof_scene: PackedScene = preload("res://scenes/building/roof.tscn")

const GRID_SIZE: float = 4.0

var preview_instance: Node3D = null
var preview_mesh: MeshInstance3D = null
var preview_material: StandardMaterial3D = null

var target_grid_position: Vector3 = Vector3.ZERO
var target_rotation_y: float = 0.0
var is_valid_placement: bool = true

# Turbo building: continuous placement when holding left click
var is_placing_continuous: bool = false
var place_cooldown: float = 0.0
const TURBO_BUILD_RATE: float = 0.15 # seconds between builds

@onready var camera: Camera3D = get_viewport().get_camera_3d()

func _ready() -> void:
	setup_preview()

func setup_preview() -> void:
	preview_material = StandardMaterial3D.new()
	preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	preview_material.albedo_color = Color(0.2, 0.6, 1.0, 0.45) # Blueprint holographic blue
	preview_material.emission_enabled = true
	preview_material.emission = Color(0.1, 0.4, 0.9)
	preview_material.emission_energy_multiplier = 0.5
	preview_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	update_preview_mesh()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("build_wall"):
		set_piece(Globals.BuildPieceType.WALL)
	elif event.is_action_pressed("build_floor"):
		set_piece(Globals.BuildPieceType.FLOOR)
	elif event.is_action_pressed("build_ramp"):
		set_piece(Globals.BuildPieceType.RAMP)
	elif event.is_action_pressed("build_roof"):
		set_piece(Globals.BuildPieceType.ROOF)
	elif event.is_action_pressed("aim"): # Right click cycles material in build mode
		if Globals.is_building_mode:
			cycle_material()
			get_viewport().set_input_as_handled()

func set_piece(piece: Globals.BuildPieceType) -> void:
	if Globals.selected_build_piece == piece and Globals.is_building_mode:
		# Toggle out of build mode
		Globals.is_building_mode = false
	else:
		Globals.is_building_mode = true
		Globals.selected_build_piece = piece
	update_preview_mesh()

func cycle_material() -> void:
	match Globals.selected_material:
		Globals.MaterialType.WOOD:
			Globals.selected_material = Globals.MaterialType.STONE
		Globals.MaterialType.STONE:
			Globals.selected_material = Globals.MaterialType.METAL
		Globals.MaterialType.METAL:
			Globals.selected_material = Globals.MaterialType.WOOD
	update_preview_material()

func update_preview_mesh() -> void:
	if preview_instance:
		preview_instance.queue_free()
		preview_instance = null
		preview_mesh = null
	
	if not Globals.is_building_mode:
		return
	
	var scene_to_instance: PackedScene = null
	match Globals.selected_build_piece:
		Globals.BuildPieceType.WALL:
			scene_to_instance = wall_scene
		Globals.BuildPieceType.FLOOR:
			scene_to_instance = floor_scene
		Globals.BuildPieceType.RAMP:
			scene_to_instance = ramp_scene
		Globals.BuildPieceType.ROOF:
			scene_to_instance = roof_scene
	
	if scene_to_instance:
		preview_instance = scene_to_instance.instantiate()
		add_child(preview_instance)
		
		# Disable collision on preview
		for child in preview_instance.get_children():
			if child is CollisionShape3D:
				child.disabled = true
			if child is MeshInstance3D:
				preview_mesh = child
				preview_mesh.material_override = preview_material
		
		# Disable script processing on preview
		preview_instance.set_script(null)

func update_preview_material() -> void:
	if not preview_material:
		return
	if Globals.can_afford_build():
		preview_material.albedo_color = Color(0.2, 0.6, 1.0, 0.45) # Blueprint blue
		preview_material.emission = Color(0.1, 0.4, 0.9)
	else:
		preview_material.albedo_color = Color(1.0, 0.2, 0.2, 0.45) # Red invalid
		preview_material.emission = Color(0.8, 0.1, 0.1)

func _process(delta: float) -> void:
	if place_cooldown > 0.0:
		place_cooldown -= delta
	
	if not Globals.is_building_mode or not preview_instance:
		if preview_instance:
			preview_instance.visible = false
		return
	
	preview_instance.visible = true
	update_preview_material()
	calculate_grid_position()
	
	# Turbo build input
	if Input.is_action_pressed("fire") and place_cooldown <= 0.0:
		try_place_piece()

func calculate_grid_position() -> void:
	if not camera:
		camera = get_viewport().get_camera_3d()
	if not camera:
		return
	
	var space_state = get_world_3d().direct_space_state
	var mouse_pos = get_viewport().get_visible_rect().size / 2.0
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 9.0
	
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var hit = space_state.intersect_ray(query)
	
	var target_point = ray_end
	if hit:
		target_point = hit.position
	
	# Determine facing direction relative to player's camera yaw
	var cam_yaw = camera.global_rotation.y
	# Quantize rotation to 4 cardinal directions (0, 90, 180, 270 deg)
	var quadrant = round(cam_yaw / (PI / 2.0))
	target_rotation_y = quadrant * (PI / 2.0)
	
	# Grid Snap calculation (4m cells)
	var snapped_x = round(target_point.x / GRID_SIZE) * GRID_SIZE
	var snapped_y = round(target_point.y / GRID_SIZE) * GRID_SIZE
	var snapped_z = round(target_point.z / GRID_SIZE) * GRID_SIZE
	
	target_grid_position = Vector3(snapped_x, snapped_y, snapped_z)
	
	# Position preview
	preview_instance.global_position = target_grid_position
	preview_instance.global_rotation = Vector3(0, target_rotation_y, 0)

func try_place_piece() -> void:
	if not Globals.can_afford_build():
		return
	
	# Check if piece already exists at this cell
	if is_piece_overlapping():
		return
	
	var scene_to_spawn: PackedScene = null
	match Globals.selected_build_piece:
		Globals.BuildPieceType.WALL:
			scene_to_spawn = wall_scene
		Globals.BuildPieceType.FLOOR:
			scene_to_spawn = floor_scene
		Globals.BuildPieceType.RAMP:
			scene_to_spawn = ramp_scene
		Globals.BuildPieceType.ROOF:
			scene_to_spawn = roof_scene
	
	if not scene_to_spawn:
		return
	
	if Globals.spend_build_material():
		var new_piece = scene_to_spawn.instantiate()
		new_piece.material_type = Globals.selected_material
		get_tree().current_scene.add_child(new_piece)
		new_piece.global_position = target_grid_position
		new_piece.global_rotation = Vector3(0, target_rotation_y, 0)
		new_piece.apply_material_color()
		
		place_cooldown = TURBO_BUILD_RATE

func is_piece_overlapping() -> bool:
	var space_state = get_world_3d().direct_space_state
	var shape = BoxShape3D.new()
	shape.size = Vector3(1.5, 1.5, 1.5)
	
	var shape_query = PhysicsShapeQueryParameters3D.new()
	shape_query.shape = shape
	shape_query.transform = Transform3D(Basis.from_euler(Vector3(0, target_rotation_y, 0)), target_grid_position + Vector3(0, 1.0, 0))
	shape_query.collision_mask = 8 # Building piece collision layer
	
	var results = space_state.intersect_shape(shape_query, 1)
	return results.size() > 0
