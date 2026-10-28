extends Node3D

@export_group("Game Elements")
@export var player_kart: CharacterBody3D
@export var karts: Node3D
@export var track_path: Path3D
@export var camera: Camera3D

@export_group("Arcade UI")
@export var lap_label: Label
@export var time_label: Label
@export var position_label: Label
@export var countdown_label: Label
@export var gameover_label: Label
@export var besttime_label: Label

@export_group("Machine")
@export var machine_manager: Node
@export var total_laps: int = 3
@export var time_limit: float = 180.0
@export var game_over_delay: float = 4.0

var mode: String = "attract"
var race_time: float = 0.0
var best_time: float = 0.0
var countdown: float = 0.0
var racers: Dictionary = {}
var checkpoints: Array = []
var game_over_timer: Timer
var initialized: bool = false

const SAVE_PATH = "user://racing_best_time.cfg"

func _ready() -> void:
	load_best_time()
	game_over_timer = Timer.new()
	game_over_timer.one_shot = true
	game_over_timer.wait_time = game_over_delay
	game_over_timer.timeout.connect(_on_game_over_timeout)
	add_child(game_over_timer)
	for i in track_path.curve.point_count:
		checkpoints.append(track_path.curve.get_closest_offset(track_path.curve.get_point_position(i)))
	for kart in karts.get_children():
		kart.race = self
		kart.get_node("KartAI").track_path = track_path
	await get_tree().physics_frame
	initialized = true
	if machine_manager:
		start_attract()
	else:
		start_match()

func reset() -> void:
	race_time = 0
	racers.clear()
	var index = 0
	for kart in karts.get_children():
		var lane = [-2.5, 0.0, 2.5][index]
		kart.get_node("KartAI").lane_offset = lane
		racers[kart] = {"lap": 0, "next": 1, "last": 0, "done": false, "finish_time": 0.0, "stuck": 0.0}
		_place_kart(kart, index * 4.5, lane)
		kart.ai_controlled = kart != player_kart or mode == "attract"
		kart.playing = mode == "attract"
		index += 1
	camera.global_position = player_kart.global_position + player_kart.global_transform.basis.z * 9 + Vector3.UP * 5
	camera.look_at(player_kart.global_position + Vector3.UP)
	update_labels()

func start_attract() -> void:
	mode = "attract"
	reset()
	if lap_label: lap_label.visible = false
	if time_label: time_label.visible = false
	if position_label: position_label.visible = false
	if countdown_label: countdown_label.visible = false
	if gameover_label: gameover_label.visible = false
	if besttime_label:
		besttime_label.text = "BEST " + format_time(best_time) if best_time > 0 else "BEST --:--"
		besttime_label.visible = true

func start_match() -> void:
	if not initialized:
		return
	game_over_timer.stop()
	mode = "ready"
	reset()
	countdown = 3.0
	if lap_label: lap_label.visible = true
	if time_label: time_label.visible = true
	if position_label: position_label.visible = true
	if countdown_label: countdown_label.visible = true
	if gameover_label: gameover_label.visible = false
	if besttime_label: besttime_label.visible = false
	if not machine_manager: $UI/Control/credit.visible = false

func end_match() -> void:
	game_over_timer.stop()
	if machine_manager:
		machine_manager.exit_play_mode()
	start_attract()

func _physics_process(delta: float) -> void:
	if not initialized:
		return
	if not machine_manager and mode == "attract" and Input.is_action_just_pressed("ui_accept"):
		start_match()
	if mode == "ready":
		countdown -= delta
		if countdown_label: countdown_label.text = str(max(1, int(ceil(countdown))))
		if countdown <= 0:
			mode = "playing"
			for kart in karts.get_children(): kart.playing = true
			if countdown_label: countdown_label.visible = false
	elif mode == "playing" or mode == "attract":
		race_time += delta
		if mode == "playing" and race_time >= time_limit:
			finish_race(true)
		elif mode == "attract" and race_time > 90:
			start_attract()
	var behind = player_kart.global_transform.basis.z
	var camera_position = player_kart.global_position + behind * 9 + Vector3.UP * 5
	camera.global_position = camera.global_position.lerp(camera_position, min(delta * 7, 1.0))
	camera.look_at(player_kart.global_position - behind * 3 + Vector3.UP)
	update_labels()

