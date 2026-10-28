extends CharacterBody2D
signal lost()

@export var base_speed: float = 350.0
@export var speed_multiplier: float = 1.02
@export var max_speed: float = 900.0
@export var min_x_component: float = 0.25
@export var min_y_component: float = 0.3
@export var paddle_spin_strength: float = 0.7
@export var paddle_half_width: float = 90.0
@export var out_of_bounds_y: float = 1150.0

var current_speed: float
var playing: bool = false

func _physics_process(delta: float) -> void:
	if not playing:
		velocity = Vector2.ZERO
		return
	var motion = velocity * current_speed * delta
	var max_bounces = 4
	for i in max_bounces:
		if motion.length() <= 0.0:
			break
		var collision_info = move_and_collide(motion)
		if not collision_info:
			break
		var normal = collision_info.get_normal()
		var collider = collision_info.get_collider()
		velocity = velocity.bounce(normal)
		if collider and collider.is_in_group("paddle"):
			var offset = (global_position.x - collider.global_position.x) / paddle_half_width
			offset = clamp(offset, -1.0, 1.0)
			velocity.x += offset * paddle_spin_strength
			if abs(velocity.x) < min_x_component:
				velocity.x = min_x_component if velocity.x >= 0 else -min_x_component
			velocity = velocity.normalized()
		elif collider and collider.is_in_group("brick"):
			if collider.has_method("take_damage"):
				collider.take_damage()
			if abs(velocity.y) < min_y_component:
				velocity.y = min_y_component if velocity.y >= 0 else -min_y_component
			velocity = velocity.normalized()
			current_speed = min(current_speed * speed_multiplier, max_speed)
		else:
			if abs(velocity.y) < min_y_component:
				velocity.y = min_y_component if velocity.y >= 0 else -min_y_component
			velocity = velocity.normalized()
		motion = velocity * collision_info.get_remainder().length()
	if global_position.y > out_of_bounds_y:
		playing = false
		lost.emit()

func serve_ball(from_position: Vector2) -> void:
	global_position = from_position
	current_speed = base_speed
	var x_dir = 1 if randf() > 0.5 else -1
	velocity = Vector2(x_dir * 0.5, -1).normalized()
	playing = true

func stop() -> void:
	playing = false
	velocity = Vector2.ZERO

func apply_slow(duration: float, factor: float) -> void:
	var original = current_speed
	current_speed *= factor
	await get_tree().create_timer(duration).timeout
	if playing:
		current_speed = original
