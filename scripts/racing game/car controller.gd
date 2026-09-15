extends CharacterBody3D

# Custom arcade kart controller (no VehicleBody3D).
#
# WHEEL DETECTION: uses ShapeCast3D (a sphere shape swept downward) instead of a thin
# RayCast3D. This matters because a bare ray has zero width and can slip through small
# gaps between track pieces or catch weird edges - a sphere the size of the actual
# wheel behaves much more like a real wheel touching the ground.
#
# Each WheelFL/FR/RL/RR ShapeCast3D needs:
#   - Shape = a new SphereShape3D with Radius matching wheel_radius below
#   - target_position = Vector3(0, -1.0, 0) (pointing down, length = max suspension travel)
#   - enabled = true
#
# IMPORTANT SCENE STRUCTURE: all visuals (body mesh + wheel meshes) should be
# children of a single "visual_root" Node3D, assigned below. The CharacterBody3D itself
# stays upright and flat (so collision/physics stays simple and stable), while
# visual_root is the thing that actually tilts and bobs with the suspension - so the
# body and all 4 wheels move together as one consistent rigid unit instead of being
# positioned independently.
#
# Scene setup expected:
#   CharacterBody3D (this script)
#     - CollisionShape3D
#     - WheelFL (ShapeCast3D, at front-left corner, pointing down, Shape = SphereShape3D)
#     - WheelFR (ShapeCast3D, at front-right corner)
#     - WheelRL (ShapeCast3D, at rear-left corner)
#     - WheelRR (ShapeCast3D, at rear-right corner)
#     - VisualRoot (Node3D)              <- assign this to "visual_root" below
#         - BodyMesh (MeshInstance3D)     <- the chassis model
#         - WheelFLMesh (Node3D/MeshInstance3D) <- assign to wheel_fl_mesh
#         - WheelFRMesh                    <- assign to wheel_fr_mesh
#         - WheelRLMesh                    <- assign to wheel_rl_mesh
#         - WheelRRMesh                    <- assign to wheel_rr_mesh
#
#   Each wheel mesh's starting local position/rotation (relative to VisualRoot) is
#   captured at _ready() as its rest pose - suspension and steering are then applied
#   as offsets from that rest pose, so place them exactly where they should sit when
#   the kart is stationary on flat ground before running the scene.

@export_group("Movement")
@export var max_speed := 20.0
@export var reverse_speed := 8.0
@export var acceleration := 14.0
@export var braking := 30.0
@export var friction := 10.0

@export_group("Steering")
@export var turn_speed := 2.4
@export var steering_smoothing := 8.0
@export var turn_speed_low_speed_mult := 1.4

@export_group("Grip")
@export var grip_normal := 14.0
@export var grip_drift := 3.5

@export_group("Drift")
@export var drift_turn_mult := 1.6
@export var drift_min_speed := 6.0
@export var drift_charge_rate := 1.0
@export var mini_boost_tiers := [1.0, 2.0, 3.0]
@export var mini_boost_speed_mult := [1.2, 1.5, 1.8]
@export var mini_boost_duration := 1.0

@export_group("Boost")
@export var boost_decay := 2.0

@export_group("Control")
@export var ai_controlled := false # if true, this kart reads input from set_ai_input() (called by a KartAIController) instead of the Input singleton - lets the same controller script drive both the player and AI racers.

var ai_input_forward := 0.0
var ai_input_turn := 0.0
var ai_input_drift := false

@export_group("Wheel Raycasts")
@export var wheel_fl: ShapeCast3D
@export var wheel_fr: ShapeCast3D
@export var wheel_rl: ShapeCast3D
@export var wheel_rr: ShapeCast3D

@export_group("Visuals")
@export var visual_root: Node3D # parent of body mesh + all wheel meshes; this tilts/bobs as one unit
@export var wheel_fl_mesh: Node3D
@export var wheel_fr_mesh: Node3D
@export var wheel_rl_mesh: Node3D
@export var wheel_rr_mesh: Node3D
@export var wheel_radius := 0.3 # distance from wheel center to ground contact
@export var max_wheel_steer_angle_deg := 25.0
@export var wheel_visual_snap_speed := 35.0 # how fast wheel meshes follow their target pose

