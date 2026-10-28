extends Node2D

@export var machine_manager: Node
const FIELD = Rect2(370, 0, 1180, 1080)
const SAVE_PATH = "user://asteroids_highscore.cfg"
const SHIP_RADIUS = 13.0

var mode: String = "attract"
var score: int = 0
var high_score: int = 0
var lives: int = 3
var wave: int = 1
var ship_position = FIELD.size / 2
var ship_velocity = Vector2.ZERO
var ship_angle: float = -PI / 2
var invulnerability: float = 0.0
var respawn_time: float = 0.0
var shot_cooldown: float = 0.0
var transition_time: float = 0.0
var wave_delay: float = 0.0
var ufo_time: float = 15.0
var ufo: Dictionary = {}
var rocks: Array = []
var bullets: Array = []
var particles: Array = []
var elapsed: float = 0.0
var thrusting: bool = false
var rng = RandomNumberGenerator.new()
var font: Font = preload("res://Resources/font.ttf")

func _ready() -> void:
	rng.randomize()
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		high_score = int(config.get_value("Leaderboard", "top_score", 0))
	start_attract()

func _reset_run() -> void:
	score = 0
	lives = 3
	wave = 1
	rocks.clear()
	bullets.clear()
	particles.clear()
	ufo.clear()
	wave_delay = 0.0
	ufo_time = 15.0
	shot_cooldown = 0.0
	respawn_time = 0.0
	_spawn_ship()
	_spawn_wave()

func start_attract() -> void:
	mode = "attract"
	_reset_run()
	queue_redraw()

func start_match() -> void:
	_reset_run()
	mode = "ready"
	transition_time = 2.0
	queue_redraw()

func end_match() -> void:
	if machine_manager:
		machine_manager.exit_play_mode()
	start_attract()

func _physics_process(delta: float) -> void:
	elapsed += delta
	_step_particles(delta)
	if not machine_manager and Input.is_action_just_pressed("ui_accept") and mode == "attract":
		start_match()
	if not machine_manager and Input.is_action_just_pressed("play") and mode != "attract":
		end_match()
	if mode == "ready":
		transition_time -= delta
		if transition_time <= 0.0:
			mode = "playing"
	elif mode == "game_over":
		transition_time -= delta
		if transition_time <= 0.0:
			end_match()
	else:
		_step_game(delta)
	if not machine_manager:
		$Credit.visible = mode == "attract"
		$Credit.text = "INSERT COIN"
	queue_redraw()

func _step_game(delta: float) -> void:
	invulnerability = maxf(0.0, invulnerability - delta)
	shot_cooldown = maxf(0.0, shot_cooldown - delta)
	if respawn_time > 0.0:
		respawn_time -= delta
		if respawn_time <= 0.0:
			_spawn_ship()
	else:
		_step_ship(delta)
	for rock in rocks:
		rock.position = _wrap(rock.position + rock.velocity * delta)
		rock.angle += rock.spin * delta
	_step_ufo(delta)
	_step_bullets(delta)
	if respawn_time <= 0.0 and invulnerability <= 0.0 and mode != "game_over":
		for rock in rocks:
			if _offset(ship_position, rock.position).length() < rock.radius + SHIP_RADIUS:
				_hit_ship()
				break
		if not ufo.is_empty() and _offset(ship_position, ufo.position).length() < 40:
			_hit_ship()
	if rocks.is_empty():
		wave_delay += delta
		if wave_delay >= 1.5:
			wave += 1
			_spawn_wave()
	else:
		wave_delay = 0.0

func _step_ship(delta: float) -> void:
	var turn = Input.get_axis("ui_left", "ui_right")
	if turn == 0.0:
		turn = Input.get_axis("move_left", "move_right")
	thrusting = Input.is_action_pressed("ui_up") or Input.is_action_pressed("move_forward")
	var shooting = Input.is_action_pressed("shoot")
	if mode == "attract":
		var target = Vector2.RIGHT.rotated(elapsed * 0.3)
		if not rocks.is_empty():
			target = _offset(ship_position, rocks[0].position)
		var difference = angle_difference(ship_angle, target.angle())
		turn = clampf(difference * 3.0, -1.0, 1.0)
		thrusting = sin(elapsed * 1.4) > 0.0
		shooting = absf(difference) < 0.3
	ship_angle += turn * 4.1 * delta
	if thrusting:
		ship_velocity += Vector2.RIGHT.rotated(ship_angle) * 270.0 * delta
	ship_velocity = ship_velocity.limit_length(420.0) * exp(-0.15 * delta)
	ship_position = _wrap(ship_position + ship_velocity * delta)
	if shooting and shot_cooldown <= 0.0:
		_fire()

