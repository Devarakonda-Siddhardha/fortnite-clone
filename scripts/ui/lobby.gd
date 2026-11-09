extends Control
class_name GameLobby

## Fortnite Battle Royale Lobby with 3D Character Showcase, Skin Selector, Controls, and Looping Music

@onready var music_player: AudioStreamPlayer = $LobbyMusicPlayer
@onready var play_button: Button = $MainOverlay2/BottomRight/PlayButton
@onready var controls_button: Button = $MainOverlay2/BottomRight/ControlsButton
@onready var close_controls_button: Button = $ControlsPanel/VBox/CloseControlsButton
@onready var skin_container: HBoxContainer = $LockerPanel/SkinList
@onready var controls_panel: PanelContainer = $ControlsPanel
@onready var character_holder: Node3D = $SubViewportContainer/SubViewport/ShowcaseWorld/CharacterHolder
@onready var showcase_camera: Camera3D = $SubViewportContainer/SubViewport/ShowcaseWorld/Camera3D

var current_skin_instance: Node3D = null
var is_dragging_char: bool = false
var last_mouse_pos: Vector2 = Vector2.ZERO
var skin_buttons: Array[Button] = []

const SKINS = [
	{"name": "Y-Bot", "path": "res://assets/characters/YBot.fbx", "color": Color(0.2, 0.6, 1.0)},
	{"name": "Ninja", "path": "res://assets/characters/Ninja.fbx", "color": Color(0.15, 0.15, 0.15)},
	{"name": "Swat", "path": "res://assets/characters/Swat.fbx", "color": Color(0.2, 0.3, 0.4)},
	{"name": "Vanguard", "path": "res://assets/characters/Vanguard.fbx", "color": Color(0.8, 0.6, 0.2)},
	{"name": "Kate", "path": "res://assets/characters/Kate.fbx", "color": Color(0.9, 0.4, 0.5)},
	{"name": "Remy", "path": "res://assets/characters/Remy.fbx", "color": Color(0.3, 0.7, 0.3)}
]

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true
	
	if controls_panel:
		controls_panel.visible = false
	
	start_lobby_music()
	setup_skin_buttons()
	select_skin(Globals.selected_skin_path)
	
	if play_button:
		play_button.pressed.connect(_on_play_pressed)
	if controls_button:
		controls_button.pressed.connect(toggle_controls)
	if close_controls_button:
		close_controls_button.pressed.connect(toggle_controls)
	
	GameManager.return_to_lobby.connect(_on_return_to_lobby)

func _process(delta: float) -> void:
	if not visible:
		return
	# Gentle cinematic idle rotation of character showcase
	if character_holder and not is_dragging_char:
		character_holder.rotate_y(delta * 0.25)

func start_lobby_music() -> void:
	if music_player:
		if not music_player.stream:
			music_player.stream = load("res://assets/audio/lobby_music.mp3")
		music_player.volume_db = -4.0
		if not music_player.playing:
			music_player.play()

func setup_skin_buttons() -> void:
	if not skin_container:
		return
	
	skin_buttons.clear()
	for c in skin_container.get_children():
		c.queue_free()
	
	for skin_info in SKINS:
		var btn = Button.new()
		btn.text = skin_info["name"]
		btn.custom_minimum_size = Vector2(95, 38)
		btn.add_theme_font_size_override("font_size", 14)
		
		# Normal style
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.16, 0.25, 0.9)
		style.border_color = Color(0.3, 0.6, 0.9, 0.8)
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", style)
		
		var s_path = skin_info["path"]
		btn.pressed.connect(func(): select_skin(s_path))
		skin_container.add_child(btn)
		skin_buttons.append(btn)

func select_skin(skin_path: String) -> void:
	Globals.selected_skin_path = skin_path
	
	# Highlight selected button
	for i in range(SKINS.size()):
		if i < skin_buttons.size():
			var btn = skin_buttons[i]
			if SKINS[i]["path"] == skin_path:
				btn.modulate = Color(1.2, 1.2, 0.4, 1.0)
			else:
				btn.modulate = Color(1.0, 1.0, 1.0, 0.8)
	
	# Update 3D showcase character on pedestal
	if not character_holder:
		return
	
	if current_skin_instance:
		current_skin_instance.queue_free()
		current_skin_instance = null
	
	if ResourceLoader.exists(skin_path):
		var res = load(skin_path)
		if res and res is PackedScene:
			current_skin_instance = res.instantiate()
			character_holder.add_child(current_skin_instance)
			
			# Auto-normalize height to 1.80m
			var min_y: float = 9999.0
			var max_y: float = -9999.0
			for m in current_skin_instance.find_children("*", "MeshInstance3D"):
				if m is MeshInstance3D and m.mesh:
					var aabb = m.mesh.get_aabb()
					min_y = min(min_y, aabb.position.y)
					max_y = max(max_y, aabb.position.y + aabb.size.y)
			var mesh_h = max_y - min_y
			var scale_factor = 1.0
			if mesh_h > 0.1:
				scale_factor = 1.80 / mesh_h
			current_skin_instance.scale = Vector3(scale_factor, scale_factor, scale_factor)
			var y_offset = -min_y * scale_factor if min_y < 9000.0 else 0.0
			current_skin_instance.position = Vector3(0, y_offset, 0)
			current_skin_instance.rotation_degrees = Vector3(0, 180, 0)
			
			# Setup benchmark idle animation
			var ap = current_skin_instance.get_node_or_null("AnimationPlayer")
			if not ap:
				for child in current_skin_instance.get_children():
					if child is AnimationPlayer:
						ap = child
						break
			if ap:
				var shared_lib = load("res://assets/animations/mixamo_library.tres")
				if shared_lib:
					if not ap.has_animation_library(""):
						ap.add_animation_library("", shared_lib)
					else:
						var d_lib = ap.get_animation_library("")
						for a_name in shared_lib.get_animation_list():
							if not d_lib.has_animation(a_name):
								d_lib.add_animation(a_name, shared_lib.get_animation(a_name))
					if ap.has_animation("idle"):
						ap.play("idle")

func _gui_input(event: InputEvent) -> void:
	# Click and drag in 3D area to rotate character
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_dragging_char = event.pressed
			last_mouse_pos = event.position
	elif event is InputEventMouseMotion and is_dragging_char:
		var delta_x = event.position.x - last_mouse_pos.x
		last_mouse_pos = event.position
		if character_holder:
			character_holder.rotate_y(delta_x * 0.012)

func _on_play_pressed() -> void:
	# Fade out lobby music
	if music_player and music_player.playing:
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", -40.0, 0.3)
		tween.tween_callback(music_player.stop)
	
	# Start Match
	GameManager.start_match()
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_return_to_lobby() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	start_lobby_music()
	select_skin(Globals.selected_skin_path)

func toggle_controls() -> void:
	if controls_panel:
		controls_panel.visible = not controls_panel.visible
