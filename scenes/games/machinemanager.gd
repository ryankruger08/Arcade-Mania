extends Area3D

# Generic arcade machine controller - reusable across every machine.
# Once the player presses "play", this hands full control over to
# "gamemanager", which owns everything shown on the cabinet's screen
# (menus, gameplay, scoring). gamemanager must implement:
#   enter_machine() -> void      # called when the player presses "play"
#   signal exited                # emitted when the player backs out / quits,
#                                 # so the machine can hand control back

@export var machine: String = "machine"
@export var player: CharacterBody3D
@export var camera: Camera3D
@export var label: Label # world "Press F To Play" prompt, separate from the cabinet screen
@export var gamemanager: Node
@export var attract_sound: AudioStreamPlayer3D # assign a looping stream in the Inspector, set it to loop

enum State { ATTRACT, READY, ACTIVE }

var state: State = State.ATTRACT
var player_in_range: bool = false

func _ready() -> void:
	_enter_attract()
	if gamemanager and gamemanager.has_signal("exited"):
		gamemanager.exited.connect(_on_gamemanager_exited)

func _unhandled_input(event: InputEvent) -> void:
	if state == State.READY and Input.is_action_just_pressed("play"):
		_enter_active()

func _enter_attract() -> void:
	state = State.ATTRACT
	label.visible = false
	if attract_sound and not attract_sound.playing:
		attract_sound.play()

func _enter_ready() -> void:
	state = State.READY
	if attract_sound and attract_sound.playing:
		attract_sound.stop()
	label.visible = true
	label.text = str("Press F To Play ", machine)

func _enter_active() -> void:
	state = State.ACTIVE
	camera.current = true
	player.playing = true
	label.visible = false
	gamemanager.enter_machine()

func _on_gamemanager_exited() -> void:
	camera.current = false
	player.playing = false
	if player_in_range:
		_enter_ready()
	else:
		_enter_attract()

func _on_body_entered(body: Node3D) -> void:
	if body != player:
		return
	player_in_range = true
	if state == State.ATTRACT:
		_enter_ready()

func _on_body_exited(body: Node3D) -> void:
	if body != player:
		return
	player_in_range = false
	if state == State.READY:
		_enter_attract()