func _fire() -> void:
	var forward = Vector2.RIGHT.rotated(ship_angle)
	bullets.append({"position": _wrap(ship_position + forward * 23), "velocity": forward * 760 + ship_velocity, "life": 1.15, "enemy": false})
	shot_cooldown = 0.17

func _wrap(point: Vector2) -> Vector2:
	return Vector2(fposmod(point.x, FIELD.size.x), fposmod(point.y, FIELD.size.y))

func _offset(from: Vector2, to: Vector2) -> Vector2:
	var difference = to - from
	return Vector2(wrapf(difference.x, -FIELD.size.x / 2, FIELD.size.x / 2), wrapf(difference.y, -FIELD.size.y / 2, FIELD.size.y / 2))

func _spawn_ship() -> void:
	# Choose the safest of several points instead of spawning inside a rock.
	var best_clearance: float = -1.0
	for i in 12:
		var candidate = FIELD.size / 2 if i == 0 else Vector2(rng.randf_range(80, FIELD.size.x - 80), rng.randf_range(80, FIELD.size.y - 80))
		var clearance: float = 10000.0
		for rock in rocks:
			clearance = minf(clearance, _offset(candidate, rock.position).length() - rock.radius)
		if clearance > best_clearance:
			best_clearance = clearance
			ship_position = candidate
	ship_velocity = Vector2.ZERO
	ship_angle = -PI / 2
	invulnerability = 2.5
	respawn_time = 0.0

func _spawn_wave() -> void:
	wave_delay = 0.0
	for i in mini(3 + wave, 11):
		var point = Vector2(rng.randf_range(0, FIELD.size.x), rng.randf_range(0, FIELD.size.y))
		if _offset(ship_position, point).length() < 190:
			point = _wrap(ship_position + Vector2(400, 240).rotated(rng.randf() * TAU))
		_add_rock(point, 3)

func _add_rock(point: Vector2, size: int) -> void:
	var radius = [0.0, 17.0, 32.0, 57.0][size]
	var outline = PackedVector2Array()
	for i in 11:
		outline.append(Vector2.RIGHT.rotated(i * TAU / 11) * radius * rng.randf_range(0.72, 1.14))
	outline.append(outline[0])
	var speed = rng.randf_range(42, 76) + (3 - size) * 32 + mini(wave, 15) * 6
	rocks.append({"position": _wrap(point), "velocity": Vector2.RIGHT.rotated(rng.randf() * TAU) * speed, "size": size, "radius": radius, "outline": outline, "angle": 0.0, "spin": rng.randf_range(-0.9, 0.9)})

func _destroy_rock(index: int) -> void:
	var rock = rocks[index]
	rocks.remove_at(index)
	_award([0, 100, 50, 20][rock.size])
	_burst(rock.position, Color.WHITE, 12)
	if rock.size > 1:
		for i in 2:
			_add_rock(rock.position, rock.size - 1)

func _award(points: int) -> void:
	if mode == "playing":
		score += points

func _segment_hits(start: Vector2, motion: Vector2, target: Vector2, radius: float) -> bool:
	var difference = _offset(start, target)
	var progress = clampf(difference.dot(motion) / maxf(motion.length_squared(), 0.001), 0.0, 1.0)
	return (difference - motion * progress).length_squared() <= radius * radius

func _step_bullets(delta: float) -> void:
	for index in range(bullets.size() - 1, -1, -1):
		var bullet = bullets[index]
		bullet.life -= delta
		if bullet.life <= 0:
			bullets.remove_at(index)
			continue
		var start: Vector2 = bullet.position
		var motion: Vector2 = bullet.velocity * delta
		bullet.position = _wrap(start + motion)
		var hit: bool = false
		if bullet.enemy:
			if respawn_time <= 0 and invulnerability <= 0 and _segment_hits(start, motion, ship_position, SHIP_RADIUS):
				_hit_ship()
				hit = true
		else:
			for rock_index in range(rocks.size() - 1, -1, -1):
				var rock = rocks[rock_index]
				if _segment_hits(start, motion, rock.position, rock.radius):
					_destroy_rock(rock_index)
					hit = true
					break
			if not hit and not ufo.is_empty() and _segment_hits(start, motion, ufo.position, 30):
				_award(250)
				_burst(ufo.position, Color.WHITE, 22)
				ufo.clear()
				hit = true
		if hit:
			bullets.remove_at(index)

func _step_ufo(delta: float) -> void:
	ufo_time -= delta
	if ufo.is_empty():
		if ufo_time <= 0:
			ufo = {"position": Vector2(25, rng.randf_range(80, FIELD.size.y - 80)), "shot": 1.0, "life": 9.0}
			ufo_time = rng.randf_range(14, 22)
		return
	ufo.position = _wrap(ufo.position + Vector2(145, sin(elapsed * 2) * 45) * delta)
	ufo.life -= delta
	ufo.shot -= delta
	if ufo.shot <= 0:
		var aim = _offset(ufo.position, ship_position).normalized().rotated(rng.randf_range(-0.15, 0.15))
		bullets.append({"position": ufo.position, "velocity": aim * 310, "life": 2.4, "enemy": true})
		ufo.shot = maxf(0.55, 1.5 - wave * 0.07)
	if ufo.life <= 0:
		ufo.clear()

