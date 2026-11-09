extends Node3D
class_name CharacterAnimator

## Rigs Mixamo 3D character models and transfers benchmark animations (Idle, Walk, Run, Sprint, Slide, Glider, Swing, Victory)

@export var character_fbx_path: String = "res://assets/characters/YBot.fbx"
@export var is_bot: bool = false

var anim_player: AnimationPlayer = null
var current_anim_name: String = ""
var is_action_playing: bool = false

var shared_anim_lib: AnimationLibrary = preload("res://assets/animations/mixamo_library.tres")

func _ready() -> void:
	call_deferred("setup_character")

func setup_character() -> void:
	if not ResourceLoader.exists(character_fbx_path):
		return
	
	var res = load(character_fbx_path)
	if not res or not (res is PackedScene):
		return
	
	var char_node = res.instantiate()
	add_child(char_node)
	
	# Scale Mixamo character to match 2m Fortnite capsule
	char_node.scale = Vector3(0.01, 0.01, 0.01)
	# Rotate to face forward
	char_node.rotation_degrees = Vector3(0, 180, 0)
	
	# Hide parent placeholder capsule mesh if present
	var parent_node = get_parent()
	if parent_node:
		var placeholder = parent_node.get_node_or_null("MeshInstance3D")
		if placeholder:
			placeholder.visible = false
	
	# Find AnimationPlayer on the character model
	anim_player = char_node.get_node_or_null("AnimationPlayer")
	if not anim_player:
		for child in char_node.get_children():
			if child is AnimationPlayer:
				anim_player = child
				break
	
	if anim_player and shared_anim_lib:
		if not anim_player.has_animation_library(""):
			anim_player.add_animation_library("", shared_anim_lib)
		else:
			var default_lib = anim_player.get_animation_library("")
			for a_name in shared_anim_lib.get_animation_list():
				if not default_lib.has_animation(a_name):
					default_lib.add_animation(a_name, shared_anim_lib.get_animation(a_name))
		play_anim("idle")

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
	anim_player.play(action_name)
	
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
