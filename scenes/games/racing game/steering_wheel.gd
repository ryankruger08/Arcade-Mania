extends Node3D

@onready var wheel = $"racing machine/AnimationPlayer"
# Called when the node enters the scene tree for the first time.
func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("steer_left"):
		wheel.play("turn_left")
	#if Input.is_action_just_pressed("steer_right"):
		#right
	if Input.is_action_just_released("steer_left"):
		wheel.play("middle")
	if Input.is_action_just_released("steer_right"):
		wheel.play("middle")
