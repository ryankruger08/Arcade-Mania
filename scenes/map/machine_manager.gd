extends Area3D
@export var machine_name: String = "machine"
@export var player: CharacterBody3D 
@export var camera: Camera3D
@export var label: Label 
@export var credit_label: Label
@export var gamemanager: Node
var playready = false
var coin_ready = false
var start_ready = false
var playing = false
var credits: int = 0
var credit_flash_timer: Timer
func _ready() -> void:
	_setup_credit_flash_timer()
	_update_credit_label()
func _setup_credit_flash_timer() -> void:
	credit_flash_timer = Timer.new()
	credit_flash_timer.wait_time = 0.5
	credit_flash_timer.timeout.connect(_on_credit_flash_timeout)
	add_child(credit_flash_timer)
	credit_flash_timer.start()
func _on_credit_flash_timeout() -> void:
	if playing or not credit_label:
		return
	if credits <= 0:
		credit_label.visible = !credit_label.visible
func _update_credit_label() -> void:
	if not credit_label:
		return
	if playing:
		credit_label.visible = false
		return
	if credits <= 0:
		credit_label.text = "INSERT COIN"
		credit_label.visible = true
	else:
		credit_label.visible = true
		credit_label.text = "CREDIT " + str(credits)
func _refresh_label() -> void:
	if not label:
		return
	if playing:
		label.visible = playready
		label.text = "Press Play To Stop"
	elif start_ready:
		label.visible = true
		label.text = "Press Play To Start " + machine_name
	elif coin_ready:
		label.visible = true
		label.text = "Press Insert Coin"
	else:
		label.visible = false
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("insert_coin") and coin_ready and not playing:
		if Wallet.spend_coin():
			credits += 1
			_update_credit_label()
			get_viewport().set_input_as_handled()
	if event.is_action_pressed("remove_credit") and coin_ready and not playing and credits > 0:
		credits -= 1
		Wallet.add_coins(1)
		_update_credit_label()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("play"):
		if not playing and start_ready and credits > 0:
			credits -= 1
			_update_credit_label()
			if camera: camera.current = true
			playing = true
			if player:
				player.set_physics_process(false)
				player.set_process_unhandled_input(false)
			if gamemanager: gamemanager.start_match()
			_refresh_label()
			get_viewport().set_input_as_handled()
		elif playing:
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
