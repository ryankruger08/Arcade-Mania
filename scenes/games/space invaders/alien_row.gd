extends Node2D
signal alien_killed()
signal cleared()

var alive_count: int = 0
#spacing is 90
func build(columns: int, alien_scene: PackedScene, spacing: float) -> void:
	for child in $aliens.get_children():
		child.queue_free()
	alive_count = columns
	for i in columns:
		var alien = alien_scene.instantiate()
		alien.position = Vector2(i * spacing, 0)
		alien.died.connect(_on_alien_killed)
		$aliens.add_child(alien)

func _on_alien_killed() -> void:
	alive_count -= 1
	alien_killed.emit()
	if alive_count == 0:
		cleared.emit()
