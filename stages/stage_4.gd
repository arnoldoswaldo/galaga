extends Node2D

signal stage_completed
signal game_over

const ENEMY_SCENE := preload("res://enemies/enemy.tscn")

# Cada patrón describe una oleada:
#  from: "left", "right" o "both" (alterna lados)
#  count: cuántos enemigos entran
#  delay: segundos entre un enemigo y el siguiente
#  row: fila de formación preferida (0 = arriba, 1 = abajo)
#  cols: columnas de destino, en el orden en que van llegando (0 a 6)
#  types: tipos de enemigo (1 = Goei, 2 = Yako); se alternan
#  entry_time: (opcional) segundos que tarda cada entrada
const PATTERNS := [
	# Pinza: entran por los dos lados a la vez hacia los extremos
	{"from": "both", "count": 6, "delay": 0.25, "row": 0,
		"cols": [0, 6, 1, 5, 2, 4], "types": [1, 2]},
	# Cascada desde la izquierda
	{"from": "left", "count": 5, "delay": 0.3, "row": 1,
		"cols": [4, 3, 2, 1, 0], "types": [2]},
	# Cascada desde la derecha
	{"from": "right", "count": 5, "delay": 0.3, "row": 1,
		"cols": [2, 3, 4, 5, 6], "types": [1]},
	# Cruce: cada lado va a la casilla del lado contrario
	{"from": "both", "count": 6, "delay": 0.2, "row": 0,
		"cols": [4, 2, 5, 1, 6, 0], "types": [1, 2], "entry_time": 2.2},
]

@export var max_minions := 6
@export var wave_interval := 22.0
@export var minion_attack_interval := 2.5
@export var max_minion_attackers := 2
@export var slot_spacing_x := 50.0
@export var slot_spacing_y := 45.0
@export var slots_top_y := 250.0

var score := 0
var starting_lives := 3
var is_stage_completed := false
var is_game_over := false

var wave_index := 0
var is_spawning_wave := false
var slots := {}  # casillas de formación ocupadas: Vector2i -> true

var enemies_container: Node
var wave_timer: Timer
var minion_attack_timer: Timer

@onready var stage_label: Label = $StageLabel
@onready var boss: Area2D = $Boss


func _ready() -> void:
	$Gyaraga.lives_changed.connect($HUD.update_lives)
	$Gyaraga.lives = starting_lives
	$HUD.update_lives(starting_lives)
	$HUD.update_score(score)
	$Gyaraga.player_destroyed.connect(_on_player_destroyed)

	$BossUI/BossHealthBar.max_value = boss.max_health
	$BossUI/BossHealthBar.value = boss.health
	boss.health_changed.connect(_on_boss_health_changed)
	boss.phase_changed.connect(_on_boss_phase_changed)
	boss.defeated.connect(complete_stage)

	_setup_waves()

	# El jefe empieza fuera de pantalla, arriba
	boss.position = Vector2(240, -200)

	stage_label.text = "STAGE 4"
	stage_label.modulate = Color.WHITE
	stage_label.visible = true
	await get_tree().create_timer(2.0, false).timeout
	stage_label.visible = false
	boss_entry()


func boss_entry() -> void:
	stage_label.text = "WARNING!!!"
	stage_label.visible = true

	var blink_tween := create_tween()
	blink_tween.set_loops()
	blink_tween.tween_property(stage_label, "modulate:a", 0.2, 0.6)
	blink_tween.tween_property(stage_label, "modulate:a", 1.0, 0.6)

	var tween := create_tween()
	tween.tween_property(boss, "position", Vector2(240, 140), 4.0) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween.finished

	blink_tween.kill()
	stage_label.modulate.a = 1.0
	stage_label.visible = false

	boss.start_fight()
	_start_waves()


# ---------- Oleadas ----------

func _setup_waves() -> void:
	enemies_container = get_node_or_null("Enemies")
	if enemies_container == null:
		enemies_container = Node2D.new()
		enemies_container.name = "Enemies"
		add_child(enemies_container)

	wave_timer = Timer.new()
	wave_timer.wait_time = wave_interval
	wave_timer.one_shot = false
	wave_timer.timeout.connect(_on_wave_timer_timeout)
	add_child(wave_timer)

	minion_attack_timer = Timer.new()
	minion_attack_timer.wait_time = minion_attack_interval
	minion_attack_timer.one_shot = false
	minion_attack_timer.timeout.connect(_on_minion_attack_timeout)
	add_child(minion_attack_timer)


func _start_waves() -> void:
	spawn_wave(_next_pattern())
	wave_timer.start()
	minion_attack_timer.start()


func _stop_waves() -> void:
	wave_timer.stop()
	minion_attack_timer.stop()


func _next_pattern() -> Dictionary:
	var pattern: Dictionary = PATTERNS[wave_index % PATTERNS.size()]
	wave_index += 1
	return pattern


# Hay pelea en curso (el jefe puede estar peleando o en transición de fase)
func _fight_active() -> bool:
	if is_stage_completed or is_game_over or not is_instance_valid(boss):
		return false
	return boss.state == boss.State.FIGHTING or boss.state == boss.State.TRANSITION


