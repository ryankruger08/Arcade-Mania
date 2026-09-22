extends CharacterBody2D

const SPEED = 300.0
@export var bullet: PackedScene
@export var lives: int = 3
signal died()

func _ready() -> void:
	add_to_group("player")

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("shoot"):
		if bullet:
			var bullety = bullet.instantiate()
			bullety.global_position = $".".global_position + Vector2(0, -100)
			bullety.alienbullet = false
			get_tree().current_scene.add_child(bullety)
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

func take_damage() -> void:
	lives -= 1
	if lives <= 0:
		died.emit()
		visible = false
		set_physics_process(false)

func reset(start_lives: int) -> void:
	lives = start_lives
	visible = true
	set_physics_process(true)
