extends "res://enemies/enemy.gd"

signal escaped

var flight_path: Curve2D
var flight_distance := 0.0
var flight_speed := 155.0

func _process(delta: float) -> void:
	if is_being_hit or flight_path == null:
		return
	flight_distance += flight_speed * delta
	var length := flight_path.get_baked_length()
	global_position = flight_path.sample_baked(minf(flight_distance, length), true)
	var ahead := flight_path.sample_baked(minf(flight_distance + 3.0, length), true)
	var behind := flight_path.sample_baked(maxf(flight_distance - 3.0, 0.0), true)
	var direction := ahead - behind
	# The sheet mixes animation poses and partial turns, not eight compass directions.
	# Rotate the downward pose in eight directions to follow the curve consistently.
	if direction.length_squared() > 0.01:
		sprite.frame = 0
		sprite.rotation = roundf((direction.angle() - PI / 2.0) / (PI / 4.0)) * (PI / 4.0)
	if flight_distance >= length:
		escaped.emit()
		queue_free()

func hit() -> void:
	if is_being_hit:
		return
	set_deferred("monitorable", false)
	$Sprite2D.hide()
	super.hit()
