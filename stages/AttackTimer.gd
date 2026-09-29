extends Timer

func _ready() -> void:
	timeout.connect(_on_timeout)

func _on_timeout() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if enemy.state == enemy.State.FORMATION:
			enemy.start_attack()
			break
