extends CharacterBody2D

signal enemy_destroyed(points_value: int)

@onready var _animated_sprite = $AnimatedSprite2D
@onready var _hitbox: Area2D = $Hitbox

@export var points_value := 100

@export var shoot_cooldown := 1.0
@export var velocidad_ataque := 350.0
@export var espera_min := 4.0
@export var espera_max := 12.0
@export var intervalo_disparo_ataque := 0.5
@export var tiempo_especial := 5.0

@export var especial_espera_minima := 2.0
@export var especial_prob_por_segundo := 0.02

var Bullet = preload("res://bullets/s_bullet_enemie.tscn")
var Special = preload("res://bullets/s_special.tscn")

var _path_follow: PathFollow2D
var velocidad := 300.0
var posicion_final: Vector2
var animation: String

var shootEnabled := true
var tiempo_espera := 0.0
var direccion_ataque := Vector2.DOWN
var temporizador_disparo := 0.0
var especial_llegado := false
var temporizador_especial := 0.0

enum Estado { ENTRAR, ORGANIZAR, FORMACION, ATACAR, ESPECIAL, MORIR }
var estado_actual = Estado.ENTRAR


func _ready() -> void:
	add_to_group("enemies")
	_hitbox.body_entered.connect(_on_hitbox_body_entered)


func iniciar(curva: Curve2D, destino: Vector2, animacion: String) -> void:
	posicion_final = destino
	animation = animacion

	var path2d = Path2D.new()
	path2d.curve = curva
	path2d.top_level = true

	_path_follow = PathFollow2D.new()
	_path_follow.rotates = true
	_path_follow.loop = false

	path2d.add_child(_path_follow)
	add_child(path2d)


# Colisión con el jugador (la detecta el Area2D, no una distancia)
func _on_hitbox_body_entered(body: Node) -> void:
	if estado_actual == Estado.MORIR:
		return
	if body.is_in_group("player") and body.has_method("hit"):
		body.hit()
		hit()


func _physics_process(delta: float) -> void:
	match estado_actual:
		Estado.ENTRAR:
			avanzar_curva(delta)
		Estado.ORGANIZAR:
			organizar(delta)
		Estado.FORMACION:
			formacion(delta)
		Estado.ATACAR:
			atacar(delta)
		Estado.ESPECIAL:
			especial(delta)
		Estado.MORIR:
			morir()


func avanzar_curva(delta: float) -> void:
	_animated_sprite.play(animation)

	if _path_follow:
		_path_follow.progress += velocidad * delta
		global_position = _path_follow.global_position
		global_rotation = _path_follow.global_rotation + (PI / 2.0)

		if _path_follow.progress_ratio >= 1.0:
			estado_actual = Estado.ORGANIZAR


func organizar(delta: float) -> void:
	global_rotation = lerp_angle(global_rotation, 0.0, 10.0 * delta)

	if (posicion_final - global_position).length() < 5.0:
		global_position = posicion_final
		global_rotation = 0.0
		tiempo_espera = especial_espera_minima if animation == "default2" \
			else randf_range(espera_min, espera_max)
		estado_actual = Estado.FORMACION
		return

	global_position = global_position.move_toward(posicion_final, velocidad * delta)


func formacion(delta: float) -> void:
	tiempo_espera -= delta
	if tiempo_espera > 0.0:
		return

	if animation == "default2":
		# Sale en un momento aleatorio
		if randf() < especial_prob_por_segundo * delta:
			empezar_ataque()
	else:
		empezar_ataque()


func empezar_ataque() -> void:
	if animation == "default2":
		especial_llegado = false
		temporizador_especial = tiempo_especial
		estado_actual = Estado.ESPECIAL
		return

	var jugador = get_tree().get_first_node_in_group("player")
	var objetivo = jugador.global_position if jugador \
		else global_position + Vector2(0, get_viewport_rect().size.y)

	direccion_ataque = (objetivo - global_position).normalized()
	if direccion_ataque.y < 0.2:
		direccion_ataque = Vector2(direccion_ataque.x, 0.2).normalized()

	temporizador_disparo = intervalo_disparo_ataque * 0.5
	estado_actual = Estado.ATACAR


func atacar(delta: float) -> void:
	global_position += direccion_ataque * velocidad_ataque * delta
	global_rotation = direccion_ataque.angle() + PI / 2.0

	temporizador_disparo -= delta
	if temporizador_disparo <= 0.0:
		temporizador_disparo = intervalo_disparo_ataque
		shoot()

	# Sale por abajo y reaparece arriba sobre su columna
	if global_position.y > get_viewport_rect().size.y + 50.0:
		global_position = Vector2(posicion_final.x, -50.0)
		estado_actual = Estado.ORGANIZAR


func especial(delta: float) -> void:
	if not especial_llegado:
		var objetivo = Vector2(global_position.x, get_viewport_rect().size.y / 2.0)
		global_position = global_position.move_toward(objetivo, velocidad_ataque * delta)
		global_rotation = lerp_angle(global_rotation, 0.0, 10.0 * delta)

		if global_position.distance_to(objetivo) < 2.0:
			especial_llegado = true
			disparar(Special)
	else:
		temporizador_especial -= delta
		if temporizador_especial <= 0.0:
			estado_actual = Estado.ORGANIZAR


func shoot() -> void:
	disparar(Bullet)


func disparar(escena: PackedScene) -> void:
	if not shootEnabled:
		return

	shootEnabled = false

	var b = escena.instantiate()
	b.start($Muzzle.global_position, 0.0)
	get_parent().add_child(b)

	await get_tree().create_timer(shoot_cooldown).timeout
	shootEnabled = true


# Lo llaman las balas del jugador
func hit() -> void:
	if estado_actual == Estado.MORIR:
		return

	estado_actual = Estado.MORIR
	enemy_destroyed.emit(points_value)

	# Desactivar colisiones apenas muere
	$CollisionShape2D.set_deferred("disabled", true)
	_hitbox.set_deferred("monitoring", false)
	_hitbox.set_deferred("monitorable", false)

	_animated_sprite.play("killed")
	await _animated_sprite.animation_finished
	queue_free()


# La muerte ocurre en hit(); este estado solo detiene el movimiento
func morir() -> void:
	pass
