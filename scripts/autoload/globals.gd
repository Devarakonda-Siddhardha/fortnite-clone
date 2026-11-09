extends Node

## Global Game State, Events, and Economy

signal health_changed(current: float, max_val: float)
signal shield_changed(current: float, max_val: float)
signal materials_changed(wood: int, stone: int, metal: int)
signal active_slot_changed(slot_idx: int)
signal storm_updated(radius: float, center: Vector3, phase: int, time_left: float)
signal scoping_changed(is_scoping: bool, is_sniper: bool)
signal ammo_changed(current_mag: int, reserve: int)
signal poi_entered(poi_name: String)

enum MaterialType {
	WOOD,
	STONE,
	METAL
}

enum BuildPieceType {
	NONE,
	WALL,
	FLOOR,
	RAMP,
	ROOF
}

var max_health: float = 100.0
var player_health: float = 100.0:
	set(val):
		var upper = max(max_health, val)
		player_health = clamp(val, 0.0, upper)
		health_changed.emit(player_health, upper)

var max_shield: float = 100.0
var player_shield: float = 100.0:
	set(val):
		var upper = max(max_shield, val)
		player_shield = clamp(val, 0.0, upper)
		shield_changed.emit(player_shield, upper)

# Building Resources
var wood: int = 200:
	set(val):
		wood = max(0, val)
		materials_changed.emit(wood, stone, metal)

var stone: int = 150:
	set(val):
		stone = max(0, val)
		materials_changed.emit(wood, stone, metal)

var metal: int = 100:
	set(val):
		metal = max(0, val)
		materials_changed.emit(wood, stone, metal)

const BUILD_COST: int = 10

# Inventory (Slot 0 is Pickaxe, Slots 1-5 are weapons/items)
var active_slot: int = 0:
	set(val):
		active_slot = clamp(val, 0, 5)
		active_slot_changed.emit(active_slot)

# Building Mode State
var is_building_mode: bool = false
var selected_build_piece: BuildPieceType = BuildPieceType.WALL
var selected_material: MaterialType = MaterialType.WOOD

# Selected Character Skin
var selected_skin_path: String = "res://assets/characters/YBot.fbx"

# Mobile Virtual Controls State
var mobile_move_vector: Vector2 = Vector2.ZERO
var mobile_sprint: bool = false
var mobile_fire: bool = false
var mobile_aim: bool = false
var mobile_jump_pressed: bool = false
var mobile_crouch_pressed: bool = false
var mobile_reload_pressed: bool = false
var mobile_interact_pressed: bool = false
var mobile_controls_enabled: bool = false
signal mobile_controls_toggled(enabled: bool)

func reset_player_stats() -> void:
	player_health = 100.0
	player_shield = 100.0
	wood = 200
	stone = 150
	metal = 100
	active_slot = 0
	is_building_mode = false

func can_afford_build(mat_type: MaterialType = selected_material) -> bool:
	match mat_type:
		MaterialType.WOOD:
			return wood >= BUILD_COST
		MaterialType.STONE:
			return stone >= BUILD_COST
		MaterialType.METAL:
			return metal >= BUILD_COST
	return false

func spend_build_material(mat_type: MaterialType = selected_material) -> bool:
	if not can_afford_build(mat_type):
		return false
	match mat_type:
		MaterialType.WOOD:
			wood -= BUILD_COST
		MaterialType.STONE:
			stone -= BUILD_COST
		MaterialType.METAL:
			metal -= BUILD_COST
	return true

func add_material(mat_type: MaterialType, amount: int) -> void:
	match mat_type:
		MaterialType.WOOD:
			wood += amount
		MaterialType.STONE:
			stone += amount
		MaterialType.METAL:
			metal += amount

func apply_damage(amount: float, bypass_shield: bool = false) -> void:
	if bypass_shield or player_shield <= 0.0:
		player_health -= amount
	else:
		if player_shield >= amount:
			player_shield -= amount
		else:
			var remainder = amount - player_shield
			player_shield = 0.0
			player_health -= remainder
			
			# Play ElevenLabs shield break sound
			var sfx = load("res://assets/audio/shield_break.mp3")
			if sfx:
				var asp = AudioStreamPlayer.new()
				asp.stream = sfx
				add_child(asp)
				asp.play()
				get_tree().create_timer(1.5).timeout.connect(asp.queue_free)
	
	if player_health <= 0.0:
		var gm = get_node_or_null("/root/GameManager")
		if gm and not gm.is_player_eliminated:
			gm.register_player_death("Storm" if bypass_shield else "Bot")
