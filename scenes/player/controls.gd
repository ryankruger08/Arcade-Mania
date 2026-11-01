extends Node

signal device_changed
signal devices_changed
const SAVE_PATH = "user://controls.cfg"
const BINDINGS = [
	["Move left", ["game_left", "move_left"]],
	["Move right", ["game_right", "move_right"]],
	["Move forward / Up", ["game_up", "move_forward"]],
	["Move back / Down", ["game_down", "move_back"]],
	["Look left", ["look_left"]], ["Look right", ["look_right"]],
	["Look up", ["look_up"]], ["Look down", ["look_down"]],
	["Jump", ["jump"]], ["Insert coin", ["insert_coin"]],
	["Refund coin", ["remove_credit"]], ["Play / leave cabinet", ["play"]],
	["Interact / Café", ["interact"]],
	["Primary action / Fire", ["game_action"]], ["Drift", ["game_secondary"]],
	["Reset kart", ["game_reset"]], ["Accelerate trigger", ["race_accelerate"]],
	["Brake trigger", ["race_brake"]], ["Pause", ["pause"]],
	["Menu confirm", ["ui_accept"]], ["Menu back", ["ui_cancel"]]
]
var controller = false
var preferred_device = "Keyboard"
var defaults = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for action in InputMap.get_actions():
		if ProjectSettings.has_setting("input/" + action):
			defaults[action] = InputMap.action_get_events(action).duplicate(true)
	load_bindings()
	controller = preferred_device == "Controller" and not Input.get_connected_joypads().is_empty()
	Input.joy_connection_changed.connect(controller_connection)

func is_controller_event(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion

func events_for(action: String, profile: String) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	for event in InputMap.action_get_events(action):
		if is_controller_event(event) == (profile == "Controller"): events.append(event)
	return events

func replace_events(action: String, profile: String, events: Array) -> void:
	for event in events_for(action, profile): InputMap.action_erase_event(action, event)
	for event in events:
		if event is InputEvent and is_controller_event(event) == (profile == "Controller"):
			InputMap.action_add_event(action, event)

func set_preferred_device(profile: String) -> void:
	preferred_device = profile
	controller = profile == "Controller" and not Input.get_connected_joypads().is_empty()
	save_bindings()
	device_changed.emit()

func save_bindings() -> void:
	var config = ConfigFile.new()
	config.set_value("Device", "selected", preferred_device)
	for profile in ["Keyboard", "Controller"]:
		for action in defaults:
			config.set_value(profile, action, events_for(action, profile))
	config.save(SAVE_PATH)

func load_bindings() -> void:
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) != OK: return
	preferred_device = config.get_value("Device", "selected", "Keyboard")
	if preferred_device not in ["Keyboard", "Controller"]: preferred_device = "Keyboard"
	for profile in ["Keyboard", "Controller"]:
		for action in defaults:
			if config.has_section_key(profile, action):
				var events = config.get_value(profile, action)
				if events is Array: replace_events(action, profile, events)

func conflicting_action(actions: Array, profile: String, event: InputEvent) -> String:
	for group in [["jump", "insert_coin", "remove_credit", "play"], ["game_left", "game_right", "game_up", "game_down"], ["look_left", "look_right", "look_up", "look_down"]]:
		if actions[0] not in group: continue
		for action in group:
			if action in actions: continue
			for binding in events_for(action, profile):
				if binding.is_match(event, true):
					for entry in BINDINGS:
						if action in entry[1]: return entry[0]
	return ""

func set_binding(actions: Array, profile: String, event: InputEvent) -> void:
	for action in actions: replace_events(action, profile, [event])
	save_bindings()
	device_changed.emit()

func reset_bindings(profile: String) -> void:
	for action in defaults:
		var events = []
		for event in defaults[action]:
			if is_controller_event(event) == (profile == "Controller"): events.append(event)
		replace_events(action, profile, events)
	save_bindings()
	device_changed.emit()

func detected_devices() -> String:
	var names: Array[String] = []
	for device in Input.get_connected_joypads(): names.append(Input.get_joy_name(device))
	return "Keyboard / mouse ready\n" + ("Controller: " + ", ".join(names) if not names.is_empty() else "No controller connected")

func captured_event(event: InputEvent, profile: String) -> InputEvent:
	if profile == "Keyboard":
		if event is InputEventKey and event.pressed and not event.echo:
			var key = InputEventKey.new()
			key.physical_keycode = event.physical_keycode if event.physical_keycode else event.keycode
			return key
		if event is InputEventMouseButton and event.pressed:
			var mouse = InputEventMouseButton.new()
			mouse.button_index = event.button_index
			return mouse
	else:
		if event is InputEventJoypadButton and event.pressed:
			var button = InputEventJoypadButton.new()
			button.device = -1
			button.button_index = event.button_index
			return button
		if event is InputEventJoypadMotion and absf(event.axis_value) >= 0.65:
			var axis = InputEventJoypadMotion.new()
			axis.device = -1
			axis.axis = event.axis
			axis.axis_value = signf(event.axis_value)
			return axis
	return null

func binding_text(action: String, profile: String = "") -> String:
	var use_controller = controller if profile.is_empty() else profile == "Controller"
	var names: Array[String] = []
	for event in InputMap.action_get_events(action):
		var text = ""
		if use_controller and event is InputEventJoypadButton:
			text = {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y", JOY_BUTTON_START: "Start", JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down", JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right", JOY_BUTTON_LEFT_STICK: "Left stick click", JOY_BUTTON_RIGHT_STICK: "Right stick click"}.get(event.button_index, event.as_text())
		elif use_controller and event is InputEventJoypadMotion:
			text = {JOY_AXIS_TRIGGER_RIGHT: "RT", JOY_AXIS_TRIGGER_LEFT: "LT"}.get(event.axis, "")
			if text.is_empty():
				var stick = "Left stick" if event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y] else "Right stick"
				var direction = ("left" if event.axis_value < 0 else "right") if event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_RIGHT_X] else ("up" if event.axis_value < 0 else "down")
				text = stick + " " + direction
		elif not use_controller and event is InputEventKey:
			text = OS.get_keycode_string(event.physical_keycode if event.physical_keycode else event.keycode)
		elif not use_controller and event is InputEventMouseButton:
			text = {MOUSE_BUTTON_LEFT: "Left Mouse", MOUSE_BUTTON_RIGHT: "Right Mouse", MOUSE_BUTTON_MIDDLE: "Middle Mouse"}.get(event.button_index, event.as_text())
		if not text.is_empty() and text not in names: names.append(text)
	return " / ".join(names) if not names.is_empty() else "Unbound"

func _input(event: InputEvent) -> void:
	var previous = controller
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and abs(event.axis_value) > 0.3): controller = true
	elif event is InputEventKey or event is InputEventMouseButton or (event is InputEventMouseMotion and event.relative.length() > 2): controller = false
	if previous != controller: device_changed.emit()

func controller_connection(_device: int, connected: bool) -> void:
	devices_changed.emit()
	if connected and preferred_device == "Controller":
		controller = true
		device_changed.emit()
	elif not connected and controller and Input.get_connected_joypads().is_empty():
		controller = false
		device_changed.emit()
		if Menu.page == "game": Menu.pause_menu()
