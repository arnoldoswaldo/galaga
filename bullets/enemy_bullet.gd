extends Area2D

@export var speed := 250.0

func _ready() -> void:
	add_to_group("enemy_bullets")

func _process(delta: float) -> void:
	position.y += speed * delta

	if position.y > 672:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	print("BALA ENEMIGA COLISIONÓ CON: ", body.name)

	if body.is_in_group("player"):
		body.hit_by_enemy()
		queue_free()
