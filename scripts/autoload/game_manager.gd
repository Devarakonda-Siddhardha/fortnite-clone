extends Node

## Manages 25-Player Battle Royale Match Loop, Alive Count, Killfeed, and Victory Royale

signal match_started()
signal player_eliminated(victim: String, killer: String, weapon: String)
signal alive_count_changed(count: int)
signal victory_royale()
signal game_over()

var total_players: int = 25
var players_alive: int = 25:
	set(val):
		players_alive = max(0, val)
		alive_count_changed.emit(players_alive)
		if players_alive == 1 and not is_player_eliminated:
			victory_royale.emit()

var is_player_eliminated: bool = false
var player_kills: int = 0

func _ready() -> void:
	reset_match()

func reset_match() -> void:
	total_players = 25
	players_alive = 25
	is_player_eliminated = false
	player_kills = 0

func register_elimination(victim_name: String, killer_name: String, weapon_name: String) -> void:
	player_eliminated.emit(victim_name, killer_name, weapon_name)
	players_alive -= 1
	if killer_name == "Player":
		player_kills += 1

func register_player_death(killer_name: String) -> void:
	is_player_eliminated = true
	register_elimination("Player", killer_name, "Assault Rifle")
	game_over.emit()