func _hit_ship() -> void:
	if invulnerability > 0 or respawn_time > 0 or mode == "game_over":
		return
	_burst(ship_position, Color.WHITE, 28)
	if mode == "attract":
		_spawn_ship()
		return
	lives -= 1
	respawn_time = 1.2
	thrusting = false
	if lives <= 0:
		_finish_run()

func _finish_run() -> void:
	mode = "game_over"
	transition_time = 3.0
	if score > high_score:
		var previous = high_score
		high_score = score
		var config = ConfigFile.new()
		config.set_value("Leaderboard", "top_score", high_score)
		config.save(SAVE_PATH)
		if machine_manager:
			machine_manager.add_wallet_bonus(clampi((score - previous) / 1000, 0, 3))

func _burst(point: Vector2, color: Color, count: int) -> void:
	for i in count:
		particles.append({"position": point, "velocity": Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(40, 220), "life": rng.randf_range(0.25, 0.75), "color": color})

func _step_particles(delta: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var particle = particles[i]
		particle.life -= delta
		particle.position = _wrap(particle.position + particle.velocity * delta)
		if particle.life <= 0:
			particles.remove_at(i)

func _text(text: String, at: Vector2, size: int, color: Color = Color.WHITE) -> void:
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _center(text: String, y: float, size: int, color: Color = Color.WHITE) -> void:
	_text(text, Vector2(960 - font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2, y), size, color)

func _copies(point: Vector2, radius: float) -> Array:
	var offsets = [Vector2.ZERO]
	if point.x < radius: offsets.append(Vector2(FIELD.size.x, 0))
	if point.x > FIELD.size.x - radius: offsets.append(Vector2(-FIELD.size.x, 0))
	var result: Array = []
	for offset in offsets:
		result.append(point + offset)
		if point.y < radius: result.append(point + offset + Vector2(0, FIELD.size.y))
		if point.y > FIELD.size.y - radius: result.append(point + offset - Vector2(0, FIELD.size.y))
	return result

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), Color.BLACK)
	for rock in rocks:
		for point in _copies(rock.position, rock.radius * 1.2):
			draw_set_transform(FIELD.position + point, rock.angle)
			draw_polyline(rock.outline, Color.WHITE, 2, true)
	for bullet in bullets:
		draw_set_transform(FIELD.position + bullet.position)
		draw_circle(Vector2.ZERO, 3, Color.WHITE)
	for particle in particles:
		draw_set_transform(FIELD.position + particle.position)
		draw_line(Vector2.ZERO, -particle.velocity * 0.035, Color(1, 1, 1, minf(particle.life * 2, 1)), 2, true)
	if not ufo.is_empty():
		for point in _copies(ufo.position, 35):
			draw_set_transform(FIELD.position + point)
			draw_polyline(PackedVector2Array([Vector2(-30, 0), Vector2(-14, -12), Vector2(-8, -23), Vector2(8, -23), Vector2(14, -12), Vector2(30, 0), Vector2(15, 11), Vector2(-15, 11), Vector2(-30, 0), Vector2(30, 0)]), Color.WHITE, 2, true)
	if respawn_time <= 0 and mode != "game_over" and (invulnerability <= 0 or fmod(elapsed, 0.22) < 0.14):
		for point in _copies(ship_position, 30):
			draw_set_transform(FIELD.position + point, ship_angle)
			if thrusting:
				draw_polyline(PackedVector2Array([Vector2(-12, -7), Vector2(-26 - sin(elapsed * 50) * 7, 0), Vector2(-12, 7)]), Color.WHITE, 2, true)
			draw_polyline(PackedVector2Array([Vector2(22, 0), Vector2(-15, 14), Vector2(-9, 0), Vector2(-15, -14), Vector2(22, 0)]), Color.WHITE, 2, true)
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(0, 0, FIELD.position.x, 1080), Color.BLACK)
	draw_rect(Rect2(FIELD.end.x, 0, 1920 - FIELD.end.x, 1080), Color.BLACK)
	if mode != "attract":
		_text(str(score), Vector2(400, 75), 57)
		_text("LIVES " + str(lives), Vector2(1250, 75), 57)
	if mode == "ready":
		_center(str(maxi(1, ceili(transition_time))), 580, 100)
	elif mode == "game_over":
		_center("GAME OVER", 580, 115)
