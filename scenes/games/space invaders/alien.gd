extends CharacterBody2D

signal died(points)
@export var point_value: int = 1
var _dead: bool = false

func _ready() -> void:
	add_to_group("alien")

func take_damage() -> void:
	if _dead:
		return
	_dead = true
	died.emit(point_value)
	remove_from_group("alien")
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.finished.connect(queue_free)
