extends Node2D

@export var alien_scene: PackedScene 
@export var rows: int = 5
@export var columns: int = 11
@export var spacing: float = 40.0    

@export var base_speed: float = 100.0 
var current_speed: float = 100.0
var move_direction: float = 1.0       
var drop_distance: float = 20.0       

@export var left_bound: float = 50.0
@export var right_bound: float = 1100.0

var total_aliens: int = 0

@onready var shoot_timer: Timer = $ShootTimer

func _ready() -> void:
	spawn_grid()
	current_speed = base_speed
	
	# Connect the timer timeout signal to our code
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)

func spawn_grid() -> void:
	for row in range(rows):
		for col in range(columns):
			var alien = alien_scene.instantiate()
			add_child(alien)
			
			var x_pos = (col - (columns / 2.0)) * spacing
			var y_pos = row * spacing
			
			alien.position = Vector2(x_pos, y_pos)
			total_aliens += 1

func _physics_process(delta: float) -> void:
	if get_child_count() == 0:
		shoot_timer.stop() # Stop shooting if everyone is dead
		return 
		
	var alien_ratio = float(get_child_count()) / float(total_aliens)
	current_speed = base_speed * (2.5 - alien_ratio) 

	position.x += move_direction * current_speed * delta
	check_boundaries()

func check_boundaries() -> void:
	var shift_down: bool = false
	for alien in get_children():
		# Filter out the ShootTimer node since it isn't an alien
		if not alien is CharacterBody2D: continue
		
		var global_x = alien.global_position.x
		if move_direction > 0 and global_x >= right_bound:
			move_direction = -1.0
			shift_down = true
			break
		elif move_direction < 0 and global_x <= left_bound:
			move_direction = 1.0
			shift_down = true
			break
			
	if shift_down:
		position.y += drop_distance

# --- NEW SHOOTING LOGIC ---

func _on_shoot_timer_timeout() -> void:
	var bottom_aliens = get_bottom_aliens()
	
	# If we have valid shooters, pick one at random to fire
	if bottom_aliens.size() > 0:
		var random_shooter = bottom_aliens.pick_random()
		if random_shooter.has_method("spawn_bullet"):
			random_shooter.spawn_bullet()

func get_bottom_aliens() -> Array:
	# Dictionary to track the lowest alien for each unique X column position
	var columns_dict = {}
	
	for child in get_children():
		# Skip the Timer node inside the grid
		if not child is CharacterBody2D: 
			continue
			
		var local_x = child.position.x
		
		# If we haven't seen this column yet, or if this alien is lower down (larger local Y)
		if not columns_dict.has(local_x) or child.position.y > columns_dict[local_x].position.y:
			columns_dict[local_x] = child
			
	return columns_dict.values()
