extends Node2D

@export_group("Game Elements")
@export var frog: Node2D
@export var lanes: Node2D

@export_group("Arcade UI")
@export var score_label: Label
@export var lives_label: Label
@export var gameover_label: Label
@export var highscore_label: Label

@export_group("Machine")
@export var machine_manager: Node
@export var starting_lives: int = 3
@export var game_over_delay: float = 3.0

var mode: String = "attract"
var score: int = 0
var lives: int = 3
var high_score: int = 0
var round_number: int = 1
var best_row: int = 14
var homes: Array = [false, false, false, false, false]
var home_columns: Array = [1, 5, 9, 13, 17]
var respawn_time: float = 0.0
var demo_time: float = 0.0
var game_over_timer: Timer

const SAVE_PATH = "user://frogger_highscore.cfg"

func _ready() -> void:
	load_high_score()
	game_over_timer = Timer.new()
	game_over_timer.one_shot = true
	game_over_timer.wait_time = game_over_delay
	game_over_timer.timeout.connect(_on_game_over_timeout)
	add_child(game_over_timer)
	frog.moved.connect(_on_frog_moved)
	start_attract()

func reset() -> void:
	score = 0
	lives = starting_lives
	round_number = 1
	best_row = frog.start_row
	homes = [false, false, false, false, false]
	respawn_time = 0
	demo_time = 0
	for lane in lanes.get_children():
		lane.reset(1.0)
	frog.reset()
	frog.playing = true
	queue_redraw()

func start_attract() -> void:
	mode = "attract"
	reset()
	frog.demo_mode = true
	if score_label: score_label.visible = false
	if lives_label: lives_label.visible = false
	if gameover_label: gameover_label.visible = false
	if highscore_label:
		highscore_label.text = "HIGH SCORE " + str(high_score)
		highscore_label.visible = true

func start_match() -> void:
	game_over_timer.stop()
	mode = "playing"
	reset()
	frog.demo_mode = false
	if score_label: score_label.visible = true
	if lives_label: lives_label.visible = true
	if gameover_label: gameover_label.visible = false
	if highscore_label: highscore_label.visible = false
	update_scores()

func end_match() -> void:
	game_over_timer.stop()
	if machine_manager:
		machine_manager.exit_play_mode()
	start_attract()

func _physics_process(delta: float) -> void:
	if mode == "game_over":
		return
	for lane in lanes.get_children():
		lane.step(delta)
	if respawn_time > 0:
		respawn_time -= delta
		if respawn_time <= 0:
			respawn_frog()
		return
	if mode == "attract":
		demo_time -= delta
		if demo_time <= 0:
			demo_time = 0.25
			_demo_move()
	check_frog(delta)

func get_lane(row: int) -> Node2D:
	for lane in lanes.get_children():
		if int(lane.position.y / frog.cell_size) == row:
			return lane
	return null

func check_frog(delta: float) -> void:
	var row = int(frog.position.y / frog.cell_size)
	if row == 0:
		reach_home()
		return
	var lane = get_lane(row)
	if lane:
		if lane.water:
			frog.position.x += lane.current_speed * delta
			if frog.position.x < 18 or frog.position.x > 1122 or not lane.contains_frog(frog.position.x):
				lose_life()
		elif lane.contains_frog(frog.position.x):
			lose_life()

func _on_frog_moved() -> void:
	var row = int(frog.position.y / frog.cell_size)
	if row < best_row:
		if mode == "playing":
			score += (best_row - row) * 10
		best_row = row
		update_scores()

func reach_home() -> void:
	var home = -1
	for i in home_columns.size():
		var x = home_columns[i] * frog.cell_size + frog.cell_size / 2
		if abs(frog.position.x - x) <= 26:
			home = i
			break
	if home == -1 or homes[home]:
		lose_life()
		return
	homes[home] = true
	if mode == "playing": score += 100
	if not homes.has(false):
		if mode == "playing": score += 500
		round_number += 1
		homes = [false, false, false, false, false]
		for lane in lanes.get_children():
			lane.reset(min(1.0 + (round_number - 1) * 0.15, 2.5))
	update_scores()
	respawn_frog()
	queue_redraw()

func respawn_frog() -> void:
	frog.reset()
	frog.playing = true
	best_row = frog.start_row
	respawn_time = 0

func lose_life() -> void:
	if respawn_time > 0 or mode == "game_over":
		return
	if mode == "attract":
		respawn_frog()
		return
	lives -= 1
	frog.playing = false
	frog.visible = false
	update_scores()
	if lives <= 0:
		_on_game_over()
	else:
		respawn_time = 0.6

func update_scores() -> void:
	if score_label: score_label.text = str(score)
	if lives_label: lives_label.text = "LIVES " + str(lives)

func _on_game_over() -> void:
	mode = "game_over"
	frog.playing = false
	if score > high_score:
		high_score = score
		save_high_score()
	if gameover_label:
		gameover_label.text = "GAME OVER"
		gameover_label.visible = true
	game_over_timer.start()

func _on_game_over_timeout() -> void:
	if machine_manager:
		machine_manager.exit_play_mode()
	start_attract()

func _demo_move() -> void:
	var target_x = 570.0
	for i in homes.size():
		if not homes[i]:
			target_x = home_columns[i] * frog.cell_size + frog.cell_size / 2
			break
	var best_direction = Vector2i.ZERO
	var best_distance = 999999.0
	for direction in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]:
		var next = frog.position + Vector2(direction) * frog.cell_size
		if next.x < 25 or next.x > 1115 or next.y < 30:
			continue
		var row = int(next.y / frog.cell_size)
		if row == 0 and abs(next.x - target_x) > 26:
			continue
		var lane = get_lane(row)
		if lane:
			var occupied = lane.contains_frog(next.x, 0.25)
			if (lane.water and not occupied) or (not lane.water and occupied):
				continue
		var distance = next.y * 4 + abs(next.x - target_x)
		if distance < best_distance:
			best_distance = distance
			best_direction = direction
	if best_direction != Vector2i.ZERO:
		frog.hop(best_direction)

func save_high_score() -> void:
	var config = ConfigFile.new()
	config.set_value("Leaderboard", "top_score", high_score)
	config.save(SAVE_PATH)

func load_high_score() -> void:
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		high_score = config.get_value("Leaderboard", "top_score", 0)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), Color.BLACK)
	draw_rect(Rect2(390, 120, 1140, 900), Color("205020"))
	draw_rect(Rect2(390, 180, 1140, 300), Color("101080"))
	draw_rect(Rect2(390, 540, 1140, 300), Color("282828"))
	for row in range(8, 12):
		for x in range(410, 1510, 100):
			draw_rect(Rect2(x, 120 + row * 60, 40, 3), Color.WHITE)
	for i in home_columns.size():
		var x = 390 + home_columns[i] * 60
		draw_rect(Rect2(x, 124, 60, 52), Color.LIME_GREEN if homes[i] else Color.BLACK)
