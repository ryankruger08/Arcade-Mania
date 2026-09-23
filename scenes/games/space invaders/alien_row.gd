extends Node2D
signal alien_killed(points)
signal cleared()

var alive_count: int = 0

func build(columns: int, alien_scene: PackedScene, spacing: float, point_value: int) -> void:
	for child in $aliens.get_children():
		child.queue_free()
	alive_count = columns
	for i in columns:
		var alien = alien_scene.instantiate()
		alien.position = Vector2(i * spacing, 0)
		alien.point_value = point_value
		alien.died.connect(_on_alien_killed)
		$aliens.add_child(alien)

func _on_alien_killed(points) -> void:
	alive_count -= 1
	alien_killed.emit(points)
	if alive_count == 0:
		cleared.emit()
