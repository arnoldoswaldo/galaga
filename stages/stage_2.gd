extends Node2D

const ENEMY_SCENE := preload("res://enemies/enemy.tscn")

@export var rows := 3
@export var columns := 7
@export var stage_number := 2
@export var attack_interval := 1.5
@export var max_attacks := 3
var starting_lives := 3

@export var start_x := 75.0
@export var start_y := 100.0

@export var spacing_x := 45.0
@export var spacing_y := 42.0

var enemies: Array[Node] = []
var score := 0
var enemies_destroyed := 0
var is_stage_completed := false
signal stage_completed
signal game_over

func _ready() -> void:
	$Gyaraga.lives = starting_lives
	$HUD.update_lives(starting_lives)
	$HUD.update_score(score)
	$AttackTimer.wait_time = attack_interval
	$AttackTimer.max_simultaneous_attacks = max_attacks
	print("STAGE 2 INICIADO")

	# Conectar las vidas del jugador con el HUD
	$Gyaraga.lives_changed.connect($HUD.update_lives)

	# Conectar destrucción del jugador
	$Gyaraga.player_destroyed.connect(_on_player_destroyed)

	# Mostrar título del Stage
	$StageLabel.text = "STAGE %d" % stage_number
	$StageLabel.visible = true

	# Esperar antes de iniciar la formación
	await get_tree().create_timer(2.0).timeout

	$StageLabel.visible = false

	# Crear los 21 enemigos
	create_formation()

	# Iniciar ataques
	$AttackTimer.start()

func create_formation() -> void:
	for row in range(rows):
		for column in range(columns):

			var enemy = ENEMY_SCENE.instantiate()

			var formation_pos := Vector2(
				start_x + column * spacing_x,
				start_y + row * spacing_y
			)

			var enemy_type := get_enemy_type(row, column)

			$Enemies.add_child(enemy)

			enemy.configure(
				enemy_type,
				formation_pos
			)

			print(
				"FILA: ", row,
				" | COLUMNA: ", column,
				" | TIPO: ", enemy_type,
				" | POSICION: ", formation_pos
			)

			# Conectar destrucción del enemigo
			enemy.enemy_destroyed.connect(_on_enemy_destroyed)

			enemies.append(enemy)

			# Determinar desde qué lado entra
			var start_position: Vector2

			if row % 2 == 0:
				start_position = Vector2(
					-50,
					150 + row * 40
				)
			else:
				start_position = Vector2(
					730,
					150 + row * 40
				)

			enemy.start_entry(
				start_position,
				formation_pos
			)

	print("Enemigos creados: ", enemies.size())


func get_enemy_type(row: int, column: int) -> int:

	# Primera fila
	# Boss en el centro
	if row == 0:

		if column == 3:
			return 0

		return 1

	# Segunda fila
	if row == 1:

		if column % 2 == 0:
			return 4

		return 3

	# Tercera fila
	return 2


func _on_enemy_destroyed(points_value: int) -> void:

	# Actualizar score
	score += points_value

	$HUD.update_score(score)

	enemies_destroyed += 1

	print("Score: ", score)
	print(
		"Enemigos destruidos: ",
		enemies_destroyed,
		"/",
		rows * columns
	)

	# Verificar si todos los enemigos fueron destruidos
	if enemies_destroyed >= rows * columns and not is_stage_completed:
		complete_stage()

func complete_stage() -> void:
	is_stage_completed = true

	print("================================")
	print("STAGE 2 COMPLETADO")
	print("================================")

	
	$AttackTimer.stop()
	$StageLabel.text = "STAGE COMPLETE"
	$StageLabel.visible = true
	await get_tree().create_timer(2.0).timeout
	stage_completed.emit()
func _on_player_destroyed() -> void:
	print("GAME OVER: señal recibida del jugador")

	$AttackTimer.stop()

	$HUD.show_game_over()

	print("GAME OVER: emitiendo señal hacia Main")
	game_over.emit()
