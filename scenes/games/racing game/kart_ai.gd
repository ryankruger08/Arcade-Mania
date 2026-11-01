extends Node

@export var kart: CharacterBody3D
@export var track_path: Path3D
@export var lane_offset: float = 0.0

func _physics_process(delta: float) -> void:
	if not kart or not kart.ai_controlled or not kart.playing or not track_path:
		return
	var curve = track_path.curve
	var length = curve.get_baked_length()
	var progress = curve.get_closest_offset(track_path.to_local(kart.global_position))
	var look_ahead = 7.0 + abs(kart.current_speed) * 0.2
	var target_progress = fposmod(progress + look_ahead, length)
	var target = curve.sample_baked(target_progress)
	var ahead = curve.sample_baked(fposmod(target_progress + 1, length))
	var direction = (ahead - target).normalized()
	var right = direction.cross(Vector3.UP).normalized()
	target = track_path.to_global(target + right * lane_offset)
	var to_target = target - kart.global_position
	to_target.y = 0
	var facing = -kart.global_transform.basis.z
	facing.y = 0
	var angle = facing.normalized().signed_angle_to(to_target.normalized(), Vector3.UP)
	var turn = clamp(-angle * 2.2, -1.0, 1.0)
	var desired_speed = clamp(kart.max_speed * (1.0 - abs(angle) * 0.8), 10.0, kart.max_speed)
	var forward = 1.0 if kart.current_speed < desired_speed else 0.0
	if kart.current_speed > desired_speed + 3: forward = -0.3
	kart.set_ai_input(forward, turn)