extends Node3D
class_name CharacterAnimator

## Rigs Mixamo 3D character models and transfers benchmark animations (Idle, Walk, Run, Sprint, Slide, Glider, Swing, Victory)

@export var character_fbx_path: String = "res://assets/characters/YBot.fbx"
@export var is_bot: bool = false

var anim_player: AnimationPlayer = null
var skeleton: Skeleton3D = null
var hand_attachment: BoneAttachment3D = null
var current_anim_name: String = ""
var is_action_playing: bool = false
var char_node: Node3D = null

var shared_anim_lib: AnimationLibrary = preload("res://assets/animations/mixamo_library.tres")

signal character_ready()

const BOT_SKINS = [
	"res://assets/characters/Ninja.fbx",
	"res://assets/characters/Swat.fbx",
	"res://assets/characters/Vanguard.fbx",
	"res://assets/characters/Kate.fbx",
	"res://assets/characters/Remy.fbx",
	"res://assets/characters/Ty.fbx",
	"res://assets/characters/Timmy.fbx",
	"res://assets/characters/SportyGranny.fbx",
	"res://assets/characters/YBot.fbx"
]

func _ready() -> void:
	call_deferred("setup_character")

func set_skin(skin_path: String) -> void:
	character_fbx_path = skin_path
	setup_character()

func setup_character() -> void:
	if not is_bot and Globals.selected_skin_path != "":
		character_fbx_path = Globals.selected_skin_path
	elif is_bot and BOT_SKINS.size() > 0:
		character_fbx_path = BOT_SKINS[randi() % BOT_SKINS.size()]
	
	if not ResourceLoader.exists(character_fbx_path):
		return
	
	var res = load(character_fbx_path)
	if not res or not (res is PackedScene):
		return
	
	if char_node and is_instance_valid(char_node):
		char_node.queue_free()
		char_node = null
		hand_attachment = null
		anim_player = null
		skeleton = null
	
	char_node = res.instantiate()
	char_node.name = "CharacterRig"
	add_child(char_node)
	
	# Scale Mixamo character to match 1.8m-2.0m Fortnite character height
	char_node.scale = Vector3(1.0, 1.0, 1.0)
	char_node.position = Vector3(0, 0, 0)
	# Face forward (-Z in Godot coordinates)
	char_node.rotation_degrees = Vector3(0, 180, 0)
	
	# Hide parent placeholder capsule mesh if present
	var parent_node = get_parent()
	if parent_node:
		var placeholder = parent_node.get_node_or_null("MeshInstance3D")
		if placeholder:
			placeholder.visible = false
	
	# Find Skeleton3D and AnimationPlayer
	skeleton = char_node.get_node_or_null("Skeleton3D")
	anim_player = char_node.get_node_or_null("AnimationPlayer")
	
	if not anim_player:
		for child in char_node.get_children():
			if child is AnimationPlayer:
				anim_player = child
				break
	
	if skeleton:
		var r_hand_idx = skeleton.find_bone("mixamorig_RightHand")
		if r_hand_idx != -1:
			hand_attachment = BoneAttachment3D.new()
			hand_attachment.name = "RightHandAttachment"
			hand_attachment.bone_name = "mixamorig_RightHand"
			skeleton.add_child(hand_attachment)
	
	if anim_player and shared_anim_lib:
		if not anim_player.has_animation_library(""):
			anim_player.add_animation_library("", shared_anim_lib)
		else:
			var default_lib = anim_player.get_animation_library("")
			for a_name in shared_anim_lib.get_animation_list():
				if not default_lib.has_animation(a_name):
					default_lib.add_animation(a_name, shared_anim_lib.get_animation(a_name))
		play_anim("idle")
	
	character_ready.emit()

func get_hand_holder() -> Node3D:
	if hand_attachment and is_instance_valid(hand_attachment):
		return hand_attachment
	return self

func update_locomotion(horizontal_speed: float, is_sprinting: bool, is_sliding: bool, is_gliding: bool) -> void:
	if is_action_playing:
		return
	
	if is_gliding:
		play_anim("glide")
	elif is_sliding:
		play_anim("slide")
	elif horizontal_speed > 6.5:
		play_anim("sprint")
	elif horizontal_speed > 0.8:
		play_anim("run")
	else:
		play_anim("idle")

func play_action(action_name: String) -> void:
	if not anim_player or not anim_player.has_animation(action_name):
		return
	
	is_action_playing = true
	anim_player.play(action_name, 0.15)
	
	var anim_length = anim_player.get_animation(action_name).length
	get_tree().create_timer(min(anim_length, 0.6)).timeout.connect(func():
		is_action_playing = false
		current_anim_name = ""
	)

func play_anim(anim_name: String) -> void:
	if not anim_player or not anim_player.has_animation(anim_name):
		return
	if current_anim_name == anim_name:
		return
	current_anim_name = anim_name
	anim_player.play(anim_name, 0.2)
