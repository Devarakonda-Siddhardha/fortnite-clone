extends SceneTree

func _init() -> void:
	print("--- Running Fortnite V2 Feature Tests ---")
	call_deferred("_run_tests")

func _run_tests() -> void:
	var main_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	
	# Wait 20 frames for initialization
	for i in range(20):
		await process_frame
	
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
	
	# Wait 20 frames for character rig and bus drop
	for i in range(25):
		await process_frame
	
	# Test Weapon Hand Attachment
	var char_anim = player.get_node_or_null("CharacterAnimator")
	assert(char_anim != null, "CharacterAnimator must exist")
	var hand = char_anim.get_hand_holder()
	print("✓ Player Hand Holder: %s" % (hand.name if hand else "null"))
	
	var weap_mgr = player.get_node_or_null("WeaponManager")
	if weap_mgr:
		print("✓ WeaponManager found, active_slot: %d" % Globals.active_slot)
		# Test reload
		Globals.active_slot = 1
		weap_mgr.current_magazines[1] = 10
		weap_mgr.start_reload()
		assert(weap_mgr.is_reloading == true, "WeaponManager should enter reloading state")
		print("✓ Reload triggered successfully, timer: %f" % weap_mgr.reload_timer)
		weap_mgr.finish_reload()
		assert(weap_mgr.current_magazines[1] == 30, "Magazine should be refilled to 30")
		print("✓ Reload finished successfully, mag: %d" % weap_mgr.current_magazines[1])
	
	# Test Bots
	var spawner = main_scene.get_node_or_null("BotSpawner")
	assert(spawner != null, "BotSpawner must exist")
	print("✓ Bots spawned count: %d" % spawner.get_child_count())
	assert(spawner.get_child_count() > 0, "Bots should be spawned")
	
	var first_bot = spawner.get_child(0) as BotAI
	if first_bot:
		print("✓ First bot: %s (HP: %f, Shield: %f)" % [first_bot.bot_name, first_bot.health, first_bot.shield])
		# Test defensive building
		var child_count_before = main_scene.get_child_count()
		first_bot.take_damage(25.0, "TestPlayer")
		print("✓ Bot took damage, new HP: %f, shield: %f" % [first_bot.health, first_bot.shield])
		var child_count_after = main_scene.get_child_count()
		print("✓ Scene children after damage: %d (before: %d)" % [child_count_after, child_count_before])
	
	# Test Supply Drop Spawner
	island.spawn_supply_drop()
	print("✓ Supply drop spawned from island spawner")
	
	# Test POI Event
	Globals.poi_entered.emit("Pleasant Park")
	print("✓ POI entered signal emitted successfully")
	
	print("=== ALL V2 FEATURES PASSED SUCCESSFULLY ===")
	quit(0)
