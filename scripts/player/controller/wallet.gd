extends Node
var coins: int = 5
const SAVE_PATH = "user://wallet.cfg"
func _ready() -> void:
	load_coins()
func add_coins(amount: int) -> void:
	coins += amount
	save_coins()
func spend_coin() -> bool:
	if coins > 0:
		coins -= 1
		save_coins()
		return true
	return false
func get_coins() -> int:
	return coins
func save_coins() -> void:
	var config = ConfigFile.new()
	config.set_value("Wallet", "coins", coins)
	config.save(SAVE_PATH)
func load_coins() -> void:
	var config = ConfigFile.new()
	var error = config.load(SAVE_PATH)
	if error == OK:
		coins = config.get_value("Wallet", "coins", 0)
	else:
		coins = 0
