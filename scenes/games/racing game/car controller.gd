extends CharacterBody3D

@export_group("Movement")
@export var max_speed: float = 26.0
@export var reverse_speed: float = 7.0
@export var acceleration: float = 12.0
@export var braking: float = 24.0
@export var friction: float = 6.0
@export var turn_speed: float = 2.0
@export var grip: float = 9.0

@export_group("Game")
@export var ai_controlled: bool = false
@export var body_color: Color = Color.RED
@export var visual_root: Node3D
var race: Node3D
var playing: bool = false
var current_speed: float = 0.0
var ai_input_forward: float = 0.0
var ai_input_turn: float = 0.0
var ai_input_drift: bool = false
var reset_cooldown: float = 0.0

func _ready() -> void:
	floor_snap_length = 1.2
	floor_max_angle = deg_to_rad(55)
	var body = visual_root.get_node_or_null("Cube") if visual_root else null
	if body:
		var material = StandardMaterial3D.new()
		material.albedo_color = body_color
		body.material_override = material

func reset(point: Vector3, angle: float) -> void:
	global_position = point
	rotation = Vector3(0, angle, 0)
	velocity = Vector3.ZERO
	current_speed = 0
	ai_input_forward = 0
	ai_input_turn = 0
	ai_input_drift = false
	reset_cooldown = 1.0

func set_ai_input(forward: float, turn: float, drifting: bool = false) -> void:
	ai_input_forward = forward
	ai_input_turn = turn
	ai_input_drift = drifting

func _physics_process(delta: float) -> void:
	reset_cooldown = max(0.0, reset_cooldown - delta)
	var forward = 0.0
	var turn = 0.0
	var drifting = false
	if playing:
		if ai_controlled:
			forward = ai_input_forward
			turn = ai_input_turn
			drifting = ai_input_drift
		else:
			forward = Input.get_axis("brake", "accelerate")
			if forward == 0: forward = Input.get_axis("ui_down", "ui_up")
			turn = Input.get_axis("steer_left", "steer_right")
			if turn == 0: turn = Input.get_axis("ui_left", "ui_right")
			drifting = Input.is_action_pressed("drift")
			if Input.is_physical_key_pressed(KEY_R) and reset_cooldown <= 0 and race:
				race.reset_kart(self)
	if forward > 0:
		current_speed = move_toward(current_speed, max_speed, acceleration * delta)
	elif forward < 0:
		current_speed = move_toward(current_speed, -reverse_speed, braking * delta)
	else:
		current_speed = move_toward(current_speed, 0, friction * delta)
	if not playing:
		current_speed = 0
	if abs(current_speed) > 0.5:
		var steering = turn_speed * clamp(abs(current_speed) / 12.0, 0.0, 1.0)
		if drifting: steering *= 1.2
		rotation.y -= turn * steering * sign(current_speed) * delta
	var direction = -global_transform.basis.z * current_speed
	var current_grip = 3.0 if drifting else grip
	velocity.x = move_toward(velocity.x, direction.x, current_grip * max_speed * delta)
	velocity.z = move_toward(velocity.z, direction.z, current_grip * max_speed * delta)
	if not is_on_floor():
		velocity.y -= 25.0 * delta
	else:
		velocity.y = -0.5
	move_and_slide()
	if visual_root:
		visual_root.rotation.z = lerp(visual_root.rotation.z, -turn * abs(current_speed) * 0.002, min(delta * 8, 1.0))
	if playing and race:
		race.check_kart(self, delta)