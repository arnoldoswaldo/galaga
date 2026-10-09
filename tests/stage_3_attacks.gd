extends SceneTree
# Run with: godot --headless --path . --script res://tests/stage_3_attacks.gd

func _initialize() -> void:
	call_deferred("verify")

func verify() -> void:
	root.size = Vector2i(480, 640)
	var stage = load("res://stages/stage_3.tscn").instantiate()
	root.add_child(stage)
	current_scene = stage
	var elapsed := 0.0
	while get_nodes_in_group("enemy_bullets").is_empty() and elapsed < 12.0:
		await create_timer(0.05).timeout
		elapsed += 0.05
	assert(not get_nodes_in_group("enemy_bullets").is_empty(), "Stage 3 must fire during natural flight")
	var shot = get_nodes_in_group("enemy_bullets")[0]
	assert(shot.direction.y > 0.0, "Shot must head down toward the player")
	stage.attack_timer.stop()
	stage.clear_bullets()
	await physics_frame
	await physics_frame
	var player = stage.get_node("Gyaraga")
	var enemy = stage.get_node("Enemies").get_child(0)
	enemy.set_process(false)
	enemy.global_position = player.global_position - Vector2(0, 70)
	var lives_before: int = player.lives
	enemy.shoot()
	await create_timer(0.5).timeout
	assert(player.lives == lives_before - 1, "Actual projectile collision must remove one life")
	assert(stage.get_node("HUD/LivesLabel").text == "LIVES: %d" % player.lives)
	player.lives = 1
	enemy.global_position = player.global_position - Vector2(0, 70)
	enemy.shoot()
	await create_timer(2.8).timeout
	assert(stage.failed and stage.finished and stage.results_ready)
	assert(stage.attack_timer.is_stopped())
	assert(stage.get_node("HUD/LivesLabel").text == "LIVES: 0")
	assert(get_nodes_in_group("enemy_bullets").is_empty())
	var enemy_count: int = stage.get_node("Enemies").get_child_count()
	await create_timer(0.5).timeout
	assert(stage.get_node("Enemies").get_child_count() == enemy_count, "No new enemies after game over")
	stage.queue_free()
	await process_frame
	var win = load("res://stages/stage_3.tscn").instantiate()
	root.add_child(win)
	current_scene = win
	win.spawn_enemy(0, 0, win.create_flight_path(0))
	var winning_enemy = win.get_node("Enemies").get_child(0)
	winning_enemy.global_position = Vector2(240, 150)
	winning_enemy.shoot()
	win.hits = 40
	win.show_results()
	await physics_frame
	await physics_frame
	assert(win.attack_timer.is_stopped())
	assert(get_nodes_in_group("enemy_bullets").is_empty(), "Results must clear enemy fire")
	await create_timer(win.RESULTS_SOUND.get_length() + 3.5).timeout
	assert(win.score == 10000 and win.results_ready and not win.failed)
	win.queue_free()
	await process_frame
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main.start_game()
	main.current_stage_node.score = 2500
	main.current_stage_node.get_node("Gyaraga").lives = 2
	main._on_stage_completed()
	assert(main.current_stage == 3 and main.current_stage_node.score == 2500)
	assert(main.current_stage_node.get_node("Gyaraga").lives == 2)
	main.current_stage_node.get_node("Gyaraga").lives = 1
	main.current_stage_node.get_node("Gyaraga").hit_by_enemy()
	await create_timer(3.0).timeout
	assert(main.current_stage_node == null and not main.game_started)
	main.queue_free()
	await process_frame
	print("PASS: natural enemy fire, physical damage, HUD lives, game over, stopped spawning and safe results")
	quit()
