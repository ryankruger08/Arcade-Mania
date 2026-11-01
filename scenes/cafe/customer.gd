extends CharacterBody3D

signal arrived(customer)
signal lost_patience(customer)
signal finished_meal(customer)
signal left_cafe(customer)

@export var walk_speed = 1.5
@export var patience_seconds = 90.0
var state = "inactive"
var meal = "Coffee"
var table_index = -1
var patience_left = 90.0
var stay_seconds = 10.0
var eat_left = 0.0
var route: Array = []
var destination_state = "queue"

func walk(points: Array, next_state: String) -> void:
	route = points.duplicate()
	destination_state = next_state
	state = "walking"
	visible = true
	$Visual.position.y = 0

func reset_customer(point: Vector3, order: String) -> void:
	global_position = point
	meal = order
	table_index = -1
	patience_left = patience_seconds
	$Order.text = ""
	visible = true

func _physics_process(delta: float) -> void:
	if state in ["inactive", "gone"]: return
	if state in ["queue", "waiting"]:
		patience_left = maxf(0, patience_left-delta)
		if patience_left <= 0:
			state = "leaving"
			lost_patience.emit(self)
			return
	if state == "eating":
		eat_left -= delta
		if eat_left <= 0:
			state = "leaving"
			$Visual.position.y = 0
			finished_meal.emit(self)
		return
	if not route.is_empty():
		var offset: Vector3 = route[0] - global_position
		offset.y = 0
		if offset.length() < 0.15:
			route.pop_front()
			if route.is_empty():
				state = destination_state
				velocity = Vector3.ZERO
				if state == "eating":
					eat_left = stay_seconds
					$Visual.position.y = -0.25
					$Order.text = ""
				elif state == "gone":
					visible = false
					left_cafe.emit(self)
				arrived.emit(self)
			return
		velocity.x = offset.normalized().x * walk_speed
		velocity.z = offset.normalized().z * walk_speed
		rotation.y = lerp_angle(rotation.y, atan2(-offset.x,-offset.z), minf(1,delta*8))
	else:
		velocity.x = 0
		velocity.z = 0
	velocity.y = -0.5 if is_on_floor() else velocity.y - 20*delta
	move_and_slide()