@export_group("Wheel Suspension")
@export var ride_height := 0.5 # MUST equal the real-world distance from each wheel node's global position straight down to the ground when the kart sits at rest. If wheels look "too high," this number doesn't match your actual scene placement/scale - measure it in the editor and correct it.
@export var suspension_stiffness := 25.0 # affects only the cosmetic wheel-mesh bob, not body height
@export var suspension_damping := 6.0
@export var body_response_speed := 25.0 # how fast the BODY's height corrects each frame - higher = snappier, less lag/clipping
@export var gravity := 25.0

var current_speed := 0.0
var steering_input := 0.0
var move_direction := Vector3.FORWARD
var drift_direction := 0
var drift_charge_time := 0.0
var boost_multiplier := 1.0
var boost_timer := 0.0
var vertical_velocity := 0.0

# per-wheel suspension compression state, keyed by ShapeCast3D
var wheel_compression := {}
var wheel_compression_velocity := {}

# rest pose of each wheel mesh, captured relative to visual_root at _ready
var wheel_rest_local_pos := {}
var wheel_rest_local_rot_y := {}
var wheel_mesh_map := {}
var steering_wheel_meshes := []

# rest pose of visual_root relative to this body, captured at _ready
var visual_root_rest_local_pos: Vector3
var visual_root_rest_local_basis: Basis


func _ready() -> void:
	move_direction = -global_transform.basis.z

	for w in [wheel_fl, wheel_fr, wheel_rl, wheel_rr]:
		if w:
			wheel_compression[w] = 0.0
			wheel_compression_velocity[w] = 0.0

	wheel_mesh_map[wheel_fl] = wheel_fl_mesh
	wheel_mesh_map[wheel_fr] = wheel_fr_mesh
	wheel_mesh_map[wheel_rl] = wheel_rl_mesh
	wheel_mesh_map[wheel_rr] = wheel_rr_mesh
	steering_wheel_meshes = [wheel_fl_mesh, wheel_fr_mesh]

	for mesh in [wheel_fl_mesh, wheel_fr_mesh, wheel_rl_mesh, wheel_rr_mesh]:
		if mesh:
			wheel_rest_local_pos[mesh] = mesh.position
			wheel_rest_local_rot_y[mesh] = mesh.rotation.y

	if visual_root:
		visual_root_rest_local_pos = visual_root.position
		visual_root_rest_local_basis = visual_root.transform.basis


func _physics_process(delta: float) -> void:
	var input_forward: float
	var input_turn: float
	var drift_held: bool

	if ai_controlled:
		input_forward = ai_input_forward
		input_turn = ai_input_turn
		drift_held = ai_input_drift
	else:
		input_forward = Input.get_action_strength("accelerate") - Input.get_action_strength("brake")
		input_turn = Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")
		drift_held = Input.is_action_pressed("drift")

	steering_input = move_toward(steering_input, input_turn, steering_smoothing * delta)

	_handle_acceleration(input_forward, delta)
	_handle_drift(drift_held, delta)
	_handle_turning(delta)
	_handle_grip(delta)
	_handle_boost(delta)
	_update_wheel_springs(delta)
	_handle_body_height(delta)
	_handle_visual_root(delta)
	_handle_wheel_visuals(delta)

	var horizontal_velocity := move_direction * current_speed * boost_multiplier
	velocity = Vector3(horizontal_velocity.x, vertical_velocity, horizontal_velocity.z)
	move_and_slide()


# Called by a KartAIController each physics frame instead of that AI kart reading
# the Input singleton. forward/turn are -1..1, drift is a bool (held or not).
func set_ai_input(forward: float, turn: float, drift: bool) -> void:
	ai_input_forward = forward
	ai_input_turn = turn
	ai_input_drift = drift


func _handle_acceleration(input_forward: float, delta: float) -> void:
	if input_forward > 0.0:
		var speed_ratio: float = clampf(current_speed / max_speed, 0.0, 1.0)
		var curve_mult: float = lerpf(1.4, 0.5, speed_ratio)
		current_speed = move_toward(current_speed, max_speed * input_forward, acceleration * curve_mult * delta)
	elif input_forward < 0.0:
		if current_speed > 0.5:
			current_speed = move_toward(current_speed, 0.0, braking * delta)
		else:
			current_speed = move_toward(current_speed, reverse_speed * input_forward, acceleration * delta)
	else:
		current_speed = move_toward(current_speed, 0.0, friction * delta)


