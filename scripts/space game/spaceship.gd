extends CharacterBody2D

@export var speed: float = 300.0
@export var bullet: PackedScene
@export var bullet_container: Node2D
@export var lives: int = 3
@export var demo_speed_multiplier: float = 0.5
@export var demo_shoot_interval: float = 1.0
@export var demo_edge_margin: float = 40.0
@export var invulnerability_time: float = 1.2
signal died()
var demo_mode: bool = false
var demo_direction: int = 1
var demo_shoot_timer: Timer
var invulnerable: bool = false

func _ready() -> void:
	add_to_group("player")
	demo_shoot_timer = Timer.new()
	demo_shoot_timer.wait_time = demo_shoot_interval
	demo_shoot_timer.one_shot = false
	demo_shoot_timer.timeout.connect(_on_demo_shoot_timeout)
	add_child(demo_shoot_timer)

func _physics_process(delta: float) -> void:
	if demo_mode:
		_demo_move()
		return
	if Input.is_action_just_pressed("shoot"):
		_fire_bullet()
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)

	move_and_slide()

func _demo_move() -> void:
	var screen_width = get_viewport_rect().size.x
	velocity.x = demo_direction * speed * demo_speed_multiplier
	move_and_slide()
	if global_position.x <= demo_edge_margin or global_position.x >= screen_width - demo_edge_margin:
		demo_direction *= -1

func _on_demo_shoot_timeout() -> void:
	if not demo_mode:
		return
	_fire_bullet()

func _fire_bullet() -> void:
	if not bullet:
		return
	var bullety = bullet.instantiate()
	bullety.global_position = global_position + Vector2(0, -100)
	bullety.alienbullet = false
	if bullet_container:
		bullet_container.add_child(bullety)
	else:
		get_tree().current_scene.add_child(bullety)

func take_damage() -> void:
	if demo_mode or invulnerable:
		return
	lives -= 1
	if lives <= 0:
		died.emit()
		visible = false
		set_physics_process(false)
		return
	_start_invulnerability()

func _start_invulnerability() -> void:
	invulnerable = true
	var tween = create_tween()
	tween.set_loops(int(invulnerability_time / 0.2))
	tween.tween_property(self, "modulate:a", 0.2, 0.1)
	tween.tween_property(self, "modulate:a", 1.0, 0.1)
	tween.finished.connect(_end_invulnerability)

func _end_invulnerability() -> void:
	invulnerable = false
	modulate.a = 1.0

func reset(start_lives: int) -> void:
	lives = start_lives
	visible = true
	invulnerable = false
	modulate.a = 1.0
	set_physics_process(true)

func set_demo_mode(enabled: bool) -> void:
	demo_mode = enabled
	if enabled:
		demo_shoot_timer.wait_time = demo_shoot_interval
		demo_shoot_timer.start()
	else:
		demo_shoot_timer.stop()
