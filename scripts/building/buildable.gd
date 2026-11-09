extends StaticBody3D
class_name BuildableStructure

## Represents a placed Fortnite building piece (Wall, Floor, Ramp, Roof)
## Dynamically loads authentic 3D .glb models (Wood, Brick/Stone, Metal)

@export var piece_type: Globals.BuildPieceType = Globals.BuildPieceType.WALL
@export var material_type: Globals.MaterialType = Globals.MaterialType.WOOD

var max_hp: float = 150.0
var current_hp: float = 1.0
var build_progress: float = 0.0
var build_time: float = 4.0

var model_node: Node3D = null

func _ready() -> void:
	add_to_group("buildables")
	add_to_group("harvestable")
	setup_material_properties()
	attach_glb_model()

func apply_material_color() -> void:
	setup_material_properties()

func setup_material_properties() -> void:
	match material_type:
		Globals.MaterialType.WOOD:
			max_hp = 150.0
			build_time = 3.5
		Globals.MaterialType.STONE:
			max_hp = 300.0
			build_time = 5.0
		Globals.MaterialType.METAL:
			max_hp = 450.0
			build_time = 7.0
	current_hp = max_hp * 0.4 # Starts at 40% initial HP

func get_model_path() -> String:
	var type_str = ""
	match piece_type:
		Globals.BuildPieceType.WALL: type_str = "wall"
		Globals.BuildPieceType.FLOOR: type_str = "floor"
		Globals.BuildPieceType.RAMP: type_str = "ramp"
		Globals.BuildPieceType.ROOF: type_str = "pyramid_roof"
	
	var mat_str = ""
	match material_type:
		Globals.MaterialType.WOOD: mat_str = "wood"
		Globals.MaterialType.STONE: mat_str = "brick"
		Globals.MaterialType.METAL: mat_str = "metal"
	
	return "res://assets/models/%s_%s.glb" % [type_str, mat_str]

func attach_glb_model() -> void:
	var path = get_model_path()
	if ResourceLoader.exists(path):
		var glb_res = load(path)
		if glb_res is PackedScene:
			model_node = glb_res.instantiate()
			add_child(model_node)
			# Align model to origin
			model_node.position = Vector3.ZERO
			# Hide generic fallback mesh if it exists
			var fallback_mesh = get_node_or_null("MeshInstance3D")
			if fallback_mesh:
				fallback_mesh.visible = false

func _process(delta: float) -> void:
	if build_progress < 1.0:
		build_progress += delta / build_time
		current_hp = lerp(max_hp * 0.4, max_hp, clamp(build_progress, 0.0, 1.0))
		# Construction growth animation
		if model_node:
			var scale_y = clamp(0.2 + 0.8 * build_progress, 0.2, 1.0)
			model_node.scale = Vector3(1.0, scale_y, 1.0)

func take_damage(amount: float) -> void:
	current_hp -= amount
	# Visual hit flash
	if model_node:
		var orig_pos = model_node.position
		model_node.position += Vector3(randf_range(-0.05, 0.05), randf_range(-0.05, 0.05), randf_range(-0.05, 0.05))
		get_tree().create_timer(0.06).timeout.connect(func():
			if is_instance_valid(model_node):
				model_node.position = orig_pos
		)
	
	if current_hp <= 0:
		destroy_piece()

func destroy_piece() -> void:
	queue_free()
