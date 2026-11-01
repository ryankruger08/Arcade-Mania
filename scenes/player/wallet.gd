extends Node

signal money_changed
signal progression_changed
const SAVE_PATH = "user://wallet.cfg"
const MACHINE_ORDER = ["Pong", "Frogger", "Space Game", "Snake", "Breakout", "Asteroids", "Road Racer"]
const MACHINE_PRICES = {"Pong": 0, "Frogger": 55, "Space Game": 50, "Snake": 35, "Breakout": 45, "Asteroids": 65, "Road Racer": 90}
var money = 0
var arcade_owned = false
var arcade_open = false
var unlocked_machines: Array = []
var cafe_orders = 0
var machine_credits: Dictionary = {}
var world_state: Dictionary = {}
var arcade_state: Dictionary = {}
var cabinet_layout: Dictionary = {}

func _ready() -> void:
	load_money()

func reset_progress() -> void:
	money = 0
	arcade_owned = false
	arcade_open = false
	unlocked_machines.clear()
	cafe_orders = 0
	machine_credits.clear()
	world_state.clear()
	arcade_state.clear()
	cabinet_layout.clear()
	money_changed.emit()
	progression_changed.emit()

func add_money(amount: int) -> void:
	if amount <= 0: return
	money += amount
	save_money()
	money_changed.emit()

func spend_money(amount: int = 1) -> bool:
	if amount < 0 or money < amount: return false
	money -= amount
	save_money()
	money_changed.emit()
	return true

func buy_arcade(price: int) -> bool:
	if arcade_owned or price < 0 or money < price: return false
	money -= price
	arcade_owned = true
	arcade_open = false
	unlocked_machines = ["Pong"]
	cabinet_layout = {"Pong": 0}
	save_money()
	money_changed.emit()
	progression_changed.emit()
	return true

func repair_machine(id: String, price: int) -> bool:
	if not arcade_owned or id in unlocked_machines or price < 0 or money < price: return false
	var slot = MACHINE_ORDER.find(id)
	if slot < 0: return false
	if slot in cabinet_layout.values():
		for free in MACHINE_ORDER.size():
			if free not in cabinet_layout.values():
				slot = free
				break
	money -= price
	unlocked_machines.append(id)
	cabinet_layout[id] = slot
	save_money()
	money_changed.emit()
	progression_changed.emit()
	return true

func place_machine(id: String, slot: int) -> bool:
	if not arcade_owned or arcade_open or id not in MACHINE_PRICES or slot < 0 or slot >= MACHINE_ORDER.size(): return false
	var owned = id in unlocked_machines
	var price = 0 if owned else MACHINE_PRICES[id]
	if money < price: return false
	var occupant = ""
	for other in cabinet_layout:
		if cabinet_layout[other] == slot and other != id: occupant = other
	if not owned and not occupant.is_empty(): return false
	if not occupant.is_empty(): cabinet_layout[occupant] = cabinet_layout.get(id, MACHINE_ORDER.find(id))
	cabinet_layout[id] = slot
	if not owned:
		money -= price
		unlocked_machines.append(id)
	save_money()
	money_changed.emit()
	progression_changed.emit()
	return true

func pay_cafe_order(wage: int, shift_size: int, bonus: int, save_now: bool = true) -> int:
	if wage < 0 or shift_size < 1 or bonus < 0: return 0
	cafe_orders += 1
	var paid = wage + (bonus if cafe_orders % shift_size == 0 else 0)
	money += paid
	if save_now: save_money()
	money_changed.emit()
	return paid

func save_money() -> void:
	var config = ConfigFile.new()
	config.set_value("Money", "balance", money)
	config.set_value("Progress", "arcade_owned", arcade_owned)
	config.set_value("Progress", "arcade_open", arcade_open)
	config.set_value("Progress", "machines", unlocked_machines)
	config.set_value("Progress", "cafe_orders", cafe_orders)
	config.set_value("Progress", "machine_credits", machine_credits)
	config.set_value("Progress", "world", world_state)
	config.set_value("Progress", "arcade_customers", arcade_state)
	config.set_value("Progress", "cabinet_layout", cabinet_layout)
	if config.save(SAVE_PATH + ".tmp") != OK:
		push_warning("Could not save progress")
		return
	var previous = ConfigFile.new()
	if previous.load(SAVE_PATH) == OK and (previous.has_section("Money") or previous.has_section("Wallet")):
		if DirAccess.copy_absolute(SAVE_PATH, SAVE_PATH + ".bak") != OK:
			push_warning("Could not back up progress")
	if DirAccess.rename_absolute(SAVE_PATH + ".tmp", SAVE_PATH) != OK:
		push_warning("Could not replace progress save")

func load_money() -> void:
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) != OK or not (config.has_section("Money") or config.has_section("Wallet")):
		if config.load(SAVE_PATH + ".bak") != OK: return
	money = maxi(0, config.get_value("Money", "balance", config.get_value("Wallet", "coins", 0)))
	arcade_owned = config.get_value("Progress", "arcade_owned", false)
	arcade_open = arcade_owned and config.get_value("Progress", "arcade_open", arcade_owned)
	unlocked_machines = config.get_value("Progress", "machines", [])
	cafe_orders = maxi(0, config.get_value("Progress", "cafe_orders", 0))
	machine_credits = config.get_value("Progress", "machine_credits", {})
	world_state = config.get_value("Progress", "world", {})
	arcade_state = config.get_value("Progress", "arcade_customers", {})
	cabinet_layout = config.get_value("Progress", "cabinet_layout", {})
	var used: Array = []
	for id in unlocked_machines:
		if id not in MACHINE_ORDER: continue
		var slot = int(cabinet_layout.get(id, MACHINE_ORDER.find(id)))
		if slot < 0 or slot >= MACHINE_ORDER.size() or slot in used:
			for free in MACHINE_ORDER.size():
				if free not in used:
					slot = free
					break
		cabinet_layout[id] = slot
		used.append(slot)

func insert_money(machine: String) -> bool:
	if money < 1: return false
	money -= 1
	machine_credits[machine] = machine_credits.get(machine, 0) + 1
	save_money()
	money_changed.emit()
	return true

func set_arcade_open(open: bool) -> void:
	if not arcade_owned: return
	arcade_open = open
	save_money()
	progression_changed.emit()

func refund_money(machine: String) -> bool:
	if machine_credits.get(machine, 0) <= 0: return false
	machine_credits[machine] -= 1
	money += 1
	save_money()
	money_changed.emit()
	return true

func set_machine_credits(machine: String, amount: int) -> void:
	machine_credits[machine] = maxi(0, amount)
	save_money()
