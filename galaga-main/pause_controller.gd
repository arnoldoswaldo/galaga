extends Node

@onready var pause_panel: Control = get_parent().get_node("PauseUI/PausePanel")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_panel.hide()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			toggle_pause()

func toggle_pause() -> void:
	var main = get_parent()

	if not main.game_started:
		return

	get_tree().paused = not get_tree().paused

	if get_tree().paused:
		print("JUEGO PAUSADO")
		pause_panel.show()
	else:
		print("JUEGO REANUDADO")
		pause_panel.hide()
