extends Node2D

# STAGE 3: "ORBITAL"


const ENEMY_SCENE := preload("res://enemies/enemy.tscn")

@export var stage_number := 1
@export var center_x := 240.0   
@export var center_y := 200.0
@export var entry_speed := 340.0
@export var rotate_during_entry := true
@export var attack_interval := 0.9
@export var max_attacks := 3
@export var combo_window := 1.5        
@export var max_multiplier := 4

# Anillos
const RINGS: Array[Dictionary] = [
	{"count": 14, "rx": 190.0, "ry": 120.0, "types": [2]},
	{"count": 8,  "rx": 125.0, "ry": 78.0,  "types": [3, 4]},
	{"count": 4,  "rx": 60.0,  "ry": 38.0,  "types": [1]},
]
const BOSS_TYPE := 0

var starting_lives := 3
var enemies: Array[Node] = []
var total_enemies := 0
var score := 0
var enemies_destroyed := 0
var flying := 0
var is_stage_completed := false
var phase := 0
var combo := 0
var combo_timer := 0.0
var combo_label: Label
var banner_id := 0

signal stage_completed
signal game_over


func _ready() -> void:
	$Gyaraga.lives = starting_lives
	$HUD.update_lives(starting_lives)
	$HUD.update_score(score)
	$AttackTimer.wait_time = attack_interval
	$AttackTimer.max_simultaneous_attacks = max_attacks

	$Gyaraga.lives_changed.connect($HUD.update_lives)
	$Gyaraga.player_destroyed.connect(_on_player_destroyed)

	_create_combo_label()

	print("STAGE %d INICIADO" % stage_number)
	$StageLabel.text = "STAGE %d" % stage_number
	$StageLabel.visible = true

	await get_tree().create_timer(2.0).timeout
	if _should_stop():
		return
	$StageLabel.visible = false

	await run_waves()
	if _should_stop():
		return

	# Esperar a que todos terminen de acomodarse en la formación.
	while not _should_stop():
		var still_entering := false
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy.state == enemy.State.ENTERING:
				still_entering = true
				break
		if not still_entering:
			break
		await get_tree().create_timer(0.1).timeout

	if _should_stop():
		return

	$AttackTimer.start()
	print("Formación completa. Ataques iniciados.")


func _process(delta: float) -> void:
	if combo > 0:
		combo_timer -= delta
		combo_label.modulate.a = clampf(combo_timer / combo_window, 0.0, 1.0)
		if combo_timer <= 0.0:
			combo = 0
			combo_label.visible = false


func _should_stop() -> bool:
	return is_stage_completed or not is_inside_tree()


# ---------------------------------------------------------------- FORMACIÓN

func build_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	var center := Vector2(center_x, center_y)

	for ring_index in range(RINGS.size()):
		var ring: Dictionary = RINGS[ring_index]
		var count: int = ring["count"]
		var types: Array = ring["types"]
		for i in range(count):
			var angle := -PI / 2.0 + TAU * i / count
			slots.append({
				"pos": center + Vector2(cos(angle) * ring["rx"], sin(angle) * ring["ry"]),
				"type": types[i % types.size()],
				"ring": ring_index,
			})

	# Jefe en el centro.
	slots.append({"pos": center, "type": BOSS_TYPE, "ring": RINGS.size()})
	return slots


