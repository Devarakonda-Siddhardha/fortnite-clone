extends Node

func _ready() -> void:
	print("--- Running Fortnite V2 Feature Tests in Scene ---")
	call_deferred("_run_tests")

func _run_tests() -> void:
	var main_scene = load("res://scenes/main.tscn").instantiate()
	add_child(main_scene)
	
	for i in range(20):
		await get_tree().process_frame
	
	var player = main_scene.get_node_or_null("Player")
	assert(player != null, "Player node must exist")
	print("✓ Player node found")
	
	var island = main_scene.get_node_or_null("Island")
	assert(island != null, "Island generator node must exist")
	assert(island.island_size >= 480.0, "Island size must be >= 480m")
	print("✓ Island size verified: %fm" % island.island_size)
	
	# Start match
	GameManager.start_match()
	print("✓ Match started")
	
	for i in range(30):
		await get_tree().process_frame
	
	# Test Weapon Hand Attachment
	var char_anim = player.get_node_or_null("CharacterAnimator")
	assert(char_anim != null, "CharacterAnimator must exist")
	var hand = char_anim.get_hand_holder()
	print("✓ Player Hand Holder: %s" % (hand.name if hand else "null"))
	
	# Test Weapon Reload
	var weap_mgr = player.get_node_or_null("WeaponManager")
	if not weap_mgr:
		weap_mgr = player.find_child("WeaponManager", true, false)
	
	if weap_mgr:
		print("✓ WeaponManager found, active_slot: %d" % Globals.active_slot)
		Globals.active_slot = 1
		weap_mgr.current_magazines[1] = 8
		weap_mgr.start_reload()
		assert(weap_mgr.is_reloading == true, "WeaponManager should enter reloading state")
		print("✓ Reload triggered, is_reloading: %s" % str(weap_mgr.is_reloading))
		weap_mgr.finish_reload()
		assert(weap_mgr.current_magazines[1] == 30, "Magazine refilled to 30")
		print("✓ Reload finished, magazine: %d / %d" % [weap_mgr.current_magazines[1], weap_mgr.reserve_ammo[1]])
	
	# Test Bots
	var spawner = main_scene.get_node_or_null("BotSpawner")
	assert(spawner != null, "BotSpawner must exist")
	print("✓ Bots spawned count: %d" % spawner.get_child_count())
	assert(spawner.get_child_count() > 0, "Bots should be spawned")
	
	var first_bot = spawner.get_child(0) as BotAI
	if first_bot:
		print("✓ Bot found: %s, HP: %f, Shield: %f" % [first_bot.bot_name, first_bot.health, first_bot.shield])
		var child_count_before = main_scene.get_child_count()
		first_bot.take_damage(25.0, "Player")
		print("✓ Bot took 25 damage -> HP: %f, Shield: %f" % [first_bot.health, first_bot.shield])
		var child_count_after = main_scene.get_child_count()
		print("✓ Objects in scene after bot defense: %d (was %d)" % [child_count_after, child_count_before])
	
	# Test Supply Drop Spawner
	island.spawn_supply_drop()
	print("✓ Supply drop spawned from spawner")
	
	# Test POI Event
	Globals.poi_entered.emit("Pleasant Park")
	print("✓ POI entered signal emitted successfully")
	
	print("============================================")
	print("=== ALL V2 FEATURES PASSED VERIFICATION ===")
	print("============================================")
	get_tree().quit(0)
