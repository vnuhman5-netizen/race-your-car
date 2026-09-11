extends CanvasLayer
class_name HUD
## HUD.gd
##
## Milestone 1 HUD: a speed readout plus a minimal pause overlay with Resume
## and Reset Car buttons. Listens for the pause/reset_car input actions and
## routes them through GameManager so any other script can react consistently.

@onready var speed_label: Label = $Control/SpeedLabel
@onready var pause_panel: Panel = $Control/PausePanel
@onready var resume_button: Button = $Control/PausePanel/VBoxContainer/ResumeButton
@onready var reset_button: Button = $Control/PausePanel/VBoxContainer/ResetButton

var car


func _ready() -> void:
	# Stay responsive while the game is paused, so the Resume button works.
	process_mode = Node.PROCESS_MODE_ALWAYS

	pause_panel.visible = false
	GameManager.game_paused.connect(_on_game_paused)
	GameManager.game_resumed.connect(_on_game_resumed)
	resume_button.pressed.connect(GameManager.resume_game)
	reset_button.pressed.connect(GameManager.request_car_reset)

	car = get_tree().get_first_node_in_group("player_car")
	if car:
		car.speed_changed.connect(_on_speed_changed)
	else:
		push_warning("HUD could not find a node in the 'player_car' group — is the Car node in that group?")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		GameManager.toggle_pause()
	elif event.is_action_pressed("reset_car"):
		GameManager.request_car_reset()


func _on_speed_changed(speed_kmh: float) -> void:
	speed_label.text = "%d km/h" % round(speed_kmh)


func _on_game_paused() -> void:
	pause_panel.visible = true


func _on_game_resumed() -> void:
	pause_panel.visible = false
