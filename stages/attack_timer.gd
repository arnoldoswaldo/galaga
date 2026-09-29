extends Timer

func _ready() -> void:
	print("ATTACK TIMER: READY")
	timeout.connect(_on_timeout)


func _on_timeout() -> void:
	print("ATTACK TIMER: DISPARO")

	var enemies = get_tree().get_nodes_in_group("enemies")

	print("Enemigos encontrados: ", enemies.size())

	for enemy in enemies:
		if enemy.state == enemy.State.FORMATION:
			print("ENEMIGO SELECCIONADO")
			enemy.start_attack()
			break
