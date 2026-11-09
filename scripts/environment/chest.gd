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

var glow_light: OmniLight3D = null

func _ready() -> void:
	if ResourceLoader.exists(CHEST_MODEL_PATH):
		var glb_res = load(CHEST_MODEL_PATH)
		if glb_res is PackedScene:
			model_node = glb_res.instantiate()
			add_child(model_node)
			lid_node = model_node.find_child("*lid*", true, false)
	
	glow_light = OmniLight3D.new()
	glow_light.light_color = Color(1.0, 0.84, 0.3)
	glow_light.light_energy = 2.2
	glow_light.omni_range = 5.5
	glow_light.position = Vector3(0, 0.5, 0)
	add_child(glow_light)
	
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
	
	# Dim golden glow
	if glow_light:
		var tw = create_tween()
		tw.tween_property(glow_light, "light_energy", 0.0, 0.6)
	
	# Play chest open sound
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
		var tween = create_tween()
		tween.tween_property(model_node, "scale:y", 1.25, 0.15)
		tween.tween_property(model_node, "scale:y", 1.0, 0.15)
	
	# Reward materials
	Globals.add_material(Globals.MaterialType.WOOD, 30)
	Globals.add_material(Globals.MaterialType.STONE, 30)
	Globals.add_material(Globals.MaterialType.METAL, 30)
	
	# Spawn random weapon (AR, Shotgun, or Sniper)
	if pickup_scene:
		var weapon_types = [0, 1, 2]
		var chosen_weapon = weapon_types[randi() % weapon_types.size()]
		var weapon_pickup = pickup_scene.instantiate()
		weapon_pickup.pickup_type = chosen_weapon
		get_tree().current_scene.add_child(weapon_pickup)
		weapon_pickup.global_position = global_position + Vector3(randf_range(-0.8, 0.8), 0.8, randf_range(-0.8, 0.8))
		
		# Spawn consumable (Shield potion or Medkit)
		var consumable_types = [3, 4]
		var chosen_cons = consumable_types[randi() % consumable_types.size()]
		var pot_pickup = pickup_scene.instantiate()
		pot_pickup.pickup_type = chosen_cons
		get_tree().current_scene.add_child(pot_pickup)
		pot_pickup.global_position = global_position + Vector3(randf_range(-0.8, 0.8), 0.8, randf_range(-0.8, 0.8))
