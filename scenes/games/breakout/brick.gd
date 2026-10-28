extends StaticBody2D
signal died(points, death_position)

@export var max_health: int = 1
@export var point_value: int = 1
var health: int
var _dead: bool = false

func _ready() -> void:
	add_to_group("brick")
	health = max_health
	_update_visual()

func take_damage() -> void:
	if _dead:
		return
	health -= 1
	if health <= 0:
		_dead = true
		died.emit(point_value, global_position)
		queue_free()
	else:
		_update_visual()

func _update_visual() -> void:
	modulate.a = 0.4 + 0.6 * (float(health) / float(max_health))
