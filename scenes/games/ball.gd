extends CharacterBody2D

@export var base_speed: float = 400.0
@export var speed_multiplier: float = 1.05
@export var label = Label
@export var rect = ColorRect
var current_speed: float
var playing = false

func _physics_process(delta: float) -> void:
	var collision_info = move_and_collide(velocity * current_speed * delta)
	
	if collision_info:
		velocity = velocity.bounce(collision_info.get_normal())
		
		velocity = velocity.normalized()
		
		current_speed *= speed_multiplier


func reset_ball() -> void:
	label.visible = true
	rect.visible = true
	label.text = str("3")
	await get_tree().create_timer(1.0).timeout
	label.text = str("2")
	await get_tree().create_timer(1.0).timeout
	label.text = str("1")
	await get_tree().create_timer(1.0).timeout
	rect.visible = false
	label.visible = false
	position = Vector2(815, 540)
	current_speed = base_speed
	var x_dir = 1 if randf() > 0.5 else -1
	var y_dir = randf_range(-0.5, 0.5)
	
	velocity = Vector2(x_dir, y_dir).normalized()
