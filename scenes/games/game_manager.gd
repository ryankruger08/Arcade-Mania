extends Node

@export var ball = CharacterBody2D
@export var score_label = Label
var score = [0, 0]


func _physics_process(delta: float) -> void:
	pass


#player 2 detector
func _on_area_2d_2_body_entered(body: Node2D) -> void:
	pass



#Player 1 Detector
func _on_area_2d_body_entered(body: Node2D) -> void:
	pass # Replace with function body.
