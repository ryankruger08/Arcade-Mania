extends Area2D
signal died(points)
@export var speed: float = 200.0
@export var min_bonus: int = 5
@export var max_bonus: int = 15
var direction: int = 1

func _ready() -> void:
	add_to_group("ufo")

func _physics_process(delta: float) -> void:
	global_position.x += direction * speed * delta
	var screen_width = get_viewport_rect().size.x
	if global_position.x < -50 or global_position.x > screen_width + 50:
		queue_free()

func take_damage() -> void:
	var bonus = randi_range(min_bonus, max_bonus)
	died.emit(bonus)
	queue_free()

func launch(start_x: float, y: float, dir: int) -> void:
	direction = dir
	global_position = Vector2(start_x, y)
