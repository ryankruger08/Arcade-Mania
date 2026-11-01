extends Node

signal changed
signal audio_changed

const SAVE_PATH = "user://settings.cfg"
const PRESETS = {
	"Potato": {"shadows": 0, "effects": 0, "sdfgi": false, "render_scale": 0.5, "cabinet_scale": 0.25, "idle_fps": 5, "distance": 24.0},
	"Low": {"shadows": 0, "effects": 1, "sdfgi": false, "render_scale": 0.7, "cabinet_scale": 0.5, "idle_fps": 10, "distance": 40.0},
	"Medium": {"shadows": 1, "effects": 2, "sdfgi": false, "render_scale": 0.85, "cabinet_scale": 0.75, "idle_fps": 15, "distance": 64.0},
	"High": {"shadows": 2, "effects": 3, "sdfgi": true, "render_scale": 1.0, "cabinet_scale": 1.0, "idle_fps": 30, "distance": 96.0}
}

var preset = "Medium"
var graphics: Dictionary = PRESETS["Medium"].duplicate()
var resolution = Vector2i(1920, 1080)
var fullscreen = true
var vsync = true
var machines: Array = []
var tick = 0.0
var audio_volumes = {"Master": 1.0, "Games": 1.0, "Racing": 1.0}

func native_resolution() -> Vector2i:
	var size = DisplayServer.screen_get_size(get_window().current_screen)
	return size if size.x > 0 and size.y > 0 else Vector2i(1920, 1080)

func get_resolutions() -> Array[Vector2i]:
	return resolutions_for(native_resolution())

func resolutions_for(native: Vector2i) -> Array[Vector2i]:
	var sizes: Array[Vector2i] = []
	for height in [360, 480, 540, 600, 720, 768, 800, 900, 1000, 1080, 1200, 1440, 1600, 1800, 2000, 2160, 2880, 4320]:
		if height >= native.y: continue
		var width = maxi(2, roundi(float(native.x) * height / native.y / 2) * 2)
		var size = Vector2i(mini(width, native.x), height)
		if size not in sizes: sizes.append(size)
	sizes.append(native)
	return sizes

func _ready() -> void:
	resolution = native_resolution()
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		preset = config.get_value("graphics", "preset", "Medium")
		if not PRESETS.has(preset) and preset != "Custom": preset = "Medium"
		for key in graphics:
			graphics[key] = config.get_value("graphics", key, graphics[key])
		if PRESETS.has(preset): graphics = PRESETS[preset].duplicate()
		else: graphics.distance = maxf(24.0, graphics.distance)
		resolution = config.get_value("display", "resolution", resolution)
		fullscreen = config.get_value("display", "fullscreen", true)
		vsync = config.get_value("display", "vsync", true)
		for channel in audio_volumes:
			audio_volumes[channel] = clampf(config.get_value("audio", channel, 1.0), 0, 1)
	process_mode = Node.PROCESS_MODE_ALWAYS
	apply_display()

func save() -> void:
	var config = ConfigFile.new()
	config.set_value("graphics", "preset", preset)
	for key in graphics: config.set_value("graphics", key, graphics[key])
	config.set_value("display", "resolution", resolution)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "vsync", vsync)
	for channel in audio_volumes: config.set_value("audio", channel, audio_volumes[channel])
	config.save(SAVE_PATH)

func set_audio_volume(channel: String, value: float) -> void:
	audio_volumes[channel] = clampf(value, 0, 1)
	audio_changed.emit()
	save()

func set_preset(value: String) -> void:
	if not PRESETS.has(value): return
	preset = value
	graphics = PRESETS[value].duplicate()
	apply_graphics()

func set_custom(key: String, value) -> void:
	preset = "Custom"
	graphics[key] = value
	apply_graphics()

func apply_display() -> void:
	var window = get_window()
	var choices = get_resolutions()
	if resolution not in choices: resolution = native_resolution()
	var was_fullscreen = window.mode == Window.MODE_FULLSCREEN
	window.mode = Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
	if not fullscreen and was_fullscreen:
		window.size = Vector2i(Vector2(native_resolution()) * 0.8)
	window.content_scale_size = resolution
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	window.content_scale_factor = 1.0
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	var menu = get_tree().root.get_node_or_null("Menu")
	if menu: menu.resize_ui()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)

func apply_graphics() -> void:
	get_viewport().scaling_3d_scale = graphics.render_scale
	get_viewport().msaa_3d = Viewport.MSAA_4X if graphics.effects == 3 else (Viewport.MSAA_2X if graphics.effects == 2 else Viewport.MSAA_DISABLED)
	var scene = get_tree().current_scene
	if scene: apply_scene(scene)
	for machine in machines:
		if is_instance_valid(machine) and machine.is_inside_tree(): configure_machine(machine)
	save()
	changed.emit()

