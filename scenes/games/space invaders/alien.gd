extends CharacterBody2D

signal enemy_shot(bullet_instance, global_spawn_position)

@export var points: int = 10
@export var bullet: PackedScene

func spawn_bullet() -> void:
	if not bullet:
		return
		
	var bullety = bullet.instantiate()
	
	bullety.global_position = global_position
	
	get_tree().current_scene.add_child(bullety)

func take_damage() -> void:
	queue_free()
