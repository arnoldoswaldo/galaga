extends CharacterBody2D

var Bullet = preload("res://bullets/bullet.tscn")
var speed = 300

func get_input():
	var input_dir = Input.get_axis("ui_left", "ui_right")
	velocity = Vector2(input_dir, 0) * speed
	if Input.is_action_just_pressed("shoot"):
		shoot()

func shoot():
	var b = Bullet.instantiate()
	b.start($Muzzle.global_position, rotation)
	get_tree().root.add_child(b)


func _physics_process(delta: float) -> void:
	get_input()
	move_and_collide(velocity * delta)

	var viewport_size = get_viewport_rect().size
	var rect = $Sprite2D.get_rect()
	var half_width = (rect.size.x * scale.x)/ 2.0
	
	position.x = clamp(position.x, half_width, viewport_size.x - half_width)

func _ready():
	var viewport_size = get_viewport_rect().size
	var rect = $Sprite2D.get_rect()
	var half_width = (rect.size.x * scale.x)/ 2.0
	
	position = Vector2(viewport_size.x / 2.0, viewport_size.y - (4*half_width))
