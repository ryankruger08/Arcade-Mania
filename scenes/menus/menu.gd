extends CanvasLayer

const MAP = "res://scenes/map/map.tscn"
const SAVE_FILES = ["wallet.cfg", "settings.cfg", "controls.cfg", "arcade_highscore.cfg", "asteroids_highscore.cfg", "breakout_highscore.cfg", "frogger_highscore.cfg", "snake_highscore.cfg", "racing_best_time.cfg", "highscore.save"]
var page = "main"
var settings_from = "main"
var panel: PanelContainer
var rows: VBoxContainer
var title: Label
var progress: ProgressBar
var loading = false
var loading_scene = false
var shade: ColorRect
var resolution_label: Label
var focused_setting = "Graphics"
var root_rows: VBoxContainer
var controls_status: Label
var binding_buttons = {}
var capturing: Array = []
var capture_ready_at = 0
var last_control = ""

func resize_ui() -> void:
	var size = Vector2(Settings.resolution)
	var factor = minf(size.x / 1920.0, size.y / 1080.0)
	scale = Vector2.ONE * factor
	offset = (size - Vector2(1920, 1080) * factor) / 2
	if is_instance_valid(shade):
		shade.position = -offset / factor
		shade.size = size / factor

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	var screen = Control.new()
	screen.size = Vector2(1920, 1080)
	add_child(screen)
	shade = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.85)
	screen.add_child(shade)
	resize_ui()
	panel = PanelContainer.new()
	screen.add_child(panel)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.025, 0.025)
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 30
	style.content_margin_bottom = 30
	panel.add_theme_stylebox_override("panel", style)
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 14)
	panel.add_child(rows)
	root_rows = rows
	Controls.devices_changed.connect(_controls_devices_changed)
	var theme = Theme.new()
	theme.default_font = load("res://Resources/font.ttf")
	theme.default_font_size = 25
	panel.theme = theme
	initialize.call_deferred()

func initialize() -> void:
	var scene = get_tree().current_scene
	if scene and scene.scene_file_path != "res://scenes/menus/menu.tscn":
		Settings.apply_graphics()
		page = "game"
		hide()
	else:
		main_menu()

func clear(text: String) -> void:
	capturing = []
	for child in root_rows.get_children():
		root_rows.remove_child(child)
		child.queue_free()
	rows = root_rows
	var height = 900 if page in ["graphics", "controls"] else (430 if page in ["pause", "audio", "settings"] else 360)
	if page in ["main", "delete_saves"]: height = 480
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -350
	panel.offset_right = 350
	panel.offset_top = -height / 2.0
	panel.offset_bottom = height / 2.0
	title = Label.new()
	title.text = text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 45)
	rows.add_child(title)
	if page in ["graphics", "controls"]:
		var scroll = ScrollContainer.new()
		scroll.custom_minimum_size.y = 680
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.follow_focus = true
		root_rows.add_child(scroll)
		rows = VBoxContainer.new()
		rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rows.add_theme_constant_override("separation", 14)
		scroll.add_child(rows)
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func focus_control(control: Control) -> void:
	if is_instance_valid(control) and control.is_inside_tree(): control.grab_focus()

func button(text: String, action: Callable) -> Button:
	var item = Button.new()
	item.text = text
	item.custom_minimum_size.y = 56
	item.pressed.connect(action)
	rows.add_child(item)
	return item

func main_menu() -> void:
	page = "main"
	clear("ARCADE MANIA")
	button("Play", start_game).grab_focus()
	button("Settings", func(): settings_from = "main"; settings_menu())
	button("Delete all saves", confirm_delete_saves)
	button("Quit", quit_game)

func confirm_delete_saves() -> void:
	page = "delete_saves"
	clear("DELETE ALL SAVES?")
	var warning = Label.new()
	warning.text = "This deletes money, arcade progress, cabinet layouts, high scores, settings and saved controls.\n\nThis cannot be undone."
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.custom_minimum_size = Vector2(600, 150)
	rows.add_child(warning)
	button("Cancel", main_menu).grab_focus()
	button("Delete everything", delete_all_saves)

