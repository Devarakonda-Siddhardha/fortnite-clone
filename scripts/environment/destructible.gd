extends StaticBody3D
class_name DestructibleProp

## Breakable world object (Trees, Rocks, Crates, Furniture)

@export var max_health: float = 100.0
@export var material_type: Globals.MaterialType = Globals.MaterialType.WOOD
@export var material_yield_on_destroy: int = 25

var current_health: float = 100.0

@onready var mesh: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	current_health = max_health
	add_to_group("harvestable")
	if material_type == Globals.MaterialType.WOOD:
		add_to_group("tree")
	elif material_type == Globals.MaterialType.STONE:
		add_to_group("rock")
	elif material_type == Globals.MaterialType.METAL:
		add_to_group("metal")

func take_damage(amount: float) -> void:
	current_health -= amount
	
	# Squash & stretch / wobble feedback on hit
	if mesh:
		var orig_scale = mesh.scale
		mesh.scale = orig_scale * Vector3(1.1, 0.85, 1.1)
		get_tree().create_timer(0.08).timeout.connect(func():
			if is_instance_valid(mesh):
				mesh.scale = orig_scale
		)
	
	if current_health <= 0.0:
		destroy_prop()

func destroy_prop() -> void:
	Globals.add_material(material_type, material_yield_on_destroy)
	# Clean despawn / fragmentation
	queue_free()
