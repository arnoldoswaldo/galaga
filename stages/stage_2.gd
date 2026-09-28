extends Node2D


const ENEMY_SCENE := preload("res://enemies/enemy.tscn")


@export var rows := 3
@export var columns := 7

@export var start_x := 75.0
@export var start_y := 100.0

@export var spacing_x := 45.0
@export var spacing_y := 42.0


var enemies: Array[Node] = []


func _ready() -> void:

	print("STAGE 2 INICIADO")

	$StageLabel.text = "STAGE 2"
	$StageLabel.visible = true

	await get_tree().create_timer(2.0).timeout

	$StageLabel.visible = false

	create_formation()


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

			enemies.append(enemy)

			# Posición inicial fuera de la pantalla
			var start_position: Vector2

			if row % 2 == 0:
				start_position = Vector2(-50, 150 + row * 40)
			else:
				start_position = Vector2(730, 150 + row * 40)

			enemy.start_entry(
				start_position,
				formation_pos
			)

	print("Enemigos creados: ", enemies.size())


func get_enemy_type(row: int, column: int) -> int:

	if row == 0:

		if column == 3:
			return 0

		return 1

	if row == 1:

		if column % 2 == 0:
			return 4

		return 3

	return 2


func show_stage_label() -> void:

	var stage_label: Label = $StageLabel

	stage_label.text = "STAGE 2"
	stage_label.visible = true

	await get_tree().create_timer(2.0).timeout

	stage_label.visible = false
