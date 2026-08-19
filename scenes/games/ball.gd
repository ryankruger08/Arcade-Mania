extends CharacterBody2D

# Configure your starting parameters
@export var base_speed: float = 400.0
@export var speed_multiplier: float = 1.05 # Increases speed by 5% on each hit

var current_speed: float

func _ready() -> void:
	reset_ball()

func _physics_process(delta: float) -> void:
	# Move the ball and check for any impact data
	var collision_info = move_and_collide(velocity * current_speed * delta)
	
	if collision_info:
		# Use the collider's surface normal to bounce backward instantly
		velocity = velocity.bounce(collision_info.get_normal())
		
		# Prevent the ball from losing horizontal momentum if it scrapes a surface angle
		velocity = velocity.normalized()
		
		# Make the ball faster on every single impact
		current_speed *= speed_multiplier


# Call this function when someone scores to put the ball back in the middle
func reset_ball() -> void:
	# Position the ball in the dead center of your 1630x1080 resolution
	position = Vector2(815, 540)
	current_speed = base_speed
	
	# Choose a random starting direction (Left or Right)
	var x_dir = 1 if randf() > 0.5 else -1
	# Give it a slight up/down angle so it doesn't just travel in a flat horizontal line
	var y_dir = randf_range(-0.5, 0.5)
	
	# Combine into a directional unit vector
	velocity = Vector2(x_dir, y_dir).normalized()
