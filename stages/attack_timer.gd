extends Timer

var attack_index := 0
var max_simultaneous_attacks := 3

func _ready() -> void:
	print("ATTACK TIMER: READY")
	timeout.connect(_on_timeout)

	wait_time = 1.5

func _on_timeout() -> void:
	print("ATTACK TIMER: DISPARO")

	var enemies = get_tree().get_nodes_in_group("enemies")

	print("Enemigos encontrados: ", enemies.size())

	if enemies.is_empty():
		return

	# Contar enemigos que están atacando o regresando
	var active_attacks := 0

	for enemy in enemies:
		if enemy.state == enemy.State.ATTACKING:
			active_attacks += 1
		elif enemy.state == enemy.State.RETURNING:
			active_attacks += 1

	print("ATAQUES ACTIVOS: ", active_attacks)

	if active_attacks >= max_simultaneous_attacks:
		print("MAXIMO DE ATAQUES SIMULTANEOS")
		return

	for i in range(enemies.size()):

		var index := (attack_index + i) % enemies.size()
		var enemy = enemies[index]

		print(
			"Revisando enemigo ",
			index,
			" | Estado: ",
			enemy.state
		)

		if enemy.state == enemy.State.FORMATION:

			print("ENEMIGO SELECCIONADO: ", index)

			enemy.start_attack()

			attack_index = (index + 1) % enemies.size()

			return

	print("NO HAY ENEMIGOS DISPONIBLES")
