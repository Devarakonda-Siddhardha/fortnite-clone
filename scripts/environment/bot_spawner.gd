extends Node3D
class_name BotSpawner

## Spawns Battle Royale AI Bots across island zones and drops from Battle Bus

@export var bot_scene: PackedScene = preload("res://scenes/bot/bot.tscn")
@export var initial_ground_bots: int = 11

const BOT_NAMES = [
	"Bot_Ninja", "Bot_Vanguard", "Bot_Swat", "Bot_Recon", "Bot_Dusk", "Bot_Ember",
	"Bot_Flare", "Bot_Jungle", "Bot_Sand", "Bot_Tide", "Bot_Blossom", "Bot_Kate",
	"Bot_Remy", "Bot_Jackie", "Bot_Michelle", "Bot_Kaya", "Bot_Timmy", "Bot_Ty",
	"Bot_Granny", "Bot_Vegas", "Bot_Ace", "Bot_Shadow", "Bot_Blaze", "Bot_Frost"
]

func _ready() -> void:
	add_to_group("bot_spawner")
	GameManager.match_started.connect(spawn_initial_bots)
	GameManager.return_to_lobby.connect(clear_all_bots)
	if GameManager.is_in_match:
		call_deferred("spawn_initial_bots")

func clear_all_bots() -> void:
	for c in get_children():
		c.queue_free()

func spawn_initial_bots() -> void:
	clear_all_bots()
	if not bot_scene:
		return
	
	var rand = RandomNumberGenerator.new()
	rand.seed = 777
	
	for i in range(initial_ground_bots):
		var bot = bot_scene.instantiate()
		var bot_name_idx = i % BOT_NAMES.size()
		bot.bot_name = BOT_NAMES[bot_name_idx]
		
		var rx = rand.randf_range(-160.0, 160.0)
		var rz = rand.randf_range(-160.0, 160.0)
		if Vector2(rx, rz).length() < 25.0:
			rx += 35.0
			rz += 35.0
		
		add_child(bot)
		bot.global_position = Vector3(rx, 15.0, rz)

func drop_bot_from_bus(drop_pos: Vector3) -> void:
	if not bot_scene:
		return
	var bot = bot_scene.instantiate()
	var bot_idx = get_child_count() % BOT_NAMES.size()
	bot.bot_name = BOT_NAMES[bot_idx]
	add_child(bot)
	bot.global_position = drop_pos
	
	# Random gliding velocity towards ground
	var rand_angle = randf() * TAU
	bot.velocity = Vector3(cos(rand_angle) * 6.0, -4.5, sin(rand_angle) * 6.0)
