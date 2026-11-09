extends CharacterBody3D
class_name SupplyDrop

## Fortnite Supply Drop (Hot-Air Balloon Falling, Flare, Landed Crate, High-Tier Loot)

@export var pickup_scene: PackedScene = preload("res://scenes/environment/pickup.tscn")
@export var fall_speed: float = 4.5

var is_landed: bool = false
var is_opened: bool = false
var player_in_range: bool = false

var falling_model: Node3D = null
var landed_model: Node3D = null
var flare_light: OmniLight3D = null

@onready var interaction_area: Area3D = $InteractionArea
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

const FALLING_PATH = "res://assets/models/supply_drop_falling.glb"
const LANDED_PATH = "res://assets/models/supply_drop_landed.glb"

func _ready() -> void:
	if ResourceLoader.exists(FALLING_PATH):
		var res_fall = load(FALLING_PATH)
		if res_fall is PackedScene:
			falling_model = res_fall.instantiate()
			add_child(falling_model)
	
	if ResourceLoader.exists(LANDED_PATH):
		var res_land = load(LANDED_PATH)
		if res_land is PackedScene:
			landed_model = res_land.instantiate()
			add_child(landed_model)
			landed_model.visible = false
	
	# Blue Supply Drop Flare Light
	flare_light = OmniLight3D.new()
	flare_light.light_color = Color(0.2, 0.7, 1.0)
	flare_light.light_energy = 3.5
	flare_light.omni_range = 14.0
	flare_light.position = Vector3(0, 1.2, 0)
	add_child(flare_light)
	
	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)

func _physics_process(delta: float) -> void:
	if not is_landed:
		velocity.y = -fall_speed
		move_and_slide()
		
		# Rotate balloon gently while falling
		if falling_model:
			falling_model.rotation.y += delta * 0.4
		
		# Check if touched ground
		if is_on_floor() or global_position.y <= 1.0:
			land()

func land() -> void:
	if is_landed:
		return
	is_landed = true
	velocity = Vector3.ZERO
	
	if falling_model:
		falling_model.visible = false
	if landed_model:
		landed_model.visible = true
	
	# Flare dims slightly to remain visible as a landmark
	if flare_light:
		flare_light.light_color = Color(0.3, 0.8, 1.0)
		flare_light.light_energy = 2.0
		flare_light.omni_range = 8.0

func _unhandled_input(event: InputEvent) -> void:
	if is_landed and player_in_range and not is_opened and event.is_action_pressed("interact"):
		open_supply_drop()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = true

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = false

func open_supply_drop() -> void:
	if is_opened:
		return
	is_opened = true
	
	var sfx = load("res://assets/audio/chest_open.mp3")
	if sfx:
		var asp = AudioStreamPlayer3D.new()
		asp.stream = sfx
		asp.max_distance = 40.0
		add_child(asp)
		asp.play()
	
	if flare_light:
		var tw = create_tween()
		tw.tween_property(flare_light, "light_energy", 0.0, 0.8)
	
	# Massive building materials reward
	Globals.add_material(Globals.MaterialType.WOOD, 100)
	Globals.add_material(Globals.MaterialType.STONE, 100)
	Globals.add_material(Globals.MaterialType.METAL, 100)
	
	# Spawn Legendary Tier Loot Pickups
	if pickup_scene:
		# Gold Assault Rifle
		var ar_drop = pickup_scene.instantiate()
		ar_drop.pickup_type = 0 # Assault Rifle
		get_tree().current_scene.add_child(ar_drop)
		ar_drop.global_position = global_position + Vector3(1.2, 0.8, 0.0)
		
		# Sniper Rifle
		var sn_drop = pickup_scene.instantiate()
		sn_drop.pickup_type = 2 # Sniper
		get_tree().current_scene.add_child(sn_drop)
		sn_drop.global_position = global_position + Vector3(-1.2, 0.8, 0.0)
		
		# Full Shield Potion
		var pot_drop = pickup_scene.instantiate()
		pot_drop.pickup_type = 3 # Shield Potion
		get_tree().current_scene.add_child(pot_drop)
		pot_drop.global_position = global_position + Vector3(0.0, 0.8, 1.2)
		
		# Medkit
		var med_drop = pickup_scene.instantiate()
		med_drop.pickup_type = 4 # Medkit
		get_tree().current_scene.add_child(med_drop)
		med_drop.global_position = global_position + Vector3(0.0, 0.8, -1.2)
