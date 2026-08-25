extends CharacterBody2D

@export var base_speed: float = 400.0
@export var speed_multiplier: float = 1.05

var current_speed: float
var playing = false

func _physics_process(delta: float) -> void:
	# Keep the ball frozen if the Game Manager hasn't set playing to true
	if not playing:
		velocity = Vector2.ZERO
		return
		
	var collision_info = move_and_collide(velocity * current_speed * delta)
	
	if collision_info:
		velocity = velocity.bounce(collision_info.get_normal())
		velocity = velocity.normalized()
		current_speed *= speed_multiplier

func serve_ball() -> void:
	position = Vector2(815, 540)
	current_speed = base_speed
	
	var x_dir = 1 if randf() > 0.5 else -1
	var y_dir = randf_range(-0.5, 0.5)
	velocity = Vector2(x_dir, y_dir).normalized()
	playing = true
