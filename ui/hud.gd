extends CanvasLayer

@onready var score_label: Label = $ScoreLabel
@onready var lives_label: Label = $LivesLabel
@onready var game_over_label: Label = $GameOverLabel


func _ready() -> void:
	update_score(0)
	update_lives(3)

	game_over_label.visible = false


func update_score(value: int) -> void:
	score_label.text = "SCORE: " + str(value)


func update_lives(value: int) -> void:
	lives_label.text = "LIVES: " + str(value)


func show_game_over() -> void:
	game_over_label.text = "GAME OVER"
	game_over_label.visible = true
