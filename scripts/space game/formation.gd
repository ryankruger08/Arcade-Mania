extends Node2D
signal alien_killed(points)
signal cleared()

@export var alien_row_scene: PackedScene
@export var alien_scene: PackedScene
@export var bullet_scene: PackedScene
@export var bullet_container: Node2D
@export var columns: int = 6
@export var column_spacing: float = 64.0
@export var row_spacing: float = 56.0
@export var base_speed: float = 120.0
@export var speed_per_kill: float = 4.0
@export var step_down_amount: float = 20.0
@export var edge_margin: float = 32.0
@export var shoot_interval: float = 1.5
@export var row_point_values: Array[int] = [3, 2, 2, 1, 1, 1]

var direction: int = 1
var rows_alive: int = 0
var total_aliens: int = 0
var alive_aliens: int = 0

func build(row_count: int) -> void:
	if not alien_row_scene or not alien_scene:
		return
	for child in get_children():
		child.queue_free()
	rows_alive = row_count
	total_aliens = row_count * columns
	alive_aliens = total_aliens
	var formation_width = columns * column_spacing
	var screen_width = get_viewport_rect().size.x
	position.x = (screen_width - formation_width) / 2.0
	position.y = 0
	for r in row_count:
		var row = alien_row_scene.instantiate()
		row.position = Vector2(0, r * row_spacing)
		row.alien_killed.connect(_on_alien_killed)
		row.cleared.connect(_on_row_cleared)
		add_child(row)
		var points = row_point_values[r] if r < row_point_values.size() else 1
		row.build(columns, alien_scene, column_spacing, points)
	var timer = Timer.new()
	timer.wait_time = shoot_interval
	timer.one_shot = false
	timer.autostart = true
	timer.timeout.connect(_on_shoot_timer)
	add_child(timer)

func _physics_process(delta: float) -> void:
	if alive_aliens == 0:
		return
	var speed = base_speed + (total_aliens - alive_aliens) * speed_per_kill
	position.x += direction * speed * delta
	var formation_width = columns * column_spacing
	var screen_width = get_viewport_rect().size.x
	if direction == 1 and position.x + formation_width >= screen_width - edge_margin:
		direction = -1
		position.y += step_down_amount
	elif direction == -1 and position.x <= edge_margin:
		direction = 1
		position.y += step_down_amount

func _on_alien_killed(points) -> void:
	alive_aliens -= 1
	alien_killed.emit(points)

func _on_row_cleared() -> void:
	rows_alive -= 1
	if rows_alive == 0:
		cleared.emit()
		queue_free()

func _on_shoot_timer() -> void:
	if alive_aliens == 0 or not bullet_scene:
		return
	var shooters = []
	for row in get_children():
		if row is Timer:
			continue
		var aliens_node = row.get_node("aliens")
		for alien in aliens_node.get_children():
			shooters.append(alien)
	if shooters.is_empty():
		return
	var shooter = shooters[randi() % shooters.size()]
	var bullety = bullet_scene.instantiate()
	bullety.global_position = shooter.global_position + Vector2(0, 20)
	bullety.alienbullet = true
	if bullet_container:
		bullet_container.add_child(bullety)
	else:
		get_tree().current_scene.add_child(bullety)
