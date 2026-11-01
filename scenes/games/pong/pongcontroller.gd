extends CharacterBody2D

const SPEED = 400.0 
@export var player = 1
@export var CPU = false
var playing = false

@export var ai_deadzone = 15.0
@export var ball: CharacterBody2D

var starting_x: float = 0.0

func _ready() -> void:
	starting_x = global_position.x

func _physics_process(delta: float) -> void:
	velocity.y = 0

	if playing:
		if player == 1 and not CPU:
			var direction := Input.get_axis("game_up", "game_down")
			if direction:
				velocity.y = direction * SPEED
		elif player == 1 and CPU:
			_handle_cpu_ai()
			
		elif player == 2 and not CPU:
			var direction := Input.get_axis("game_up", "game_down")
			if direction:
				velocity.y = direction * SPEED
		elif player == 2 and CPU:
			_handle_cpu_ai()

	move_and_slide()
	global_position.x = starting_x

func _handle_cpu_ai() -> void:
	if not ball:
		ball = get_parent().get_node_or_null("Ball")
		return
		
	var distance_to_ball = ball.global_position.y - global_position.y
	
	if abs(distance_to_ball) > ai_deadzone:
		if distance_to_ball > 0:
			velocity.y = SPEED
		else:
			velocity.y = -SPEED
