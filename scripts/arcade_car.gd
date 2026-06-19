extends RigidBody3D

# Quick tuning notes:
# - Faster acceleration: raise engine_force, then raise max_speed if it hits the cap too soon.
# - Tighter turning: raise steering_torque; lower it if the car spins too easily.
# - Less flipping: raise downforce or upright_strength, or lower steering_torque.
# - More drift: lower grip; Space also cuts grip for a stronger slide.
# - Stronger braking: raise brake_force.

@export var engine_force: float = 420.0
@export var reverse_force: float = 220.0
@export var brake_force: float = 620.0
@export var steering_torque: float = 145.0
@export var max_speed: float = 22.0
@export var grip: float = 13.0
@export var downforce: float = 14.0
@export var upright_strength: float = 38.0

var reset_position: Vector3


func _ready() -> void:
	reset_position = global_position
	can_sleep = false
	print("BrickCar scene loaded successfully.")


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if Input.is_action_just_pressed("reset_car"):
		reset_car(state)
		return

	var basis := state.transform.basis.orthonormalized()
	var forward := -basis.z.normalized()
	var right := basis.x.normalized()
	var up := basis.y.normalized()
	var velocity := state.linear_velocity
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var horizontal_speed := horizontal_velocity.length()
	var forward_speed := velocity.dot(forward)

	_apply_engine_and_brakes(forward, horizontal_velocity, horizontal_speed, forward_speed)
	_apply_steering(up, forward_speed, horizontal_speed, state)
	_apply_grip(right, velocity)
	_apply_speed_limit(horizontal_velocity, horizontal_speed)
	_apply_stability(up, horizontal_speed, state)


func _apply_engine_and_brakes(
	forward: Vector3,
	horizontal_velocity: Vector3,
	horizontal_speed: float,
	forward_speed: float
) -> void:
	var throttle := Input.get_action_strength("accelerate")
	var brake := Input.get_action_strength("brake")
	var handbrake_on := Input.is_action_pressed("handbrake")

	if throttle > 0.0 and forward_speed < max_speed:
		apply_central_force(forward * engine_force * throttle)

	if brake > 0.0:
		if forward_speed > 1.0:
			apply_central_force(-forward * brake_force * brake)
		elif forward_speed > -max_speed * 0.45:
			apply_central_force(-forward * reverse_force * brake)

	if handbrake_on and horizontal_speed > 0.2:
		apply_central_force(-horizontal_velocity.normalized() * brake_force * 0.35)


func _apply_steering(
	up: Vector3,
	forward_speed: float,
	horizontal_speed: float,
	state: PhysicsDirectBodyState3D
) -> void:
	var steer := Input.get_action_strength("steer_left") - Input.get_action_strength("steer_right")

	if absf(steer) < 0.01 or horizontal_speed < 0.4:
		return

	var speed_factor := clampf(horizontal_speed / max_speed, 0.25, 1.0)
	var yaw_damping := -state.angular_velocity.dot(Vector3.UP) * 8.0
	var direction_sign := 1.0
	if forward_speed < -0.2:
		direction_sign = -1.0

	apply_torque(up * steer * steering_torque * speed_factor * direction_sign)
	apply_torque(Vector3.UP * yaw_damping)


func _apply_grip(right: Vector3, velocity: Vector3) -> void:
	var lateral_speed := velocity.dot(right)
	var drift_multiplier := 1.0
	if Input.is_action_pressed("handbrake"):
		drift_multiplier = 0.22

	apply_central_force(-right * lateral_speed * grip * drift_multiplier * mass)


func _apply_speed_limit(horizontal_velocity: Vector3, horizontal_speed: float) -> void:
	if horizontal_speed <= max_speed:
		return

	var overspeed := horizontal_speed - max_speed
	apply_central_force(-horizontal_velocity.normalized() * overspeed * mass * 8.0)


func _apply_stability(up: Vector3, horizontal_speed: float, state: PhysicsDirectBodyState3D) -> void:
	if horizontal_speed > 0.1:
		apply_central_force(Vector3.DOWN * downforce * horizontal_speed)

	var tilt_axis := up.cross(Vector3.UP)
	if tilt_axis.length_squared() > 0.0001:
		apply_torque(tilt_axis * upright_strength)

	var yaw_velocity := Vector3.UP * state.angular_velocity.dot(Vector3.UP)
	var roll_pitch_velocity := state.angular_velocity - yaw_velocity
	apply_torque(-roll_pitch_velocity * upright_strength * 0.08)


func reset_car(state: PhysicsDirectBodyState3D) -> void:
	state.transform = Transform3D(Basis(), reset_position + Vector3.UP * 1.5)
	state.linear_velocity = Vector3.ZERO
	state.angular_velocity = Vector3.ZERO
