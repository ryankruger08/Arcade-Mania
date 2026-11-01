extends Node3D

@onready var wheel: AnimationPlayer = get_node_or_null("racing machine/AnimationPlayer")
var last_animation = ""

func _process(_delta: float) -> void:
	if not wheel: return
	var turn = Input.get_axis("game_left", "game_right") if $coinslot.playing else 0.0
	var animation = "turn_left" if turn < -0.1 else ("turn_right" if turn > 0.1 else "middle")
	if animation != last_animation and wheel.has_animation(animation):
		wheel.play(animation)
		last_animation = animation
