extends Area3D
@export var machine_name: String = "machine"
@export var player: CharacterBody3D 
@export var camera: Camera3D
@export var label: Label 
@export var credit_label: Label
@export var gamemanager: Node
@export var repair_price: int = 50
var playready = false
var coin_ready = false
var start_ready = false
var playing = false
var credits: int = 0
var credit_flash_timer: Timer
var coin_trigger_down = false
var exit_hint_timer: Timer
var credit_feedback: Tween
var lock_layer: CanvasLayer
var lock_label: Label
var visitor: Node


func _ready() -> void:
	credits = maxi(0, Wallet.machine_credits.get(machine_name, 0))
	_setup_credit_flash_timer()
	_update_credit_label()
	Settings.register_machine.call_deferred(self)
	Controls.device_changed.connect(_on_input_device_changed)
	exit_hint_timer = Timer.new()
	exit_hint_timer.one_shot = true
	exit_hint_timer.wait_time = 3.0
	exit_hint_timer.timeout.connect(_refresh_label)
	add_child(exit_hint_timer)
	Wallet.progression_changed.connect(_on_progression_changed)
	_setup_lock.call_deferred()

func is_unlocked() -> bool:
	if not get_tree().get_first_node_in_group("arcade_progression"): return true
	return Wallet.arcade_owned and machine_name in Wallet.unlocked_machines

func _setup_lock() -> void:
	if not get_tree().get_first_node_in_group("arcade_progression"): return
	var viewport = get_parent().get_node("SubViewport")
	lock_layer = viewport.get_node("LockScreen")
	lock_label = lock_layer.get_node("Message")
	_on_progression_changed()

func _on_progression_changed() -> void:
	if lock_layer:
		lock_layer.visible = not is_unlocked()
		lock_label.text = machine_name + ("\nREPAIR $" + str(repair_price) if Wallet.arcade_owned else "\nARCADE FOR SALE")
	Settings.wake_machine(self)
	_update_credit_label()
	if coin_ready or start_ready or playing: _refresh_label()


func _setup_credit_flash_timer() -> void:
	credit_flash_timer = Timer.new()
	credit_flash_timer.wait_time = 0.5
	credit_flash_timer.timeout.connect(_on_credit_flash_timeout)
	add_child(credit_flash_timer)
	credit_flash_timer.start()


func _on_credit_flash_timeout() -> void:
	if playing or not credit_label or not is_unlocked():
		return
	if credits <= 0:
		credit_label.visible = !credit_label.visible


func _update_credit_label() -> void:
	if not credit_label:
		return
	if playing or not is_unlocked():
		credit_label.visible = false
		return
	if credits <= 0:
		credit_label.text = "INSERT $1"
		credit_label.visible = true
	else:
		credit_label.visible = true
		credit_label.text = "$" + str(credits) + " LOADED"

func flash_credit() -> void:
	if not credit_label: return
	if credit_feedback: credit_feedback.kill()
	credit_label.visible = true
	credit_label.modulate = Color(1, 0.85, 0.3)
	credit_feedback = create_tween()
	credit_feedback.tween_property(credit_label, "modulate", Color.WHITE, 0.45)


func _refresh_label() -> void:
	if not label:
		return
	if is_instance_valid(visitor) and (start_ready or coin_ready):
		label.visible = true
		label.text = "Customer using " + machine_name
		return
	if not is_unlocked() and (start_ready or coin_ready):
		label.visible = true
		label.text = Controls.binding_text("play") + ": Repair " + machine_name + " ($" + str(repair_price) + ")" if Wallet.arcade_owned else "Buy the arcade at the entrance first"
		return
	if playing:
		label.visible = exit_hint_timer != null and not exit_hint_timer.is_stopped()
		label.text = Controls.binding_text("play") + ": Leave " + machine_name
	elif start_ready:
		label.visible = true
		label.text = Controls.binding_text("play") + ": Play " + machine_name
		label.text += "\n" + Controls.binding_text("insert_coin") + ": Insert $1"
		if credits > 0: label.text += "\n" + Controls.binding_text("remove_credit") + ": Refund Money"
	elif coin_ready:
		label.visible = true
		label.text = Controls.binding_text("insert_coin") + ": Insert $1"
		if credits > 0: label.text += "\n" + Controls.binding_text("remove_credit") + ": Refund Money"
	else:
		label.visible = false

