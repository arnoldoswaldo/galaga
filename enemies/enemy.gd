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
var attack_path: Curve2D
var return_path: Curve2D
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
func update_return(delta: float) -> void:

	if return_path == null:
		return

	return_time += delta

	var t := clampf(return_time / return_duration, 0.0, 1.0)
	var distance := t * return_path.get_baked_length()

	global_position = return_path.sample_baked(distance, true)

	if t >= 1.0:

		global_position = formation_position
		return_path = null
		attack_path = null

		state = State.FORMATION

		print("REGRESO COMPLETADO: ", name)

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
	
func create_flight_path(
	start: Vector2,
	control_1: Vector2,
	control_2: Vector2,
	target: Vector2
) -> Curve2D:

	var path := Curve2D.new()
	path.bake_interval = 2.0

	path.add_point(start, Vector2.ZERO, control_1 - start)
	path.add_point(
		target,
		control_2 - target,
		Vector2.ZERO
	)

	return path


func start_attack() -> void:
	if state != State.FORMATION:
		print("ENEMIGO NO PUEDE ATACAR. ESTADO: ", state)
		return

	print("ENEMIGO INICIANDO ATAQUE: ", name)

	state = State.ATTACKING
	attack_time = 0.0
	attack_start_position = global_position
	attack_direction = get_attack_direction()

	var start := global_position
	var side := attack_direction.x

	# Si el enemigo está en el centro, elegir un lado.
	if side == 0.0:
		side = -1.0 if randf() < 0.5 else 1.0

	# Variar la amplitud y la forma de la maniobra.
	var maneuver := randi_range(0, 2)
	var horizontal_distance: float
	var vertical_distance: float
	var curve_strength: float

	match maneuver:
		0:
			# Ataque lateral.
			horizontal_distance = 120.0
			vertical_distance = 220.0
			curve_strength = 180.0

		1:
			# Ataque diagonal.
			horizontal_distance = 180.0
			vertical_distance = 250.0
			curve_strength = 100.0

		2:
			# Ataque con curva amplia.
			horizontal_distance = 100.0
			vertical_distance = 200.0
			curve_strength = 260.0

	var target := start + Vector2(
		side * horizontal_distance,
		vertical_distance
	)

	var control_1 := start + Vector2(
		side * curve_strength,
		40.0
	)

	var control_2 := target + Vector2(
		-side * curve_strength * 0.8,
		-60.0
	)

	attack_path = create_flight_path(
		start,
		control_1,
		control_2,
		target
	)

	print("MANIOBRA SELECCIONADA: ", maneuver)

	shoot()


func update_attack(delta: float) -> void:

	if attack_path == null:
		return

	attack_time += delta

	var t := clampf(attack_time / attack_duration, 0.0, 1.0)
	var distance := t * attack_path.get_baked_length()

	global_position = attack_path.sample_baked(distance, true)

	if t >= 1.0:

		return_start_position = global_position
		return_time = 0.0

		return_path = create_flight_path(
			return_start_position,
			return_start_position + Vector2(0.0, -100.0),
			formation_position + Vector2(0.0, 100.0),
			formation_position
		)

		state = State.RETURNING

		print("ATAQUE TERMINADO: ", name)
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
