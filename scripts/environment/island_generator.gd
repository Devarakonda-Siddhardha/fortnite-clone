extends Node3D
class_name IslandGenerator

## Procedural 480x480m Fortnite Island with Biomes, 5 Major POIs, 25+ Chests, and Supply Drops

@export var island_size: float = 480.0
@export var grid_res: int = 50
@export var max_height: float = 28.0

@export var tree_scene: PackedScene = preload("res://scenes/environment/tree.tscn")
@export var rock_scene: PackedScene = preload("res://scenes/environment/rock.tscn")
@export var chest_scene: PackedScene = preload("res://scenes/environment/chest.tscn")
@export var supply_drop_scene: PackedScene = preload("res://scenes/environment/supply_drop.tscn")

var noise: FastNoiseLite

@onready var terrain_mesh: MeshInstance3D = $TerrainMesh
@onready var terrain_collider: CollisionShape3D = $TerrainStaticBody/TerrainCollisionShape
@onready var water_mesh: MeshInstance3D = $WaterMesh
@onready var props_container: Node3D = $PropsContainer

# Landmark GLB Paths
const HOUSE_PATH = "res://assets/models/house.glb"
const WAREHOUSE_PATH = "res://assets/models/warehouse.glb"
const TOWER_PATH = "res://assets/models/lookout_tower.glb"
const FENCE_PATH = "res://assets/models/fence_segment.glb"
const CRATE_PATH = "res://assets/models/wood_crate.glb"
const BARREL_PATH = "res://assets/models/barrel.glb"
const BUSH_PATH = "res://assets/models/bush_plain.glb"
const AMMO_BOX_PATH = "res://assets/models/ammo_box.glb"

# POI Definitions
var pois: Array[Dictionary] = [
	{"name": "Pleasant Park", "pos": Vector2(-130, -120), "radius": 70.0},
	{"name": "Tilted Towers", "pos": Vector2(40, 60), "radius": 75.0},
	{"name": "Retail Row", "pos": Vector2(130, -40), "radius": 70.0},
	{"name": "Oasis Bay", "pos": Vector2(-130, 130), "radius": 70.0},
	{"name": "Misty Peaks", "pos": Vector2(120, -130), "radius": 70.0},
	{"name": "Central Plaza", "pos": Vector2(0, 0), "radius": 50.0}
]

var last_poi_name: String = ""
var poi_check_timer: float = 0.0
var supply_drop_timer: float = 30.0

func _ready() -> void:
	generate_island()

func _process(delta: float) -> void:
	if not GameManager.is_in_match:
		return
	
	# POI detection
	poi_check_timer -= delta
	if poi_check_timer <= 0.0:
		poi_check_timer = 0.6
		check_player_poi()
	
	# Supply drop spawner
	supply_drop_timer -= delta
	if supply_drop_timer <= 0.0:
		supply_drop_timer = 50.0
		spawn_supply_drop()

func check_player_poi() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var p_pos = Vector2(player.global_position.x, player.global_position.z)
	var in_any_poi = false
	for poi in pois:
		if p_pos.distance_to(poi.pos) <= poi.radius:
			in_any_poi = true
			if last_poi_name != poi.name:
				last_poi_name = poi.name
				Globals.poi_entered.emit(poi.name)
			break
	if not in_any_poi:
		last_poi_name = ""

func spawn_supply_drop() -> void:
	if not supply_drop_scene or not props_container:
		return
	
	# Drop within 120m of center (safe storm zone)
	var rand_angle = randf_range(0, TAU)
	var rand_dist = randf_range(20.0, 110.0)
	var drop_x = cos(rand_angle) * rand_dist
	var drop_z = sin(rand_angle) * rand_dist
	
	var drop = supply_drop_scene.instantiate()
	props_container.add_child(drop)
	drop.global_position = Vector3(drop_x, 95.0, drop_z)

