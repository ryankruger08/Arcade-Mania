extends Area2D

@export var speed: float = 400.0
@onready var alienbullet = $alien
@onready var playerbullet = $player
var alien = true

func ready():
	if alien == true:
		playerbullet.visible = false
		alienbullet.visible = true
	elif alien == false:
		playerbullet.visible = true
		alienbullet.visible = false

func _physics_process(delta: float) -> void:
	global_position.y += speed * delta
	
	if global_position.y > 750:
		queue_free()
