extends Area2D

signal health_changed(current: int, maximum: int)
signal phase_changed(phase: int)
signal defeated

enum State { ENTERING, FIGHTING, TRANSITION, DYING, STOPPED }

const ENEMY_BULLET_SCENE := preload("res://bullets/enemy_bullet.tscn")
const EXPLOSION_TEXTURE := preload("res://assets/enemies/EnemyExplosion.png")
const TRANSFORM_SOUND := preload("res://assets/sounds/transform.wav")
const DIVE_SOUND := preload("res://assets/sounds/dive.wav")

@export var max_health := 100
@export var damage_per_hit := 2
@export var points := 1000
@export var phase2_ratio := 0.66
@export var phase3_ratio := 0.33
# Un valor por fase: [fase 1, fase 2, fase 3]
@export var attack_intervals: Array[float] = [1.2, 0.9, 0.6]
@export var bullet_speeds: Array[float] = [200.0, 220.0, 240.0]
@export var move_speeds: Array[float] = [1.0, 1.4, 1.9]
@export var dive_y := 360.0

var health := 0
var state := State.ENTERING
var phase := 1
var attack_count := 0
var is_diving := false
var dive_tween: Tween

var base_x := 0.0
var base_y := 0.0
var amplitude := 0.0
var move_angle := 0.0
var ring_offset := 0.0

# Solo para que enemy.gd pueda leerla del grupo "enemies"
var formation_position := Vector2.ZERO

@onready var attack_timer: Timer = $AttackTimer


func _ready() -> void:
	health = max_health
	formation_position = global_position
	attack_timer.one_shot = false
	attack_timer.autostart = false
	attack_timer.timeout.connect(_on_attack_timer_timeout)


func _process(delta: float) -> void:
	if state != State.FIGHTING:
		return
	move_angle += delta * move_speeds[phase - 1]
	position.x = base_x + sin(move_angle) * amplitude


# ---------- Control desde el stage ----------

# El stage la llama cuando el jefe termina de entrar
func start_fight() -> void:
	base_x = position.x
	base_y = position.y

	var viewport_width := get_viewport_rect().size.x
	var half_width: float = ($Sprite2D.get_rect().size.x * $Sprite2D.scale.x * scale.x) / 2.0
	amplitude = maxf(viewport_width / 2.0 - half_width - 10.0, 0.0)

	state = State.FIGHTING
	_apply_phase_settings()
	attack_timer.start()


# El stage la llama si el jugador muere
func stop_fight() -> void:
	if state == State.DYING:
		return
	state = State.STOPPED
	attack_timer.stop()
	if dive_tween:
		dive_tween.kill()


# ---------- Daño y fases ----------

func hit() -> void:
	if state != State.FIGHTING:
		return

	health = maxi(health - damage_per_hit, 0)
	health_changed.emit(health, max_health)

	if health <= 0:
		_die()
		return

	$Hitsound.play()
	_flash()

	var ratio := float(health) / float(max_health)
	var target_phase := 1
	if ratio <= phase3_ratio:
		target_phase = 3
	elif ratio <= phase2_ratio:
		target_phase = 2

	if target_phase > phase:
		_change_phase(target_phase)


func _apply_phase_settings() -> void:
	attack_timer.wait_time = attack_intervals[phase - 1]


func _change_phase(new_phase: int) -> void:
	state = State.TRANSITION
	phase = new_phase
	attack_timer.stop()
	if dive_tween:
		dive_tween.kill()
	is_diving = false
	_clear_enemy_bullets()
	_play_sound(TRANSFORM_SOUND)
	phase_changed.emit(phase)

	# Vuelve a su altura base (por si lo golpearon en plena embestida)
	var back := create_tween()
	back.tween_property(self, "position:y", base_y, 0.5)

	# Parpadeo de transición (~1.5 s), invulnerable
	var blink := create_tween()
	blink.set_loops(5)
	blink.tween_property($Sprite2D, "modulate:a", 0.2, 0.15)
	blink.tween_property($Sprite2D, "modulate:a", 1.0, 0.15)
	await blink.finished

	if state != State.TRANSITION:
		return

	$Sprite2D.modulate.a = 1.0
	state = State.FIGHTING
	attack_count = 0
	_apply_phase_settings()
	attack_timer.start()


# ---------- Ataques ----------

