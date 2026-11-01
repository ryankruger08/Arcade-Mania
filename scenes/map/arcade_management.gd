extends Node3D

const CABINETS = {"Pong": "Pong Arcade", "Frogger": "Frogger Arcade", "Space Game": "Space Arcade", "Snake": "snake_arcade", "Breakout": "breakout_arcade", "Asteroids": "Asteroids Arcade", "Road Racer": "Racing Arcade"}
var machines: Dictionary = {}
var collisions: Dictionary = {}
var owns_prompt = false
var menu_open = false
@onready var player = get_parent().get_node("CharacterBody3D")
@onready var ui = $Menu/Screen
@onready var rows = $Menu/Screen/Panel/Margin/Rows
@onready var game_pick = $Menu/Screen/Panel/Margin/Rows/Game
@onready var slot_pick = $Menu/Screen/Panel/Margin/Rows/Slot
@onready var action = $Menu/Screen/Panel/Margin/Rows/Place
@onready var status = $Menu/Screen/Panel/Margin/Rows/Status

func _ready() -> void:
	add_to_group("arcade_management")
	process_mode = Node.PROCESS_MODE_ALWAYS
	for id in Wallet.MACHINE_ORDER:
		var cabinet = get_parent().get_node(CABINETS[id])
		machines[id] = cabinet.get_node("coinslot")
		var bodies: Array = []
		for body in cabinet.find_children("*", "CollisionObject3D", true, false):
			bodies.append([body, body.collision_layer, body.collision_mask])
		collisions[id] = bodies
		game_pick.add_item(id)
	game_pick.item_selected.connect(func(_index): refresh_menu())
	slot_pick.item_selected.connect(func(_index): refresh_menu(false))
	action.pressed.connect(place_selected)
	rows.get_node("Back").pressed.connect(close_menu)
	Wallet.progression_changed.connect(apply_layout)
	get_viewport().size_changed.connect(resize_menu)
	resize_menu()
	apply_layout()

func resize_menu() -> void:
	var size = get_viewport().get_visible_rect().size
	var factor = minf(size.x/1920.0,size.y/1080.0)
	ui.scale = Vector2.ONE*factor
	ui.position = (size-Vector2(1920,1080)*factor)/2

func apply_layout() -> void:
	for id in machines:
		var machine = machines[id]
		var cabinet = machine.get_parent()
		var owned = Wallet.arcade_owned and id in Wallet.unlocked_machines
		cabinet.visible = owned
		cabinet.process_mode = Node.PROCESS_MODE_INHERIT if owned else Node.PROCESS_MODE_DISABLED
		for saved in collisions[id]:
			saved[0].collision_layer = saved[1] if owned else 0
			saved[0].collision_mask = saved[2] if owned else 0
		if owned:
			var slot = clampi(Wallet.cabinet_layout.get(id, Wallet.MACHINE_ORDER.find(id)),0,6)
			var target = $Bays.get_child(slot).global_position
			if not cabinet.global_position.is_equal_approx(target):
				cabinet.global_position = target
				machine.coin_ready = false
				machine.start_ready = false
		var viewport = cabinet.get_node("SubViewport")
		if not owned:
			viewport.get_child(0).process_mode = Node.PROCESS_MODE_DISABLED
			viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		else: Settings.wake_machine(machine)
	var arcade = get_parent().get_node("ArcadeCustomers")
	for marker in arcade.get_node("Machines").get_children():
		var cabinet = get_parent().get_node(marker.get_meta("cabinet"))
		marker.global_position.x = cabinet.global_position.x
		marker.global_position.z = cabinet.global_position.z + (2.1 if marker.name == "Racing" else 1.64)
	refresh_menu()

func aimed_at_terminal() -> bool:
	var camera = player.get_node("Camera3D")
	var offset = $Terminal/Interact.global_position-camera.global_position
	if offset.length()>2.2 or -camera.global_basis.z.dot(offset.normalized())<0.85: return false
	var ray = PhysicsRayQueryParameters3D.create(camera.global_position,$Terminal/Interact.global_position,1,[player.get_rid()])
	var hit = get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.is_empty() or hit.position.distance_to($Terminal/Interact.global_position)<0.3

func _process(_delta: float) -> void:
	if menu_open or get_tree().paused or not player.is_physics_processing(): return
	var prompt = player.get_node("Camera3D/Control/Label")
	if aimed_at_terminal():
		prompt.visible = true
		prompt.text = Controls.binding_text("interact")+": Cabinet shop"
		owns_prompt = true
	elif owns_prompt:
		if "Cabinet shop" in prompt.text: prompt.visible = false
		owns_prompt = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo(): return
	if menu_open:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
			close_menu()
			get_viewport().set_input_as_handled()
	elif not get_tree().paused and player.is_physics_processing() and event.is_action_pressed("interact") and aimed_at_terminal():
		open_menu()
		get_viewport().set_input_as_handled()

func open_menu() -> void:
	menu_open = true
	$Menu.visible = true
	Menu.page = "cabinets"
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	status.text = "Buy the arcade first." if not Wallet.arcade_owned else ("Close the arcade before moving cabinets." if Wallet.arcade_open else "Choose a machine and a bay. Owned machines can swap places.")
	refresh_menu()
	game_pick.grab_focus()

func close_menu() -> void:
	if not menu_open: return
	menu_open = false
	$Menu.visible = false
	Menu.page = "game"
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func refresh_menu(rebuild_slots: bool = true) -> void:
	if game_pick.item_count == 0: return
	rows.get_node("Balance").text = "Money: $"+str(Wallet.money)
	var id = Wallet.MACHINE_ORDER[game_pick.selected]
	var owned = id in Wallet.unlocked_machines
	if rebuild_slots:
		var selected = slot_pick.selected
		slot_pick.clear()
		for i in Wallet.MACHINE_ORDER.size():
			var occupant = "Empty"
			for other in Wallet.cabinet_layout:
				if other in Wallet.unlocked_machines and Wallet.cabinet_layout[other] == i: occupant = other
			slot_pick.add_item(str(i+1)+" - "+occupant)
		slot_pick.select(clampi(selected,0,6))
	action.text = "Move here" if owned else "Buy and place - $"+str(Wallet.MACHINE_PRICES[id])
	action.disabled = not Wallet.arcade_owned or Wallet.arcade_open or (not owned and Wallet.money < Wallet.MACHINE_PRICES[id])

func place_selected() -> void:
	if Wallet.arcade_open:
		status.text = "Close the arcade first."
		return
	var arcade = get_parent().get_node("ArcadeCustomers")
	if not arcade.visits.is_empty() or arcade.customers.any(func(customer): return customer.state not in ["inactive", "gone"]):
		status.text = "Let the last customers leave, then reopen this menu."
		return
	if machines.values().any(func(machine): return machine.playing):
		status.text = "Leave the game before moving cabinets."
		return
	var id = Wallet.MACHINE_ORDER[game_pick.selected]
	if Wallet.place_machine(id,slot_pick.selected):
		status.text = id+" placed in bay "+str(slot_pick.selected+1)+". Saved."
		ArcadeAudio.play(self,"coin")
	else: status.text = "Choose an empty bay for a new machine."
	refresh_menu()
