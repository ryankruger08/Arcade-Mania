extends Node2D

@onready var scoretext = $in_game_ui/RichTextLabel
@onready var livestext = $in_game_ui/LivesLabel
@onready var gameovertext = $in_game_ui/GameOverLabel
@onready var player = $spaceship
@export var formation_scene: PackedScene
@export var spawn_interval: float = 8.0
@export var rows_per_score_step: int = 10
@export var max_rows: int = 6
@export var max_concurrent_formations: int = 1
@export var starting_lives: int = 3
var score = 0
var game_over: bool = false
var active: bool = false
var spawn_timer: Timer
var player_start_position: Vector2

func _ready() -> void:
	$background_anim/AnimationPlayer.play("background")
	gameovertext.visible = false
	player_start_position = player.global_position
	player.died.connect(_on_player_died)
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.one_shot = false
	spawn_timer.timeout.connect(spawn_wave)
	add_child(spawn_timer)


func _process(delta: float) -> void:
	if not active or game_over:
		return
	if Input.is_action_just_pressed("remove_credit"):
		spawn_wave()

func killed_alien(amount):
	score += amount
	scoretext.text = str(score)
	

func spawn_wave() -> void:
	if not active or game_over:
		return
	if $aliens.get_child_count() >= max_concurrent_formations:
		return
	var formation = formation_scene.instantiate()
	formation.alien_killed.connect(_on_alien_killed)
	formation.reached_bottom.connect(_on_game_over)
	$aliens.add_child(formation)
	var row_count = clamp(1 + int(score / rows_per_score_step), 1, max_rows)
	formation.build(row_count)

func _on_alien_killed() -> void:
	killed_alien(1)
	livestext.text = str(player.lives)

func _on_player_died() -> void:
	_on_game_over()

func _on_game_over() -> void:
	if game_over:
		return
	game_over = true
	gameovertext.visible = true
	spawn_timer.stop()

func start_match() -> void:
	game_over = false
	score = 0
	scoretext.text = str(score)
	gameovertext.visible = false
	for child in $aliens.get_children():
		child.queue_free()
	player.global_position = player_start_position
	player.reset(starting_lives)
	livestext.text = str(player.lives)
	active = true
	spawn_wave()
	spawn_timer.start()

func end_match() -> void:
	active = false
	game_over = false
	spawn_timer.stop()
	for child in $aliens.get_children():
		child.queue_free()
	gameovertext.visible = false
