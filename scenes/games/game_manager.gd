extends Node

@export var ball = CharacterBody2D
@export var score_label = Label
@export var player1 = CharacterBody2D
@export var player2 = CharacterBody2D
var playing = false
var score1 = 0
var score2 = 0


func _physics_process(delta: float) -> void:
	if playing == true:
		player1.playing = true
		player2.playing = true
		ball.playing = true
		ball.reset_ball()


#player 2 detector
func _on_area_2d_2_body_entered(body: Node2D) -> void:
	score1 += 1
	ball.reset_ball()
	update_scores()



#Player 1 Detector
func _on_area_2d_body_entered(body: Node2D) -> void:
	score2 += 1
	ball.reset_ball()
	update_scores()
	
func update_scores():
	score_label.text = str(score1, " - ", score2)
	