func delete_all_saves() -> void:
	if page != "delete_saves" or not get_tree().get_nodes_in_group("arcade_progression").is_empty(): return
	Settings.preset = "Medium"
	Settings.graphics = Settings.PRESETS.Medium.duplicate()
	Settings.resolution = Settings.native_resolution()
	Settings.fullscreen = true
	Settings.vsync = true
	Settings.audio_volumes = {"Master": 1.0, "Games": 1.0, "Racing": 1.0}
	Settings.apply_display()
	Settings.apply_graphics()
	Settings.audio_changed.emit()
	for action in Controls.defaults:
		InputMap.action_erase_events(action)
		for event in Controls.defaults[action]: InputMap.action_add_event(action, event.duplicate())
	Controls.preferred_device = "Keyboard"
	Controls.controller = false
	Controls.device_changed.emit()
	var failed = false
	for file in SAVE_FILES:
		for suffix in ["", ".bak", ".tmp"]:
			var path = "user://" + file + suffix
			if FileAccess.file_exists(path) and DirAccess.remove_absolute(path) != OK: failed = true
	if failed:
		clear("COULDN'T DELETE SAVES")
		button("Try again", delete_all_saves).grab_focus()
		button("Back", main_menu)
		return
	Wallet.reset_progress()
	main_menu()
	title.text = "SAVES DELETED"

func pause_menu() -> void:
	page = "pause"
	get_tree().paused = true
	clear("PAUSED")
	button("Resume", resume).grab_focus()
	button("Settings", func(): settings_from = "pause"; settings_menu())
	button("Main Menu", return_to_menu)
	button("Quit", quit_game)

func resume() -> void:
	page = "game"
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func save_progress() -> void:
	for cafe in get_tree().get_nodes_in_group("arcade_progression"):
		cafe.save_world()
	for arcade in get_tree().get_nodes_in_group("arcade_customers"):
		arcade.save_visits()

func quit_game() -> void:
	save_progress()
	get_tree().quit()

func return_to_menu() -> void:
	save_progress()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menus/menu.tscn")
	main_menu()

func option(text: String, items: Array, selected: int, action: Callable) -> OptionButton:
	var row = HBoxContainer.new()
	var label = Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var item = OptionButton.new()
	item.custom_minimum_size = Vector2(265, 42)
	for value in items: item.add_item(str(value))
	item.get_popup().max_size.y = 650
	item.select(maxi(0, selected))
	item.item_selected.connect(action)
	item.focus_entered.connect(func(): focused_setting = text)
	row.add_child(item)
	rows.add_child(row)
	if text == focused_setting: focus_control.call_deferred(item)
	return item

func settings_menu() -> void:
	page = "settings"
	clear("SETTINGS")
	button("Graphics", graphics_menu).grab_focus()
	button("Audio", audio_menu)
	button("Controls", controls_menu)
	button("Back", settings_back)

