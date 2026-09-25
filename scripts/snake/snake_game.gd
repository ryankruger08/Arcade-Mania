extends Node2D

@export_group("Game Elements")
@export var snake: Node2D
@export var food: Node2D

@export_group("Arcade UI")
@export var score_label: Label
@export var gameover_label: Label
@export var highscore_label: Label
@export var countdown_label: Label
@export var countdown_rect: ColorRect

@export_group("Machine")
@export var machine_manager: Node
@export var game_over_delay: float = 3.0
@export var high_score_bonus_multiplier: float = 0.2
@export var max_bonus_credits: int = 3

var mode: String = "attract"
var score: int = 0
var high_score: int = 0
var game_over_timer: Timer
var is_counting_down: bool = false

const SAVE_PATH = "user://snake_highscore.cfg"

func _ready() -> void:
	if not machine_manager:
		push_warning("machine_manager export is not assigned, exit_play_mode will never be called")
	if not snake:
		push_warning("snake export is not assigned")
	if not food:
		push_warning("food export is not assigned")
	load_high_score()
	game_over_timer = Timer.new()
	game_over_timer.one_shot = true
	game_over_timer.wait_time = game_over_delay
	game_over_timer.timeout.connect(_on_game_over_timeout)
	add_child(game_over_timer)
	if snake:
		snake.ate_food.connect(_on_ate_food)
		snake.died.connect(_on_snake_died)
	start_attract()

func start_attract() -> void:
	mode = "attract"
	score = 0
	if score_label: score_label.visible = false
	if gameover_label: gameover_label.visible = false
	if countdown_label: countdown_label.visible = false
	if countdown_rect: countdown_rect.visible = false
	if highscore_label:
		highscore_label.text = "HIGH SCORE " + str(high_score)
		highscore_label.visible = true
	if snake:
		snake.stop()
		snake.reset()
		_spawn_food()
		snake.start(true)

func start_match() -> void:
	mode = "playing"
	score = 0
	if snake:
		snake.stop()
		snake.reset()
	_spawn_food()
	if score_label:
		score_label.text = str(score)
		score_label.visible = true
	if highscore_label: highscore_label.visible = false
	if gameover_label: gameover_label.visible = false
	game_over_timer.stop()
	await run_countdown()
	if mode == "playing" and snake:
		snake.start(false)

func run_countdown() -> void:
	is_counting_down = true
	if countdown_label: countdown_label.visible = true
	if countdown_rect: countdown_rect.visible = true
	for step in ["3", "2", "1"]:
		if countdown_label: countdown_label.text = step
		await get_tree().create_timer(0.75).timeout
	if countdown_label: countdown_label.visible = false
	if countdown_rect: countdown_rect.visible = false
	is_counting_down = false

func end_match() -> void:
	game_over_timer.stop()
	if snake: snake.stop()
	if machine_manager:
		machine_manager.exit_play_mode()
	start_attract()

func _spawn_food() -> void:
	if not snake or not food:
		return
	var free_cells = []
	for x in snake.grid_width:
		for y in snake.grid_height:
			var cell = Vector2i(x, y)
			if not snake.segments.has(cell):
				free_cells.append(cell)
	if free_cells.is_empty():
		return
	var pos = free_cells[randi() % free_cells.size()]
	snake.food_position = pos
	food.set_grid_position(pos)

func _on_ate_food() -> void:
	if mode == "playing":
		score += 1
		if score_label:
			score_label.text = str(score)
	_spawn_food()

func _on_snake_died() -> void:
	if is_counting_down:
		return
	if mode == "playing":
		_on_game_over()
	elif mode == "attract":
		start_attract()

func _on_game_over() -> void:
	mode = "game_over"
	if score > high_score:
		var amount_over = score - high_score
		high_score = score
		save_high_score()
		if machine_manager:
			var bonus = min(int(amount_over * high_score_bonus_multiplier), max_bonus_credits)
			if bonus > 0:
				machine_manager.add_wallet_bonus(bonus)
	if highscore_label:
		highscore_label.text = "HIGH SCORE " + str(high_score)
		highscore_label.visible = true
	if gameover_label:
		gameover_label.text = "GAME OVER"
		gameover_label.visible = true
	game_over_timer.start()

func _on_game_over_timeout() -> void:
	if machine_manager:
		machine_manager.exit_play_mode()
	start_attract()

func save_high_score() -> void:
	var config = ConfigFile.new()
	config.set_value("Leaderboard", "top_score", high_score)
	config.save(SAVE_PATH)

func load_high_score() -> void:
	var config = ConfigFile.new()
	var error = config.load(SAVE_PATH)
	if error == OK:
		high_score = config.get_value("Leaderboard", "top_score", 0)
	else:
		high_score = 0
