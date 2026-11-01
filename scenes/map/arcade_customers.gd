extends Node3D

@export var entry_price = 1
@export var arrival_seconds = 10.0
@export var shortest_game = 18.0
@export var longest_game = 32.0
var arrival_left = 4.0
var save_left = 1.0
var visits: Dictionary = {}
var machines: Dictionary = {}
@onready var customers = $Customers.get_children()

func _ready() -> void:
	add_to_group("arcade_customers")
	for marker in $Machines.get_children():
		var cabinet = get_parent().get_node(marker.get_meta("cabinet"))
		machines[marker.name] = cabinet.get_node("coinslot")
	for customer in customers:
		customer.visible = false
		customer.add_collision_exception_with(get_parent().get_node("CharacterBody3D"))
		customer.arrived.connect(_arrived)
	load_visits()
	Wallet.progression_changed.connect(_opening_changed)
	_opening_changed()

func _opening_changed() -> void:
	if Wallet.arcade_open: return
	for customer in customers:
		if visits.has(customer.name): send_home(customer)

func point(name: String) -> Vector3:
	return get_node("Route/" + name).global_position

func available_machine() -> String:
	var free: Array[String] = []
	for id in machines:
		var machine = machines[id]
		if machine.is_unlocked() and not machine.playing and not is_instance_valid(machine.visitor) and machine.credits == 0 and not machine.coin_ready and not machine.start_ready:
			free.append(id)
	return free.pick_random() if not free.is_empty() else ""

func invite_customer() -> bool:
	if not Wallet.arcade_owned or not Wallet.arcade_open: return false
	var target = available_machine()
	if target.is_empty(): return false
	for customer in customers:
		if customer.state not in ["inactive", "gone"]: continue
		var marker = get_node("Machines/" + target)
		customer.reset_customer(point("Entrance"), "")
		visits[customer.name] = {"machine": target, "time_left": randf_range(shortest_game, longest_game), "paid": false, "walk_left": 35.0}
		machines[target].visitor = customer
		var approach = Vector3(marker.global_position.x, point("Aisle").y, point("Aisle").z)
		customer.walk([point("Door"), point("Aisle"), approach, marker.global_position], "playing")
		save_visits()
		return true
	return false

func _arrived(customer) -> void:
	if customer.state != "playing" or not visits.has(customer.name): return
	var visit = visits[customer.name]
	var machine = machines[visit.machine]
	if not Wallet.arcade_open or not machine.is_unlocked() or machine.playing:
		send_home(customer)
		return
	customer.rotation.y = get_node("Machines/" + visit.machine).global_rotation.y
	if not visit.paid:
		visit.paid = true
		save_visits(false)
		Wallet.add_money(entry_price)
		machine._refresh_label()
		if machine.player and machine.player.global_position.distance_to(customer.global_position) < 8:
			ArcadeAudio.play(machine, "coin")

func send_home(customer) -> void:
	if not visits.has(customer.name): return
	var visit = visits[customer.name]
	var machine = machines.get(visit.machine)
	if machine and machine.visitor == customer:
		machine.visitor = null
		machine._refresh_label()
	visits.erase(customer.name)
	var aisle = point("Aisle")
	customer.get_node("Order").text = ""
	customer.get_node("Visual/Arms").visible = false
	var route = [point("Door"), point("Entrance")]
	if customer.global_position.z <= aisle.z:
		route = [Vector3(customer.global_position.x, aisle.y, aisle.z), aisle] + route
	customer.walk(route, "gone")
	save_visits()

func _process(delta: float) -> void:
	arrival_left -= delta
	if arrival_left <= 0:
		arrival_left = arrival_seconds
		invite_customer()
	for customer in customers:
		customer.get_node("Visual/Arms").visible = customer.state == "playing"
		if not visits.has(customer.name): continue
		var visit = visits[customer.name]
		if customer.state == "playing":
			visit.time_left -= delta
			if visit.time_left <= 0: send_home(customer)
		elif customer.state == "walking":
			visit.walk_left -= delta
			if visit.walk_left <= 0: send_home(customer)
	save_left -= delta
	if save_left <= 0:
		save_left = 1.0
		save_visits()

func save_visits(write_file: bool = true) -> void:
	var people: Array = []
	for customer in customers:
		people.append({"position": customer.global_position, "rotation": customer.rotation.y,
			"state": customer.state, "route": customer.route.duplicate(), "destination_state": customer.destination_state})
	Wallet.arcade_state = {"customers": people, "visits": visits.duplicate(true), "arrival_left": arrival_left}
	if write_file: Wallet.save_money()

func load_visits() -> void:
	var data = Wallet.arcade_state
	arrival_left = data.get("arrival_left", arrival_left)
	visits = data.get("visits", {}).duplicate(true)
	var people = data.get("customers", [])
	for i in mini(people.size(), customers.size()):
		var customer = customers[i]
		var saved = people[i]
		customer.global_position = saved.get("position", customer.global_position)
		customer.rotation.y = saved.get("rotation", 0.0)
		customer.state = saved.get("state", "inactive")
		customer.route = saved.get("route", [])
		customer.destination_state = saved.get("destination_state", "gone")
		customer.visible = customer.state not in ["inactive", "gone"]
		if visits.has(customer.name):
			var machine = machines.get(visits[customer.name].machine)
			if machine and machine.is_unlocked() and not is_instance_valid(machine.visitor):
				machine.visitor = customer
			else: send_home(customer)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_node_ready(): save_visits()
