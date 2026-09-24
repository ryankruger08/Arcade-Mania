extends Node2D
signal ate_food()
signal died()

@export var cell_size: int = 32
@export var grid_width: int = 20
@export var grid_height: int = 15
@export var move_interval: float = 0.15
@export var start_length: int = 3

var segments: Array = []
var direction: Vector2i = Vector2i.RIGHT
var next_direction: Vector2i = Vector2i.RIGHT
var playing: bool = false
var demo_mode: bool = false
var food_position: Vector2i = Vector2i.ZERO
var move_timer: Timer
var pending_growth: int = 0

func _ready() -> void:
	move_timer = Timer.new()
	move_timer.wait_time = move_interval
	move_timer.one_shot = false
	move_timer.timeout.connect(_on_move_tick)
	add_child(move_timer)

func reset() -> void:
	segments.clear()
	var start_x = grid_width / 2
	var start_y = grid_height / 2
	for i in start_length:
		segments.append(Vector2i(start_x - i, start_y))
	direction = Vector2i.RIGHT
	next_direction = Vector2i.RIGHT
	pending_growth = 0
	queue_redraw()

func start(is_demo: bool) -> void:
	demo_mode = is_demo
	playing = true
	move_timer.wait_time = move_interval
	move_timer.start()

func stop() -> void:
	playing = false
	move_timer.stop()

func set_direction(dir: Vector2i) -> void:
	if dir == -direction:
		return
	next_direction = dir

func _unhandled_input(event: InputEvent) -> void:
	if not playing or demo_mode:
		return
	if event.is_action_pressed("ui_up"):
		set_direction(Vector2i.UP)
	elif event.is_action_pressed("ui_down"):
		set_direction(Vector2i.DOWN)
	elif event.is_action_pressed("ui_left"):
		set_direction(Vector2i.LEFT)
	elif event.is_action_pressed("ui_right"):
		set_direction(Vector2i.RIGHT)

func _on_move_tick() -> void:
	if not playing:
		return
	if demo_mode:
		_demo_choose_direction()
	direction = next_direction
	var new_head = segments[0] + direction
	if new_head.x < 0 or new_head.x >= grid_width or new_head.y < 0 or new_head.y >= grid_height:
		_die()
		return
	if segments.has(new_head):
		_die()
		return
	segments.insert(0, new_head)
	if new_head == food_position:
		pending_growth += 1
		ate_food.emit()
	if pending_growth > 0:
		pending_growth -= 1
	else:
		segments.pop_back()
	queue_redraw()

func _die() -> void:
	playing = false
	move_timer.stop()
	died.emit()

func _demo_choose_direction() -> void:
	var head = segments[0]
	var options = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	var best_dir = direction
	var best_dist = 999999
	for dir in options:
		if dir == -direction:
			continue
		var next = head + dir
		if next.x < 0 or next.x >= grid_width or next.y < 0 or next.y >= grid_height:
			continue
		if segments.has(next):
			continue
		var dist = abs(next.x - food_position.x) + abs(next.y - food_position.y)
		if dist < best_dist:
			best_dist = dist
			best_dir = dir
	next_direction = best_dir

func _draw() -> void:
	for i in segments.size():
		var seg = segments[i]
		var color = Color.LIME_GREEN if i == 0 else Color.GREEN
		draw_rect(Rect2(seg.x * cell_size, seg.y * cell_size, cell_size, cell_size), color)
