extends Area2D

@export var speed := 250.0

func _process(delta: float) -> void:
	position.y += speed * delta
	if position.y > 672:
		queue_free()
