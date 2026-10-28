extends CharacterBody2D

const SPEED = 400.0 
@export var player = 1
@export var CPU = false
var playing = false

@export var ai_deadzone = 15.0 # Increased deadzone for smoother arcade tracking
@export var ball: CharacterBody2D

var starting_x: float = 0.0

func _ready() -> void:
	# Save the exact X position where you placed the paddle in the editor
	starting_x = global_position.x

func _physics_process(delta: float) -> void:
	velocity.y = 0

	if playing:
		if player == 1 and not CPU:
			var direction := Input.get_axis("move_forward", "move_back")
			if direction:
				velocity.y = direction * SPEED
		elif player == 1 and CPU:
			_handle_cpu_ai()
			
		elif player == 2 and not CPU:
			var direction := Input.get_axis("ui_up", "ui_down")
			if direction:
				velocity.y = direction * SPEED
		elif player == 2 and CPU:
			_handle_cpu_ai()

	move_and_slide()
	
	# HARD LOCK: Force the paddle to stay perfectly on its horizontal track
	global_position.x = starting_x

func _handle_cpu_ai() -> void:
	if not ball:
		# Auto-grab the ball if it wasn't linked in the inspector
		ball = get_parent().get_node_or_null("Ball")
		return
		
	var distance_to_ball = ball.global_position.y - global_position.y
	
	if abs(distance_to_ball) > ai_deadzone:
		if distance_to_ball > 0:
			velocity.y = SPEED
		else:
			velocity.y = -SPEED