func apply_scene(scene: Node) -> void:
	for node in scene.find_children("*", "", true, false):
		if node is WorldEnvironment and node.environment:
			var env = node.environment
			if not env.has_meta("original_effects"):
				env.set_meta("original_effects", [env.sdfgi_enabled, env.ssil_enabled, env.ssao_enabled, env.glow_enabled])
			var original = env.get_meta("original_effects")
			env.sdfgi_enabled = original[0] and graphics.sdfgi
			env.ssil_enabled = original[1] and graphics.effects == 3
			env.ssao_enabled = original[2] and graphics.effects >= 2
			env.glow_enabled = original[3] and graphics.effects >= 1
			env.ssr_enabled = false
			env.volumetric_fog_enabled = false
		elif node is Light3D:
			if not node.has_meta("original_shadows"): node.set_meta("original_shadows", node.shadow_enabled)
			node.shadow_enabled = node.get_meta("original_shadows") and (graphics.shadows == 2 or node is DirectionalLight3D)
			if node is DirectionalLight3D:
				if not node.has_meta("original_shadow_distance"): node.set_meta("original_shadow_distance", node.directional_shadow_max_distance)
				node.directional_shadow_max_distance = minf(node.get_meta("original_shadow_distance"), 20.0 if graphics.shadows == 0 else 40.0) if graphics.shadows < 2 else node.get_meta("original_shadow_distance")
			if not node is DirectionalLight3D:
				if not node.has_meta("original_energy"): node.set_meta("original_energy", node.light_energy)
				node.light_energy = node.get_meta("original_energy") * (0.6 if graphics.shadows < 2 else 1.0)
				node.distance_fade_enabled = true
				node.distance_fade_begin = graphics.distance
				node.distance_fade_length = 4.0
		elif node is ReflectionProbe:
			node.visible = graphics.effects >= 2
		elif node is MeshInstance3D:
			if not node.has_meta("original_cast_shadow"): node.set_meta("original_cast_shadow", node.cast_shadow)
			node.cast_shadow = node.get_meta("original_cast_shadow")
			node.visibility_range_end = 0.0

func register_machine(machine: Node) -> void:
	if not is_instance_valid(machine) or not machine.is_inside_tree(): return
	if machine not in machines: machines.append(machine)
	configure_machine(machine)

func configure_machine(machine: Node) -> void:
	var viewport = machine.get_parent().get_node("SubViewport")
	viewport.size_2d_override = Vector2i(1920, 1080)
	viewport.size_2d_override_stretch = true
	viewport.size = Vector2i(Vector2(1920, 1080) * float(graphics.cabinet_scale))
	viewport.scaling_3d_scale = graphics.render_scale
	viewport.msaa_3d = Viewport.MSAA_2X if graphics.effects >= 2 else Viewport.MSAA_DISABLED
	wake_machine(machine)

func wake_machine(machine: Node) -> void:
	var viewport = machine.get_parent().get_node("SubViewport")
	if not machine.get_parent().is_visible_in_tree():
		viewport.get_child(0).process_mode = Node.PROCESS_MODE_DISABLED
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	viewport.get_child(0).process_mode = Node.PROCESS_MODE_INHERIT if machine.is_unlocked() else Node.PROCESS_MODE_DISABLED
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if machine.playing else SubViewport.UPDATE_ONCE

func _process(delta: float) -> void:
	if get_tree().paused: return
	tick += delta
	if tick < 1.0 / float(graphics.idle_fps): return
	tick = 0
	var camera = get_viewport().get_camera_3d()
	for i in range(machines.size() - 1, -1, -1):
		var machine = machines[i]
		if not is_instance_valid(machine) or not machine.is_inside_tree():
			machines.remove_at(i)
			continue
		var viewport = machine.get_parent().get_node("SubViewport")
		if not machine.is_unlocked() or not machine.get_parent().is_visible_in_tree():
			viewport.get_child(0).process_mode = Node.PROCESS_MODE_DISABLED
			viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			continue
		var position = machine.get_parent().global_position + Vector3.UP
		var nearby = machine.playing or not camera or camera.global_position.distance_to(position) < graphics.distance
		var visible = nearby and (not camera or camera.is_position_in_frustum(position))
		viewport.get_child(0).process_mode = Node.PROCESS_MODE_INHERIT if machine.playing or visible else Node.PROCESS_MODE_DISABLED
		if machine.playing:
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		elif visible:
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		else:
			viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