func _on_attack_timer_timeout() -> void:
	if state != State.FIGHTING or is_diving:
		return

	attack_count += 1
	var speed: float = bullet_speeds[phase - 1]

	match phase:
		1:
			if attack_count % 2 == 0:
				_shoot_fan(3, 20.0, speed)
			else:
				_shoot_aimed_sides(speed)
		2:
			if attack_count % 2 == 0:
				_shoot_ring(10, speed)
			else:
				_shoot_fan(5, 18.0, speed)
		3:
			if attack_count % 4 == 0:
				_dive()
			elif attack_count % 2 == 0:
				_shoot_ring(12, speed)
			else:
				_shoot_fan(5, 15.0, speed)


func _aim_dir(from: Vector2) -> Vector2:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		return (player.global_position - from).normalized()
	return Vector2.DOWN


func _spawn_bullet(from: Vector2, dir: Vector2, speed: float) -> void:
	var bullet = ENEMY_BULLET_SCENE.instantiate()
	bullet.speed = speed
	bullet.direction = dir
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = from


# Una bala apuntada desde cada cañón lateral
func _shoot_aimed_sides(speed: float) -> void:
	for muzzle in [$MuzzleLeft, $MuzzleRight]:
		var origin: Vector2 = muzzle.global_position
		_spawn_bullet(origin, _aim_dir(origin), speed)


# Abanico apuntado al jugador. step_deg = ángulo entre balas
func _shoot_fan(count: int, step_deg: float, speed: float) -> void:
	var origin: Vector2 = $MuzzleCenter.global_position
	var base_dir := _aim_dir(origin)
	for i in count:
		var angle := (i - (count - 1) / 2.0) * step_deg
		_spawn_bullet(origin, base_dir.rotated(deg_to_rad(angle)), speed)


# Anillo que gira un poco en cada ráfaga. Se omiten las balas que van
# hacia arriba: enemy_bullet.gd no se libera al salir por el borde superior.
func _shoot_ring(count: int, speed: float) -> void:
	var origin: Vector2 = $MuzzleCenter.global_position
	ring_offset += deg_to_rad(11.0)
	for i in count:
		var dir := Vector2.DOWN.rotated(ring_offset + TAU * i / count)
		if dir.y < -0.3:
			continue
		_spawn_bullet(origin, dir, speed)


# Embestida: aviso, baja, dispara abajo, vuelve a su sitio
func _dive() -> void:
	is_diving = true
	_play_sound(DIVE_SOUND)

	dive_tween = create_tween()
	dive_tween.tween_interval(0.5)
	dive_tween.tween_property(self, "position:y", dive_y, 0.7) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	dive_tween.tween_callback(_shoot_fan.bind(5, 22.0, bullet_speeds[phase - 1]))
	dive_tween.tween_interval(0.4)
	dive_tween.tween_property(self, "position:y", base_y, 1.0) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	dive_tween.tween_callback(_end_dive)


func _end_dive() -> void:
	is_diving = false


# ---------- Muerte ----------

func _die() -> void:
	state = State.DYING
	attack_timer.stop()
	if dive_tween:
		dive_tween.kill()
	_clear_enemy_bullets()
	$CollisionShape2D.set_deferred("disabled", true)
	$DeadSound.play()

	# ~1.8 s de explosiones aleatorias sobre el cuerpo
	var half: Vector2 = $Sprite2D.get_rect().size * $Sprite2D.scale / 2.0
	for i in 12:
		var offset := Vector2(
			randf_range(-half.x, half.x),
			randf_range(-half.y, half.y)
		)
		_spawn_explosion($Sprite2D.position + offset)
		await get_tree().create_timer(0.15, false).timeout

	$Sprite2D.visible = false
	defeated.emit()

	if $DeadSound.playing:
		await $DeadSound.finished
	queue_free()


# ---------- Utilidades ----------

func _clear_enemy_bullets() -> void:
	for bullet in get_tree().get_nodes_in_group("enemy_bullets"):
		bullet.queue_free()


func _flash() -> void:
	$Sprite2D.modulate = Color(1.0, 0.45, 0.45)
	var t := create_tween()
	t.tween_property($Sprite2D, "modulate", Color.WHITE, 0.12)


func _play_sound(stream: AudioStream) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _spawn_explosion(pos: Vector2) -> void:
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", 14.0)
	frames.set_animation_loop("default", false)
	for i in 4:
		var tex := AtlasTexture.new()
		tex.atlas = EXPLOSION_TEXTURE
		tex.region = Rect2(i * 32, 0, 32, 32)
		frames.add_frame("default", tex)

	var boom := AnimatedSprite2D.new()
	boom.sprite_frames = frames
	boom.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	boom.scale = Vector2(3, 3)
	boom.position = pos
	add_child(boom)
	boom.animation_finished.connect(boom.queue_free)
	boom.play("default")
