extends PathFollow2D

@export var speed: float = 0.5
var is_in_formation: bool = false

func _process(delta: float) -> void:
	var path := get_parent() as Path2D
	if path == null or path.curve == null or path.curve.get_baked_length() <= 0.0:
		return
	if is_in_formation:
		return 

	progress_ratio += speed * delta
	
	if progress_ratio >= 1.0:
		is_in_formation = true
