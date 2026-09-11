extends Node
## GameManager.gd
##
## Autoload singleton — register this as "GameManager" in
## Project Settings > Autoload. It stays alive for the whole game session and
## is the one place every other script can safely talk to for global state:
## pause handling now, and (from Milestone 5 onward) mission/economy hooks.

signal game_paused
signal game_resumed
signal car_reset_requested

var is_paused: bool = false


func _ready() -> void:
	# Autoloads normally pause along with everything else when the tree is
	# paused. We want GameManager itself to keep working while paused (so the
	# Resume button's signal actually reaches us), so it's exempted here.
	process_mode = Node.PROCESS_MODE_ALWAYS


func toggle_pause() -> void:
	if is_paused:
		resume_game()
	else:
		pause_game()


func pause_game() -> void:
	if is_paused:
		return
	is_paused = true
	get_tree().paused = true
	game_paused.emit()


func resume_game() -> void:
	if not is_paused:
		return
	is_paused = false
	get_tree().paused = false
	game_resumed.emit()


func request_car_reset() -> void:
	car_reset_requested.emit()