func spawn_wave(pattern: Dictionary) -> void:
	if is_spawning_wave or not _fight_active():
		return

	var room := max_minions - _alive_minions().size()
	var count := mini(pattern["count"], room)
	if count <= 0:
		return

	is_spawning_wave = true

	for i in count:
		if not _fight_active():
			break

		var slot = _take_free_slot(pattern["row"], pattern["cols"])
		if slot == null:
			break

		var target := _slot_position(slot)
		var types: Array = pattern["types"]

		var enemy = ENEMY_SCENE.instantiate()
		enemies_container.add_child(enemy)
		enemy.configure(types[i % types.size()], target)
		enemy.add_to_group("minions")
		enemy.entry_duration = pattern.get("entry_time", 2.5)
		enemy.enemy_destroyed.connect(_on_minion_destroyed.bind(slot))
		enemy.start_entry(_entry_point(pattern["from"], i), target)

		await get_tree().create_timer(pattern["delay"], false).timeout

	is_spawning_wave = false


func _entry_point(from: String, index: int) -> Vector2:
	var side := from
	if from == "both":
		side = "left" if index % 2 == 0 else "right"
	var y := 320.0 + (index % 3) * 20.0
	if side == "left":
		return Vector2(-40.0, y)
	return Vector2(520.0, y)


# Busca una casilla libre: primero la fila preferida, luego la otra
func _take_free_slot(row: int, cols: Array):
	for r in [row, 1 - row]:
		for c in cols:
			var key := Vector2i(c, r)
			if not slots.has(key):
				slots[key] = true
				return key
	return null


func _slot_position(slot: Vector2i) -> Vector2:
	return Vector2(
		240.0 + (slot.x - 3) * slot_spacing_x,
		slots_top_y + slot.y * slot_spacing_y
	)


func _alive_minions() -> Array:
	var result: Array = []
	for minion in get_tree().get_nodes_in_group("minions"):
		if is_instance_valid(minion) and not minion.is_being_hit:
			result.append(minion)
	return result


func _clear_minions() -> void:
	_stop_waves()
	for minion in get_tree().get_nodes_in_group("minions"):
		minion.queue_free()
	slots.clear()


func _on_wave_timer_timeout() -> void:
	if _fight_active() and boss.state == boss.State.FIGHTING:
		spawn_wave(_next_pattern())


func _on_minion_attack_timeout() -> void:
	if not _fight_active() or boss.state != boss.State.FIGHTING:
		return

	var attackers := 0
	var available: Array = []
	for minion in _alive_minions():
		if minion.state == minion.State.ATTACKING or minion.state == minion.State.RETURNING:
			attackers += 1
		elif minion.state == minion.State.FORMATION:
			available.append(minion)

	if attackers >= max_minion_attackers or available.is_empty():
		return

	available.pick_random().start_attack()


func _on_minion_destroyed(points_value: int, slot: Vector2i) -> void:
	slots.erase(slot)
	score += points_value
	$HUD.update_score(score)


# ---------- Jefe, fin y game over ----------

func _on_boss_health_changed(current: int, maximum: int) -> void:
	$BossUI/BossHealthBar.max_value = maximum
	$BossUI/BossHealthBar.value = current


func _on_boss_phase_changed(phase: int) -> void:
	# Oleada nueva en cada fase, mientras el jefe está invulnerable
	spawn_wave(_next_pattern())
	wave_timer.start()

	stage_label.text = "PHASE " + str(phase)
	stage_label.modulate.a = 1.0
	stage_label.visible = true
	await get_tree().create_timer(1.5, false).timeout
	if not is_stage_completed and not is_game_over:
		stage_label.visible = false


func complete_stage() -> void:
	if is_stage_completed:
		return
	is_stage_completed = true

	print("================================")
	print("STAGE 4 COMPLETADO")
	print("================================")

	_clear_minions()

	score += boss.points
	$HUD.update_score(score)

	stage_label.text = "STAGE COMPLETE"
	stage_label.modulate.a = 1.0
	stage_label.visible = true
	await get_tree().create_timer(2.5, false).timeout

	_clear_bullets()
	stage_completed.emit()


func _on_player_destroyed() -> void:
	if is_stage_completed or is_game_over:
		return
	is_game_over = true

	print("GAME OVER: señal recibida del jugador")

	_stop_waves()
	if is_instance_valid(boss):
		boss.stop_fight()

	$HUD.show_game_over()
	await get_tree().create_timer(2.0, false).timeout

	_clear_minions()
	_clear_bullets()
	print("GAME OVER: emitiendo señal hacia Main")
	game_over.emit()


# Las balas se agregan a current_scene (main), no al stage,
# así que hay que borrarlas a mano al terminar.
func _clear_bullets() -> void:
	for group_name in ["enemy_bullets", "player_bullets"]:
		for bullet in get_tree().get_nodes_in_group(group_name):
			bullet.queue_free()
