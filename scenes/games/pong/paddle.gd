extends CharacterBody2D

const SPEED = 300.0

@export var player: int = 1
@export var CPU: bool = false
@export var ball: CharacterBody2D # only needed if CPU == true, used to track the ball's position
@export var cpu_reaction_deadzone: float = 10.0 # pixels of slack so the CPU doesn't jitter when roughly lined up

var playing = false

func _physics_process(delta: float) -> void:
	if player == 1 and playing == true:
		var direction := Input.get_axis("move_forward", "move_back")
		if direction:
			velocity.y = direction * SPEED
		else:
			velocity.y = move_toward(velocity.y, 0, SPEED)

	elif player == 2 and playing == true:
		if CPU == false:
			var direction := Input.get_axis("ui_up", "ui_down")
			if direction:
				velocity.y = direction * SPEED
			else:
				velocity.y = move_toward(velocity.y, 0, SPEED)
		else:
			_cpu_move()

	move_and_slide()

func _cpu_move() -> void:
	if ball == null:
		velocity.y = move_toward(velocity.y, 0, SPEED)
		return

	var offset = ball.position.y - position.y

	if abs(offset) < cpu_reaction_deadzone:
		velocity.y = move_toward(velocity.y, 0, SPEED)
	elif offset > 0:
		velocity.y = SPEED
	else:
		velocity.y = -SPEED
