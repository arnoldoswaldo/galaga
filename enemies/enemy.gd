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
var attack_phase := 0.0

# Entrada de los enemigos
var entry_time := 0.0
var entry_duration := 2.5

var entry_start := Vector2.ZERO
var entry_target := Vector2.ZERO

# Evita procesar varios impactos al mismo tiempo
var is_being_hit := false

# Bala enemiga
var enemy_bullet_scene = preload("res://bullets/enemy_bullet.tscn")

@onready var sprite: Sprite2D = $Sprite2D


# Texturas de los diferentes tipos de enemigo
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
	sprite.scale = Vector2(2.0, 2.0)


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
	formation_position = target_position

	global_position = start_position

	entry_time = 0.0
	state = State.ENTERING


func _process(delta: float) -> void:
	if state == State.ENTERING:
		update_entry(delta)


func update_entry(delta: float) -> void:
	entry_time += delta

	var t: float = entry_time / entry_duration
	t = clamp(t, 0.0, 1.0)

	var start: Vector2 = entry_start
	var target: Vector2 = formation_position

	var x: float = lerp(start.x, target.x, t)

	var curve: float = sin(t * PI) * 180.0

	var y: float = lerp(start.y, target.y, t) - curve

	global_position = Vector2(x, y)

	if t >= 1.0:
		global_position = target
		state = State.FORMATION



func start_attack() -> void:
	print("ENEMIGO INICIANDO ATAQUE")

	if state != State.FORMATION:
		print("ENEMIGO NO ESTA EN FORMATION")
		return

	state = State.ATTACKING

	shoot()


func shoot() -> void:
	print("ENEMIGO DISPARANDO")

	var bullet = enemy_bullet_scene.instantiate()

	get_tree().current_scene.add_child(bullet)

	bullet.global_position = global_position

	print("BALA CREADA: ", bullet)
	print("POSICION DE BALA: ", bullet.global_position)
	print("PADRE DE BALA: ", bullet.get_parent())


func hit() -> void:
	if is_being_hit:
		return

	is_being_hit = true

	enemy_destroyed.emit(points)

	$HitSound.play()

	await $HitSound.finished

	queue_free()
