extends Control
class_name MobileControls

## Fortnite Mobile On-Screen Virtual Controls:
## Virtual Analog Joystick, Fire Button, Jump/Glider, Slide/Crouch, ADS/Scope, Reload, Interact, and Quick Building

@onready var joystick_base: Panel = $JoystickBase
@onready var joystick_knob: Panel = $JoystickBase/JoystickKnob
@onready var sprint_indicator: Label = $JoystickBase/SprintIndicator

@onready var fire_btn: Button = $ActionButtons/FireButton
@onready var jump_btn: Button = $ActionButtons/JumpButton
@onready var slide_btn: Button = $ActionButtons/SlideButton
@onready var aim_btn: Button = $ActionButtons/AimButton
@onready var reload_btn: Button = $ActionButtons/ReloadButton
@onready var interact_btn: Button = $ActionButtons/InteractButton
@onready var build_mode_btn: Button = $ActionButtons/BuildModeButton

@onready var build_bar: HBoxContainer = $BuildBar
@onready var wall_btn: Button = $BuildBar/WallButton
@onready var floor_btn: Button = $BuildBar/FloorButton
@onready var ramp_btn: Button = $BuildBar/RampButton
@onready var roof_btn: Button = $BuildBar/RoofButton
@onready var mat_cycle_btn: Button = $BuildBar/MatCycleButton

var joystick_touch_id: int = -1
var joystick_center: Vector2 = Vector2.ZERO
var knob_center: Vector2 = Vector2.ZERO
const JOYSTICK_MAX_RADIUS: float = 65.0

func _ready() -> void:
	# Auto-detect mobile environment
	var is_mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or DisplayServer.is_touchscreen_available()
	visible = is_mobile or Globals.mobile_controls_enabled
	
	if joystick_base and joystick_knob:
		knob_center = joystick_knob.position
	
	setup_buttons()

func setup_buttons() -> void:
	if fire_btn:
		fire_btn.button_down.connect(func(): Globals.mobile_fire = true)
		fire_btn.button_up.connect(func(): Globals.mobile_fire = false)
	
	if jump_btn:
		jump_btn.pressed.connect(func(): Globals.mobile_jump_pressed = true)
	
	if slide_btn:
		slide_btn.pressed.connect(func(): Globals.mobile_crouch_pressed = true)
	
	if aim_btn:
		aim_btn.toggled.connect(func(toggled_on: bool): Globals.mobile_aim = toggled_on)
	
	if reload_btn:
		reload_btn.pressed.connect(func(): Globals.mobile_reload_pressed = true)
	
	if interact_btn:
		interact_btn.pressed.connect(func(): Globals.mobile_interact_pressed = true)
	
	if build_mode_btn:
		build_mode_btn.pressed.connect(func():
			Globals.is_building_mode = not Globals.is_building_mode
		)
	
	if wall_btn:
		wall_btn.pressed.connect(func():
			Globals.selected_build_piece = Globals.BuildPieceType.WALL
		)
	if floor_btn:
		floor_btn.pressed.connect(func():
			Globals.selected_build_piece = Globals.BuildPieceType.FLOOR
		)
	if ramp_btn:
		ramp_btn.pressed.connect(func():
			Globals.selected_build_piece = Globals.BuildPieceType.RAMP
		)
	if roof_btn:
		roof_btn.pressed.connect(func():
			Globals.selected_build_piece = Globals.BuildPieceType.ROOF
		)
	if mat_cycle_btn:
		mat_cycle_btn.pressed.connect(func():
			Globals.selected_material = (Globals.selected_material + 1) % 3
		)

func _process(_delta: float) -> void:
	if not visible:
		return
	
	if build_bar:
		build_bar.visible = Globals.is_building_mode
	
	if aim_btn and aim_btn.button_pressed != Globals.mobile_aim:
		aim_btn.button_pressed = Globals.mobile_aim

func _input(event: InputEvent) -> void:
	# Auto-show touch controls on first screen touch
	if event is InputEventScreenTouch and not visible:
		visible = true
		Globals.mobile_controls_enabled = true
	
	if not visible:
		return
	
	# Virtual Joystick Touch Handling
	if event is InputEventScreenTouch:
		var touch_pos = event.position
		var base_global_rect = joystick_base.get_global_rect()
		# Expand touchable area around joystick
		var touch_area = base_global_rect.grow(40.0)
		
		if event.pressed:
			if touch_area.has_point(touch_pos) and joystick_touch_id == -1:
				joystick_touch_id = event.index
				update_joystick(touch_pos)
		else:
			if event.index == joystick_touch_id:
				reset_joystick()
	
	elif event is InputEventScreenDrag:
		if event.index == joystick_touch_id:
			update_joystick(event.position)

func update_joystick(screen_pos: Vector2) -> void:
	var base_center = joystick_base.global_position + joystick_base.size / 2.0
	var offset = screen_pos - base_center
	var distance = offset.length()
	
	if distance > JOYSTICK_MAX_RADIUS:
		offset = offset.normalized() * JOYSTICK_MAX_RADIUS
	
	joystick_knob.global_position = base_center + offset - joystick_knob.size / 2.0
	
	var norm_vec = offset / JOYSTICK_MAX_RADIUS
	Globals.mobile_move_vector = Vector2(norm_vec.x, norm_vec.y)
	
	# Auto-sprint if pushed forward past 75%
	if norm_vec.y < -0.75:
		Globals.mobile_sprint = true
		if sprint_indicator: sprint_indicator.visible = true
	else:
		Globals.mobile_sprint = false
		if sprint_indicator: sprint_indicator.visible = false

func reset_joystick() -> void:
	joystick_touch_id = -1
	Globals.mobile_move_vector = Vector2.ZERO
	Globals.mobile_sprint = false
	if joystick_knob:
		joystick_knob.position = knob_center
	if sprint_indicator:
		sprint_indicator.visible = false
