extends PathFollow2D

@export var speed: float = 0.5
var is_in_formation: bool = false

func _process(delta: float) -> void:
	if is_in_formation:
		return 

	progress_ratio += speed * delta
	
	if progress_ratio >= 1.0:
		is_in_formation = true
