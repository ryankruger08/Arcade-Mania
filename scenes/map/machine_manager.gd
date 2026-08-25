extends Area3D

@export var machine_name: String = "machine"
@export var player: CharacterBody3D 
@export var camera: Camera3D
@export var label: Label 
@export var gamemanager: Node

var playready = false
var playing = false

func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("play") and playready:
		if not playing:
			if camera: camera.current = true
			playing = true
			
			if player:
				player.set_physics_process(false) 
				player.set_process_unhandled_input(false)
			
			if gamemanager: gamemanager.start_match()
		else:
			# FIX: Only let them exit if they are NOT inside the menu screens
			if gamemanager and "is_selecting_players" in gamemanager and gamemanager.is_selecting_players:
				return # Let the Game Manager handle the input choice instead!
				
			if camera: camera.current = false
			playing = false
			
			if player:
				player.set_physics_process(true)
				player.set_process_unhandled_input(true)
				
			if gamemanager: gamemanager.end_match()

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
