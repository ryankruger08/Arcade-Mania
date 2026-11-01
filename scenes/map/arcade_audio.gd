class_name ArcadeAudio
extends Node

@export_group("Sound")
@export var enabled = true
@export var cabinet_sounds = true
@export var game_sounds = true
@export var racing_sounds = true
@export var use_default_sounds = true
@export_range(-40, 0) var volume_db = -12.0
@export_range(-40, 0) var racing_volume_db = -20.0

@export_group("Cabinets")
@export var coin: AudioStream
@export var refund: AudioStream
@export var start: AudioStream
@export var exit: AudioStream

@export_group("Games")
@export var shoot: AudioStream
@export var bounce: AudioStream
@export var hit: AudioStream
@export var score: AudioStream
@export var game_over: AudioStream

@export_group("Racing")
@export var racing_machine: Node
@export var racing_engine: AudioStream
@export var racing_skid: AudioStream
@export var racing_lap: AudioStream

var voices: Array[AudioStreamPlayer] = []
var engine: AudioStreamPlayer
var skid: AudioStreamPlayer
var defaults = {}
var cooldowns = {}

static func play(source: Node, sound: String) -> void:
	if not source.is_inside_tree(): return
	var audio = source.get_tree().get_first_node_in_group("arcade_audio")
	if not audio: return
	var node = source
	var machine = null
	while node:
		if node.has_node("coinslot"):
			machine = node.get_node("coinslot")
			break
		node = node.get_parent()
	if sound not in ["coin", "refund", "start", "exit"] and (not machine or not machine.playing): return
	audio.play_sound(sound)

func _ready() -> void:
	add_to_group("arcade_audio")
	for i in 8:
		var voice = AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	engine = AudioStreamPlayer.new()
	skid = AudioStreamPlayer.new()
	add_child(engine)
	add_child(skid)
	Settings.audio_changed.connect(apply_volumes)
	if use_default_sounds:
		var frequencies = {"coin": 1100, "refund": 450, "start": 700, "exit": 300, "shoot": 1400, "bounce": 500, "hit": 130, "score": 900, "game_over": 180}
		for sound in frequencies:
			defaults[sound] = tone(frequencies[sound], 0.12 if sound != "game_over" else 0.4)
		defaults["racing_engine"] = tone(80, 0.2, true)
		defaults["racing_skid"] = tone(100, 0.2, true, true)
		var lap = tone(880, 0.12)
		lap.data += tone(1320, 0.18).data
		defaults["racing_lap"] = lap

func volume_for(racing: bool) -> float:
	return Settings.audio_volumes.Master * Settings.audio_volumes["Racing" if racing else "Games"]

func apply_volumes() -> void:
	for voice in voices:
		var racing = voice.get_meta("racing", false)
		var level = volume_for(racing)
		voice.volume_db = (racing_volume_db if racing else volume_db) + linear_to_db(maxf(level, 0.00001))
		if level == 0: voice.stop()
	if volume_for(true) == 0:
		engine.stop()
		skid.stop()

func tone(frequency: float, duration: float, loop = false, noise = false) -> AudioStreamWAV:
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 22050
	var samples = PackedByteArray()
	var count = int(duration * stream.mix_rate)
	samples.resize(count)
	var rng = RandomNumberGenerator.new()
	rng.seed = 17
	for i in count:
		var t = float(i) / stream.mix_rate
		var wave = rng.randf_range(-1, 1) if noise else sin(TAU * frequency * t) + sin(TAU * frequency * 2 * t) * 0.25
		var envelope = 1.0 if loop else minf(t * 200, 1.0) * pow(1.0 - float(i) / count, 2)
		samples[i] = int(clampf(wave * envelope * 70, -127, 127)) & 255
	stream.data = samples
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = count
	return stream

func sound_stream(sound: String) -> AudioStream:
	var custom = get(sound)
	return custom if custom else (defaults.get(sound) if use_default_sounds else null)

func play_sound(sound: String) -> void:
	if not enabled or get_tree().paused: return
	if sound in ["coin", "refund", "start", "exit"]:
		if not cabinet_sounds: return
	elif sound.begins_with("racing_"):
		if not racing_sounds: return
	elif not game_sounds: return
	var racing = sound.begins_with("racing_")
	if volume_for(racing) == 0: return
	var now = Time.get_ticks_msec()
	if now - cooldowns.get(sound, -1000) < 50: return
	var stream = sound_stream(sound)
	if not stream: return
	cooldowns[sound] = now
	for voice in voices:
		if not voice.playing:
			voice.stream = stream
			voice.set_meta("racing", racing)
			voice.volume_db = (racing_volume_db if racing else volume_db) + linear_to_db(volume_for(racing))
			voice.play()
			return

func _process(_delta: float) -> void:
	var active = enabled and racing_sounds and volume_for(true) > 0 and is_instance_valid(racing_machine) and racing_machine.playing
	var race = racing_machine.gamemanager if active else null
	active = active and race.mode == "playing"
	if not active:
		engine.stop()
		skid.stop()
		return
	var kart = race.player_kart
	var speed = absf(kart.current_speed) / kart.max_speed
	engine.volume_db = racing_volume_db + linear_to_db(volume_for(true))
	engine.pitch_scale = 0.65 + speed * 1.8
	var stream = sound_stream("racing_engine")
	if stream and not engine.playing:
		engine.stream = stream
		engine.play()
	var skidding = Input.is_action_pressed("game_secondary") and speed > 0.2
	skid.volume_db = engine.volume_db - 6
	stream = sound_stream("racing_skid")
	if skidding and stream and not skid.playing:
		skid.stream = stream
		skid.play()
	elif not skidding: skid.stop()
