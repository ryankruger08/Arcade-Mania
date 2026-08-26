extends Node

@export_group("Game Elements")
@export var ball: CharacterBody2D
@export var player1: CharacterBody2D
@export var player2: CharacterBody2D

@export_group("Arcade UI")
@export var score_label: Label
@export var countdown_label: Label
@export var countdown_rect: ColorRect

var playing = false
var score1 = 0
var score2 = 0
var attract = true
var is_counting_down = false
var high_score: int = 0

const SAVE_PATH = "user://arcade_highscore.cfg"

func _ready() -> void:
	load_high_score()
	await get_tree().process_frame
	setup_attract_mode()

func setup_attract_mode() -> void:
	attract = true
	playing = false
	is_counting_down = false
	
	if score_label: score_label.visible = false
	if countdown_label: countdown_label.visible = false
	if countdown_rect: countdown_rect.visible = false
	
	if player1:
		player1.CPU = true
		player1.playing = true
	if player2:
		player2.CPU = true
		player2.playing = true
		
	if ball:
		ball.serve_ball()

func start_match() -> void:
	attract = false
	playing = false
	
	if ball: ball.playing = false
	
	score1 = 0
	score2 = 0
	if score_label:
		score_label.visible = true
	update_scores()
	
	if player1: player1.CPU = false
	if player2: player2.CPU = true
	
	await run_game_countdown()
	playing = true
	
	if ball:
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

	if not attract:
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
	check_for_new_highscore(score1)
	check_for_new_highscore(score2)
	setup_attract_mode()

func _on_area_2d_2_body_entered(body: Node2D) -> void:
	if not attract and playing and not is_counting_down:
		score1 += 1
		update_scores()
		check_for_new_highscore(score1)
		await run_game_countdown()
		if ball and playing: ball.serve_ball()
	elif attract:
		if ball: ball.serve_ball()

func _on_area_2d_body_entered(body: Node2D) -> void:
	if not attract and playing and not is_counting_down:
		score2 += 1
		update_scores()
		check_for_new_highscore(score2)
		await run_game_countdown()
		if ball and playing: ball.serve_ball()
	elif attract:
		if ball: ball.serve_ball()
	
func update_scores() -> void:
	if score_label and not attract:
		score_label.text = str(score1, " - ", score2)

func check_for_new_highscore(final_score: int) -> void:
	if final_score > high_score:
		high_score = final_score
		save_high_score()
		Wallet.add_coins(1)

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
