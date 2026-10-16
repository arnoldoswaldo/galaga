extends Area2D

var speed = -750


func start(_position, _direction):
	global_position = _position
	rotation = _direction

func _physics_process(delta):
	var direccion = Vector2.UP.rotated(rotation)
	global_position += direccion * speed * delta

	if global_position.y <= 0:
		queue_free()

func _on_body_entered(body):
	print("Bullet: Golpeó: ", body.name)

	if body.has_method("hit"):
		body.hit()

	queue_free()
