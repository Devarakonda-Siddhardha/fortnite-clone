extends Node3D
class_name TreasureChest

## Interactive Fortnite Treasure Chest with opening lid and loot spawning

@export var pickup_scene: PackedScene = preload("res://scenes/environment/pickup.tscn")

var is_opened: bool = false
var player_in_range: bool = false
var model_node: Node3D = null
var lid_node: Node3D = null

@onready var interaction_area: Area3D = $InteractionArea

const CHEST_MODEL_PATH = "res://assets/models/treasure_chest.glb"

func _ready() -> void:
	if ResourceLoader.exists(CHEST_MODEL_PATH):
		var glb_res = load(CHEST_MODEL_PATH)
		if glb_res is PackedScene:
			model_node = glb_res.instantiate()
			add_child(model_node)
			# Find lid node for rotation
			lid_node = model_node.find_child("*lid*", true, false)
	
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and not is_opened and event.is_action_pressed("interact"):
		open_chest()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = true

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = false

func open_chest() -> void:
	if is_opened:
		return
	is_opened = true
	
	# Play ElevenLabs chest open sound
	var sfx = load("res://assets/audio/chest_open.mp3")
	if sfx:
		var asp = AudioStreamPlayer3D.new()
		asp.stream = sfx
		asp.max_distance = 35.0
		add_child(asp)
		asp.play()
	
	# Open lid rotation
	if lid_node:
		var tween = create_tween()
		tween.tween_property(lid_node, "rotation:x", -deg_to_rad(75.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	elif model_node:
		# If separate lid not found, bounce chest
		var tween = create_tween()
		tween.tween_property(model_node, "scale:y", 1.25, 0.15)
		tween.tween_property(model_node, "scale:y", 1.0, 0.15)
	
	# Reward materials
	Globals.add_material(Globals.MaterialType.WOOD, 30)
	Globals.add_material(Globals.MaterialType.STONE, 30)
	Globals.add_material(Globals.MaterialType.METAL, 30)
	
	# Spawn weapon loot pickup
	if pickup_scene:
		var weapon_pickup = pickup_scene.instantiate()
		weapon_pickup.pickup_type = 0 # AR
		get_tree().current_scene.add_child(weapon_pickup)
		weapon_pickup.global_position = global_position + Vector3(randf_range(-1.0, 1.0), 1.2, randf_range(-1.0, 1.0))
		
		# Spawn shield potion pickup
		var pot_pickup = pickup_scene.instantiate()
		pot_pickup.pickup_type = 3 # Shield Potion
		get_tree().current_scene.add_child(pot_pickup)
		pot_pickup.global_position = global_position + Vector3(randf_range(-1.0, 1.0), 1.2, randf_range(-1.0, 1.0))