func generate_island() -> void:
	noise = FastNoiseLite.new()
	noise.seed = 2026
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.006
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var half_size = island_size / 2.0
	var step = island_size / float(grid_res)
	
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
	
	spawn_pois()
	scatter_foliage_and_rocks()

func add_colored_vertex(st: SurfaceTool, pos: Vector3) -> void:
	var col = Color(0.32, 0.68, 0.26) # Stylized vibrant grass green
	if pos.y < 2.0:
		col = Color(0.88, 0.82, 0.58) # Sand beach
	elif pos.y > 18.0:
		col = Color(0.55, 0.58, 0.62) # Mountain stone
	# Oasis area: sandier
	if pos.x < -80 and pos.z > 80 and pos.y < 4.5:
		col = Color(0.88, 0.82, 0.58)
	st.set_color(col)
	st.add_vertex(pos)

func get_height_at(x: float, z: float) -> float:
	var dist_from_center = Vector2(x, z).length()
	var max_radius = island_size * 0.46
	
	if dist_from_center >= max_radius:
		return -4.0
	
	var falloff = 1.0 - (dist_from_center / max_radius)
	falloff = smoothstep(0.0, 1.0, falloff)
	
	# Biome elevation offsets:
	# Misty Peaks (North-East: x > 60, z < -60): Elevated mountain ridge
	var misty_dist = Vector2(x - 120, z - (-130)).length()
	var mountain_boost = 0.0
	if misty_dist < 85.0:
		mountain_boost = (1.0 - (misty_dist / 85.0)) * 14.0
	
	# Oasis Bay (South-West: x < -60, z > 60): low beach depression
	var oasis_dist = Vector2(x - (-130), z - 130).length()
	var oasis_drop = 0.0
	if oasis_dist < 75.0:
		oasis_drop = (1.0 - (oasis_dist / 75.0)) * 0.55
	
	# Flatter town basins for Pleasant Park, Tilted Towers, Retail Row, and Central Plaza
	var pleasant_dist = Vector2(x - (-130), z - (-120)).length()
	var tilted_dist = Vector2(x - 40, z - 60).length()
	var retail_dist = Vector2(x - 130, z - (-40)).length()
	var town_flatten = 1.0
	if pleasant_dist < 55.0:
		town_flatten = 0.35 + 0.65 * (pleasant_dist / 55.0)
	elif tilted_dist < 60.0:
		town_flatten = 0.35 + 0.65 * (tilted_dist / 60.0)
	elif retail_dist < 55.0:
		town_flatten = 0.35 + 0.65 * (retail_dist / 55.0)
	elif dist_from_center < 50.0:
		town_flatten = 0.35 + 0.65 * (dist_from_center / 50.0)
	
	var n = (noise.get_noise_2d(x, z) + 1.0) * 0.5
	var height = (n * max_height + mountain_boost) * falloff * town_flatten * (1.0 - oasis_drop)
	
	if dist_from_center > max_radius * 0.88:
		height = lerp(height, 0.4, (dist_from_center - max_radius * 0.88) / (max_radius * 0.12))
	
	return height

