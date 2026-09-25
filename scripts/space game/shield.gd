extends StaticBody2D

@export var max_health: int = 4
var health: int

func _ready() -> void:
	add_to_group("shield")
	health = max_health
	_update_visual()

func take_damage() -> void:
	if health <= 0:
		return
	health -= 1
	_update_visual()

func reset() -> void:
	health = max_health
	visible = true
	_update_visual()

func _update_visual() -> void:
	modulate.a = float(health) / float(max_health)
	if health <= 0:
		visible = false
		set_collision_layer_value(4, false)
		set_collision_mask_value(4, false)
	else:
		visible = true
		set_collision_layer_value(4, true)
		set_collision_mask_value(4, true)
