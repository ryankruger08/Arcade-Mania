extends Area2D

@export var speed: float = 400.0
@export var alienbullet = false
@export var lifetime: float = 3.0
var _has_collided: bool = false

func _ready():
	var timer = Timer.new()
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.autostart = true
	timer.timeout.connect(timer_finish)
	add_child(timer)

func _physics_process(delta: float) -> void:
	if alienbullet == true:
		global_position.y += speed * delta
	else:
		global_position.y -= speed * delta
	


func timer_finish():
	queue_free()

func _on_body_entered(body: Node2D) -> void:
	if _has_collided:
		return
	
	if body.is_in_group("shield"):
		if body.has_method("take_damage"):
			_has_collided = true
			body.take_damage()
			queue_free()
		return
	
	if alienbullet:
		if not body.is_in_group("player"):
			return
	else:
		if not body.is_in_group("alien"):
			return
	
	if body.has_method("take_damage"):
		_has_collided = true
		body.take_damage()
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if _has_collided:
		return
	if alienbullet:
		return
	if not area.is_in_group("ufo"):
		return
	if area.has_method("take_damage"):
		_has_collided = true
		area.take_damage()
		queue_free()
