extends RigidBody3D
class_name Car
## Car.gd
##
## Arcade-style car controller. The car IS a RigidBody3D (so it collides
## properly with the world, traffic, and pedestrians later on), but instead of
## simulating real wheel/suspension physics — which is fiddly to tune and easy
## to get feeling floaty or twitchy in Godot's VehicleBody3D — we drive it
## directly through linear_velocity / angular_velocity each physics step. This
## is the simplest approach that (a) still respects the physics engine for
## collisions and (b) is easy to hand-tune for a fun, forgiving arcade feel.
##
## Requires 4 RayCast3D children (grouped under a "WheelRays" Node3D) pointing
## downward near each wheel corner, used only to check "is the car on the
## ground" so it doesn't accelerate/steer while airborne.

signal speed_changed(speed_kmh: float)

@export_group("Speed")
@export var max_forward_speed: float = 22.0   ## m/s (~79 km/h)
@export var max_reverse_speed: float = 8.0    ## m/s
@export var acceleration: float = 14.0        ## m/s^2
@export var braking_power: float = 24.0       ## m/s^2
@export var coast_deceleration: float = 6.0   ## m/s^2, rolling resistance with no input

@export_group("Steering")
@export var max_turn_rate: float = 1.8        ## rad/s achievable at max speed
@export var min_speed_to_steer: float = 0.3   ## m/s, avoids spinning in place
@export var steer_smoothing: float = 6.0      ## higher = snappier turn-in

var forward_speed: float = 0.0                ## signed: positive = forward, negative = reverse
var is_grounded: bool = true

@onready var ground_rays: Array[RayCast3D] = [
	$WheelRays/FL as RayCast3D,
	$WheelRays/FR as RayCast3D,
	$WheelRays/RL as RayCast3D,
	$WheelRays/RR as RayCast3D,
]


func _ready() -> void:
	GameManager.car_reset_requested.connect(_on_reset_requested)
	# Keep the arcade car flat on the road instead of tipping or barrel-rolling.
	axis_lock_angular_x = true
	axis_lock_angular_z = true


func _physics_process(delta: float) -> void:
	_update_grounded()

	var throttle := Input.get_action_strength("move_forward") - Input.get_action_strength("move_backward")
	var steer := Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")
	var braking := Input.is_action_pressed("brake")

	_update_speed(throttle, braking, delta)
	_update_steering(steer, delta)
	_apply_horizontal_velocity()

	speed_changed.emit(get_speed_kmh())


func _update_grounded() -> void:
	is_grounded = false
	for ray in ground_rays:
		if ray.is_colliding():
			is_grounded = true
			break


func _update_speed(throttle: float, braking: bool, delta: float) -> void:
	if not is_grounded:
		return  # no traction in the air

	if braking:
		forward_speed = move_toward(forward_speed, 0.0, braking_power * delta)
	elif throttle > 0.01:
		forward_speed = min(forward_speed + acceleration * throttle * delta, max_forward_speed)
	elif throttle < -0.01:
		forward_speed = max(forward_speed + acceleration * throttle * delta, -max_reverse_speed)
	else:
		forward_speed = move_toward(forward_speed, 0.0, coast_deceleration * delta)


func _update_steering(steer: float, delta: float) -> void:
	var target_angular_speed := 0.0
	if abs(forward_speed) > min_speed_to_steer and is_grounded:
		var speed_ratio: float = clamp(abs(forward_speed) / max_forward_speed, 0.15, 1.0)
		var direction_sign: float = sign(forward_speed)
		target_angular_speed = -steer * max_turn_rate * speed_ratio * direction_sign

	angular_velocity.y = move_toward(angular_velocity.y, target_angular_speed, steer_smoothing * delta)


func _apply_horizontal_velocity() -> void:
	var forward_dir := -global_transform.basis.z
	var horizontal := forward_dir * forward_speed
	linear_velocity.x = horizontal.x
	linear_velocity.z = horizontal.z
	# linear_velocity.y is left alone so gravity keeps working normally.


func get_speed_kmh() -> float:
	return abs(forward_speed) * 3.6


func _on_reset_requested() -> void:
	global_position = Vector3(0, 1.0, 0)
	rotation = Vector3.ZERO
	forward_speed = 0.0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