func run_waves() -> void:
	var slots := build_slots()
	total_enemies = slots.size()

	var ring0: Array = slots.filter(func(s): return s["ring"] == 0)
	var ring1: Array = slots.filter(func(s): return s["ring"] == 1)
	var ring2: Array = slots.filter(func(s): return s["ring"] == 2)
	var boss: Array = slots.filter(func(s): return s["ring"] == RINGS.size())

	# Oleada 1: anillo exterior, dos trenes en espejo con bucle.
	var wave1: Array[Dictionary] = []
	for i in range(ring0.size()):
		wave1.append({
			"slot": ring0[i], "kind": "loop",
			"side": -1.0 if i % 2 == 0 else 1.0,
			"delay": floori(i * 0.5) * 0.22,
		})
	await run_wave("OLEADA 1", wave1)
	if _should_stop():
		return

	# Oleada 2: anillo medio, espiral desde arriba.
	var wave2: Array[Dictionary] = []
	for i in range(ring1.size()):
		wave2.append({
			"slot": ring1[i], "kind": "spiral",
			"side": -1.0 if i % 2 == 0 else 1.0,
			"delay": floori(i * 0.5) * 0.3,
		})
	await run_wave("OLEADA 2", wave2)
	if _should_stop():
		return

	# Oleada 3: anillo interior con bucle rápido + el jefe baja al final.
	var wave3: Array[Dictionary] = []
	for i in range(ring2.size()):
		wave3.append({
			"slot": ring2[i], "kind": "loop",
			"side": -1.0 if i % 2 == 0 else 1.0,
			"delay": i * 0.3,
		})
	wave3.append({"slot": boss[0], "kind": "descend", "side": 1.0, "delay": 1.8})
	await run_wave("¡EL JEFE LLEGA!", wave3)


func run_wave(label: String, jobs: Array[Dictionary]) -> void:
	show_banner(label, 1.4)
	await get_tree().create_timer(1.0).timeout
	if _should_stop():
		return

	for job in jobs:
		fly_enemy(job)  # corrutina en paralelo, no se espera

	while flying > 0 and not _should_stop():
		await get_tree().create_timer(0.1).timeout

	if not _should_stop():
		await get_tree().create_timer(0.4).timeout


# ------------------------------------------------------------ VUELO / CURVAS

func fly_enemy(job: Dictionary) -> void:
	flying += 1

	await get_tree().create_timer(job["delay"]).timeout
	if _should_stop():
		flying -= 1
		return

	var slot: Dictionary = job["slot"]
	var formation_pos: Vector2 = slot["pos"]

	var enemy = ENEMY_SCENE.instantiate()
	$Enemies.add_child(enemy)
	enemy.configure(slot["type"], formation_pos)
	enemy.enemy_destroyed.connect(_on_enemy_destroyed)
	enemies.append(enemy)

	var curve := build_curve(job["kind"], job["side"], formation_pos)
	var length := curve.get_baked_length()
	var speed := entry_speed * (0.6 if job["kind"] == "descend" else 1.0)

	enemy.global_position = curve.sample_baked(0.0)
	enemy.visible = true

	var tween := create_tween()
	tween.tween_method(_follow_path.bind(enemy, curve, length), 0.0, 1.0, length / speed)
	await tween.finished

	flying -= 1
	if _should_stop() or not is_instance_valid(enemy):
		return

	enemy.rotation = 0.0
	enemy.global_position = formation_pos
	enemy.start_entry(formation_pos, formation_pos)


func _follow_path(t: float, enemy: Node, curve: Curve2D, length: float) -> void:
	if not is_instance_valid(enemy):
		return
	var distance := t * length
	var pos := curve.sample_baked(distance)
	if rotate_during_entry:
		var ahead := curve.sample_baked(minf(length, distance + 6.0))
		var dir := ahead - pos
		if dir.length() > 0.1:
			enemy.rotation = dir.angle() - PI / 2.0
	enemy.global_position = pos


func build_curve(kind: String, side: float, target: Vector2) -> Curve2D:
	var pts := get_waypoints(kind, side)
	pts.append(target)

	# Suavizado tipo Catmull-Rom: la tangente de cada punto sale de sus vecinos.
	var curve := Curve2D.new()
	for i in range(pts.size()):
		var prev := pts[maxi(i - 1, 0)]
		var next := pts[mini(i + 1, pts.size() - 1)]
		var tangent := (next - prev) * 0.2
		curve.add_point(pts[i], -tangent, tangent)
	return curve


