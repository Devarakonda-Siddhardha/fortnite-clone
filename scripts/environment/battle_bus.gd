extends Node3D
class_name BattleBus

## Fortnite Battle Bus: Aerial drop across the island with balloon, propellers, horn, and skydive jump

signal player_dropped(drop_position: Vector3, forward_vector: Vector3)
signal bus_flight_finished()

@export var flight_start: Vector3 = Vector3(-180, 85, -200)
@export var flight_end: Vector3 = Vector3(180, 85, 200)
@export var flight_duration: float = 16.0

@onready var bus_model_root: Node3D = $BusModel
@onready var bus_camera: Camera3D = $BusCamera
@onready var horn_audio: AudioStreamPlayer = $HornAudio
@onready var engine_audio: AudioStreamPlayer = $EngineAudio
@onready var overlay: Control = $BusOverlay
@onready var timer_label: Label = $BusOverlay/TopBar/VBox/TimerLabel
@onready var passenger_label: Label = $BusOverlay/TopBar/VBox/PassengerLabel

var is_flying: bool = false
var flight_progress: float = 0.0
var player_has_jumped: bool = false
var passengers_left: int = 25
var bot_drop_timer: float = 0.0

var prop_left: Node3D = null
var prop_right: Node3D = null
var flame_mesh: Node3D = null

func _ready() -> void:
	visible = false
	if overlay:
		overlay.visible = false
	
	GameManager.match_started.connect(start_bus_flight)
	GameManager.return_to_lobby.connect(reset_bus)
	
	_setup_model_references()

func _setup_model_references() -> void:
	if not bus_model_root:
		return
	prop_left = bus_model_root.get_node_or_null("drop_vehicle/propeller_left")
	prop_right = bus_model_root.get_node_or_null("drop_vehicle/propeller_right")
	flame_mesh = bus_model_root.get_node_or_null("drop_vehicle/burner_flame")

func start_bus_flight() -> void:
	visible = true
	is_flying = true
	flight_progress = 0.0
	player_has_jumped = false
	passengers_left = 25
	bot_drop_timer = 1.0
	
	global_position = flight_start
	look_at(flight_end, Vector3.UP)
	
	if bus_camera:
		bus_camera.current = true
	
	if overlay:
		overlay.visible = true
		_update_overlay()
	
	# Play Battle Bus horn and engine
	if horn_audio:
		horn_audio.play()
	if engine_audio and not engine_audio.playing:
		engine_audio.play()

func reset_bus() -> void:
	is_flying = false
	visible = false
	flight_progress = 0.0
	player_has_jumped = false
	if overlay:
		overlay.visible = false
	if bus_camera:
		bus_camera.current = false
	if engine_audio and engine_audio.playing:
		engine_audio.stop()

func _process(delta: float) -> void:
	if not is_flying:
		return
	
	flight_progress += delta / flight_duration
	var t = clamp(flight_progress, 0.0, 1.0)
	global_position = flight_start.lerp(flight_end, t)
	look_at(flight_end, Vector3.UP)
	
	# Spin propellers and flicker burner flame
	if prop_left:
		prop_left.rotate_x(delta * 25.0)
	if prop_right:
		prop_right.rotate_x(-delta * 25.0)
	if flame_mesh:
		flame_mesh.scale = Vector3(1.0, randf_range(0.85, 1.25), 1.0)
	
	_update_overlay()
	
	# Drop AI bots periodically along route
	bot_drop_timer -= delta
	if bot_drop_timer <= 0.0 and passengers_left > 1:
		bot_drop_timer = randf_range(0.6, 1.1)
		var drop_count = randi_range(1, 2)
		for _k in range(drop_count):
			if passengers_left > 1:
				passengers_left -= 1
				_spawn_bot_drop()
	
	# Handle Player Jump Key (SPACE)
	if not player_has_jumped:
		if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("ui_accept"):
			drop_player()
	
	# End of flight path -> force drop if still on bus
	if flight_progress >= 1.0:
		if not player_has_jumped:
			drop_player()
		bus_flight_finished.emit()
		is_flying = false
		if engine_audio:
			engine_audio.stop()
		get_tree().create_timer(3.0).timeout.connect(func():
			visible = false
			if overlay:
				overlay.visible = false
		)

func drop_player() -> void:
	if player_has_jumped:
		return
	player_has_jumped = true
	passengers_left = max(0, passengers_left - 1)
	
	if overlay:
		overlay.visible = false
	if bus_camera:
		bus_camera.current = false
	
	# Drop position right beside the bus exit door
	var drop_pos = global_position + (-global_transform.basis.z * 1.5) + (global_transform.basis.x * 3.0) + Vector3(0, -2.0, 0)
	var forward_dir = -global_transform.basis.z
	player_dropped.emit(drop_pos, forward_dir)

func _spawn_bot_drop() -> void:
	var spawner = get_tree().get_first_node_in_group("bot_spawner")
	if not spawner:
		spawner = get_parent().get_node_or_null("BotSpawner")
	if spawner and spawner.has_method("drop_bot_from_bus"):
		var drop_pos = global_position + (global_transform.basis.x * randf_range(-3.0, 3.0)) + Vector3(0, -2.0, 0)
		spawner.drop_bot_from_bus(drop_pos)

func _update_overlay() -> void:
	if not overlay or not overlay.visible:
		return
	var time_left = max(0.0, (1.0 - flight_progress) * flight_duration)
	if timer_label:
		timer_label.text = "DOORS CLOSING IN: %02ds" % int(time_left)
	if passenger_label:
		passenger_label.text = "%d PLAYERS ON BUS" % passengers_left
