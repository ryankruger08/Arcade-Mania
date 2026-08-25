extends CharacterBody2D
@export var base_speed: float = 400.0
@export var speed_multiplier: float = 1.05
@export var max_speed: float = 1200.0
@export var min_y_component: float = 0.2
@export var paddle_spin_strength: float = 0.6
@export var paddle_half_height: float = 60.0
var current_speed: float
var playing = false
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
		velocity = velocity.bounce(normal)
		if abs(normal.x) > abs(normal.y):
			var collider = collision_info.get_collider()
			if collider:
				var offset = (global_position.y - collider.global_position.y) / paddle_half_height
				offset = clamp(offset, -1.0, 1.0)
				velocity.y += offset * paddle_spin_strength
		if abs(velocity.y) < min_y_component:
			velocity.y = min_y_component if velocity.y >= 0 else -min_y_component
		velocity = velocity.normalized()
		current_speed = min(current_speed * speed_multiplier, max_speed)
		motion = velocity * collision_info.get_remainder().length()
func serve_ball() -> void:
	position = Vector2(815, 540)
	current_speed = base_speed
	var x_dir = 1 if randf() > 0.5 else -1
	var y_dir = randf_range(-0.5, 0.5)
	velocity = Vector2(x_dir, y_dir).normalized()
	playing = true
