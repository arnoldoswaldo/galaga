extends Area2D


@export var speed := 500.0


func _ready() -> void:
	add_to_group("player_bullets")


func start(spawn_position: Vector2, bullet_rotation: float = 0.0) -> void:
	global_position = spawn_position
	rotation = bullet_rotation


func _process(delta: float) -> void:
	position.y -= speed * delta

	if position.y < -32:
		queue_free()


func _on_area_entered(area: Area2D) -> void:

	if area.is_in_group("enemies"):
		area.hit()
		queue_free()
