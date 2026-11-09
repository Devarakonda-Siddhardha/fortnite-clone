extends Node3D
class_name IslandGenerator

## Procedural 400x400m Fortnite Island with Biomes, Real Landmarks, and Zone Scattering

@export var island_size: float = 400.0
@export var grid_res: int = 42
@export var max_height: float = 26.0

@export var tree_scene: PackedScene = preload("res://scenes/environment/tree.tscn")
@export var rock_scene: PackedScene = preload("res://scenes/environment/rock.tscn")

var noise: FastNoiseLite

@onready var terrain_mesh: MeshInstance3D = $TerrainMesh
@onready var terrain_collider: CollisionShape3D = $TerrainStaticBody/TerrainCollisionShape
@onready var water_mesh: MeshInstance3D = $WaterMesh
@onready var props_container: Node3D = $PropsContainer

# Landmark GLBs
const HOUSE_PATH = "res://assets/models/house.glb"
const WAREHOUSE_PATH = "res://assets/models/warehouse.glb"
const TOWER_PATH = "res://assets/models/lookout_tower.glb"
const BUS_PATH = "res://assets/models/drop_vehicle.glb"
const CHEST_PATH = "res://scenes/environment/chest.tscn"

func _ready() -> void:
	generate_island()

func generate_island() -> void:
	noise = FastNoiseLite.new()
	noise.seed = 2026
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.007
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var half_size = island_size / 2.0
	var step = island_size / float(grid_res)
	
	# Generate terrain mesh
	for z_idx in range(grid_res):
		for x_idx in range(grid_res):
			var x0 = -half_size + x_idx * step
			var z0 = -half_size + z_idx * step
			var x1 = x0 + step
			var z1 = z0 + step
			
			var y00 = get_height_at(x0, z0)
			var y10 = get_height_at(x1, z0)
			var y01 = get_height_at(x0, z1)
			var y11 = get_height_at(x1, z1)
			
			var v00 = Vector3(x0, y00, z0)
			var v10 = Vector3(x1, y10, z0)
			var v01 = Vector3(x0, y01, z1)
			var v11 = Vector3(x1, y11, z1)
			
			add_colored_vertex(st, v00)
			add_colored_vertex(st, v10)
			add_colored_vertex(st, v01)
			
			add_colored_vertex(st, v10)
			add_colored_vertex(st, v11)
			add_colored_vertex(st, v01)
	
	st.generate_normals()
	var mesh = st.commit()
	terrain_mesh.mesh = mesh
	
	var shape = mesh.create_trimesh_shape()
	terrain_collider.shape = shape
	
	spawn_landmarks()
	scatter_foliage_and_rocks()

func add_colored_vertex(st: SurfaceTool, pos: Vector3) -> void:
	var col = Color(0.32, 0.68, 0.26) # Stylized vibrant grass green
	if pos.y < 1.8:
		col = Color(0.88, 0.82, 0.58) # Sand beach
	elif pos.y > 16.0:
		col = Color(0.55, 0.58, 0.62) # Mountain stone
	st.set_color(col)
	st.add_vertex(pos)

func get_height_at(x: float, z: float) -> float:
	var dist_from_center = Vector2(x, z).length()
	var max_radius = island_size * 0.46
	
	if dist_from_center >= max_radius:
		return -4.0
	
	var falloff = 1.0 - (dist_from_center / max_radius)
	falloff = smoothstep(0.0, 1.0, falloff)
	
	# Flatter center for village plaza
	var center_dist = Vector2(x, z).length()
	if center_dist < 45.0:
		falloff = lerp(0.35, falloff, center_dist / 45.0)
	
	var n = (noise.get_noise_2d(x, z) + 1.0) * 0.5
	var height = n * max_height * falloff
	
	if dist_from_center > max_radius * 0.85:
		height = lerp(height, 0.5, (dist_from_center - max_radius * 0.85) / (max_radius * 0.15))
	
	return height

