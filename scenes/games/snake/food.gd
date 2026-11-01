extends Node2D

@export var cell_size: int = 60
var grid_position: Vector2i = Vector2i.ZERO

func set_grid_position(pos: Vector2i) -> void:
	grid_position = pos
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(grid_position.x * cell_size, grid_position.y * cell_size, cell_size, cell_size), Color.RED)
