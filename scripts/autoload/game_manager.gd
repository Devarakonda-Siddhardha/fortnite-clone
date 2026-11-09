extends Node

## Manages 25-Player Battle Royale Match Loop, Alive Count, Killfeed, and Victory Royale

signal match_started()
signal player_eliminated(victim: String, killer: String, weapon: String)
signal alive_count_changed(count: int)
signal victory_royale()
signal game_over()
signal return_to_lobby()

var is_in_match: bool = false
var total_players: int = 25
var players_alive: int = 25:
	set(val):
		players_alive = max(0, val)
		alive_count_changed.emit(players_alive)
		if is_in_match and players_alive <= 1 and not is_player_eliminated:
			victory_royale.emit()

var is_player_eliminated: bool = false
var player_kills: int = 0

func _ready() -> void:
	reset_match()

func reset_match() -> void:
	is_in_match = false
	total_players = 25
	players_alive = 25
	is_player_eliminated = false
	player_kills = 0

func start_match() -> void:
	reset_match()
	is_in_match = true
	match_started.emit()

func go_to_lobby() -> void:
	reset_match()
	return_to_lobby.emit()

func register_elimination(victim_name: String, killer_name: String, weapon_name: String) -> void:
	if not is_in_match:
		return
	player_eliminated.emit(victim_name, killer_name, weapon_name)
	players_alive -= 1
	if killer_name == "Player":
		player_kills += 1

func register_player_death(killer_name: String) -> void:
	if not is_in_match or is_player_eliminated:
		return
	is_player_eliminated = true
	register_elimination("Player", killer_name, "Assault Rifle")
	game_over.emit()
