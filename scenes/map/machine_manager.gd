extends Area3D
@export var machine_name: String = "machine"
@export var player: CharacterBody3D 
@export var camera: Camera3D
@export var label: Label 
@export var credit_label: Label
@export var gamemanager: Node
var playready = false
var playing = false
var credits: int = 1
func _ready() -> void:
	_update_credit_label()
func _unhandled_input(event: InputEvent) -> void:
	if not playready:
		return
	if event.is_action_pressed("insert_coin") and not playing:
		if Wallet.spend_coin():
			credits += 1
			_update_credit_label()
			get_viewport().set_input_as_handled()
	if event.is_action_pressed("play"):
		if not playing:
			if credits <= 0:
				return
			credits -= 1
			_update_credit_label()
			if camera: camera.current = true
			playing = true
			
			if player:
				player.set_physics_process(false) 
				player.set_process_unhandled_input(false)
			
			if gamemanager: gamemanager.start_match()
			get_viewport().set_input_as_handled()
		else:
			if camera: camera.current = false
			playing = false
			
			if player:
				player.set_physics_process(true)
				player.set_process_unhandled_input(true)
				
			if gamemanager: gamemanager.end_match()
			get_viewport().set_input_as_handled()
func _update_credit_label() -> void:
	if credit_label:
		credit_label.text = "CREDIT " + str(credits)
func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D: 
		if label:
			label.visible = true
			label.text = "Press F To Play " + machine_name
		playready = true
func _on_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		if label:
			label.visible = false
		playready = false
