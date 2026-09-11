extends Node3D
class_name CameraRig
## CameraRig.gd
##
## Smooth third-person follow camera. This node is a SIBLING of the car, not a
## child — if it were parented to the car it would inherit the car's snappy
## rotation directly and feel jittery. Instead, each physics frame it
## lerps/slerps its own transform toward an "ideal" position and orientation
## behind the target, which gives the classic smoothed chase-cam feel.

@export var target_path: NodePath
@export var follow_distance: float = 6.5
@export var follow_height: float = 3.0
@export var look_ahead_height: float = 1.0
@export var position_smoothing: float = 5.0
@export var rotation_smoothing: float = 4.0

@onready var camera: Camera3D = $Camera3D

var target: Node3D


func _ready() -> void:
	if target_path != NodePath():
		target = get_node(target_path)
	else:
		push_warning("CameraRig has no target_path set — assign it in the Inspector.")


func _physics_process(delta: float) -> void:
	if target == null:
		return

	# The car faces -Z, so +Z (in the car's local space) is "behind" it.
	var behind_dir := target.global_transform.basis.z
	var desired_position := target.global_position + behind_dir * follow_distance + Vector3.UP * follow_height
	global_position = global_position.lerp(desired_position, 1.0 - exp(-position_smoothing * delta))

	var look_target := target.global_position + Vector3.UP * look_ahead_height
	var desired_transform := global_transform.looking_at(look_target, Vector3.UP)
	global_transform.basis = global_transform.basis.slerp(desired_transform.basis, 1.0 - exp(-rotation_smoothing * delta))
