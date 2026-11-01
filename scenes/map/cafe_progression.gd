extends Node3D

@export var player: CharacterBody3D
@export var room: Node3D
@export var arcade_price = 150
@export var order_wage = 15
@export var food_wage = 18
@export var combo_wage = 25
@export var orders_per_shift = 3
@export var shift_bonus = 10
@export var brew_seconds = 2.5
@export var toast_seconds = 4.5
@export var coffee_stay = 8.0
@export var food_stay = 14.0
@export var combo_stay = 20.0
@export var repair_prices = {"Pong": 0, "Snake": 35, "Breakout": 45, "Space Game": 50, "Frogger": 55, "Asteroids": 65, "Road Racer": 90}

var shift_open = false
var served_this_shift = 0
var order_serial = 0
var spawn_left = 0.0
var queue: Array = []
var table_customers: Array = [null, null]
var order_taken = false
var brew_left = 0.0
var food_left = 0.0
var coffee_ready = false
var food_ready = false
var carrying: Array[String] = []
var notice = ""
var notice_left = 0.0
var owns_prompt = false
var save_left = 1.0
var world_loaded = false
@onready var furniture = $Interior
@onready var customers = $Interior/Customers.get_children()
@onready var board = $Interior/OrderBoard
@onready var cup = $Interior/CarriedOrder

func _enter_tree() -> void:
	add_to_group("arcade_progression")

func _ready() -> void:
	cup.reparent(player.get_node("Camera3D"), false)
	cup.position = Vector3(0.25,-0.2,-0.5)
	cup.visible = false
	for customer in customers:
		customer.visible = false
		for chair in ["Chair1", "Chair2"]:
			customer.add_collision_exception_with(furniture.get_node(chair).get_child(0))
		customer.arrived.connect(_customer_arrived)
		customer.lost_patience.connect(_customer_left_order)
		customer.finished_meal.connect(_finished_meal)
	for node in get_parent().find_children("*", "Area3D", true, false):
		if node.has_method("spend_credit"): node.repair_price = repair_prices.get(node.machine_name, 50)
	Wallet.progression_changed.connect(_update_ownership)
	_update_ownership()
	if not Wallet.arcade_owned:
		player.global_position = room.to_global(Vector3(-20,1.5,6.7))
		player.rotation.y = PI
		player.get_node("Camera3D").rotation.x = 0
	load_world()
	world_loaded = true

func save_world() -> void:
	if not world_loaded: return
	var visitors: Array = []
	for customer in customers:
		visitors.append({"position": customer.global_position, "rotation": customer.rotation.y,
			"state": customer.state, "meal": customer.meal, "table_index": customer.table_index,
			"patience_left": customer.patience_left, "stay_seconds": customer.stay_seconds,
			"eat_left": customer.eat_left, "route": customer.route.duplicate(),
			"destination_state": customer.destination_state, "text": customer.get_node("Order").text})
	var line: Array = []
	for customer in queue: line.append(customers.find(customer))
	var tables: Array = []
	for customer in table_customers: tables.append(customers.find(customer))
	Wallet.world_state = {"position": player.global_position, "yaw": player.rotation.y,
		"pitch": player.get_node("Camera3D").rotation.x, "shift_open": shift_open,
		"served_this_shift": served_this_shift, "order_serial": order_serial,
		"spawn_left": spawn_left, "order_taken": order_taken, "brew_left": brew_left,
		"food_left": food_left, "coffee_ready": coffee_ready, "food_ready": food_ready,
		"carrying": carrying.duplicate(), "customers": visitors, "queue": line, "tables": tables}
	Wallet.save_money()

func load_world() -> void:
	var data = Wallet.world_state
	if data.is_empty(): return
	player.global_position = data.get("position", player.global_position)
	player.rotation.y = data.get("yaw", player.rotation.y)
	player.get_node("Camera3D").rotation.x = data.get("pitch", 0.0)
	for key in ["shift_open", "served_this_shift", "order_serial", "spawn_left", "order_taken",
		"brew_left", "food_left", "coffee_ready", "food_ready"]:
		if data.has(key): set(key, data[key])
	carrying.assign(data.get("carrying", []))
	var visitors = data.get("customers", [])
	for i in mini(visitors.size(), customers.size()):
		var customer = customers[i]
		var saved = visitors[i]
		customer.global_position = saved.get("position", customer.global_position)
		customer.rotation.y = saved.get("rotation", 0.0)
		for key in ["state", "meal", "table_index", "patience_left", "stay_seconds", "eat_left", "route", "destination_state"]:
			if saved.has(key): customer.set(key, saved[key])
		customer.visible = customer.state not in ["inactive", "gone"]
		customer.get_node("Visual").position.y = -0.25 if customer.state == "eating" else 0.0
		customer.get_node("Order").text = saved.get("text", "")
	queue.clear()
	for index in data.get("queue", []):
		if index >= 0 and index < customers.size(): queue.append(customers[index])
	var tables = data.get("tables", [-1, -1])
	for i in mini(tables.size(), table_customers.size()):
		var index = tables[i]
		table_customers[i] = customers[index] if index >= 0 and index < customers.size() else null

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and world_loaded: save_world()

