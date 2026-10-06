extends Node2D

signal stage_completed
signal game_over

const ENEMY_SCENE := preload("res://enemies/enemy.tscn")
const CHALLENGE_SCRIPT := preload("res://stages/challenge_enemy.gd")
const TOTAL_ENEMIES := 40
const START_SOUND := preload("res://assets/sounds/challenging_stage_start.wav")
const RESULTS_SOUND := preload("res://assets/sounds/challenging_stage_results.wav")
const PERFECT_SOUND := preload("res://assets/sounds/challenging_stage_perfect.wav")

var score := 0
var starting_lives := 3
var hits := 0
var resolved := 0
var finished := false
var results_ready := false
var wave_hits: Array[int] = [0, 0, 0, 0, 0]
var wave_resolved: Array[int] = [0, 0, 0, 0, 0]
var sound: AudioStreamPlayer

func _ready() -> void:
	sound = AudioStreamPlayer.new()
	add_child(sound)
	$Gyaraga.lives = starting_lives
	$HUD.update_lives(starting_lives)
	$HUD.update_score(score)
	$StageLabel.text = "STAGE 3\nCHALLENGING STAGE"
	$StageLabel.modulate = Color(0.3, 0.85, 1.0)
	$StageLabel.show()
	play_sound(START_SOUND)
	await get_tree().create_timer(maxf(2.5, START_SOUND.get_length())).timeout
	$StageLabel.hide()
	for wave in range(5):
		var path := create_flight_path(wave)
		$HitsLabel.text = "FORMATION %d / 5" % (wave + 1)
		for index in range(8):
			spawn_enemy(wave, index, path)
			await get_tree().create_timer(0.18).timeout
		# Wait for the last survivor to exit; no fixed dead time after early clears.
		while wave_resolved[wave] < 8:
			await get_tree().process_frame
		await get_tree().create_timer(0.65).timeout

func create_flight_path(wave: int) -> Curve2D:
	# Hand-authored arcade-inspired loops. Coordinates are for the 480 x 640 field.
	# These are approximations, not extracted original arcade trajectories.
	var points: Array[Vector2]
	match wave:
		0, 1:
			points = [Vector2(-35, 110), Vector2(150, 150), Vector2(350, 290), Vector2(300, 400), Vector2(170, 350), Vector2(180, 220), Vector2(330, 170), Vector2(515, 90)]
		2, 3:
			points = [Vector2(120, -35), Vector2(100, 170), Vector2(200, 350), Vector2(350, 360), Vector2(370, 230), Vector2(260, 170), Vector2(200, 270), Vector2(260, 410), Vector2(390, 250), Vector2(400, -35)]
		_:
			points = [Vector2(-35, 170), Vector2(140, 210), Vector2(300, 370), Vector2(400, 300), Vector2(320, 190), Vector2(170, 300), Vector2(90, 390), Vector2(160, 470), Vector2(290, 420), Vector2(380, 240), Vector2(515, 120)]
	if wave == 1 or wave == 3:
		for i in range(points.size()):
			points[i].x = 480.0 - points[i].x
	var curve := Curve2D.new()
	curve.bake_interval = 2.0
	for i in range(points.size()):
		var previous: Vector2 = points[maxi(0, i - 1)]
		var following: Vector2 = points[mini(points.size() - 1, i + 1)]
		var tangent := (following - previous) / 6.0
		curve.add_point(points[i], -tangent, tangent)
	return curve

func spawn_enemy(wave: int, _index: int, path: Curve2D) -> void:
	var enemy = ENEMY_SCENE.instantiate()
	enemy.set_script(CHALLENGE_SCRIPT)
	$Enemies.add_child(enemy)
	enemy.configure(1 if wave % 2 == 0 else 2, path.get_point_position(0))
	enemy.flight_path = path
	enemy.flight_speed = 155.0 + wave * 5.0
	enemy.enemy_destroyed.connect(_on_hit.bind(wave))
	enemy.escaped.connect(_on_escape.bind(wave))

func play_sound(stream: AudioStream) -> void:
	sound.stream = stream
	sound.play()

func _on_hit(points: int, wave: int) -> void:
	hits += 1
	wave_hits[wave] += 1
	score += points
	if wave_hits[wave] == 8:
		score += 1000
		$HitsLabel.text = "FORMATION BONUS  1000 PTS"
	$HUD.update_score(score)
	_resolve_enemy(wave)

func _on_escape(wave: int) -> void:
	_resolve_enemy(wave)

func _resolve_enemy(wave: int) -> void:
	resolved += 1
	wave_resolved[wave] += 1
	if resolved == TOTAL_ENEMIES and not finished:
		show_results()

func show_results() -> void:
	finished = true
	$HitsLabel.hide()
	$Gyaraga.set_physics_process(false)
	for bullet in get_tree().get_nodes_in_group("player_bullets"):
		bullet.queue_free()
	$StageLabel.modulate = Color.WHITE
	$StageLabel.text = "NUMBER OF HITS  %2d" % hits
	$StageLabel.show()
	play_sound(RESULTS_SOUND)
	await get_tree().create_timer(maxf(1.5, RESULTS_SOUND.get_length())).timeout
	var bonus := 10000 if hits == TOTAL_ENEMIES else hits * 100
	score += bonus
	$HUD.update_score(score)
	if hits == TOTAL_ENEMIES:
		$StageLabel.modulate = Color(1.0, 0.85, 0.2)
		$StageLabel.text = "PERFECT!\nSPECIAL BONUS\n10000 PTS"
		play_sound(PERFECT_SOUND)
	else:
		$StageLabel.text += "\nBONUS  %d PTS" % bonus
	await get_tree().create_timer(3.0).timeout
	results_ready = true
	if get_tree().current_scene == self:
		$StageLabel.text += "\nENTER: RETRY CHALLENGE"
	else:
		stage_completed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if results_ready and event.is_action_pressed("ui_accept") and get_tree().current_scene == self:
		get_tree().reload_current_scene()
