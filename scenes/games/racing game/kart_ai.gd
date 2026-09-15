extends Node

# Waypoint-following AI for the custom kart controller (kart_controller_custom.gd).
# Attach this as a sibling/child node on the same kart, point it at a Path3D (or a
# plain array of Marker3D nodes) representing the track, and it'll drive the kart
# around by calling set_ai_input() on the controller each physics frame.
#
# Scene setup:
#   Kart (CharacterBody3D, kart_controller_custom.gd, ai_controlled = true)
#     - KartAI (Node, this script)
#
# Waypoints: either
#   (a) assign "waypoints_path" to a Path3D node whose curve traces the racing line, or
#   (b) leave it empty and assign "waypoints" directly to an array of Node3D markers.
# Option (a) is usually easier to author in the editor (draw a curve along the track).

@export var kart: Node # the CharacterBody3D running kart_controller_custom.gd - assign in inspector
@export var waypoints_path: Path3D # optional: auto-generates waypoints from this curve
@export var waypoints_from_path_count := 40 # how many sample points to take along the curve
@export var waypoints: Array[Node3D] = [] # used directly if waypoints_path is not set

@export_group("Driving")
@export var waypoint_reach_distance := 4.0 # how close counts as "reached this waypoint"
@export var look_ahead_waypoints := 1 # steer toward N waypoints ahead of the nearest one, for smoother lines through corners
@export var max_steer_angle_for_full_turn_deg := 45.0 # angle-to-target beyond which steering input is maxed out
@export var slow_down_angle_deg := 25.0 # angle-to-target beyond which the AI starts easing off the accelerator
@export var min_throttle_in_corners := 0.4 # never brakes to a full stop in corners, just eases off
@export var drift_angle_threshold_deg := 20.0 # start drifting through turns sharper than this
@export var drift_min_speed_ratio := 0.5 # only drift if going reasonably fast (matches controller's own drift_min_speed roughly)

@export_group("Rubber-banding (optional)")
@export var enable_rubber_banding := false
@export var rubber_band_target: Node3D # usually the player kart, to compare progress against
@export var rubber_band_max_boost := 1.15 # top speed multiplier when far behind
@export var rubber_band_max_slow := 0.9 # speed multiplier when far ahead

var current_waypoint_index := 0
var _generated_waypoints: Array[Vector3] = []
var _use_generated := false


func _ready() -> void:
	if kart:
		kart.ai_controlled = true

	if waypoints_path:
		_generate_waypoints_from_path()
		_use_generated = true
	elif waypoints.is_empty():
		push_warning("KartAIController has no waypoints_path and no waypoints assigned - AI will not drive anywhere.")


func _generate_waypoints_from_path() -> void:
	_generated_waypoints.clear()
	var curve := waypoints_path.curve
	if curve == null or curve.get_baked_length() <= 0.0:
		push_warning("KartAIController's waypoints_path has no valid curve.")
		return

	var length := curve.get_baked_length()
	for i in waypoints_from_path_count:
		var distance := (float(i) / float(waypoints_from_path_count)) * length
		var local_point := curve.sample_baked(distance)
		_generated_waypoints.append(waypoints_path.to_global(local_point))


func _get_waypoint_position(index: int) -> Vector3:
	var count := _waypoint_count()
	var wrapped_index := ((index % count) + count) % count

	if _use_generated:
		return _generated_waypoints[wrapped_index]
	else:
		return waypoints[wrapped_index].global_position


func _waypoint_count() -> int:
	return _generated_waypoints.size() if _use_generated else waypoints.size()


func _physics_process(delta: float) -> void:
	if kart == null or _waypoint_count() == 0:
		return

	_advance_waypoint_if_reached()

	var look_ahead_index := current_waypoint_index + look_ahead_waypoints
	var target_pos := _get_waypoint_position(look_ahead_index)

	var kart_pos: Vector3 = kart.global_position
	var kart_forward: Vector3 = -kart.global_transform.basis.z

	var to_target := target_pos - kart_pos
	to_target.y = 0.0 # steer in the horizontal plane only
	if to_target.length() < 0.001:
		return
	to_target = to_target.normalized()

	var flat_forward := kart_forward
	flat_forward.y = 0.0
	flat_forward = flat_forward.normalized()

	# signed angle between where we're facing and where we want to go:
	# positive = target is to the right, negative = target is to the left.
	var angle_to_target := flat_forward.signed_angle_to(to_target, Vector3.UP)
	var angle_deg := rad_to_deg(angle_to_target)

	var steer_input := _compute_steer_input(angle_deg)
	var throttle_input := _compute_throttle_input(angle_deg)
	var drift_input := _compute_drift_input(angle_deg)

	if enable_rubber_banding and rubber_band_target:
		throttle_input *= _compute_rubber_band_multiplier()

	kart.set_ai_input(throttle_input, steer_input, drift_input)


func _advance_waypoint_if_reached() -> void:
	var current_target := _get_waypoint_position(current_waypoint_index)
	var kart_pos: Vector3 = kart.global_position
	var flat_distance := Vector2(current_target.x - kart_pos.x, current_target.z - kart_pos.z).length()

	if flat_distance <= waypoint_reach_distance:
		current_waypoint_index += 1


func _compute_steer_input(angle_deg: float) -> float:
	var t: float = clampf(angle_deg / max_steer_angle_for_full_turn_deg, -1.0, 1.0)
	return t


func _compute_throttle_input(angle_deg: float) -> float:
	var abs_angle: float = absf(angle_deg)
	if abs_angle <= slow_down_angle_deg:
		return 1.0

	# ease throttle down as the turn gets sharper, but never fully brake -
	# arcade AI should keep moving, not stop dead in corners.
	var over_angle: float = abs_angle - slow_down_angle_deg
	var max_over: float = max_steer_angle_for_full_turn_deg - slow_down_angle_deg
	var t: float = clampf(over_angle / maxf(max_over, 0.001), 0.0, 1.0)
	return lerpf(1.0, min_throttle_in_corners, t)


func _compute_drift_input(angle_deg: float) -> bool:
	var abs_angle: float = absf(angle_deg)
	if abs_angle < drift_angle_threshold_deg:
		return false

	var speed_ratio: float = kart.get_speed_ratio() if kart.has_method("get_speed_ratio") else 1.0
	return speed_ratio >= drift_min_speed_ratio


func _compute_rubber_band_multiplier() -> float:
	# very simple rubber-banding: compare distance-to-next-waypoint as a rough proxy
	# for race progress. Replace with lap/checkpoint progress tracking for a real race.
	if rubber_band_target == null:
		return 1.0

	var my_pos: Vector3 = kart.global_position
	var their_pos: Vector3 = rubber_band_target.global_position
	var target_pos := _get_waypoint_position(current_waypoint_index)

	var my_distance := my_pos.distance_to(target_pos)
	var their_distance := their_pos.distance_to(target_pos)

	# if I'm further from the shared target than they are, I'm behind - speed up a bit.
	var gap := their_distance - my_distance # positive = I'm ahead, negative = I'm behind
	var normalized_gap: float = clampf(-gap / 20.0, -1.0, 1.0) # tune 20.0 to your track scale

	if normalized_gap > 0.0:
		return lerpf(1.0, rubber_band_max_boost, normalized_gap)
	else:
		return lerpf(1.0, rubber_band_max_slow, -normalized_gap)
