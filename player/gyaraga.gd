extends CharacterBody2D

var Bullet = preload("res://bullets/bullet.tscn")

@export var speed := 300.0
@export var max_lives := 3

var lives := max_lives
var is_destroyed := false

signal lives_changed(current_lives: int)
signal player_destroyed

func _ready() -> void:
	add_to_group("player")

	var viewport_size = get_viewport_rect().size
	var rect = $Sprite2D.get_rect()
	var half_width = (rect.size.x * scale.x) / 2.0

	position = Vector2(
		viewport_size.x / 2.0,
		viewport_size.y - (4 * half_width)
	)

	lives_changed.emit(lives)


func get_input() -> void:
	if is_destroyed:
		return

	var input_dir = Input.get_axis("ui_left", "ui_right")

	velocity = Vector2(input_dir, 0) * speed

	if Input.is_action_just_pressed("shoot"):
		shoot()


func shoot() -> void:
	if is_destroyed:
		return

	var b = Bullet.instantiate()

	get_tree().current_scene.add_child(b)

	b.global_position = $Muzzle.global_position

	$ShotSound.play()


func _physics_process(delta: float) -> void:
	if is_destroyed:
		return

	get_input()

	move_and_collide(velocity * delta)

	var viewport_size = get_viewport_rect().size
	var rect = $Sprite2D.get_rect()
	var half_width = (rect.size.x * scale.x) / 2.0

	position.x = clamp(
		position.x,
		half_width,
		viewport_size.x - half_width
	)

func hit_by_enemy() -> void:
	if is_destroyed:
		return

	lives = max(lives - 1, 0)

	print("Gyaraga recibió un impacto. Vidas restantes: ", lives)

	lives_changed.emit(lives)

	if lives <= 0:
		destroy_player()
	else:
		reset_position()

func reset_position() -> void:
	var viewport_size = get_viewport_rect().size
	var rect = $Sprite2D.get_rect()
	var half_width = (rect.size.x * scale.x) / 2.0

	position = Vector2(
		viewport_size.x / 2.0,
		viewport_size.y - (4 * half_width)
	)

func destroy_player() -> void:
	is_destroyed = true

	velocity = Vector2.ZERO

	player_destroyed.emit()

	$ExplosionSound.play()

	$Sprite2D.visible = false

	await $ExplosionSound.finished