func _handle_turning(delta: float) -> void:
	if absf(current_speed) < 0.1:
		return

	var speed_factor: float = clampf(absf(current_speed) / max_speed, 0.0, 1.0)
	var low_speed_bonus: float = lerpf(turn_speed_low_speed_mult, 1.0, speed_factor)
	var effective_turn_speed: float = turn_speed * low_speed_bonus

	var turn_mult := 1.0
	if drift_direction != 0:
		turn_mult = drift_turn_mult

	var direction_sign: float = signf(current_speed)
	rotate_y(-steering_input * effective_turn_speed * turn_mult * direction_sign * delta)


func _handle_grip(delta: float) -> void:
	var target_dir := -global_transform.basis.z
	var current_grip := grip_drift if drift_direction != 0 else grip_normal
	move_direction = move_direction.slerp(target_dir, clampf(current_grip * delta, 0.0, 1.0))
	move_direction = move_direction.normalized()


func _handle_drift(drift_held: bool, delta: float) -> void:
	if drift_held and absf(current_speed) >= drift_min_speed and steering_input != 0.0:
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


func _get_wheel_distance(wheel: ShapeCast3D) -> float:
	# actual measured distance from the raycast origin to the ground, or -1 if no ground found.
	if wheel == null or not wheel.is_colliding():
		return -1.0
	var hit_point := wheel.get_collision_point(0)
	return wheel.global_position.distance_to(hit_point)


func _update_wheel_springs(delta: float) -> void:
	# spring-damper per wheel: compression = how much shorter than rest_length the
	# measured ground distance is. 0 = fully extended, positive = pushed in by a bump.
	for w in [wheel_fl, wheel_fr, wheel_rl, wheel_rr]:
		if w == null:
			continue

		var distance := _get_wheel_distance(w)
		var target_compression: float = clampf(ride_height - distance, 0.0, ride_height) if distance >= 0.0 else 0.0

		var compression: float = wheel_compression.get(w, 0.0)
		var compression_vel: float = wheel_compression_velocity.get(w, 0.0)

		var spring_force := (target_compression - compression) * suspension_stiffness
		compression_vel += spring_force * delta
		compression_vel *= clampf(1.0 - suspension_damping * delta, 0.0, 1.0)
		compression += compression_vel * delta

		wheel_compression[w] = compression
		wheel_compression_velocity[w] = compression_vel


func _handle_body_height(delta: float) -> void:
	# moves the actual CharacterBody3D up/down to follow the ground - kept simple
	# (height only, no tilt) so physics/collision stays predictable. All visual
	# tilt/lean happens on visual_root separately.
	#
	# Uses a direct proportional correction (velocity = how-far-off-we-are * response
	# speed) rather than deriving velocity from a lerp's frame-to-frame movement -
	# the lerp-derived approach lags behind and can drift/clip since it's reacting to
	# its own previous correction instead of the actual current error.
	var wheels := [wheel_fl, wheel_fr, wheel_rl, wheel_rr]
	var hit_heights := []

	for w in wheels:
		if w and w.is_colliding():
			hit_heights.append(w.get_collision_point(0).y)

	if hit_heights.is_empty():
		vertical_velocity -= gravity * delta
		return

	var avg_height := 0.0
	for h in hit_heights:
		avg_height += h
	avg_height /= hit_heights.size()

	var target_y: float = avg_height + ride_height
	var height_error: float = target_y - global_position.y

	# proportional control: velocity scales with how wrong the current height is,
	# so it corrects fast when far off and settles smoothly as it approaches target.
	vertical_velocity = height_error * body_response_speed
	# safety clamp so a big one-frame error (e.g. spawning embedded in ground)
	# can't launch the kart instead of just correcting smoothly.
	vertical_velocity = clampf(vertical_velocity, -30.0, 30.0)


