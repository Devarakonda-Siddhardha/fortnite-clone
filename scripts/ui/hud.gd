extends Control
class_name GameHUD

## Fortnite-Style UI: Health, Shield, Materials, Storm Timer, Hotbar, Killfeed, and Victory Royale

@onready var health_bar: ProgressBar = $BottomLeft/BarsContainer/HealthBar
@onready var health_label: Label = $BottomLeft/BarsContainer/HealthBar/HealthLabel
@onready var shield_bar: ProgressBar = $BottomLeft/BarsContainer/ShieldBar
@onready var shield_label: Label = $BottomLeft/BarsContainer/ShieldBar/ShieldLabel

@onready var wood_label: Label = $BottomRight/Materials/WoodContainer/WoodLabel
@onready var stone_label: Label = $BottomRight/Materials/StoneContainer/StoneLabel
@onready var metal_label: Label = $BottomRight/Materials/MetalContainer/MetalLabel

@onready var build_mode_panel: PanelContainer = $BottomRight/BuildModeHint
@onready var build_piece_label: Label = $BottomRight/BuildModeHint/Margin/PieceLabel

@onready var storm_timer_label: Label = $TopCenter/StormInfo/TimerLabel
@onready var storm_phase_label: Label = $TopCenter/StormInfo/PhaseLabel

@onready var alive_label: Label = $TopRight/MatchStats/AliveLabel
@onready var elims_label: Label = $TopRight/MatchStats/ElimsLabel
@onready var killfeed_container: VBoxContainer = $TopRight/KillFeed

@onready var victory_banner: PanelContainer = $CenterBanner/VictoryBanner
@onready var game_over_banner: PanelContainer = $CenterBanner/GameOverBanner
@onready var victory_lobby_btn: Button = $CenterBanner/VictoryBanner/VBox/VictoryLobbyButton
@onready var game_over_lobby_btn: Button = $CenterBanner/GameOverBanner/VBox/GameOverLobbyButton

@onready var crosshair: Control = $CenterCrosshair
@onready var hotbar_container: HBoxContainer = $BottomCenter/Hotbar

func _ready() -> void:
	Globals.health_changed.connect(_on_health_changed)
	Globals.shield_changed.connect(_on_shield_changed)
	Globals.materials_changed.connect(_on_materials_changed)
	Globals.storm_updated.connect(_on_storm_updated)
	Globals.active_slot_changed.connect(_on_active_slot_changed)
	
	GameManager.alive_count_changed.connect(_on_alive_count_changed)
	GameManager.player_eliminated.connect(_on_player_eliminated)
	GameManager.victory_royale.connect(_on_victory_royale)
	GameManager.game_over.connect(_on_game_over)
	GameManager.match_started.connect(_on_match_started)
	GameManager.return_to_lobby.connect(_on_return_to_lobby)
	
	if victory_lobby_btn:
		victory_lobby_btn.pressed.connect(func(): GameManager.go_to_lobby())
	if game_over_lobby_btn:
		game_over_lobby_btn.pressed.connect(func(): GameManager.go_to_lobby())
	
	visible = GameManager.is_in_match
	if victory_banner: victory_banner.visible = false
	if game_over_banner: game_over_banner.visible = false
	
	_on_health_changed(Globals.player_health, 100.0)
	_on_shield_changed(Globals.player_shield, 100.0)
	_on_materials_changed(Globals.wood, Globals.stone, Globals.metal)
	_on_alive_count_changed(GameManager.players_alive)
	
	setup_hotbar_icons()

func setup_hotbar_icons() -> void:
	if not hotbar_container:
		return
	var icon_paths = [
		"res://assets/icons/pickaxe.png",
		"res://assets/icons/assault_rifle.png",
		"res://assets/icons/shotgun.png",
		"res://assets/icons/sniper_rifle.png",
		"res://assets/icons/shield_potion.png",
		"res://assets/icons/medkit.png"
	]
	for i in range(min(hotbar_container.get_child_count(), icon_paths.size())):
		var slot = hotbar_container.get_child(i)
		var path = icon_paths[i]
		if ResourceLoader.exists(path):
			var tex = load(path)
			var tr = TextureRect.new()
			tr.texture = tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.custom_minimum_size = Vector2(36, 36)
			slot.add_child(tr)
			# Hide text label if present so icon shines
			var lbl = slot.get_node_or_null("Label")
			if lbl:
				lbl.visible = false

