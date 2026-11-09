extends Node3D
class_name IslandGenerator

## Procedural 400x400m Low-Poly Island with Terrain, Water, and Foliage Scattering

@export var island_size: float = 400.0
@export var grid_res: int = 40
@export var max_height: float = 24.0
@export var tree_scene: PackedScene = preload("res://scenes/environment/tree.tscn")
@export var rock_scene: PackedScene = preload("res://scenes/environment/rock.tscn")

var noise: FastNoiseLite

@onready var terrain_mesh: MeshInstance3D = $TerrainMesh
@onready var terrain_collider: CollisionShape3D = $TerrainStaticBody/TerrainCollisionShape
@onready var water_mesh: MeshInstance3D = $WaterMesh
@onready var props_container: Node3D = $PropsContainer

func _ready() -> void:
	generate_island()

func generate_island() -> void:
	noise = FastNoiseLite.new()
	noise.seed = 1337
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.008
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var half_size = island_size / 2.0
	var step = island_size / float(grid_res)
	
	# Generate grid vertices with radial falloff towards ocean
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
			
			# Triangle 1
			add_colored_vertex(st, v00)
			add_colored_vertex(st, v10)
			add_colored_vertex(st, v01)
			
			# Triangle 2
			add_colored_vertex(st, v10)
			add_colored_vertex(st, v11)
			add_colored_vertex(st, v01)
	
	st.generate_normals()
	var mesh = st.commit()
	terrain_mesh.mesh = mesh
	
	# Generate exact collision trimesh
	var shape = mesh.create_trimesh_shape()
	terrain_collider.shape = shape
	
	scatter_props()

func add_colored_vertex(st: SurfaceTool, pos: Vector3) -> void:
	# Biome vertex coloring based on elevation and slope
	var col = Color(0.28, 0.65, 0.22) # Grass green
	if pos.y < 1.8:
		col = Color(0.85, 0.78, 0.52) # Sandy beach
	elif pos.y > 15.0:
		col = Color(0.55, 0.55, 0.58) # Rocky peak
	st.set_color(col)
	st.add_vertex(pos)

func get_height_at(x: float, z: float) -> float:
	var dist_from_center = Vector2(x, z).length()
	var max_radius = island_size * 0.45
	
	if dist_from_center >= max_radius:
		return -4.0 # Submerged in ocean
	
	# Radial falloff curve
	var falloff = 1.0 - (dist_from_center / max_radius)
	falloff = smoothstep(0.0, 1.0, falloff)
	
	var n = (noise.get_noise_2d(x, z) + 1.0) * 0.5
	var height = n * max_height * falloff
	
	if dist_from_center > max_radius * 0.85:
		# Shoreline beach level
		height = lerp(height, 0.5, (dist_from_center - max_radius * 0.85) / (max_radius * 0.15))
	
	return height

func scatter_props() -> void:
	if not props_container:
		return
	
	var rand = RandomNumberGenerator.new()
	rand.seed = 42
	
	# Scatter 120 Trees
	for i in range(120):
		var rx = rand.randf_range(-island_size * 0.38, island_size * 0.38)
		var rz = rand.randf_range(-island_size * 0.38, island_size * 0.38)
		var ry = get_height_at(rx, rz)
		if ry > 2.2: # Only on dry grass land
			var tree = tree_scene.instantiate()
			props_container.add_child(tree)
			tree.global_position = Vector3(rx, ry, rz)
			var scale_var = rand.randf_range(0.8, 1.25)
			tree.scale = Vector3(scale_var, scale_var, scale_var)
			tree.rotation.y = rand.randf_range(0, TAU)
	
	# Scatter 80 Rocks
	for i in range(80):
		var rx = rand.randf_range(-island_size * 0.4, island_size * 0.4)
		var rz = rand.randf_range(-island_size * 0.4, island_size * 0.4)
		var ry = get_height_at(rx, rz)
		if ry > 0.5:
			var rock = rock_scene.instantiate()
			props_container.add_child(rock)
			rock.global_position = Vector3(rx, ry, rz)
			var scale_var = rand.randf_range(0.7, 1.4)
			rock.scale = Vector3(scale_var, scale_var, scale_var)
			rock.rotation.y = rand.randf_range(0, TAU)
