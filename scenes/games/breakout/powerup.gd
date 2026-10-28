extends Area2D
signal collected(type)

@export var type: int = 0
@export var fall_speed: float = 150.0

func _ready() -> void:
	add_to_group("powerup")

func _physics_process(delta: float) -> void:
	position.y += fall_speed * delta
	var screen_height = get_viewport_rect().size.y
	if position.y > screen_height + 50:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("paddle"):
		collected.emit(type)
		queue_free()