func _process(_delta: float) -> void:
	if build_mode_panel:
		build_mode_panel.visible = Globals.is_building_mode
		if Globals.is_building_mode:
			var p_name = ""
			match Globals.selected_build_piece:
				Globals.BuildPieceType.WALL: p_name = "[Q] Wall"
				Globals.BuildPieceType.FLOOR: p_name = "[Z] Floor"
				Globals.BuildPieceType.RAMP: p_name = "[C] Ramp"
				Globals.BuildPieceType.ROOF: p_name = "[V] Roof"
			var m_name = ""
			match Globals.selected_material:
				Globals.MaterialType.WOOD: m_name = "Wood (10)"
				Globals.MaterialType.STONE: m_name = "Stone (10)"
				Globals.MaterialType.METAL: m_name = "Metal (10)"
			build_piece_label.text = "%s | %s\n[RMB] Cycle Material" % [p_name, m_name]

func _on_health_changed(current: float, _max_val: float) -> void:
	if health_bar:
		health_bar.value = current
		health_label.text = "%d" % int(current)

func _on_shield_changed(current: float, _max_val: float) -> void:
	if shield_bar:
		shield_bar.value = current
		shield_label.text = "%d" % int(current)

func _on_materials_changed(wood: int, stone: int, metal: int) -> void:
	if wood_label: wood_label.text = "%d" % wood
	if stone_label: stone_label.text = "%d" % stone
	if metal_label: metal_label.text = "%d" % metal

func _on_storm_updated(_radius: float, _center: Vector3, phase: int, time_left: float) -> void:
	if storm_phase_label:
		storm_phase_label.text = "STORM PHASE %d" % phase
	if storm_timer_label:
		var mins = int(time_left) / 60
		var secs = int(time_left) % 60
		storm_timer_label.text = "%02d:%02d" % [mins, secs]

func _on_active_slot_changed(slot_idx: int) -> void:
	if not hotbar_container:
		return
	for i in range(hotbar_container.get_child_count()):
		var slot_panel = hotbar_container.get_child(i) as PanelContainer
		if slot_panel:
			if i == slot_idx:
				slot_panel.modulate = Color(1.25, 1.25, 0.35, 1.0)
			else:
				slot_panel.modulate = Color(1.0, 1.0, 1.0, 0.75)

func _on_alive_count_changed(count: int) -> void:
	if alive_label:
		alive_label.text = "%d ALIVE" % count
	if elims_label:
		elims_label.text = "%d ELIMS" % GameManager.player_kills

func _on_player_eliminated(victim: String, killer: String, weapon: String) -> void:
	_on_alive_count_changed(GameManager.players_alive)
	if killfeed_container:
		var feed_label = Label.new()
		feed_label.text = "%s eliminated %s (%s)" % [killer, victim, weapon]
		feed_label.add_theme_font_size_override("font_size", 12)
		if killer == "Player":
			feed_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		else:
			feed_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.8))
		killfeed_container.add_child(feed_label)
		
		# Fade and remove after 4.5 seconds
		get_tree().create_timer(4.5).timeout.connect(func():
			if is_instance_valid(feed_label):
				feed_label.queue_free()
		)

func _on_match_started() -> void:
	visible = true
	if victory_banner: victory_banner.visible = false
	if game_over_banner: game_over_banner.visible = false
	_on_health_changed(Globals.player_health, 100.0)
	_on_shield_changed(Globals.player_shield, 100.0)
	_on_materials_changed(Globals.wood, Globals.stone, Globals.metal)
	_on_alive_count_changed(GameManager.players_alive)

func _on_return_to_lobby() -> void:
	visible = false
	if victory_banner: victory_banner.visible = false
	if game_over_banner: game_over_banner.visible = false

func _on_victory_royale() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if victory_banner:
		victory_banner.visible = true
		victory_banner.scale = Vector2(0.5, 0.5)
		var tween = create_tween()
		tween.tween_property(victory_banner, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
		# Play ElevenLabs Victory Royale Fanfare
		var sfx = load("res://assets/audio/victory_royale.mp3")
		if sfx:
			var asp = AudioStreamPlayer.new()
			asp.stream = sfx
			add_child(asp)
			asp.play()

func _on_game_over() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if game_over_banner:
		game_over_banner.visible = true
