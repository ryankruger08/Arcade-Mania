extends Node2D

@export var speed: float = 140.0
@export var water: bool = false
@export var object_width: float = 100.0
@export var object_count: int = 3
@export var color: Color = Color.RED
@export var lane_width: float = 1140.0
var objects: Array = []
var current_speed: float

func reset(multiplier: float) -> void:
	current_speed = speed * multiplier
	objects.clear()
	var spacing = (lane_width + object_width) / object_count
	for i in object_count:
		objects.append(i * spacing - object_width / 2)
	queue_redraw()

func step(delta: float) -> void:
	for i in objects.size():
		objects[i] += current_speed * delta
		objects[i] = fposmod(objects[i] + object_width, lane_width + object_width) - object_width
	queue_redraw()

func contains_frog(x: float, seconds: float = 0.0) -> bool:
	for object in objects:
		var left = fposmod(object + current_speed * seconds + object_width, lane_width + object_width) - object_width
		if water:
			if x - 18 >= left and x + 18 <= left + object_width:
				return true
		elif x + 18 > left and x - 18 < left + object_width:
			return true
	return false

func _draw() -> void:
	for object in objects:
		draw_rect(Rect2(object, 8, object_width, 44), color)