func point(name: String) -> Vector3:
	return furniture.get_node("CustomerPoints/" + name).global_position

func current_customer():
	return queue[0] if not queue.is_empty() and queue[0].state == "waiting" else null

func start_shift() -> void:
	if shift_open: return
	shift_open = true
	served_this_shift = Wallet.cafe_orders % orders_per_shift
	order_serial = Wallet.cafe_orders
	spawn_left = 0
	tell("Café open")
	spawn_customer()

func close_shift() -> void:
	shift_open = false
	for customer in queue: send_home(customer)
	queue.clear()
	clear_order()
	tell("Shift finished")

func spawn_customer() -> void:
	if not shift_open or queue.size() + served_this_shift >= orders_per_shift: return
	for customer in customers:
		if customer.state in ["inactive", "gone"]:
			customer.reset_customer(point("Entrance"), ["Coffee", "Toast", "Coffee + toast"][order_serial % 3])
			order_serial += 1
			customer.state = "arriving"
			queue.append(customer)
			update_queue()
			return

func update_queue() -> void:
	for i in queue.size():
		var customer = queue[i]
		var target = point("Queue" + str(i+1))
		if customer.global_position.distance_to(target) < 0.18:
			customer.state = "waiting" if i == 0 else "queue"
		else:
			var route = [point("Door"), point("Aisle"), target] if customer.state == "arriving" else [target]
			customer.walk(route, "waiting" if i == 0 else "queue")
		if i > 0: customer.get_node("Order").text = ""

func _customer_arrived(customer) -> void:
	if customer.state == "waiting":
		customer.get_node("Order").text = customer.meal + ", please" if order_taken else "Ready to order"

func send_home(customer) -> void:
	customer.get_node("Order").text = ""
	customer.walk([point("Aisle"), point("Door"), point("Entrance")], "gone")

func _customer_left_order(customer) -> void:
	var front = not queue.is_empty() and queue[0] == customer
	queue.erase(customer)
	if front: clear_order()
	send_home(customer)
	update_queue()
	tell("A customer left without ordering" if not front else "Customer left - order cancelled")

func _finished_meal(customer) -> void:
	if customer.table_index >= 0:
		table_customers[customer.table_index] = null
	customer.table_index = -1
	send_home(customer)

func clear_order() -> void:
	order_taken = false
	carrying.clear()
	coffee_ready = false
	food_ready = false
	brew_left = 0
	food_left = 0

func needed_items(meal: String) -> Array:
	if meal == "Coffee + toast": return ["Coffee", "Toast"]
	return [meal]

func serve_order() -> bool:
	var customer = current_customer()
	if not customer or not order_taken: return false
	for item in needed_items(customer.meal):
		if item not in carrying:
			tell("Still need " + item.to_lower())
			return false
	var table = table_customers.find(null)
	if table == -1:
		tell("Wait for a free table")
		return false
	queue.pop_front()
	table_customers[table] = customer
	customer.table_index = table
	customer.stay_seconds = coffee_stay if customer.meal == "Coffee" else (food_stay if customer.meal == "Toast" else combo_stay)
	customer.get_node("Order").text = "Thanks!"
	customer.walk([point("Aisle"), point("Table"+str(table+1)+"Approach"), point("Table"+str(table+1)+"Seat")], "eating")
	var wage = order_wage if customer.meal == "Coffee" else (food_wage if customer.meal == "Toast" else combo_wage)
	var tip = 3 if customer.patience_left > customer.patience_seconds * 0.7 else (1 if customer.patience_left > customer.patience_seconds * 0.4 else 0)
	var paid = Wallet.pay_cafe_order(wage + tip, orders_per_shift, shift_bonus, false)
	served_this_shift += 1
	clear_order()
	update_queue()
	if served_this_shift >= orders_per_shift: shift_open = false
	tell("+$" + str(paid) + (" - shift complete" if not shift_open else " - served"))
	var audio = get_tree().get_first_node_in_group("arcade_audio")
	if audio: audio.play_sound("score")
	save_world()
	return true

func _update_ownership() -> void:
	var entrance = get_parent().get_node("ArcadeEntrance")
	entrance.get_node("ArcadeGate").visible = not Wallet.arcade_owned
	entrance.get_node("ArcadeGate").get_child(0).set_deferred("disabled", Wallet.arcade_owned)
	entrance.get_node("SaleSign").text = "YOUR ARCADE" if Wallet.arcade_owned else "ARCADE FOR SALE\n$" + str(arcade_price)
	entrance.get_node("HoursSign").text = "OPEN" if Wallet.arcade_open else "CLOSED"

func tell(text: String) -> void:
	notice = text
	notice_left = 3

