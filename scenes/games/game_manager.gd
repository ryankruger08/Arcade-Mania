extends Node

@export_group("Game Elements")
@export var ball: CharacterBody2D
@export var player1: CharacterBody2D
@export var player2: CharacterBody2D

@export_group("Arcade UI")
@export var score_label: Label
@export var countdown_label: Label
@export var countdown_rect: ColorRect
@export var gameover_label: Label

@export_group("Machine")
@export var machine_manager: Node
@export var win_score: int = 5
@export var game_over_delay: float = 3.0

var mode: String = "attract"
var score1 = 0
var score2 = 0
var is_counting_down = false
var high_score: int = 0
var game_over_timer: Timer

const SAVE_PATH = "user://arcade_highscore.cfg"

func _ready() -> void:
	if not machine_manager:
		push_warning("machine_manager export is not assigned, exit_play_mode will never be called")
	load_high_score()
	game_over_timer = Timer.new()
	game_over_timer.one_shot = true
	game_over_timer.wait_time = game_over_delay
	game_over_timer.timeout.connect(_on_game_over_timeout)
	add_child(game_over_timer)
	print("game_over_timer wait_time set to: ", game_over_timer.wait_time)
	await get_tree().process_frame
	start_attract()

func start_attract() -> void:
	print("start_attract called")
	mode = "attract"
	is_counting_down = false
	score1 = 0
	score2 = 0
	
	if score_label: score_label.visible = false
	if countdown_label: countdown_label.visible = false
	if countdown_rect: countdown_rect.visible = false
	if gameover_label: gameover_label.visible = false
	
	if player1:
		player1.CPU = true
		player1.playing = true
	if player2:
		player2.CPU = true
		player2.playing = true
		
	if ball:
		ball.serve_ball()

func start_match() -> void:
	print("start_match called")
	mode = "playing"
	
	if ball: ball.playing = false
	
	score1 = 0
	score2 = 0
	if score_label:
		score_label.visible = true
	if gameover_label: gameover_label.visible = false
	update_scores()
	
	if player1: player1.CPU = false
	if player2: player2.CPU = true
	
	await run_game_countdown()
	
	if mode == "playing" and ball:
		ball.serve_ball()

func run_game_countdown() -> void:
	is_counting_down = true
	
	if player1: player1.playing = false
	if player2: player2.playing = false
	if ball:
		ball.playing = false
		ball.position = Vector2(815, 540)
		
	if countdown_label: countdown_label.visible = true
	if countdown_rect: countdown_rect.visible = true
	
	await _flash_countdown_step("3")
	await _flash_countdown_step("2")
	await _flash_countdown_step("1")
	
	if countdown_label: countdown_label.visible = false
	if countdown_rect: countdown_rect.visible = false
	is_counting_down = false

	if mode == "playing":
		if player1:
			player1.playing = true
		if player2:
			player2.playing = true

func _flash_countdown_step(number_text: String) -> void:
	if not countdown_label: return
	
	countdown_label.text = "HIGH SCORE\n" + str(high_score)
	await get_tree().create_timer(0.5).timeout
	
	countdown_label.text = number_text
	await get_tree().create_timer(0.5).timeout

func end_match() -> void:
	print("end_match called")
	game_over_timer.stop()
	if machine_manager:
		machine_manager.exit_play_mode()
	start_attract()

func _on_area_2d_2_body_entered(body: Node2D) -> void:
	if mode == "playing" and not is_counting_down:
		score1 += 1
		update_scores()
		if score1 >= win_score:
			_on_match_won(1, score1)
			return
		await run_game_countdown()
		if mode == "playing": ball.serve_ball()
	elif mode == "attract":
		if ball: ball.serve_ball()

func _on_area_2d_body_entered(body: Node2D) -> void:
	if mode == "playing" and not is_counting_down:
		score2 += 1
		update_scores()
		if score2 >= win_score:
			_on_match_won(2, score2)
			return
		await run_game_countdown()
		if mode == "playing": ball.serve_ball()
	elif mode == "attract":
		if ball: ball.serve_ball()
	
func update_scores() -> void:
	if score_label and mode == "playing":
		score_label.text = str(score1, " - ", score2)

func _on_match_won(winner: int, winning_score: int) -> void:
	print("match won by player ", winner, " score: ", winning_score, " mode was: ", mode)
	mode = "game_over"
	if ball: ball.playing = false
	if player1: player1.playing = false
	if player2: player2.playing = false
	check_for_new_highscore(winning_score)
	if gameover_label:
		if winner == 1:
			gameover_label.text = "YOU WIN!"
		else:
			gameover_label.text = "YOU LOSE"
		gameover_label.visible = true
		print("gameover_label set visible, text: ", gameover_label.text)
	else:
		print("gameover_label is null, cannot show text")
	Wallet.add_coins(1)
	game_over_timer.start()
	print("game_over_timer started, wait_time: ", game_over_timer.wait_time)

func _on_game_over_timeout() -> void:
	print("game_over_timeout fired, calling exit_play_mode and start_attract")
	if machine_manager:
		machine_manager.exit_play_mode()
	else:
		print("machine_manager is null, exit_play_mode was skipped")
	start_attract()

func check_for_new_highscore(final_score: int) -> void:
	if final_score > high_score:
		high_score = final_score
		save_high_score()

func save_high_score() -> void:
	var config = ConfigFile.new()
	config.set_value("Leaderboard", "top_score", high_score)
	config.save(SAVE_PATH)

func load_high_score() -> void:
	var config = ConfigFile.new()
	var error = config.load(SAVE_PATH)
	
	if error == OK:
		high_score = config.get_value("Leaderboard", "top_score", 5)
	else:
		high_score = 5
