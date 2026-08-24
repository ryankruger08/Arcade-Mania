extends Node

# Pong-specific game manager - lives inside the SubViewport that gets
# displayed on the cabinet's screen. Owns the menu AND the gameplay,
# since both are rendered on that same screen.

signal exited

@export var ball: CharacterBody2D
@export var score_label: Label
@export var player1: CharacterBody2D
@export var player2: CharacterBody2D
@export var menu_label: Label # a Label inside the SAME viewport as the game screen

enum State { MENU, PLAYING }

var state: State = State.MENU
var menu_selection: int = 0 # 0 = 1 Player, 1 = 2 Player
var menu_options := ["1 PLAYER", "2 PLAYER"]

var playing = false
var score1 = 0
var score2 = 0

func enter_machine() -> void:
	state = State.MENU
	menu_selection = 0
	score_label.visible = false
	menu_label.visible = true
	_update_menu_label()

func _unhandled_input(event: InputEvent) -> void:
	match state:
		State.MENU:
			if Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("ui_down"):
				menu_selection = 1 - menu_selection
				_update_menu_label()
			elif Input.is_action_just_pressed("play") or Input.is_action_just_pressed("ui_accept"):
				_start_game()
			elif Input.is_action_just_pressed("ui_cancel"):
				exited.emit()
		State.PLAYING:
			if Input.is_action_just_pressed("ui_cancel"):
				_end_game()

func _update_menu_label() -> void:
	menu_label.text = ""
	for i in menu_options.size():
		if i == menu_selection:
			menu_label.text += "> " + menu_options[i] + "\n"
		else:
			menu_label.text += "  " + menu_options[i] + "\n"

func _start_game() -> void:
	state = State.PLAYING
	menu_label.visible = false
	score_label.visible = true
	playing = true
	player2.CPU = (menu_selection == 0)
	player1.playing = true
	player2.playing = true
	ball.playing = true
	score1 = 0
	score2 = 0
	update_scores()
	ball.reset_ball()

func _end_game() -> void:
	playing = false
	player1.playing = false
	player2.playing = false
	ball.playing = false
	exited.emit()

#player 2 detector
func _on_area_2d_2_body_entered(body: Node2D) -> void:
	if body != ball or not playing:
		return
	score1 += 1
	ball.reset_ball()
	update_scores()

#Player 1 Detector
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body != ball or not playing:
		return
	score2 += 1
	ball.reset_ball()
	update_scores()

func update_scores() -> void:
	score_label.text = str(score1, " - ", score2)
