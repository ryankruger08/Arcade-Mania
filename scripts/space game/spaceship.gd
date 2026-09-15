extends CharacterBody2D


const SPEED = 300.0
@export var bullet: PackedScene

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		if bullet:
			var bullety = bullet.instantiate()
			bullety.alien = false
			add_child(bullety)
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
