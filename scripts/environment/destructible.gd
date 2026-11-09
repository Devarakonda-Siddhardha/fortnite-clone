extends StaticBody3D
class_name DestructibleProp

## Breakable world object using authentic 3D .glb models

@export var max_health: float = 120.0
@export var material_type: Globals.MaterialType = Globals.MaterialType.WOOD
@export var material_yield_on_destroy: int = 30
@export var glb_model_path: String = ""

var current_health: float = 120.0
var model_node: Node3D = null

func _ready() -> void:
	current_health = max_health
	add_to_group("harvestable")
	if material_type == Globals.MaterialType.WOOD:
		add_to_group("tree")
	elif material_type == Globals.MaterialType.STONE:
		add_to_group("rock")
	elif material_type == Globals.MaterialType.METAL:
		add_to_group("metal")
	
	if glb_model_path != "" and ResourceLoader.exists(glb_model_path):
		var glb_res = load(glb_model_path)
		if glb_res is PackedScene:
			model_node = glb_res.instantiate()
			add_child(model_node)
			# Hide primitive placeholder if present
			for child in get_children():
				if child is MeshInstance3D and child != model_node:
					child.visible = false

func take_damage(amount: float) -> void:
	current_health -= amount
	
	# Hit wobble feedback
	if model_node:
		var orig_scale = model_node.scale
		model_node.scale = orig_scale * Vector3(1.08, 0.9, 1.08)
		get_tree().create_timer(0.07).timeout.connect(func():
			if is_instance_valid(model_node):
				model_node.scale = orig_scale
		)
	
	if current_health <= 0.0:
		destroy_prop()

func destroy_prop() -> void:
	Globals.add_material(material_type, material_yield_on_destroy)
	queue_free()