func graphics_menu() -> void:
	page = "graphics"
	clear("GRAPHICS")
	if focused_setting not in ["Graphics", "Resolution", "Window mode", "VSync", "Cabinet resolution", "3D render scale", "Shadows", "Effects", "SDFGI lighting", "Idle screen FPS", "Idle game distance"]:
		focused_setting = "Graphics"
	var presets = ["Potato", "Low", "Medium", "High", "Custom"]
	option("Graphics", presets, presets.find(Settings.preset), func(index):
		if index < 4: Settings.set_preset(presets[index])
		else: Settings.preset = "Custom"; Settings.save()
		graphics_menu())
	var resolutions = Settings.get_resolutions()
	var sizes = []
	for size in resolutions:
		sizes.append("%d x %d" % [size.x, size.y])
	option("Resolution", sizes, resolutions.find(Settings.resolution), func(index):
		Settings.resolution = resolutions[index]
		Settings.apply_display()
		Settings.save())
	resolution_label = Label.new()
	resolution_label.add_theme_font_size_override("font_size", 18)
	rows.add_child(resolution_label)
	option("Window mode", ["Windowed", "Fullscreen"], int(Settings.fullscreen), func(index):
		Settings.fullscreen = index == 1
		Settings.apply_display()
		Settings.save())
	option("VSync", ["Off", "On"], int(Settings.vsync), func(index):
		Settings.vsync = index == 1
		Settings.apply_display()
		Settings.save())
	var scales = [0.25, 0.5, 0.75, 1.0]
	option("Cabinet resolution", ["480 x 270", "960 x 540", "1440 x 810", "1920 x 1080"], scales.find(Settings.graphics.cabinet_scale), func(index):
		Settings.set_custom("cabinet_scale", scales[index]); graphics_menu())
	var render_scales = [0.5, 0.7, 0.85, 1.0]
	option("3D render scale", ["50%", "70%", "85%", "100%"], render_scales.find(Settings.graphics.render_scale), func(index):
		Settings.set_custom("render_scale", render_scales[index]); graphics_menu())
	option("Shadows", ["Basic", "Sun only", "All"], Settings.graphics.shadows, func(index):
		Settings.set_custom("shadows", index); graphics_menu())
	option("Effects", ["Off", "Low", "Medium", "High"], Settings.graphics.effects, func(index):
		Settings.set_custom("effects", index); graphics_menu())
	option("SDFGI lighting", ["Off", "On"], int(Settings.graphics.sdfgi), func(index):
		Settings.set_custom("sdfgi", index == 1); graphics_menu())
	var rates = [5, 10, 15, 30]
	option("Idle screen FPS", rates, rates.find(Settings.graphics.idle_fps), func(index):
		Settings.set_custom("idle_fps", rates[index]); graphics_menu())
	var distances = [24.0, 40.0, 64.0, 96.0]
	option("Idle game distance", ["24 m", "40 m", "64 m", "96 m"], distances.find(Settings.graphics.distance), func(index):
		Settings.set_custom("distance", distances[index]); graphics_menu())
	if Engine.is_embedded_in_editor():
		var note = Label.new()
		note.text = "Use a separate game window to test fullscreen."
		note.add_theme_font_size_override("font_size", 18)
		rows.add_child(note)
	button("Back", settings_menu)

func controls_menu() -> void:
	page = "controls"
	clear("CONTROLS")
	binding_buttons.clear()
	var device = option("Input device", ["Keyboard / Mouse", "Controller"], int(Controls.preferred_device == "Controller"), func(index):
		Controls.set_preferred_device("Controller" if index == 1 else "Keyboard")
		last_control = ""
		controls_menu())
	controls_status = Label.new()
	controls_status.text = Controls.detected_devices()
	controls_status.add_theme_font_size_override("font_size", 19)
	controls_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(controls_status)
	var note = Label.new()
	note.text = "Select a binding, then press its new input. Esc / View cancels."
	note.add_theme_font_size_override("font_size", 18)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(note)
	for entry in Controls.BINDINGS:
		var row = HBoxContainer.new()
		var label = Label.new()
		label.text = entry[0]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 22)
		row.add_child(label)
		var change = Button.new()
		change.text = Controls.binding_text(entry[1][0], Controls.preferred_device).replace(" / ", "\n")
		if Controls.preferred_device == "Keyboard" and entry[1][0].begins_with("look_") and change.text == "Unbound":
			change.text = "Mouse (add key)"
		change.custom_minimum_size = Vector2(265, 48)
		change.clip_text = true
		change.tooltip_text = change.text
		change.add_theme_font_size_override("font_size", 21)
		change.pressed.connect(func():
			capturing = entry[1]
			last_control = entry[1][0]
			capture_ready_at = Time.get_ticks_msec() + 200
			change.text = "Press input..."
			controls_status.text = "Waiting for " + Controls.preferred_device.to_lower() + " input. Esc cancels.")
		row.add_child(change)
		rows.add_child(row)
		binding_buttons[entry[1][0]] = change
		if entry[1][0] == last_control: focus_control.call_deferred(change)
	button("Reset this device", func(): Controls.reset_bindings(Controls.preferred_device); controls_menu())
	button("Back", settings_menu)
	if last_control.is_empty(): focus_control.call_deferred(device)