func _on_input_device_changed() -> void:
	if playing or start_ready or coin_ready: _refresh_label()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo(): return
	if is_instance_valid(visitor):
		if (start_ready or coin_ready) and (event.is_action_pressed("play") or event.is_action_pressed("insert_coin")):
			_refresh_label()
			get_viewport().set_input_as_handled()
		return
	if not is_unlocked():
		if event.is_action_pressed("play") and (start_ready or coin_ready):
			if Wallet.repair_machine(machine_name, repair_price): ArcadeAudio.play(self, "start")
			_refresh_label()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadMotion:
		for binding in InputMap.action_get_events("insert_coin"):
			if binding is InputEventJoypadMotion and binding.axis == event.axis and (binding.device == -1 or binding.device == event.device):
				var down = event.axis_value * binding.axis_value > InputMap.action_get_deadzone("insert_coin")
				var fresh_press = down and not coin_trigger_down
				coin_trigger_down = down
				if not fresh_press: return
	if event.is_action_pressed("insert_coin") and (coin_ready or start_ready) and not playing:
		if Wallet.insert_money(machine_name):
			credits += 1
			ArcadeAudio.play(self, "coin")
			_update_credit_label()
			flash_credit()
			_refresh_label()
			get_viewport().set_input_as_handled()
	if event.is_action_pressed("remove_credit") and (coin_ready or start_ready) and not playing and credits > 0:
		Wallet.refund_money(machine_name)
		credits -= 1
		ArcadeAudio.play(self, "refund")
		_update_credit_label()
		flash_credit()
		_refresh_label()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("play"):
		if not playing and start_ready and credits > 0:
			credits -= 1
			Wallet.set_machine_credits(machine_name, credits)
			if camera: camera.current = true
			playing = true
			exit_hint_timer.start()
			ArcadeAudio.play(self, "start")
			Settings.wake_machine(self)
			if player:
				player.set_physics_process(false)
				player.set_process_unhandled_input(false)
			if gamemanager: gamemanager.start_match()
			_update_credit_label()
			_refresh_label()
			get_viewport().set_input_as_handled()
		elif playing:
			exit_hint_timer.stop()
			ArcadeAudio.play(self, "exit")
			if camera: camera.current = false
			playing = false
			if player:
				player.set_physics_process(true)
				player.set_process_unhandled_input(true)
			if gamemanager: gamemanager.end_match()
			_update_credit_label()
			_refresh_label()
			get_viewport().set_input_as_handled()


func _on_body_entered(body: Node3D) -> void:
		playready = true
		_refresh_label()


func _on_body_exited(body: Node3D) -> void:
		playready = false
		_refresh_label()


func _on_coin_slot_body_entered(body: Node3D) -> void:
		coin_ready = true
		_refresh_label()


func _on_coin_slot_body_exited(body: Node3D) -> void:
		coin_ready = false
		_refresh_label()


func _on_start_button_body_entered(body: Node3D) -> void:
		start_ready = true
		_refresh_label()


func _on_start_button_body_exited(body: Node3D) -> void:
		start_ready = false
		_refresh_label()


func spend_credit() -> bool:
	if credits <= 0:
		return false
	credits -= 1
	Wallet.set_machine_credits(machine_name, credits)
	_update_credit_label()
	return true


func add_credits(amount: int) -> void:
	if amount <= 0:
		return
	credits += amount
	Wallet.set_machine_credits(machine_name, credits)
	_update_credit_label()


func add_wallet_bonus(amount: int) -> void:
	if amount <= 0:
		return
	Wallet.add_money(amount)


func exit_play_mode() -> void:
	if not playing:
		return
	exit_hint_timer.stop()
	ArcadeAudio.play(self, "exit")
	playing = false
	if camera: camera.current = false
	if player:
		player.set_physics_process(true)
		player.set_process_unhandled_input(true)
	_update_credit_label()
	_refresh_label()
