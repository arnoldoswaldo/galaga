
extends Node2D

const STAGE_2_SCENE := preload("res://stages/stage_2.tscn")

var current_stage := 0
var current_stage_node: Node = null
var game_started := false
var game_over := false

@onready var stage_container: Node2D = $StageContainer
@onready var welcome_ui: CanvasLayer = $UI
@onready var start_label: Label = $UI/StartLabel


func _ready() -> void:
	show_welcome()


func show_welcome() -> void:
	print("MOSTRANDO PANTALLA INICIAL")

	game_started = false
	game_over = false

	if current_stage_node != null:
		current_stage_node.queue_free()
		current_stage_node = null

	stage_container.hide()
	welcome_ui.show()

	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(start_label, "modulate:a", 0.2, 0.6)
	tween.tween_property(start_label, "modulate:a", 1.0, 0.6)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			print("ENTER DETECTADO | game_started = ", game_started)
			if not game_started:
				start_game()


func start_game() -> void:
	print("INICIANDO NUEVA PARTIDA")

	if game_started:
		return

	game_started = true
	game_over = false
	current_stage = 2

	welcome_ui.hide()
	stage_container.show()

	load_stage(current_stage)


func load_stage(stage_number: int) -> void:
	if current_stage_node != null:
		current_stage_node.queue_free()
		current_stage_node = null

	match stage_number:
		2:
			current_stage_node = STAGE_2_SCENE.instantiate()

		_:
			print("STAGE NO DISPONIBLE: ", stage_number)
			return

	stage_container.add_child(current_stage_node)

	if current_stage_node.has_signal("stage_completed"):
		current_stage_node.stage_completed.connect(
			_on_stage_completed
		)

	if current_stage_node.has_signal("game_over"):
		current_stage_node.game_over.connect(
			_on_game_over
		)
		print("MAIN: señal game_over conectada")
	else:
		print("ERROR: Stage 2 no tiene la señal game_over")

func _on_stage_completed() -> void:
	print("STAGE COMPLETADO: ", current_stage)

	current_stage += 1

	print("SIGUIENTE STAGE: ", current_stage)


func _on_game_over() -> void:
	print("GAME OVER RECIBIDO POR MAIN")

	game_over = true
	game_started = false

	show_welcome()
