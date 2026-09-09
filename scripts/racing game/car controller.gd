extends CharacterBody3D

# Custom arcade kart controller (no VehicleBody3D).
# Uses raycasts to follow ground height/slope directly, so there's no suspension
# physics to fight - full control, Mario-Kart-style handling.
#
# Scene setup expected:
#   CharacterBody3D (this script)
#     - CollisionShape3D
#     - MeshInstance3D (the kart model - can be a separate child so it can tilt independently)
#     - GroundRay (RayCast3D, pointing straight down, enabled = true)

@export_group("Movement")
@export var max_speed := 20.0
@export var reverse_speed := 8.0
@export var acceleration := 14.0
@export var braking := 30.0
@export var friction := 10.0
@export var turn_speed := 2.6
@export var turn_speed_low_speed_mult := 1.5

@export_group("Drift")
@export var drift_turn_mult := 1.7
@export var drift_min_speed := 6.0
@export var drift_charge_rate := 1.0
@export var mini_boost_tiers := [1.0, 2.0, 3.0]
@export var mini_boost_speed_mult := [1.2, 1.5, 1.8]
@export var mini_boost_duration := 1.0

@export_group("Boost")
@export var boost_decay := 2.0

@export_group("Ground Following")
@export var ground_ray_length := 1.5
@export var hover_height := 0.4 # desired distance from kart origin to ground
@export var ground_snap_speed := 12.0 # how fast the kart corrects height/tilt
@export var gravity := 25.0 # used only when ray finds no ground (falling off track)

@onready var ground_ray: RayCast3D = $GroundRay
@onready var model: Node3D = $MeshInstance3D # swap to your visual root if different

var current_speed := 0.0
var drift_direction := 0
var drift_charge_time := 0.0
var boost_multiplier := 1.0
var boost_timer := 0.0
var vertical_velocity := 0.0


func _physics_process(delta: float) -> void:
	var input_forward := Input.get_action_strength("accelerate") - Input.get_action_strength("brake")
	var input_turn := Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")
	var drift_held := Input.is_action_pressed("drift")

	_handle_acceleration(input_forward, delta)
	_handle_drift(input_turn, drift_held, delta)
	_handle_turning(input_turn, delta)
	_handle_boost(delta)
	_handle_ground_following(delta)

	var forward_dir := -global_transform.basis.z
	var horizontal_velocity := forward_dir * current_speed * boost_multiplier
	velocity = Vector3(horizontal_velocity.x, vertical_velocity, horizontal_velocity.z)
	move_and_slide()


func _handle_acceleration(input_forward: float, delta: float) -> void:
	if input_forward > 0.0:
		current_speed = move_toward(current_speed, max_speed * input_forward, acceleration * delta)
	elif input_forward < 0.0:
		if current_speed > 0.5:
			current_speed = move_toward(current_speed, 0.0, braking * delta)
		else:
			current_speed = move_toward(current_speed, reverse_speed * input_forward, acceleration * delta)
	else:
		current_speed = move_toward(current_speed, 0.0, friction * delta)


func _handle_turning(input_turn: float, delta: float) -> void:
	if abs(current_speed) < 0.1:
		return

	var speed_factor: float = clamp(abs(current_speed) / max_speed, 0.0, 1.0)
	var low_speed_bonus: float = lerp(turn_speed_low_speed_mult, 1.0, speed_factor)
	var effective_turn_speed: float = turn_speed * low_speed_bonus

	var turn_mult := 1.0
	if drift_direction != 0:
		turn_mult = drift_turn_mult

	var direction_sign: float = sign(current_speed)
	rotate_y(-input_turn * effective_turn_speed * turn_mult * direction_sign * delta)


func _handle_drift(input_turn: float, drift_held: bool, delta: float) -> void:
	if drift_held and abs(current_speed) >= drift_min_speed and input_turn != 0.0:
		if drift_direction == 0:
			drift_direction = 1 if input_turn > 0.0 else -1
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
	# This is the part that replaces VehicleBody3D's suspension entirely.
	# We raycast down, and directly snap height + tilt to match the ground,
	# instead of letting spring physics fight for control.
	if ground_ray.is_colliding():
		var hit_point := ground_ray.get_collision_point()
		var hit_normal := ground_ray.get_collision_normal()

		var target_y := hit_point.y + hover_height
		var new_y: float = lerp(global_position.y, target_y, ground_snap_speed * delta)
		vertical_velocity = (new_y - global_position.y) / delta

		# tilt the visual model to match ground slope, without rotating the whole
		# collision body (keeps physics/turning simple and predictable)
		if model:
			var up := hit_normal
			var current_forward := -global_transform.basis.z
			var right := current_forward.cross(up).normalized()
			var corrected_forward := up.cross(right).normalized()
			var target_basis := Basis(right, up, -corrected_forward).orthonormalized()
			model.global_transform.basis = model.global_transform.basis.slerp(target_basis, ground_snap_speed * delta)
	else:
		# no ground found (e.g. driving off an edge) - fall naturally
		vertical_velocity -= gravity * delta


# Call from an item pickup or boost pad for an instant speed boost.
func apply_external_boost(multiplier: float, duration: float) -> void:
	_apply_boost(multiplier, duration)