func spawn_pois() -> void:
	if not props_container:
		return
	
	# 1. Pleasant Park (Residential suburb with 5 houses, fences, chests)
	var pleasant_houses = [
		Vector3(-145, 0, -135), Vector3(-115, 0, -135),
		Vector3(-145, 0, -105), Vector3(-115, 0, -105),
		Vector3(-130, 0, -85)
	]
	spawn_houses_and_chests(pleasant_houses)
	spawn_fences(Vector3(-130, 0, -120), 4)
	
	# 2. Tilted Towers / Industrial Center (4 Warehouses, 2 Lookout Towers, Crates, Ammo Boxes, 6 Chests)
	var tilted_warehouses = [
		Vector3(25, 0, 45), Vector3(55, 0, 45),
		Vector3(25, 0, 75), Vector3(55, 0, 75)
	]
	if ResourceLoader.exists(WAREHOUSE_PATH):
		var wh_res = load(WAREHOUSE_PATH)
		for w_pos in tilted_warehouses:
			var w_y = get_height_at(w_pos.x, w_pos.z)
			var wh = wh_res.instantiate()
			props_container.add_child(wh)
			wh.global_position = Vector3(w_pos.x, w_y, w_pos.z)
			add_structure_collider(wh, Vector3(14, 7, 10))
			spawn_chest_at(Vector3(w_pos.x, w_y + 0.3, w_pos.z))
	
	var tilted_towers = [Vector3(15, 0, 60), Vector3(65, 0, 60)]
	spawn_towers(tilted_towers)
	spawn_crates([Vector3(40, 0, 50), Vector3(45, 0, 70), Vector3(30, 0, 65)])
	spawn_chest_at(Vector3(40, get_height_at(40, 60) + 0.3, 60))
	spawn_chest_at(Vector3(50, get_height_at(50, 55) + 0.3, 55))
	
	# 3. Retail Row (4 Houses/shops, Barrels, Crates, 5 Chests)
	var retail_houses = [
		Vector3(115, 0, -55), Vector3(145, 0, -55),
		Vector3(115, 0, -25), Vector3(145, 0, -25)
	]
	spawn_houses_and_chests(retail_houses)
	spawn_barrels([Vector3(130, 0, -40), Vector3(125, 0, -50), Vector3(140, 0, -35)])
	spawn_chest_at(Vector3(130, get_height_at(130, -40) + 0.3, -40))
	
	# 4. Oasis Bay (3 Beach houses, Palm Trees, Barrels, 4 Chests)
	var oasis_houses = [
		Vector3(-145, 0, 115), Vector3(-115, 0, 145), Vector3(-140, 0, 140)
	]
	spawn_houses_and_chests(oasis_houses)
	spawn_chest_at(Vector3(-130, get_height_at(-130, 130) + 0.3, 130))
	
	# 5. Misty Peaks (Lookout Tower, 4 Chests on summit outcrops)
	spawn_towers([Vector3(120, 0, -130)])
	var peak_chests = [
		Vector3(110, 0, -120), Vector3(130, 0, -120),
		Vector3(115, 0, -140), Vector3(135, 0, -140)
	]
	for p in peak_chests:
		spawn_chest_at(Vector3(p.x, get_height_at(p.x, p.z) + 0.3, p.z))
	
	# 6. Central Plaza (3 Houses, Central Monument, 3 Chests)
	var central_houses = [
		Vector3(-22, 0, -15), Vector3(22, 0, -15), Vector3(0, 0, 22)
	]
	spawn_houses_and_chests(central_houses)

func spawn_houses_and_chests(positions: Array) -> void:
	if not ResourceLoader.exists(HOUSE_PATH):
		return
	var house_res = load(HOUSE_PATH)
	for h_pos in positions:
		var h_y = get_height_at(h_pos.x, h_pos.z)
		var house = house_res.instantiate()
		props_container.add_child(house)
		house.global_position = Vector3(h_pos.x, h_y, h_pos.z)
		house.rotation.y = randf_range(0, TAU)
		add_structure_collider(house, Vector3(8, 7, 8))
		spawn_chest_at(Vector3(h_pos.x, h_y + 0.3, h_pos.z))

func spawn_towers(positions: Array) -> void:
	if not ResourceLoader.exists(TOWER_PATH):
		return
	var tower_res = load(TOWER_PATH)
	for t_pos in positions:
		var t_y = get_height_at(t_pos.x, t_pos.z)
		var tower = tower_res.instantiate()
		props_container.add_child(tower)
		tower.global_position = Vector3(t_pos.x, t_y, t_pos.z)
		add_structure_collider(tower, Vector3(4, 10, 4))

func spawn_chest_at(pos: Vector3) -> void:
	if not chest_scene or not props_container:
		return
	var chest = chest_scene.instantiate()
	props_container.add_child(chest)
	chest.global_position = pos

