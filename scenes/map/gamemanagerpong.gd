extends Area3D

@export var machine = str("machine")
@export var player = CharacterBody3D
@export var camera = Camera3D
@export var label = Label
@export var gamemanager = Node
var playready = false

func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("play") and playready == true:
		camera.current = true
		player.playing = true
		gamemanager.playing = true


func _on_body_entered(body: Node3D) -> void:
	label.visible = true
	label.text = str("Press F To Play ", machine)
	playready = true


func _on_body_exited(body: Node3D) -> void:
	label.visible = false
	playready = false