func get_waypoints(kind: String, s: float) -> Array[Vector2]:
	var cx := center_x
	var pts: Array[Vector2] = []
	match kind:
		"loop":
			pts = [
				Vector2(cx + s * 300.0, 120.0),
				Vector2(cx + s * 170.0, 160.0),
				Vector2(cx + s * 80.0, 250.0),
				Vector2(cx - s * 20.0, 320.0),
				Vector2(cx - s * 100.0, 280.0),
				Vector2(cx - s * 90.0, 200.0),
				Vector2(cx - s * 20.0, 190.0),
			]
		"spiral":
			pts = [
				Vector2(cx + s * 70.0, -50.0),
				Vector2(cx + s * 150.0, 40.0),
				Vector2(cx + s * 170.0, 150.0),
				Vector2(cx + s * 100.0, 250.0),
				Vector2(cx - s * 20.0, 260.0),
				Vector2(cx - s * 90.0, 190.0),
				Vector2(cx - s * 60.0, 110.0),
			]
		"descend":
			pts = [
				Vector2(cx, -80.0),
				Vector2(cx + 90.0, 40.0),
				Vector2(cx - 90.0, 120.0),
			]
		_:
			pts = [Vector2(cx, -50.0)]
	return pts


# ------------------------------------------------------- PUNTOS, COMBO, FASES

func _on_enemy_destroyed(points_value: int) -> void:
	if is_stage_completed:
		return

	combo += 1
	combo_timer = combo_window
	var multiplier := mini(1 + combo / 3, max_multiplier)
	score += points_value * multiplier
	$HUD.update_score(score)

	if multiplier > 1:
		combo_label.text = "COMBO x%d" % multiplier
		combo_label.modulate.a = 1.0
		combo_label.visible = true

	enemies_destroyed += 1
	update_phase()

	if total_enemies > 0 and enemies_destroyed >= total_enemies and flying == 0:
		complete_stage()


func update_phase() -> void:
	if total_enemies <= 0:
		return
	var ratio := float(enemies_destroyed) / float(total_enemies)

	if phase < 1 and ratio >= 0.33:
		phase = 1
		$AttackTimer.wait_time = 0.7
		$AttackTimer.max_simultaneous_attacks = 4
		show_banner("¡SE ACELERAN!", 1.2)
	elif phase < 2 and ratio >= 0.66:
		phase = 2
		$AttackTimer.wait_time = 0.45
		$AttackTimer.max_simultaneous_attacks = 5
		show_banner("¡FURIA!", 1.2)


func _create_combo_label() -> void:
	combo_label = Label.new()
	combo_label.position = Vector2(340.0, 48.0)
	combo_label.visible = false
	combo_label.add_theme_font_size_override("font_size", 20)
	combo_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	add_child(combo_label)


func show_banner(text: String, seconds: float) -> void:
	banner_id += 1
	var my_id := banner_id
	$StageLabel.text = text
	$StageLabel.visible = true
	await get_tree().create_timer(seconds).timeout
	if is_inside_tree() and my_id == banner_id and not is_stage_completed:
		$StageLabel.visible = false


# ------------------------------------------------------------------ FIN

func complete_stage() -> void:
	if is_stage_completed:
		return

	is_stage_completed = true
	print("STAGE %d COMPLETADO" % stage_number)

	$AttackTimer.stop()
	$StageLabel.text = "STAGE COMPLETE"
	$StageLabel.visible = true

	await get_tree().create_timer(2.0).timeout
	if not is_inside_tree():
		return

	stage_completed.emit()


func _on_player_destroyed() -> void:
	if is_stage_completed:
		return

	is_stage_completed = true
	$AttackTimer.stop()
	$HUD.show_game_over()

	await get_tree().create_timer(2.0).timeout
	if not is_inside_tree():
		return

	game_over.emit()
