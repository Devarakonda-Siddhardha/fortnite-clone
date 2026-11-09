extends Area3D
class_name GroundPickup

## Floating rotating item pickup (Weapons, Shield Potions, Medkits)

enum PickupType {
	ASSAULT_RIFLE,
	SHOTGUN,
	SNIPER,
	SHIELD_POTION,
	MEDKIT
}

@export var pickup_type: PickupType = PickupType.ASSAULT_RIFLE
@export var rarity_color: Color = Color(0.2, 0.6, 1.0) # Rare blue

var model_node: Node3D = null
var base_y: float = 0.0
var time_elapsed: float = 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Player layer
	body_entered.connect(_on_body_entered)
	base_y = position.y
	setup_model()

func setup_model() -> void:
	var glb_path = ""
	match pickup_type:
		PickupType.ASSAULT_RIFLE: glb_path = "res://assets/models/assault_rifle.glb"
		PickupType.SHOTGUN: glb_path = "res://assets/models/shotgun.glb"
		PickupType.SNIPER: glb_path = "res://assets/models/sniper_rifle.glb"
		PickupType.SHIELD_POTION: glb_path = "res://assets/models/shield_potion.glb"
		PickupType.MEDKIT: glb_path = "res://assets/models/med_kit.glb"
	
	if ResourceLoader.exists(glb_path):
		var res = load(glb_path)
		if res is PackedScene:
			model_node = res.instantiate()
			add_child(model_node)
			model_node.position = Vector3(0, 0.4, 0)
			# Scale down slightly for pickup look
			model_node.scale = Vector3(0.8, 0.8, 0.8)

func _process(delta: float) -> void:
	time_elapsed += delta
	# Floating bobbing and rotation
	position.y = base_y + sin(time_elapsed * 2.5) * 0.15
	rotation.y += delta * 1.5

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		collect_pickup()

func collect_pickup() -> void:
	match pickup_type:
		PickupType.SHIELD_POTION:
			Globals.player_shield = min(100.0, Globals.player_shield + 50.0)
		PickupType.MEDKIT:
			Globals.player_health = 100.0
		PickupType.ASSAULT_RIFLE:
			Globals.active_slot = 1
		PickupType.SHOTGUN:
			Globals.active_slot = 2
		PickupType.SNIPER:
			Globals.active_slot = 3
	
	# Clean pickup
	queue_free()
