extends Area2D

@export var speed: float = 400.0
@export var alienbullet = false
var _has_collided: bool = false

func _ready():
	pass

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
