extends Control
class_name GameHUD

## Fortnite-Style UI: Health, Shield, Materials, Storm Timer, Hotbar, and Reticle

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

@onready var crosshair: Control = $CenterCrosshair
@onready var hotbar_container: HBoxContainer = $BottomCenter/Hotbar

func _ready() -> void:
	Globals.health_changed.connect(_on_health_changed)
	Globals.shield_changed.connect(_on_shield_changed)
	Globals.materials_changed.connect(_on_materials_changed)
	Globals.storm_updated.connect(_on_storm_updated)
	Globals.active_slot_changed.connect(_on_active_slot_changed)
	
	_on_health_changed(Globals.player_health, 100.0)
	_on_shield_changed(Globals.player_shield, 100.0)
	_on_materials_changed(Globals.wood, Globals.stone, Globals.metal)

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

func _on_health_changed(current: float, max_val: float) -> void:
	if health_bar:
		health_bar.value = current
		health_label.text = "%d" % int(current)

func _on_shield_changed(current: float, max_val: float) -> void:
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
				slot_panel.modulate = Color(1.2, 1.2, 0.4, 1.0) # Active slot highlight
			else:
				slot_panel.modulate = Color(1.0, 1.0, 1.0, 0.75)
