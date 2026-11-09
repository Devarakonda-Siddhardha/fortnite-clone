extends StaticBody3D
class_name BuildableStructure

## Represents a placed building piece (Wall, Floor, Ramp, Roof)

@export var piece_type: Globals.BuildPieceType = Globals.BuildPieceType.WALL
@export var material_type: Globals.MaterialType = Globals.MaterialType.WOOD

var max_hp: float = 150.0
var current_hp: float = 1.0
var build_progress: float = 0.0
var build_time: float = 4.0 # Time to reach full HP

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	add_to_group("buildables")
	add_to_group("harvestable")
	setup_material_properties()

func setup_material_properties() -> void:
	match material_type:
		Globals.MaterialType.WOOD:
			max_hp = 150.0
			build_time = 4.0
		Globals.MaterialType.STONE:
			max_hp = 300.0
			build_time = 6.0
		Globals.MaterialType.METAL:
			max_hp = 450.0
			build_time = 8.0
	current_hp = max_hp * 0.4 # Starts at 40% health while building

func _process(delta: float) -> void:
	if build_progress < 1.0:
		build_progress += delta / build_time
		current_hp = lerp(max_hp * 0.4, max_hp, clamp(build_progress, 0.0, 1.0))
		# Visual scale / bounce effect on placement
		if mesh_instance:
			var scale_factor = clamp(0.7 + 0.3 * build_progress, 0.7, 1.0)
			mesh_instance.scale = Vector3(1.0, scale_factor, 1.0)

func take_damage(amount: float) -> void:
	current_hp -= amount
	# Flash effect or particle feedback
	if mesh_instance and mesh_instance.get_surface_override_material(0):
		var mat = mesh_instance.get_surface_override_material(0)
		mat.albedo_color = Color(1.0, 0.4, 0.4)
		get_tree().create_timer(0.08).timeout.connect(func():
			if is_instance_valid(self):
				apply_material_color()
		)
	
	if current_hp <= 0:
		destroy_piece()

func destroy_piece() -> void:
	# Clean collapse
	queue_free()

func apply_material_color() -> void:
	if not mesh_instance:
		return
	var mat = StandardMaterial3D.new()
	match material_type:
		Globals.MaterialType.WOOD:
			mat.albedo_color = Color(0.65, 0.45, 0.25) # Stylized warm wood
			mat.roughness = 0.8
		Globals.MaterialType.STONE:
			mat.albedo_color = Color(0.6, 0.6, 0.65) # Cool brick/stone
			mat.roughness = 0.9
		Globals.MaterialType.METAL:
			mat.albedo_color = Color(0.4, 0.45, 0.5) # Galvanized metal
			mat.metallic = 0.6
			mat.roughness = 0.4
	mesh_instance.set_surface_override_material(0, mat)