func station_prompt(id: String) -> String:
	var customer = current_customer()
	match id:
		"ArcadeHours": return ("Close arcade" if Wallet.arcade_open else "Open arcade") if Wallet.arcade_owned else "Buy the arcade first"
		"Sale": return "Your arcade" if Wallet.arcade_owned else "Buy arcade ($" + str(arcade_price) + ")"
		"Clock": return "Finish shift" if shift_open else "Start café shift"
		"Counter":
			if not shift_open: return "Start café shift"
			if not customer: return "Waiting for customer"
			if not order_taken: return "Take customer's order"
			var ready = needed_items(customer.meal).all(func(item): return item in carrying)
			return "Hand over order" if ready else "Prepare: " + customer.meal
		"Coffee":
			if not order_taken: return "Take a customer's order first"
			if brew_left > 0: return "Brewing... " + str(ceili(brew_left)) + "s"
			if coffee_ready: return "Pick up coffee"
			return "Coffee already picked up" if "Coffee" in carrying else "Make coffee"
		"Food":
			if not order_taken: return "Take a customer's order first"
			if food_left > 0: return "Toasting... " + str(ceili(food_left)) + "s"
			if food_ready: return "Pick up toast"
			return "Toast already picked up" if "Toast" in carrying else "Make toast"
		"Bin": return "Discard prepared order"
	return ""

func interact_station(id: String) -> void:
	match id:
		"ArcadeHours":
			if Wallet.arcade_owned:
				Wallet.set_arcade_open(not Wallet.arcade_open)
				tell("Arcade open" if Wallet.arcade_open else "Arcade closed - customers are leaving")
		"Sale":
			if Wallet.buy_arcade(arcade_price): tell("Arcade bought - Pong is ready")
			elif not Wallet.arcade_owned: tell("Need $" + str(maxi(0,arcade_price-Wallet.money)) + " more")
		"Clock":
			if shift_open: close_shift()
			else: start_shift()
		"Counter":
			if not shift_open: start_shift()
			elif current_customer():
				if not order_taken:
					order_taken = true
					current_customer().get_node("Order").text = current_customer().meal + ", please"
				else: serve_order()
		"Coffee":
			if order_taken:
				if coffee_ready:
					carrying.append("Coffee")
					coffee_ready = false
				elif brew_left <= 0 and "Coffee" not in carrying: brew_left = brew_seconds
		"Food":
			if order_taken:
				if food_ready:
					carrying.append("Toast")
					food_ready = false
				elif food_left <= 0 and "Toast" not in carrying: food_left = toast_seconds
		"Bin":
			carrying.clear()
			coffee_ready = false
			food_ready = false
			brew_left = 0
			food_left = 0
	save_world()

func find_station() -> String:
	var camera = player.get_node("Camera3D")
	var best = ""
	var score = 0.0
	for station in $Interior/Stations.get_children():
		var offset = station.global_position - camera.global_position
		if offset.length() > 2.4: continue
		var facing = -camera.global_basis.z.dot(offset.normalized())
		if facing < 0.75: continue
		var ray = PhysicsRayQueryParameters3D.create(camera.global_position, station.global_position, 1, [player.get_rid()])
		var hit = get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and hit.position.distance_to(station.global_position) > 0.35: continue
		var value = facing / maxf(offset.length(),0.5)
		if value > score:
			score = value
			best = str(station.name)
	return best

func _input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_action_pressed("interact") or not player.is_physics_processing(): return
	var station = find_station()
	if not station.is_empty():
		interact_station(station)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	save_left -= delta
	if save_left <= 0:
		save_left = 1.0
		save_world()
	if brew_left > 0:
		brew_left = maxf(0,brew_left-delta)
		if brew_left == 0: coffee_ready = true
	if food_left > 0:
		food_left = maxf(0,food_left-delta)
		if food_left == 0: food_ready = true
	if shift_open:
		spawn_left -= delta
		if spawn_left <= 0:
			spawn_left = 4
			spawn_customer()
	notice_left = maxf(0,notice_left-delta)
	var customer = current_customer()
	board.text = notice if notice_left > 0 else ("Café closed\nStart a shift here" if not shift_open else "Waiting for customers")
	if customer and notice_left <= 0:
		board.text = (customer.meal + "\nCoffee: " + (str(ceili(brew_left))+"s" if brew_left>0 else ("ready" if coffee_ready or "Coffee" in carrying else "not made")) + "\nToast: " + (str(ceili(food_left))+"s" if food_left>0 else ("ready" if food_ready or "Toast" in carrying else "not made"))) if order_taken else "Customer waiting\nTake order"
	cup.visible = not carrying.is_empty()
	cup.get_node("Coffee").visible = "Coffee" in carrying
	cup.get_node("Toast").visible = "Toast" in carrying
	for i in 2:
		var meal = furniture.get_node("TableMeal"+str(i+1))
		var visitor = table_customers[i]
		meal.visible = is_instance_valid(visitor) and visitor.state == "eating"
		if meal.visible:
			meal.get_node("Coffee").visible = "Coffee" in visitor.meal
			meal.get_node("Toast").visible = "Toast" in visitor.meal or "toast" in visitor.meal
	var prompt = player.get_node("Camera3D/Control/Label")
	if player.is_physics_processing():
		var target = find_station()
		if not target.is_empty():
			prompt.visible = true
			prompt.text = Controls.binding_text("interact") + ": " + station_prompt(target)
			owns_prompt = true
		elif owns_prompt:
			prompt.visible = false
			owns_prompt = false