func _place_kart(kart: CharacterBody3D, progress: float, lane: float) -> void:
	var length = track_path.curve.get_baked_length()
	var point = track_path.curve.sample_baked(fposmod(progress, length))
	var ahead = track_path.curve.sample_baked(fposmod(progress + 1, length))
	var direction = (ahead - point).normalized()
	point = track_path.to_global(point + direction.cross(Vector3.UP).normalized() * lane)
	var query = PhysicsRayQueryParameters3D.create(point + Vector3.UP * 10, point - Vector3.UP * 10, 1)
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): point.y = hit.position.y
	point.y += 0.55
	kart.reset(point, atan2(-direction.x, -direction.z))

func reset_kart(kart: CharacterBody3D) -> void:
	if not racers.has(kart):
		return
	var state = racers[kart]
	_place_kart(kart, checkpoints[state.last], kart.get_node("KartAI").lane_offset)
	state.stuck = 0

func check_kart(kart: CharacterBody3D, delta: float) -> void:
	if not racers.has(kart) or mode == "game_over":
		return
	var state = racers[kart]
	var local_position = track_path.to_local(kart.global_position)
	local_position.y = 0
	var progress = track_path.curve.get_closest_offset(local_position)
	var closest = track_path.to_global(track_path.curve.sample_baked(progress))
	var distance = Vector2(kart.global_position.x - closest.x, kart.global_position.z - closest.z).length()
	if kart.global_position.y < -8 or distance > 17:
		reset_kart(kart)
		return
	if kart.ai_controlled and Vector2(kart.velocity.x, kart.velocity.z).length() < 1.0:
		state.stuck += delta
		if state.stuck > 3.0:
			reset_kart(kart)
	else:
		state.stuck = 0
	if state.done:
		return
	var next = state.next
	var target = track_path.to_global(track_path.curve.get_point_position(next))
	var to_target = target - kart.global_position
	to_target.y = 0
	var tangent = track_path.curve.sample_baked(fposmod(checkpoints[next] + 1, track_path.curve.get_baked_length())) - track_path.curve.get_point_position(next)
	if to_target.length() < 9.0 and kart.velocity.dot(tangent) > 0:
		state.last = next
		state.next = (next + 1) % checkpoints.size()
		if next == 0:
			state.lap += 1
			if state.lap >= total_laps:
				state.done = true
				state.finish_time = race_time
				if kart == player_kart and mode == "playing":
					finish_race(false)

func get_race_position() -> int:
	if not racers.has(player_kart): return 1
	var position = 1
	var player_state = racers[player_kart]
	var player_progress = get_progress(player_kart)
	for kart in karts.get_children():
		if kart == player_kart: continue
		var state = racers[kart]
		if state.done:
			if not player_state.done or state.finish_time < player_state.finish_time: position += 1
		elif not player_state.done and get_progress(kart) > player_progress:
			position += 1
	return position

func get_progress(kart: CharacterBody3D) -> float:
	var point = track_path.to_local(kart.global_position)
	point.y = 0
	var progress = track_path.curve.get_closest_offset(point)
	var state = racers[kart]
	# Use the next checkpoint to distinguish finishing a lap from driving backwards.
	if state.next == 0 and progress < checkpoints[1]: progress = track_path.curve.get_baked_length()
	if state.next == 1 and progress > checkpoints[checkpoints.size() - 1]: progress = 0
	return state.lap * track_path.curve.get_baked_length() + progress

func update_labels() -> void:
	if not racers.has(player_kart): return
	if lap_label: lap_label.text = "LAP " + str(min(racers[player_kart].lap + 1, total_laps)) + "/" + str(total_laps)
	if time_label: time_label.text = format_time(race_time)
	if position_label: position_label.text = str(get_race_position()) + "/" + str(karts.get_child_count())

func finish_race(timed_out: bool) -> void:
	if mode != "playing": return
	mode = "game_over"
	for kart in karts.get_children(): kart.playing = false
	if not timed_out and (best_time == 0 or race_time < best_time):
		best_time = race_time
		save_best_time()
	if machine_manager and not timed_out and get_race_position() == 1:
		machine_manager.add_wallet_bonus(1)
	if gameover_label:
		gameover_label.text = "TIME UP" if timed_out else ["1ST PLACE", "2ND PLACE", "3RD PLACE"][get_race_position() - 1]
		gameover_label.visible = true
	game_over_timer.start()

func _on_game_over_timeout() -> void:
	if machine_manager: machine_manager.exit_play_mode()
	start_attract()

func format_time(seconds: float) -> String:
	return "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]

func save_best_time() -> void:
	var config = ConfigFile.new()
	config.set_value("Leaderboard", "best_time", best_time)
	config.save(SAVE_PATH)

func load_best_time() -> void:
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		best_time = config.get_value("Leaderboard", "best_time", 0.0)
