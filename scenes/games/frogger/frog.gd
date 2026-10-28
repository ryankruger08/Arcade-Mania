extends Node2D
signal moved()

@export var cell_size: int = 60
@export var grid_width: int = 19
@export var start_row: int = 14
var playing: bool = false
var demo_mode: bool = false

func reset() -> void:
	position = Vector2(grid_width / 2 * cell_size + cell_size / 2, start_row * cell_size + cell_size / 2)
	visible = true
	queue_redraw()

func _process(delta: float) -> void:
	if not playing or demo_mode:
		return
	if Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("move_forward"):
		hop(Vector2i.UP)
	elif Input.is_action_just_pressed("ui_down") or Input.is_action_just_pressed("move_back"):
		hop(Vector2i.DOWN)
	elif Input.is_action_just_pressed("ui_left") or Input.is_action_just_pressed("move_left"):
		hop(Vector2i.LEFT)
	elif Input.is_action_just_pressed("ui_right") or Input.is_action_just_pressed("move_right"):
		hop(Vector2i.RIGHT)

func hop(direction: Vector2i) -> void:
	if not playing:
		return
	var next = position + Vector2(direction) * cell_size
	if next.x < 20 or next.x > grid_width * cell_size - 20:
		return
	if next.y < cell_size / 2 or next.y > start_row * cell_size + cell_size / 2:
		return
	position = next
	moved.emit()

func _draw() -> void:
	draw_rect(Rect2(-18, -18, 36, 36), Color.LIME_GREEN)
	draw_rect(Rect2(-25, -12, 12, 30), Color.GREEN)
	draw_rect(Rect2(13, -12, 12, 30), Color.GREEN)
	draw_rect(Rect2(-14, -18, 8, 8), Color.BLACK)
	draw_rect(Rect2(6, -18, 8, 8), Color.BLACK)