func _handle_visual_root(delta: float) -> void:
	# tilts + bobs the WHOLE visual assembly (body + wheels) as one rigid unit,
	# based on the plane fitted through all 4 wheel contact points. This runs in
	# local space relative to the CharacterBody3D (which only yaws), so visual_root
	# carries the extra pitch/roll/height on top of that.
	if visual_root == null:
		return

	if not (wheel_fl and wheel_fr and wheel_rl and wheel_rr):
		return

	if not (wheel_fl.is_colliding() and wheel_fr.is_colliding() and wheel_rl.is_colliding() and wheel_rr.is_colliding()):
		# not all wheels grounded - ease back toward rest pose rather than guessing a tilt
		visual_root.position = visual_root.position.lerp(visual_root_rest_local_pos, body_response_speed * delta)
		visual_root.transform.basis = visual_root.transform.basis.slerp(visual_root_rest_local_basis, body_response_speed * delta).orthonormalized()
		return

	var fl: Vector3 = wheel_fl.get_collision_point(0)
	var fr: Vector3 = wheel_fr.get_collision_point(0)
	var rl: Vector3 = wheel_rl.get_collision_point(0)
	var rr: Vector3 = wheel_rr.get_collision_point(0)

	var front_mid := (fl + fr) / 2.0
	var rear_mid := (rl + rr) / 2.0
	var left_mid := (fl + rl) / 2.0
	var right_mid := (fr + rr) / 2.0

	var forward_vec := (front_mid - rear_mid).normalized()
	var right_vec := (right_mid - left_mid).normalized()
	var up_vec := right_vec.cross(forward_vec).normalized()
	var clean_forward := up_vec.cross(right_vec).normalized()

	var target_world_basis := Basis(right_vec, up_vec, -clean_forward).orthonormalized()
	# convert the world-space target tilt into visual_root's LOCAL space, since
	# visual_root is parented under the CharacterBody3D (which already has its own yaw).
	var parent_basis := global_transform.basis
	var target_local_basis: Basis = (parent_basis.inverse() * target_world_basis).orthonormalized()

	visual_root.transform.basis = visual_root.transform.basis.slerp(target_local_basis, body_response_speed * delta).orthonormalized()

	# visual_root stays at its rest LOCAL position - the body's own global height
	# (handled in _handle_body_height) already accounts for ground following, so
	# adding a second vertical offset here was double-correcting height and part of
	# why the body/wheels didn't line up with the ground correctly.
	visual_root.position = visual_root.position.lerp(visual_root_rest_local_pos, body_response_speed * delta)


func _handle_wheel_visuals(delta: float) -> void:
	# positions each wheel mesh using its OWN raycast's contact point/normal directly,
	# rather than a shared body plane - so a wheel hanging off a ledge or resting on
	# an uneven bit of track still looks physically correct even if others don't match.
	for wheel in wheel_mesh_map.keys():
		var mesh: Node3D = wheel_mesh_map[wheel]
		if mesh == null or wheel == null:
			continue

		var rest_pos: Vector3 = wheel_rest_local_pos.get(mesh, mesh.position)
		var rest_rot_y: float = wheel_rest_local_rot_y.get(mesh, mesh.rotation.y)
		var compression: float = wheel_compression.get(wheel, 0.0)

		# wheel moves UP (toward the body) as compression increases, staying at its
		# rest X/Z mount point - this is what "where the wheel needs to be" resolves to.
		var target_local_pos := rest_pos
		target_local_pos.y = rest_pos.y + compression
		mesh.position = mesh.position.lerp(target_local_pos, wheel_visual_snap_speed * delta)

		var target_rot_y := rest_rot_y
		if mesh in steering_wheel_meshes:
			target_rot_y = rest_rot_y + deg_to_rad(max_wheel_steer_angle_deg) * steering_input

		mesh.rotation.y = lerp_angle(mesh.rotation.y, target_rot_y, wheel_visual_snap_speed * delta)


# Call from an item pickup or boost pad for an instant speed boost.
func apply_external_boost(multiplier: float, duration: float) -> void:
	_apply_boost(multiplier, duration)


# Convenience getters for a KartAIController (or anything else) that needs to
# reason about this kart's current state without reaching into internals directly.
func get_current_speed() -> float:
	return current_speed


func get_speed_ratio() -> float:
	return clampf(absf(current_speed) / max_speed, 0.0, 1.0)
