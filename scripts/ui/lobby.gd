extends Control
class_name GameLobby

## Fortnite Chapter 5 Battle Royale Lobby
## Implements: Top Nav Bar, Admin Panel, Game Mode Selector, Locker Skin Selector, Squad Pedestals, and Looping Music

@onready var music_player: AudioStreamPlayer = $LobbyMusicPlayer
@onready var play_button: Button = $LeftCard/VBox/PlayButton
@onready var mode_button: Button = $LeftCard/VBox/ModePill
@onready var equipped_card: PanelContainer = $LeftCard/VBox/EquippedBanner
@onready var equipped_name_label: Label = $LeftCard/VBox/EquippedBanner/HBox/VBox/ItemName

# Top Bar
@onready var admin_button: Button = $TopBar/HBox/RightControls/AdminButton
@onready var locker_nav_btn: Button = $TopBar/HBox/NavTabs/LockerBtn
@onready var play_nav_btn: Button = $TopBar/HBox/NavTabs/PlayBtn
@onready var music_toggle_btn: Button = $RightBadges/MusicButton

# Modals
@onready var admin_panel: PanelContainer = $AdminPanel
@onready var locker_panel: PanelContainer = $LockerPanel
@onready var controls_panel: PanelContainer = $ControlsPanel
@onready var skin_grid: GridContainer = $LockerPanel/VBox/SkinGrid

# 3D Showcase
@onready var character_holder: Node3D = $SubViewportContainer/SubViewport/ShowcaseWorld/CharacterHolder
@onready var showcase_camera: Camera3D = $SubViewportContainer/SubViewport/ShowcaseWorld/Camera3D

var current_skin_instance: Node3D = null
var is_dragging_char: bool = false
var last_mouse_pos: Vector2 = Vector2.ZERO
var is_zero_build: bool = true
var is_ready: bool = false

const SKINS = [
	{"name": "Kate", "path": "res://assets/characters/Kate.fbx", "rarity": "RARE", "tag": "Anime Heroine"},
	{"name": "Y-Bot", "path": "res://assets/characters/YBot.fbx", "rarity": "EPIC", "tag": "Robotic Champion"},
	{"name": "Ninja", "path": "res://assets/characters/Ninja.fbx", "rarity": "LEGENDARY", "tag": "Shadow Assassin"},
	{"name": "Swat", "path": "res://assets/characters/Swat.fbx", "rarity": "RARE", "tag": "Tactical Operative"},
	{"name": "Vanguard", "path": "res://assets/characters/Vanguard.fbx", "rarity": "EPIC", "tag": "Armored Enforcer"},
	{"name": "Remy", "path": "res://assets/characters/Remy.fbx", "rarity": "UNCOMMON", "tag": "Island Fighter"}
]

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true
	
	if admin_panel: admin_panel.visible = false
	if locker_panel: locker_panel.visible = false
	if controls_panel: controls_panel.visible = false
	
	start_lobby_music()
	setup_locker_grid()
	
	# Default to Kate (matching pink-haired character in screenshot!) if default was YBot
	if Globals.selected_skin_path == "res://assets/characters/YBot.fbx":
		Globals.selected_skin_path = "res://assets/characters/Kate.fbx"
	
	select_skin(Globals.selected_skin_path)
	
	# Connect Button Events
	if play_button:
		play_button.pressed.connect(_on_play_pressed)
	if mode_button:
		mode_button.pressed.connect(_on_toggle_mode)
	if admin_button:
		admin_button.pressed.connect(_toggle_admin_panel)
	if locker_nav_btn:
		locker_nav_btn.pressed.connect(_toggle_locker_panel)
	if play_nav_btn:
		play_nav_btn.pressed.connect(func():
			if locker_panel: locker_panel.visible = false
			if admin_panel: admin_panel.visible = false
		)
	if music_toggle_btn:
		music_toggle_btn.pressed.connect(_on_toggle_music)
	if equipped_card:
		equipped_card.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_toggle_locker_panel()
		)
	
	var other_tabs = ["OverrideBtn", "ShopBtn", "PassesBtn", "QuestsBtn", "CompeteBtn", "CareerBtn"]
	for t_name in other_tabs:
		var t_btn = get_node_or_null("TopBar/HBox/NavTabs/" + t_name)
		if t_btn and t_btn is Button:
			t_btn.pressed.connect(_toggle_controls_panel)
	
	_connect_admin_actions()
	GameManager.return_to_lobby.connect(_on_return_to_lobby)

func _process(delta: float) -> void:
	if not visible:
		return
	if character_holder and not is_dragging_char:
		character_holder.rotate_y(delta * 0.18)

func start_lobby_music() -> void:
	if music_player:
		if not music_player.stream:
			music_player.stream = load("res://assets/audio/lobby_music.mp3")
		music_player.volume_db = -4.0
		if not music_player.playing:
			music_player.play()

