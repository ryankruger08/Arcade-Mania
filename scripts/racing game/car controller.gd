extends CharacterBody3D

# Custom arcade kart controller (no VehicleBody3D).
# Uses raycasts to follow ground height/slope, and a grip/slip system so the kart
# actually slides into turns instead of snapping velocity to face direction.
#
# Scene setup expected:
#   CharacterBody3D (this script)
#     - CollisionShape3D
#     - MeshInstance3D (the kart model - separate child so it can tilt independently)
#     - GroundRay (RayCast3D, pointing straight down, target_position ~ (0,-1.5,0), enabled = true)

@export_group("Movement")
@export var max_speed := 20.0
@export var reverse_speed := 8.0
@export var acceleration := 14.0
@export var braking := 30.0
@export var friction := 10.0

@export_group("Steering")
@export var turn_speed := 2.4 # max rad/sec the kart's facing can turn
@export var steering_smoothing := 8.0 # how fast steering input ramps up/down (higher = snappier)
@export var turn_speed_low_speed_mult := 1.4

@export_group("Grip")
@export var grip_normal := 14.0 # how fast velocity direction chases facing direction (higher = more glued)
@export var grip_drift := 3.5 # lower grip while drifting = more slide

@export_group("Drift")
@export var drift_turn_mult := 1.6
@export var drift_min_speed := 6.0
@export var drift_charge_rate := 1.0
@export var mini_boost_tiers := [1.0, 2.0, 3.0]
@export var mini_boost_speed_mult := [1.2, 1.5, 1.8]
@export var mini_boost_duration := 1.0

@export_group("Boost")
@export var boost_decay := 2.0

@export_group("Ground Following")
@export var hover_height := 0.4
@export var ground_snap_speed := 14.0
@export var gravity := 25.0

@onready var ground_ray: RayCast3D = $GroundRay
@onready var model: Node3D = $MeshInstance3D

var current_speed := 0.0
var steering_input := 0.0 # smoothed -1..1
var move_direction := Vector3.FORWARD # actual direction velocity is heading
var drift_direction := 0
var drift_charge_time := 0.0
var boost_multiplier := 1.0
var boost_timer := 0.0
var vertical_velocity := 0.0


func _ready() -> void:
	move_direction = -global_transform.basis.z


func _physics_process(delta: float) -> void:
	var input_forward := Input.get_action_strength("accelerate") - Input.get_action_strength("brake")
	var input_turn := Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")
	var drift_held := Input.is_action_pressed("drift")

	steering_input = move_toward(steering_input, input_turn, steering_smoothing * delta)

	_handle_acceleration(input_forward, delta)
	_handle_drift(delta)
	_handle_turning(delta)
	_handle_grip(delta)
	_handle_boost(delta)
	_handle_ground_following(delta)

	var horizontal_velocity := move_direction * current_speed * boost_multiplier
	velocity = Vector3(horizontal_velocity.x, vertical_velocity, horizontal_velocity.z)
	move_and_slide()


func _handle_acceleration(input_forward: float, delta: float) -> void:
	if input_forward > 0.0:
		# ease-out curve: accelerates fast off the line, tapers as it nears max speed
		var speed_ratio: float = clamp(current_speed / max_speed, 0.0, 1.0)
		var curve_mult: float = lerp(1.4, 0.5, speed_ratio)
		current_speed = move_toward(current_speed, max_speed * input_forward, acceleration * curve_mult * delta)
	elif input_forward < 0.0:
		if current_speed > 0.5:
			current_speed = move_toward(current_speed, 0.0, braking * delta)
		else:
			current_speed = move_toward(current_speed, reverse_speed * input_forward, acceleration * delta)
	else:
		current_speed = move_toward(current_speed, 0.0, friction * delta)


func _handle_turning(delta: float) -> void:
	if abs(current_speed) < 0.1:
		return

	var speed_factor: float = clamp(abs(current_speed) / max_speed, 0.0, 1.0)
	var low_speed_bonus: float = lerp(turn_speed_low_speed_mult, 1.0, speed_factor)
	var effective_turn_speed: float = turn_speed * low_speed_bonus

	var turn_mult := 1.0
	if drift_direction != 0:
		turn_mult = drift_turn_mult

	var direction_sign: float = sign(current_speed)
	rotate_y(-steering_input * effective_turn_speed * turn_mult * direction_sign * delta)


func _handle_grip(delta: float) -> void:
	# blend the actual movement direction toward the kart's facing direction.
	# high grip = they match almost instantly (glued to facing).
	# low grip (drifting) = velocity lags behind facing, so the kart slides sideways.
	var target_dir := -global_transform.basis.z
	var current_grip := grip_drift if drift_direction != 0 else grip_normal
	move_direction = move_direction.slerp(target_dir, clamp(current_grip * delta, 0.0, 1.0))
	move_direction = move_direction.normalized()


func _handle_drift(delta: float) -> void:
	if Input.is_action_pressed("drift") and abs(current_speed) >= drift_min_speed and steering_input != 0.0:
		if drift_direction == 0:
			drift_direction = 1 if steering_input > 0.0 else -1
			drift_charge_time = 0.0
		drift_charge_time += drift_charge_rate * delta
	else:
		if drift_direction != 0:
			_release_drift()
		drift_direction = 0


func _release_drift() -> void:
	var tier := -1
	for i in mini_boost_tiers.size():
		if drift_charge_time >= mini_boost_tiers[i]:
			tier = i

	if tier >= 0:
		_apply_boost(mini_boost_speed_mult[tier], mini_boost_duration)

	drift_charge_time = 0.0


func _apply_boost(multiplier: float, duration: float) -> void:
	boost_multiplier = multiplier
	boost_timer = duration


func _handle_boost(delta: float) -> void:
	if boost_timer > 0.0:
		boost_timer -= delta
	else:
		boost_multiplier = move_toward(boost_multiplier, 1.0, boost_decay * delta)


func _handle_ground_following(delta: float) -> void:
	if ground_ray == null:
		return

	if ground_ray.is_colliding():
		var hit_point := ground_ray.get_collision_point()
		var hit_normal := ground_ray.get_collision_normal()

		var target_y := hit_point.y + hover_height
		var new_y: float = lerp(global_position.y, target_y, ground_snap_speed * delta)
		vertical_velocity = (new_y - global_position.y) / delta

		if model:
			var up := hit_normal
			var current_forward := -global_transform.basis.z
			var right := current_forward.cross(up).normalized()
			var corrected_forward := up.cross(right).normalized()
			var target_basis := Basis(right, up, -corrected_forward).orthonormalized()
			model.global_transform.basis = model.global_transform.basis.slerp(target_basis, ground_snap_speed * delta)
	else:
		vertical_velocity -= gravity * delta


# Call from an item pickup or boost pad for an instant speed boost.
func apply_external_boost(multiplier: float, duration: float) -> void:
	_apply_boost(multiplier, duration)
