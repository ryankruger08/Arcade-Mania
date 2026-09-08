extends RigidBody3D

@export var max_speed: float = 20.0
@export var acceleration: float = 15.0
@export var turn_speed: float = 3.0

func _physics_process(delta: float) -> void:
	# 1. Get Inputs
	var forward_input := Input.get_axis("ui_down", "ui_up")
	var turn_input := Input.get_axis("ui_right", "ui_left")
	
	# 2. Handle Turning (Only turn if moving forward or backward)
	if abs(linear_velocity.dot(-global_transform.basis.z)) > 0.5:
		rotate_y(turn_input * turn_speed * delta)
	
	# 3. Calculate Forward Velocity
	var forward_dir := -global_transform.basis.z
	var target_velocity := forward_dir * forward_input * max_speed
	
	# 4. Smoothly blend the current velocity toward the target velocity
	# This ensures your kart moves in the direction it is actually facing
	var current_forward_vel := forward_dir * linear_velocity.dot(forward_dir)
	var new_velocity := current_forward_vel.move_toward(target_velocity, acceleration * delta)
	
	# Retain gravity (Y-axis velocity) while updating X and Z movement
	linear_velocity.x = new_velocity.x
	linear_velocity.z = new_velocity.z
