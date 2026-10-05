extends Area2D
signal enemy_destroyed(points_value: int)
enum State {
	ENTERING,
	FORMATION,
	ATTACKING,
	RETURNING
}

enum EnemyType {
	BOSS,
	GOEI,
	YAKO,
	SCORPION,
	MOMIJI
}

@export var speed := 100.0
@export var points := 100

var state := State.FORMATION
var enemy_type := EnemyType.YAKO
var formation_position := Vector2.ZERO
var attack_direction := Vector2.ZERO
var attack_time := 0.0
var attack_duration := 2.5
var attack_start_position := Vector2.ZERO
var return_time := 0.0
var return_duration := 1.5
var return_start_position := Vector2.ZERO
var entry_time := 0.0
var entry_duration := 2.5
var entry_start := Vector2.ZERO
var entry_target := Vector2.ZERO
var is_being_hit := false
var enemy_bullet_scene = preload("res://bullets/enemy_bullet.tscn")

@onready var sprite: Sprite2D = $Sprite2D


var enemy_textures: Array[Texture2D] = [
	preload("res://assets/enemies/BossGalaga.png"),
	preload("res://assets/enemies/Goei.png"),
	preload("res://assets/enemies/Yako.png"),
	preload("res://assets/enemies/Scorpion.png"),
	preload("res://assets/enemies/Momiji.png")
]

func _ready() -> void:
	add_to_group("enemies")

	sprite.visible = true
	sprite.hframes = 8
	sprite.vframes = 1
	sprite.frame = 0
	sprite.scale = Vector2(1.5, 1.5)


func configure(type: int, formation_pos: Vector2) -> void:
	enemy_type = type
	formation_position = formation_pos
	global_position = formation_pos
	sprite.texture = enemy_textures[enemy_type]
	sprite.hframes = 8
	sprite.vframes = 1
	sprite.frame = 0

func start_entry(start_position: Vector2, target_position: Vector2) -> void:
	entry_start = start_position
	entry_target = target_position
	formation_position = target_position
	global_position = start_position
	entry_time = 0.0
	state = State.ENTERING

func update_entry(delta: float) -> void:

	entry_time += delta
	var t: float = entry_time / entry_duration
	t = clamp(t, 0.0, 1.0)
	var x: float = lerp(
		entry_start.x,
		entry_target.x,
		t
	)
	var y: float = lerp(
		entry_start.y,
		entry_target.y,
		t
	)
	var curve: float = sin(t * PI) * 180.0
	y -= curve
	global_position = Vector2(x, y)
	if t >= 1.0:

		global_position = formation_position

		state = State.FORMATION

		print(
			"ENTRADA COMPLETADA: ",
			name,
			" | POSICION: ",
			global_position
		)

func _process(delta: float) -> void:

	if state == State.ENTERING:
		update_entry(delta)

	elif state == State.ATTACKING:
		update_attack(delta)

	elif state == State.RETURNING:
		update_return(delta)


func get_attack_direction() -> Vector2:

	var enemies = get_tree().get_nodes_in_group("enemies")

	if enemies.is_empty():
		return Vector2.DOWN

	var min_x := formation_position.x
	var max_x := formation_position.x

	for enemy in enemies:

		if enemy == self:
			continue

		min_x = min(min_x, enemy.formation_position.x)
		max_x = max(max_x, enemy.formation_position.x)

	var center_x := (min_x + max_x) / 2.0

	var distance_from_center := formation_position.x - center_x

	if distance_from_center < -45.0:
		return Vector2.LEFT

	if distance_from_center > 45.0:
		return Vector2.RIGHT

	return Vector2.ZERO

func start_attack() -> void:

	if state != State.FORMATION:
		print("ENEMIGO NO PUEDE ATACAR. ESTADO: ", state)
		return

	print("ENEMIGO INICIANDO ATAQUE: ", name)
	print("POSICION ACTUAL: ", global_position)
	print("POSICION FORMACION: ", formation_position)

	state = State.ATTACKING

	attack_time = 0.0


	attack_start_position = global_position

	attack_direction = get_attack_direction()

	print("DIRECCION: ", attack_direction)

	shoot()

func update_attack(delta: float) -> void:

	attack_time += delta

	var t: float = attack_time / attack_duration
	t = clamp(t, 0.0, 1.0)

	var vertical_distance := 220.0
	var horizontal_distance := 140.0

	var x := attack_start_position.x
	var y := attack_start_position.y

	x += attack_direction.x * sin(t * PI) * horizontal_distance

	y += t * vertical_distance

	global_position = Vector2(x, y)

	if t >= 1.0:

		return_start_position = global_position

		state = State.RETURNING

		return_time = 0.0

		print("ATAQUE TERMINADO: ", name)
		print("POSICION DE RETORNO: ", return_start_position)
		print("FORMACION: ", formation_position)

func update_return(delta: float) -> void:

	return_time += delta

	var t: float = return_time / return_duration
	t = clamp(t, 0.0, 1.0)

	var start := return_start_position
	var target := formation_position

	global_position = start.lerp(target, t)

	if t >= 1.0:

		global_position = formation_position

		state = State.FORMATION

		print("REGRESO COMPLETADO: ", name)
		print("POSICION FINAL: ", global_position)


func shoot() -> void:
	print("ENEMIGO DISPARANDO: ", name)

	var bullet = enemy_bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)

	bullet.global_position = global_position

	var player = get_tree().get_first_node_in_group("player")

	if player:
		bullet.direction = (
			player.global_position - global_position
		).normalized()

	print("BALA CREADA: ", bullet)


func hit() -> void:

	if is_being_hit:
		return

	is_being_hit = true

	enemy_destroyed.emit(points)

	$HitSound.play()

	await $HitSound.finished

	queue_free()