func spawn_landmarks() -> void:
	if not props_container:
		return
	
	# 1. Center Village: 6 Houses surrounding a plaza
	var house_positions = [
		Vector3(-18, 0, -18), Vector3(18, 0, -18),
		Vector3(-24, 0, 8), Vector3(24, 0, 8),
		Vector3(-12, 0, 32), Vector3(12, 0, 32)
	]
	if ResourceLoader.exists(HOUSE_PATH):
		var house_res = load(HOUSE_PATH)
		for h_pos in house_positions:
			var h_y = get_height_at(h_pos.x, h_pos.z)
			var house = house_res.instantiate()
			props_container.add_child(house)
			house.global_position = Vector3(h_pos.x, h_y, h_pos.z)
			house.rotation.y = randf_range(0, TAU)
			add_structure_collider(house, Vector3(8, 7, 8))
			# Place chest inside house
			if ResourceLoader.exists(CHEST_PATH):
				var chest = load(CHEST_PATH).instantiate()
				props_container.add_child(chest)
				chest.global_position = Vector3(h_pos.x, h_y + 0.3, h_pos.z)
	
	# 2. South-West Industrial Yard: 3 Warehouses
	var warehouse_positions = [
		Vector3(-85, 0, -85), Vector3(-110, 0, -65), Vector3(-65, 0, -110)
	]
	if ResourceLoader.exists(WAREHOUSE_PATH):
		var wh_res = load(WAREHOUSE_PATH)
		for w_pos in warehouse_positions:
			var w_y = get_height_at(w_pos.x, w_pos.z)
			var wh = wh_res.instantiate()
			props_container.add_child(wh)
			wh.global_position = Vector3(w_pos.x, w_y, w_pos.z)
			add_structure_collider(wh, Vector3(14, 7, 10))
			if ResourceLoader.exists(CHEST_PATH):
				var chest = load(CHEST_PATH).instantiate()
				props_container.add_child(chest)
				chest.global_position = Vector3(w_pos.x, w_y + 0.3, w_pos.z)
	
	# 3. Three Lookout Towers on hilltops
	var tower_positions = [
		Vector3(95, 0, -80), Vector3(110, 0, 90), Vector3(-80, 0, 100)
	]
	if ResourceLoader.exists(TOWER_PATH):
		var tower_res = load(TOWER_PATH)
		for t_pos in tower_positions:
			var t_y = get_height_at(t_pos.x, t_pos.z)
			var tower = tower_res.instantiate()
			props_container.add_child(tower)
			tower.global_position = Vector3(t_pos.x, t_y, t_pos.z)
			add_structure_collider(tower, Vector3(4, 10, 4))
	
	# 4. Battle Bus (Flying 80m above island)
	if ResourceLoader.exists(BUS_PATH):
		var bus_res = load(BUS_PATH)
		var bus = bus_res.instantiate()
		props_container.add_child(bus)
		bus.global_position = Vector3(0, 80, 0)
		bus.scale = Vector3(1.2, 1.2, 1.2)

func add_structure_collider(node: Node3D, size: Vector3) -> void:
	var sb = StaticBody3D.new()
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position = Vector3(0, size.y / 2.0, 0)
	sb.add_child(col)
	node.add_child(sb)

func scatter_foliage_and_rocks() -> void:
	var rand = RandomNumberGenerator.new()
	rand.seed = 999
	
	# Tree models
	var tree_glbs = [
		"res://assets/models/tree_pine.glb",
		"res://assets/models/tree_oak.glb",
		"res://assets/models/tree_palm.glb"
	]
	var rock_glbs = [
		"res://assets/models/rock_01.glb",
		"res://assets/models/rock_02.glb",
		"res://assets/models/rock_03.glb",
		"res://assets/models/rock_04.glb",
		"res://assets/models/rock_05.glb"
	]
	
	# Scatter 140 Trees
	for i in range(140):
		var rx = rand.randf_range(-island_size * 0.42, island_size * 0.42)
		var rz = rand.randf_range(-island_size * 0.42, island_size * 0.42)
		var ry = get_height_at(rx, rz)
		if ry > 1.2:
			var tree = tree_scene.instantiate()
			# Palm on beaches, pine in north, oak in west
			if ry < 3.0:
				tree.glb_model_path = tree_glbs[2] # Palm
			elif rz < 0:
				tree.glb_model_path = tree_glbs[0] # Pine
			else:
				tree.glb_model_path = tree_glbs[1] # Oak
			
			props_container.add_child(tree)
			tree.global_position = Vector3(rx, ry, rz)
			var scale_var = rand.randf_range(0.85, 1.3)
			tree.scale = Vector3(scale_var, scale_var, scale_var)
			tree.rotation.y = rand.randf_range(0, TAU)
	
	# Scatter 90 Rocks
	for i in range(90):
		var rx = rand.randf_range(-island_size * 0.43, island_size * 0.43)
		var rz = rand.randf_range(-island_size * 0.43, island_size * 0.43)
		var ry = get_height_at(rx, rz)
		if ry > 0.4:
			var rock = rock_scene.instantiate()
			rock.glb_model_path = rock_glbs[rand.randi() % rock_glbs.size()]
			props_container.add_child(rock)
			rock.global_position = Vector3(rx, ry, rz)
			var scale_var = rand.randf_range(0.8, 1.5)
			rock.scale = Vector3(scale_var, scale_var, scale_var)
			rock.rotation.y = rand.randf_range(0, TAU)
