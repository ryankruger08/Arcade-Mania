extends Node2D
signal brick_destroyed(points)
signal cleared()
signal powerup_spawned(powerup)

@export var brick_scene: PackedScene
@export var powerup_scene: PackedScene
@export var powerup_container: Node2D
@export var columns: int = 10
@export var rows: int = 5
@export var brick_width: float = 100.0
@export var brick_height: float = 32.0
@export var brick_spacing: float = 4.0
@export var edge_margin: float = 370.0
@export var top_offset: float = 180.0
@export var row_point_values: Array[int] = [5, 4, 3, 2, 1]
@export var row_health_values: Array[int] = [3, 2, 2, 1, 1]
@export var powerup_chance: float = 0.12

var alive_count: int = 0

func build() -> void:
	if not brick_scene:
		return
	for child in get_children():
		child.queue_free()
	var screen_width = get_viewport_rect().size.x
	var grid_width = columns * (brick_width + brick_spacing) - brick_spacing
	var start_x = edge_margin + (screen_width - edge_margin * 2 - grid_width) / 2.0
	alive_count = columns * rows
	for r in rows:
		for c in columns:
			var brick = brick_scene.instantiate()
			brick.position = Vector2(start_x + c * (brick_width + brick_spacing), top_offset + r * (brick_height + brick_spacing))
			brick.point_value = row_point_values[r] if r < row_point_values.size() else 1
			brick.max_health = row_health_values[r] if r < row_health_values.size() else 1
			brick.died.connect(_on_brick_died)
			add_child(brick)

func _on_brick_died(points, death_position) -> void:
	alive_count -= 1
	brick_destroyed.emit(points)
	if powerup_scene and randf() < powerup_chance:
		var p = powerup_scene.instantiate()
		p.global_position = death_position
		p.type = randi() % 3
		var container = powerup_container if powerup_container else self
		container.add_child(p)
		powerup_spawned.emit(p)
	if alive_count <= 0:
		cleared.emit()