func _on_toggle_music() -> void:
	if not music_player:
		return
	if music_player.playing:
		music_player.stop()
		if music_toggle_btn:
			music_toggle_btn.modulate = Color(0.6, 0.6, 0.6, 0.6)
	else:
		music_player.play()
		if music_toggle_btn:
			music_toggle_btn.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _on_toggle_mode() -> void:
	is_zero_build = not is_zero_build
	if mode_button:
		if is_zero_build:
			mode_button.text = "👥  Zero Build, Solo  ●"
			Globals.is_building_mode = false
		else:
			mode_button.text = "👥  Battle Royale, Solo  ●"

func setup_locker_grid() -> void:
	if not skin_grid:
		return
	for c in skin_grid.get_children():
		c.queue_free()
	
	for skin in SKINS:
		var btn = Button.new()
		btn.text = "%s\n[%s]" % [skin["name"], skin["rarity"]]
		btn.custom_minimum_size = Vector2(130, 64)
		btn.add_theme_font_size_override("font_size", 13)
		
		var s_path = skin["path"]
		btn.pressed.connect(func():
			select_skin(s_path)
			if locker_panel:
				locker_panel.visible = false
		)
		skin_grid.add_child(btn)

func select_skin(skin_path: String) -> void:
	Globals.selected_skin_path = skin_path
	
	# Update equipped banner text
	var skin_name = "Kate"
	for s in SKINS:
		if s["path"] == skin_path:
			skin_name = s["name"]
			break
	if equipped_name_label:
		equipped_name_label.text = "%s Equipped" % skin_name
	
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
			
			# Auto-normalize height to 1.80m so feet always rest cleanly on pedestal
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
	if music_player and music_player.playing:
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", -40.0, 0.3)
		tween.tween_callback(music_player.stop)
	
	GameManager.start_match()
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_return_to_lobby() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	start_lobby_music()
	select_skin(Globals.selected_skin_path)

func _toggle_admin_panel() -> void:
	if admin_panel:
		admin_panel.visible = not admin_panel.visible

func _toggle_locker_panel() -> void:
	if locker_panel:
		locker_panel.visible = not locker_panel.visible

func _toggle_controls_panel() -> void:
	if controls_panel:
		controls_panel.visible = not controls_panel.visible

func _connect_admin_actions() -> void:
	if not admin_panel:
		return
	
	var btn_god = admin_panel.get_node_or_null("VBox/Grid/GodModeBtn")
	if btn_god:
		btn_god.pressed.connect(func():
			Globals.player_health = 1000.0
			Globals.player_shield = 1000.0
			print("[ADMIN] God Mode Enabled: 1000 HP / 1000 Shield")
		)
	
	var btn_mats = admin_panel.get_node_or_null("VBox/Grid/MaxMatsBtn")
	if btn_mats:
		btn_mats.pressed.connect(func():
			Globals.wood = 999
			Globals.stone = 999
			Globals.metal = 999
			print("[ADMIN] 999 Materials Granted!")
		)
	
	var btn_weapons = admin_panel.get_node_or_null("VBox/Grid/GiveWeaponsBtn")
	if btn_weapons:
		btn_weapons.pressed.connect(func():
			Globals.player_shield = 100.0
			Globals.player_health = 100.0
			Globals.active_slot = 1
			print("[ADMIN] Gold Weapon Loadout Equipped!")
		)
	
	var btn_win = admin_panel.get_node_or_null("VBox/Grid/InstantWinBtn")
	if btn_win:
		btn_win.pressed.connect(func():
			GameManager.players_alive = 1
			GameManager.victory_royale.emit()
			admin_panel.visible = false
		)
	
	var btn_bus = admin_panel.get_node_or_null("VBox/Grid/LaunchBusBtn")
	if btn_bus:
		btn_bus.pressed.connect(func():
			admin_panel.visible = false
			_on_play_pressed()
		)
	
	var btn_kill_bots = admin_panel.get_node_or_null("VBox/Grid/KillBotsBtn")
	if btn_kill_bots:
		btn_kill_bots.pressed.connect(func():
			var bots = get_tree().get_nodes_in_group("bots")
			for b in bots:
				if b.has_method("apply_damage"):
					b.apply_damage(500.0)
			print("[ADMIN] All bots eliminated!")
		)
	
	var btn_close = admin_panel.get_node_or_null("VBox/CloseAdminBtn")
	if btn_close:
		btn_close.pressed.connect(func(): admin_panel.visible = false)
	
	var btn_close_locker = locker_panel.get_node_or_null("VBox/CloseLockerBtn")
	if btn_close_locker:
		btn_close_locker.pressed.connect(func(): locker_panel.visible = false)
	
	if controls_panel:
		var btn_close_controls = controls_panel.get_node_or_null("VBox/CloseControlsBtn")
		if btn_close_controls:
			btn_close_controls.pressed.connect(func(): controls_panel.visible = false)
