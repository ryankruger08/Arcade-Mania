extends CharacterBody2D


const SPEED = 300.0
@export var player = 1
@export var CPU = false

func _physics_process(delta: float) -> void:
	if player == 1:
		var direction := Input.get_axis("move_forward", "move_back")
		if direction:
			velocity.y = direction * SPEED
		else:
			velocity.y = move_toward(velocity.x, 0, SPEED)

#NOT IN USE IF CPU MODE IS ACTIVE
	elif player == 2 and CPU == false:
		var direction := Input.get_axis("ui_up", "ui_down")
		if direction:
			velocity.y = direction * SPEED
		else:
			velocity.y = move_toward(velocity.x, 0, SPEED)
	move_and_slide()
