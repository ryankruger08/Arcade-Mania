extends Node2D

@export var scoretext: Label
@export var livestext: Label
@export var gameovertext: Label
@export var highscoretext: Label
@export var wavetext: Label
@export var player: CharacterBody2D
@export var formation_scene: PackedScene
@export var aliens_container: Node2D
@export var bullet_container: Node2D
@export var ufo_container: Node2D
@export var ufo_scene: PackedScene
@export var background_anim: AnimationPlayer
@export var game_over_zone: Area2D
@export var machine_manager: Node
@export var spawn_interval: float = 8.0
@export var max_rows: int = 4
@export var max_concurrent_formations: int = 1
@export var starting_lives: int = 3
@export var game_over_delay: float = 4.0
@export var high_score_bonus_multiplier: float = 1.0
@export var base_formation_speed: float = 120.0
@export var speed_per_score: float = 0.05
@export var base_shoot_interval: float = 1.5
@export var min_shoot_interval: float = 0.4
@export var shoot_interval_reduction_per_score: float = 0.002
@export var ufo_y: float = 40.0
@export var ufo_min_interval: float = 15.0
@export var ufo_max_interval: float = 30.0
var score = 0
var high_score = 0
var mode: String = "attract"
var wave_number: int = 0
var current_rows: int = 1
var zone_triggered: bool = false
var spawn_timer: Timer
var game_over_timer: Timer
var ufo_timer: Timer
var player_start_position: Vector2
var save_path = "user://highscore.save"

func _ready() -> void:
	if not player:
		player = get_node_or_null("spaceship")
	if not aliens_container:
		aliens_container = get_node_or_null("aliens")
	if not background_anim:
		background_anim = get_node_or_null("background_anim/AnimationPlayer")
	if not scoretext:
		scoretext = get_node_or_null("in_game_ui/RichTextLabel")
	if not scoretext:
		push_warning("scoretext export is not assigned and fallback path did not find a node")
	if not game_over_zone:
		push_warning("game_over_zone export is not assigned, alien-reaches-bottom will never trigger")
	if background_anim:
		background_anim.play("background")
	if gameovertext:
		gameovertext.visible = false
	if player:
		player_start_position = player.global_position
		player.died.connect(_on_player_died)
		if bullet_container:
			player.bullet_container = bullet_container
	if game_over_zone:
		game_over_zone.body_entered.connect(_on_game_over_zone_entered)
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.one_shot = false
	spawn_timer.timeout.connect(spawn_wave)
	add_child(spawn_timer)
	game_over_timer = Timer.new()
	game_over_timer.one_shot = true
	game_over_timer.wait_time = game_over_delay
	game_over_timer.timeout.connect(_on_game_over_timeout)
	add_child(game_over_timer)
	ufo_timer = Timer.new()
	ufo_timer.one_shot = true
	add_child(ufo_timer)
	ufo_timer.timeout.connect(_on_ufo_timer)
	_schedule_ufo()
	_load_high_score()
	start_attract()


func _process(delta: float) -> void:
	if mode != "playing":
		return
	if Input.is_action_just_pressed("remove_credit"):
		spawn_wave()

func killed_alien(amount):
	if mode != "playing":
		return
	score += amount
	if scoretext:
		scoretext.text = str(score)
	

func spawn_wave() -> void:
	if mode == "game_over":
		return
	if not formation_scene or not aliens_container:
		return
	if aliens_container.get_child_count() >= max_concurrent_formations:
		return
	var formation = formation_scene.instantiate()
	formation.alien_killed.connect(_on_alien_killed)
	if bullet_container:
		formation.bullet_container = bullet_container
	aliens_container.add_child(formation)
	var row_count = clamp(current_rows, 1, max_rows)
	formation.base_speed = base_formation_speed + score * speed_per_score
	formation.shoot_interval = max(min_shoot_interval, base_shoot_interval - score * shoot_interval_reduction_per_score)
	formation.build(row_count)
	current_rows = min(current_rows + 1, max_rows)
	zone_triggered = false
	if mode == "playing":
		wave_number += 1
		if wavetext:
			wavetext.text = "WAVE " + str(wave_number)

func _on_alien_killed(points) -> void:
	killed_alien(points)
	if mode == "playing" and livestext and player:
		livestext.text = str(player.lives)

