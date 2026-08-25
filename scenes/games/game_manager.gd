extends Node

@export_group("Game Elements")
@export var ball: CharacterBody2D
@export var player1: CharacterBody2D
@export var player2: CharacterBody2D

@export_group("Arcade UI")
@export var score_label: Label         
@export var insert_coin_label: Label   
@export var countdown_label: Label     
@export var countdown_rect: ColorRect   

var playing = false
var score1 = 0
var score2 = 0
var attract = true
var is_counting_down = false
var high_score: int = 0

# Player Selection Variables
var is_selecting_players = false
var chosen_player_count = 1 # Default to 1 Player mode

var ui_flash_timer: Timer
const SAVE_PATH = "user://arcade_highscore.cfg"

func _ready() -> void:
	load_high_score()
	setup_flash_timer()
	await get_tree().process_frame
	setup_attract_mode()

func setup_flash_timer() -> void:
	ui_flash_timer = Timer.new()
	ui_flash_timer.wait_time = 0.5
	ui_flash_timer.timeout.connect(_on_flash_timer_timeout)
	add_child(ui_flash_timer)

func setup_attract_mode() -> void:
	attract = true
	playing = false
	is_counting_down = false
	is_selecting_players = false
	
	if score_label: score_label.visible = false
	if countdown_label: countdown_label.visible = false
	if countdown_rect: countdown_rect.visible = false
	if insert_coin_label: insert_coin_label.visible = true
	
	ui_flash_timer.start()
	
	if player1:
		player1.CPU = true
		player1.playing = true
	if player2:
		player2.CPU = true
		player2.playing = true
		
	if ball:
		ball.serve_ball()

# Called by the Machine Manager when the player presses 'F'
func start_match() -> void:
	# Stop attract mode and open the selection menu
	attract = false
	playing = false
	ui_flash_timer.stop()
	
	if insert_coin_label: insert_coin_label.visible = false
	if score_label: score_label.visible = false
	
	# Open player selection using the countdown UI assets
	is_selecting_players = true
	chosen_player_count = 1 # Reset default selection to 1 Player
	if countdown_rect: countdown_rect.visible = true
	if countdown_label: countdown_label.visible = true
	_update_selection_ui()

func _unhandled_input(event: InputEvent) -> void:
	# Only listen to menu controls if we are on the player select screen
	if not is_selecting_players:
		return
		
	# Toggle option using built-in UI actions (or map custom up/down keys)
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		if chosen_player_count == 1:
			chosen_player_count = 2
		else:
			chosen_player_count = 1
		_update_selection_ui()
		
	# Confirm selection and start the countdown when they press 'play' (F key)
	if event.is_action_pressed("play"):
		get_viewport().set_input_as_handled() # Prevent this input from triggering other scripts
		_confirm_player_selection()

func _update_selection_ui() -> void:
	if not countdown_label: return
	
	# Visual formatting showing an arrow pointing at the active selection
	if chosen_player_count == 1:
		countdown_label.text = "SELECT MODE\n\n> 1 PLAYER <\n  2 PLAYERS"
	else:
		countdown_label.text = "SELECT MODE\n\n  1 PLAYER\n> 2 PLAYERS <"

func _confirm_player_selection() -> void:
	is_selecting_players = false
	score1 = 0
	score2 = 0
	
	if score_label: score_label.visible = true
	update_scores()
	
	# Run the standard 3-2-1 kickoff countdown
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

	# Configure the paddles based on the choice locked into the menu
	if not attract:
		if player1:
			player1.CPU = false 
			player1.playing = true
			
		if player2:
			if chosen_player_count == 1:
				player2.CPU = true  # 1-Player Mode: AI takes over right paddle
			else:
				player2.CPU = false # 2-Player Mode: Human controls right paddle
			player2.playing = true

func _flash_countdown_step(number_text: String) -> void:
	if not countdown_label: return
	
	countdown_label.text = "HIGH SCORE\n" + str(high_score)
	await get_tree().create_timer(0.5).timeout
	
	countdown_label.text = number_text
	await get_tree().create_timer(0.5).timeout

func end_match() -> void:
	check_for_new_highscore(score1)
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
		# For 2-Player mode, check if player 2 also set a new high score record!
		if chosen_player_count == 2:
			check_for_new_highscore(score2)
			
		await run_game_countdown()
		if ball and playing: ball.serve_ball()
	elif attract:
		if ball: ball.serve_ball()
	
func update_scores() -> void:
	if score_label and not attract:
		score_label.text = str(score1, " - ", score2)

func _on_flash_timer_timeout() -> void:
	if attract and insert_coin_label:
		insert_coin_label.visible = !insert_coin_label.visible

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
