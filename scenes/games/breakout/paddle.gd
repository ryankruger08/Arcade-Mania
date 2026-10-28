extends CharacterBody2D

@export var speed: float = 500.0
@export var CPU: bool = false
@export var ball: CharacterBody2D
@export var ai_deadzone: float = 20.0

var playing: bool = false
var fixed_y: float = 0.0
var widen_tween: Tween

func _ready() -> void:
	add_to_group("paddle")
	fixed_y = global_position.y

func _physics_process(delta: float) -> void:
	velocity.x = 0
	if playing:
		if CPU:
			_handle_cpu_ai()
		else:
			var direction := Input.get_axis("ui_left", "ui_right")
			if direction:
				velocity.x = direction * speed
	move_and_slide()
	global_position.y = fixed_y

func _handle_cpu_ai() -> void:
	if not ball:
		return
	var distance = ball.global_position.x - global_position.x
	if abs(distance) > ai_deadzone:
		velocity.x = speed if distance > 0 else -speed

func apply_widen(duration: float, multiplier: float) -> void:
	if widen_tween:
		widen_tween.kill()
	scale.x = multiplier
	widen_tween = create_tween()
	widen_tween.tween_interval(duration)
	widen_tween.tween_callback(func(): scale.x = 1.0)

func reset_widen() -> void:
	if widen_tween:
		widen_tween.kill()
	scale.x = 1.0
