extends Area2D

var shoot_cooldown = 5

func start(_position, _direction):
	global_position = _position
	rotation = _direction

func _physics_process(delta):
	var direccion = Vector2.UP.rotated(rotation)
	
	await get_tree().create_timer(shoot_cooldown).timeout
	queue_free()


func _on_body_entered(body):
	print("Special: Golpeó: ", body.name)

	#if body.has_method("hit"):
		#body.hit()