func _on_player_died() -> void:
	if mode == "playing":
		_on_game_over()

func _on_game_over_zone_entered(body: Node2D) -> void:
	if not body.is_in_group("alien"):
		return
	if zone_triggered:
		return
	zone_triggered = true
	if mode == "playing":
		_on_game_over()
	elif mode == "attract":
		start_attract()

func _on_game_over() -> void:
	if mode == "game_over":
		return
	var was_playing = mode == "playing"
	mode = "game_over"
	if was_playing and score > high_score:
		var amount_over = score - high_score
		high_score = score
		_save_high_score()
		if machine_manager:
			var bonus_credits = int(amount_over * high_score_bonus_multiplier)
			if bonus_credits > 0:
				machine_manager.add_credits(bonus_credits)
	if aliens_container:
		for child in aliens_container.get_children():
			child.queue_free()
	if was_playing and machine_manager and machine_manager.spend_credit():
		_continue_match()
		return
	if highscoretext:
		highscoretext.text = str(high_score)
	if gameovertext:
		gameovertext.visible = true
	if player:
		player.set_physics_process(false)
		player.set_demo_mode(false)
		player.global_position = player_start_position
		player.visible = true
	if was_playing and machine_manager:
		machine_manager.exit_play_mode()
	spawn_timer.stop()
	game_over_timer.start()

func _continue_match() -> void:
	mode = "playing"
	current_rows = 1
	if player:
		player.global_position = player_start_position
		player.reset(starting_lives)
		player.set_demo_mode(false)
	if livestext and player:
		livestext.text = str(player.lives)
	spawn_wave()

func _on_game_over_timeout() -> void:
	start_attract()

func start_attract() -> void:
	mode = "attract"
	score = 0
	wave_number = 0
	current_rows = 1
	if scoretext:
		scoretext.text = str(score)
		scoretext.visible = false
	if gameovertext:
		gameovertext.visible = false
	if highscoretext:
		highscoretext.text = str(high_score)
		highscoretext.visible = true
	if wavetext:
		wavetext.text = ""
	if aliens_container:
		for child in aliens_container.get_children():
			child.queue_free()
	if player:
		player.global_position = player_start_position
		player.reset(starting_lives)
		player.set_demo_mode(true)
	if livestext:
		livestext.text = ""
	get_tree().call_group("shield", "reset")
	spawn_wave()
	spawn_timer.start()

func start_match() -> void:
	mode = "playing"
	score = 0
	wave_number = 0
	current_rows = 1
	if scoretext:
		scoretext.text = str(score)
		scoretext.visible = true
	if gameovertext:
		gameovertext.visible = false
	if highscoretext:
		highscoretext.visible = false
	game_over_timer.stop()
	if aliens_container:
		for child in aliens_container.get_children():
			child.queue_free()
	if player:
		player.global_position = player_start_position
		player.reset(starting_lives)
		player.set_demo_mode(false)
	if livestext:
		livestext.text = str(player.lives)
	get_tree().call_group("shield", "reset")
	spawn_wave()
	spawn_timer.start()

func end_match() -> void:
	game_over_timer.stop()
	start_attract()

func _schedule_ufo() -> void:
	ufo_timer.wait_time = randf_range(ufo_min_interval, ufo_max_interval)
	ufo_timer.start()

func _on_ufo_timer() -> void:
	if mode == "playing" and ufo_scene:
		_spawn_ufo()
	_schedule_ufo()

func _spawn_ufo() -> void:
	var ufo = ufo_scene.instantiate()
	ufo.died.connect(_on_ufo_killed)
	var container = ufo_container if ufo_container else self
	container.add_child(ufo)
	var screen_width = get_viewport_rect().size.x
	var dir = 1 if randi() % 2 == 0 else -1
	var start_x = -50.0 if dir == 1 else screen_width + 50.0
	ufo.launch(start_x, ufo_y, dir)

func _on_ufo_killed(points) -> void:
	killed_alien(points)

func _load_high_score() -> void:
	if FileAccess.file_exists(save_path):
		var file = FileAccess.open(save_path, FileAccess.READ)
		high_score = file.get_var()
		file.close()

func _save_high_score() -> void:
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	file.store_var(high_score)
	file.close()
