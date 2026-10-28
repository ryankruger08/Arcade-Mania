extends Node2D

@export_group("Game Elements")
@export var ball: CharacterBody2D
@export var ball_scene: PackedScene
@export var paddle: CharacterBody2D
@export var brick_grid: Node2D
@export var balls_container: Node2D
@export var powerups_container: Node2D

@export_group("Arcade UI")
@export var score_label: Label
@export var lives_label: Label
@export var gameover_label: Label
@export var highscore_label: Label
@export var combo_label: Label

@export_group("Machine")
@export var machine_manager: Node
@export var starting_lives: int = 3
@export var game_over_delay: float = 3.0
@export var high_score_bonus_multiplier: float = 0.05
@export var max_bonus_credits: int = 3
@export var grid_speed_increase: float = 1.1

@export_group("Power-ups")
@export var widen_duration: float = 8.0
@export var widen_multiplier: float = 1.6
@export var slow_duration: float = 6.0
@export var slow_factor: float = 0.6
@export var multiball_count: int = 2

@export_group("Combo")
@export var combo_multiplier_step: float = 0.15
@export var combo_max_multiplier: float = 3.0

var mode: String = "attract"
var score: int = 0
var lives: int = 0
var high_score: int = 0
var game_over_timer: Timer
var paddle_start_position: Vector2
var active_balls: Array = []
var combo_count: int = 0

const SAVE_PATH = "user://breakout_highscore.cfg"

func _ready() -> void:
	if not machine_manager:
		push_warning("machine_manager export is not assigned")
	if not ball:
		push_warning("ball export is not assigned")
	if not paddle:
		push_warning("paddle export is not assigned")
	if not brick_grid:
		push_warning("brick_grid export is not assigned")
	load_high_score()
	game_over_timer = Timer.new()
	game_over_timer.one_shot = true
	game_over_timer.wait_time = game_over_delay
	game_over_timer.timeout.connect(_on_game_over_timeout)
	add_child(game_over_timer)
	if paddle:
		paddle_start_position = paddle.global_position
		paddle.ball = ball
	if ball:
		ball.lost.connect(_on_primary_ball_lost)
	if brick_grid:
		if powerups_container:
			brick_grid.powerup_container = powerups_container
		brick_grid.brick_destroyed.connect(_on_brick_destroyed)
		brick_grid.cleared.connect(_on_grid_cleared)
		brick_grid.powerup_spawned.connect(_on_powerup_spawned)
	start_attract()

func start_attract() -> void:
	mode = "attract"
	score = 0
	combo_count = 0
	_clear_extra_balls()
	if score_label: score_label.visible = false
	if lives_label: lives_label.visible = false
	if gameover_label: gameover_label.visible = false
	if combo_label: combo_label.visible = false
	if highscore_label:
		highscore_label.text = "HIGH SCORE " + str(high_score)
		highscore_label.visible = true
	if paddle:
		paddle.global_position = paddle_start_position
		paddle.reset_widen()
		paddle.CPU = true
		paddle.playing = true
	if brick_grid:
		brick_grid.build()
	if ball:
		ball.base_speed = 350.0
		active_balls = [ball]
		ball.serve_ball(paddle_start_position + Vector2(0, -60))

func start_match() -> void:
	mode = "playing"
	score = 0
	lives = starting_lives
	combo_count = 0
	_clear_extra_balls()
	if score_label:
		score_label.text = str(score)
		score_label.visible = true
	if lives_label:
		lives_label.text = str(lives)
		lives_label.visible = true
	if highscore_label: highscore_label.visible = false
	if gameover_label: gameover_label.visible = false
	if combo_label: combo_label.visible = false
	game_over_timer.stop()
	if paddle:
		paddle.global_position = paddle_start_position
		paddle.reset_widen()
		paddle.CPU = false
		paddle.playing = true
	if brick_grid:
		brick_grid.build()
	if ball:
		ball.base_speed = 350.0
		active_balls = [ball]
		ball.serve_ball(paddle_start_position + Vector2(0, -60))

func end_match() -> void:
	game_over_timer.stop()
	if machine_manager:
		machine_manager.exit_play_mode()
	start_attract()

func _clear_extra_balls() -> void:
	if balls_container:
		for child in balls_container.get_children():
			child.queue_free()
	active_balls.clear()

func _spawn_extra_ball(from_position: Vector2) -> void:
	if not ball_scene:
		return
	var b = ball_scene.instantiate()
	var container = balls_container if balls_container else self
	container.add_child(b)
	b.base_speed = ball.base_speed
	b.serve_ball(from_position)
	active_balls.append(b)
	b.lost.connect(func(): _on_extra_ball_lost(b))

func _on_extra_ball_lost(b) -> void:
	if b in active_balls:
		active_balls.erase(b)
	b.queue_free()
	_check_all_balls_lost()

func _on_primary_ball_lost() -> void:
	if ball in active_balls:
		active_balls.erase(ball)
	_check_all_balls_lost()

func _check_all_balls_lost() -> void:
	if not active_balls.is_empty():
		return
	if mode == "attract":
		active_balls = [ball]
		ball.serve_ball(paddle.global_position + Vector2(0, -60))
		return
	if mode != "playing":
		return
	_reset_combo()
	lives -= 1
	if lives_label:
		lives_label.text = str(lives)
	if lives <= 0:
		_on_game_over()
		return
	if paddle:
		paddle.reset_widen()
	active_balls = [ball]
	ball.serve_ball(paddle.global_position + Vector2(0, -60))

func _on_brick_destroyed(points) -> void:
	if mode != "playing":
		return
	combo_count += 1
	var multiplier = min(1.0 + combo_count * combo_multiplier_step, combo_max_multiplier)
	var awarded = max(points, int(points * multiplier))
	score += awarded
	if score_label:
		score_label.text = str(score)
	if combo_label:
		if combo_count > 1:
			combo_label.text = "COMBO x" + str(snapped(multiplier, 0.1))
			combo_label.visible = true
		else:
			combo_label.visible = false

func _reset_combo() -> void:
	combo_count = 0
	if combo_label: combo_label.visible = false

func _on_powerup_spawned(powerup) -> void:
	powerup.collected.connect(_on_powerup_collected)

func _on_powerup_collected(type: int) -> void:
	if mode != "playing":
		return
	if type == 0:
		if paddle:
			paddle.apply_widen(widen_duration, widen_multiplier)
	elif type == 1:
		for i in multiball_count:
			_spawn_extra_ball(paddle.global_position + Vector2(0, -60))
	elif type == 2:
		for b in active_balls:
			b.apply_slow(slow_duration, slow_factor)

func _on_grid_cleared() -> void:
	if mode == "game_over":
		return
	if ball:
		ball.base_speed = min(ball.base_speed * grid_speed_increase, ball.max_speed)
	if brick_grid:
		brick_grid.build()
	_clear_extra_balls()
	if ball and paddle:
		active_balls = [ball]
		ball.serve_ball(paddle.global_position + Vector2(0, -60))

func _on_game_over() -> void:
	mode = "game_over"
	if paddle: paddle.playing = false
	_clear_extra_balls()
	_reset_combo()
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