func spawn_fences(center: Vector3, count: int) -> void:
	if not ResourceLoader.exists(FENCE_PATH):
		return
	var fence_res = load(FENCE_PATH)
	for i in range(count):
		var fx = center.x + (i - count / 2.0) * 4.0
		var fz = center.z + 12.0
		var fy = get_height_at(fx, fz)
		var fence = fence_res.instantiate()
		props_container.add_child(fence)
		fence.global_position = Vector3(fx, fy, fz)

func spawn_crates(positions: Array) -> void:
	if not ResourceLoader.exists(CRATE_PATH):
		return
	var crate_res = load(CRATE_PATH)
	for c_pos in positions:
		var cy = get_height_at(c_pos.x, c_pos.z)
		var crate = crate_res.instantiate()
		props_container.add_child(crate)
		crate.global_position = Vector3(c_pos.x, cy + 0.5, c_pos.z)
		add_structure_collider(crate, Vector3(1.2, 1.2, 1.2))

func spawn_barrels(positions: Array) -> void:
	if not ResourceLoader.exists(BARREL_PATH):
		return
	var barrel_res = load(BARREL_PATH)
	for b_pos in positions:
		var by = get_height_at(b_pos.x, b_pos.z)
		var barrel = barrel_res.instantiate()
		props_container.add_child(barrel)
		barrel.global_position = Vector3(b_pos.x, by + 0.4, b_pos.z)
		add_structure_collider(barrel, Vector3(0.9, 1.2, 0.9))

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
	
	# Scatter 180 Trees with Biome Assignment
	for i in range(180):
		var rx = rand.randf_range(-island_size * 0.43, island_size * 0.43)
		var rz = rand.randf_range(-island_size * 0.43, island_size * 0.43)
		var ry = get_height_at(rx, rz)
		if ry > 1.2:
			var tree = tree_scene.instantiate()
			# Palm in Oasis / Beach; Pine in Misty Peaks & North; Oak elsewhere
			if (rx < -70 and rz > 70) or ry < 3.0:
				tree.glb_model_path = tree_glbs[2] # Palm
			elif rz < -40 or ry > 14.0:
				tree.glb_model_path = tree_glbs[0] # Pine
			else:
				tree.glb_model_path = tree_glbs[1] # Oak
			
			props_container.add_child(tree)
			tree.global_position = Vector3(rx, ry, rz)
			var scale_var = rand.randf_range(0.85, 1.35)
			tree.scale = Vector3(scale_var, scale_var, scale_var)
			tree.rotation.y = rand.randf_range(0, TAU)
	
	# Scatter 120 Rocks
	for i in range(120):
		var rx = rand.randf_range(-island_size * 0.44, island_size * 0.44)
		var rz = rand.randf_range(-island_size * 0.44, island_size * 0.44)
		var ry = get_height_at(rx, rz)
		if ry > 0.4:
			var rock = rock_scene.instantiate()
			rock.glb_model_path = rock_glbs[rand.randi() % rock_glbs.size()]
			props_container.add_child(rock)
			rock.global_position = Vector3(rx, ry, rz)
			var scale_var = rand.randf_range(0.8, 1.6)
			rock.scale = Vector3(scale_var, scale_var, scale_var)
			rock.rotation.y = rand.randf_range(0, TAU)
	
	# Scatter 50 Bushes
	if ResourceLoader.exists(BUSH_PATH):
		var bush_res = load(BUSH_PATH)
		for i in range(50):
			var rx = rand.randf_range(-island_size * 0.42, island_size * 0.42)
			var rz = rand.randf_range(-island_size * 0.42, island_size * 0.42)
			var ry = get_height_at(rx, rz)
			if ry > 2.0 and ry < 15.0:
				var bush = bush_res.instantiate()
				props_container.add_child(bush)
				bush.global_position = Vector3(rx, ry, rz)
				bush.rotation.y = rand.randf_range(0, TAU)