func _controls_devices_changed() -> void:
	if page == "controls" and is_instance_valid(controls_status):
		controls_menu.call_deferred()

func capture_binding(event: InputEvent) -> void:
	var cancel_key = event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE)
	var cancel_button = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_BACK
	if cancel_key or cancel_button:
		controls_menu()
	elif Time.get_ticks_msec() >= capture_ready_at:
		var binding = Controls.captured_event(event, Controls.preferred_device)
		if binding:
			var conflict = Controls.conflicting_action(capturing, Controls.preferred_device, binding)
			if not conflict.is_empty():
				controls_status.text = "Already used for " + conflict + ". Choose another input."
				get_viewport().set_input_as_handled()
				return
			Controls.set_binding(capturing, Controls.preferred_device, binding)
			controls_menu()
	get_viewport().set_input_as_handled()

func audio_menu() -> void:
	page = "audio"
	clear("AUDIO")
	for channel in Settings.audio_volumes:
		var row = HBoxContainer.new()
		var label = Label.new()
		label.text = channel
		label.custom_minimum_size.x = 150
		row.add_child(label)
		var slider = HSlider.new()
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.value = Settings.audio_volumes[channel] * 100
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size.y = 44
		row.add_child(slider)
		var value = Label.new()
		value.custom_minimum_size.x = 85
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.text = str(int(slider.value)) + "%"
		row.add_child(value)
		slider.value_changed.connect(func(amount):
			value.text = str(int(amount)) + "%"
			Settings.set_audio_volume(channel, amount / 100.0))
		rows.add_child(row)
		if channel == "Master": focus_control.call_deferred(slider)
	button("Back", settings_menu)

func settings_back() -> void:
	if settings_from == "pause": pause_menu()
	else: main_menu()

func start_game() -> void:
	page = "loading"
	clear("LOADING")
	progress = ProgressBar.new()
	progress.custom_minimum_size.y = 30
	rows.add_child(progress)
	loading = true
	if ResourceLoader.load_threaded_request(MAP) != OK:
		loading = false
		clear("Couldn't load the arcade.")
		button("Back", main_menu)

func _process(_delta: float) -> void:
	if page == "graphics" and is_instance_valid(resolution_label):
		var size = get_viewport().get_texture().get_size()
		resolution_label.text = "Rendering at %d x %d" % [size.x, size.y]
	if not loading or loading_scene: return
	var values = []
	var status = ResourceLoader.load_threaded_get_status(MAP, values)
	if not values.is_empty(): progress.value = values[0] * 100
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		loading_scene = true
		finish_loading.call_deferred()
	elif status == ResourceLoader.THREAD_LOAD_FAILED:
		loading = false
		clear("Couldn't load the arcade.")
		button("Back", main_menu)

func finish_loading() -> void:
	var scene = ResourceLoader.load_threaded_get(MAP)
	progress.value = 100
	await RenderingServer.frame_post_draw
	get_tree().change_scene_to_packed(scene)
	await get_tree().process_frame
	Settings.apply_graphics()
	await get_tree().process_frame
	loading = false
	loading_scene = false
	resume()

func _input(event: InputEvent) -> void:
	if page == "controls" and not capturing.is_empty():
		capture_binding(event)
		return
	var back = event.is_action_pressed("ui_cancel") and page != "game"
	if not (event.is_action_pressed("pause") or back) or event.is_echo(): return
	if page == "cabinets":
		get_tree().call_group("arcade_management", "close_menu")
		get_viewport().set_input_as_handled()
		return
	if page == "game": pause_menu()
	elif page == "pause": resume()
	elif page == "settings": settings_back()
	elif page == "audio": settings_menu()
	elif page == "controls": settings_menu()
	elif page == "graphics": settings_menu()
	elif page == "delete_saves": main_menu()
	get_viewport().set_input_as_handled()
