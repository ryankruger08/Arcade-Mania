extends CharacterBody2D

signal died()

func _ready() -> void:
	add_to_group("alien")

func take_damage() -> void:
	died.emit()
	queue_free()
