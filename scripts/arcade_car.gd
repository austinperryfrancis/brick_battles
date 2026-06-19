extends VehicleBody3D

# Quick tuning notes:
# - Faster acceleration: raise engine_force_value, then raise max_speed if it hits the cap too soon.
# - Tighter turning: raise steering_limit or steering_response; lower them if it twitches.
# - Less flipping: lower wheel_roll_influence in BrickCar.tscn, or lower center_of_mass there.
# - More grip: raise wheel_friction_slip on the VehicleWheel3D nodes in BrickCar.tscn.
# - Stronger braking: raise brake_force.
# - Less jump launch: lower max_jump_up_speed or raise extra_air_gravity/ground_stick_force.

@export var engine_force_value: float = 120.0
@export var reverse_force: float = 65.0
@export var brake_force: float = 8.5
@export var steering_limit: float = 0.42
@export var steering_response: float = 2.8
@export var max_speed: float = 24.0
@export var low_speed_boost: float = 2.4
@export var ground_stick_force: float = 8.0
@export var extra_air_gravity: float = 12.0
@export var max_jump_up_speed: float = 4.5
@export var air_angular_damping: float = 1.6

var reset_position: Vector3
var _wheels: Array[VehicleWheel3D] = []


func _ready() -> void:
	reset_position = global_position
	can_sleep = false
	_wheels.assign(find_children("*", "VehicleWheel3D", false, false))
	print("BrickCar VehicleBody scene loaded successfully.")


func _physics_process(delta: float) -> void:
	var grounded := _get_grounded_wheel_count() > 0
	var speed := linear_velocity.length()
	var forward_speed := linear_velocity.dot(global_transform.basis.z)

	_update_drive(speed, forward_speed, grounded)
	_update_steering(delta, speed, grounded)

	if grounded and speed > 0.5:
		apply_central_force(Vector3.DOWN * ground_stick_force * speed)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if Input.is_action_just_pressed("reset_car"):
		reset_car(state)
		return

	if _get_grounded_wheel_count() > 0:
		return

	var velocity := state.linear_velocity
	if velocity.y > max_jump_up_speed:
		velocity.y = max_jump_up_speed

	velocity += Vector3.DOWN * extra_air_gravity * state.step
	state.linear_velocity = velocity
	state.angular_velocity = state.angular_velocity.lerp(Vector3.ZERO, air_angular_damping * state.step)


func _update_drive(speed: float, forward_speed: float, grounded: bool) -> void:
	if not grounded:
		engine_force = 0.0
		brake = 0.0
		return

	var throttle := Input.get_action_strength("accelerate")
	var brake_input := Input.get_action_strength("brake")
	var handbrake_on := Input.is_action_pressed("handbrake")

	engine_force = 0.0
	brake = 0.0

	if throttle > 0.0 and speed < max_speed:
		engine_force = _scaled_engine_force(engine_force_value, speed) * throttle

	if brake_input > 0.0:
		if forward_speed > 1.0:
			brake = brake_force * brake_input
		elif speed < max_speed * 0.45:
			engine_force = -_scaled_engine_force(reverse_force, speed) * brake_input

	if handbrake_on:
		brake = maxf(brake, brake_force * 1.4)


func _update_steering(delta: float, speed: float, grounded: bool) -> void:
	var steer_input := Input.get_action_strength("steer_left") - Input.get_action_strength("steer_right")
	var target_steering := 0.0

	if grounded:
		var speed_factor := clampf(speed / max_speed, 0.0, 1.0)
		var high_speed_limit := lerpf(steering_limit, steering_limit * 0.55, speed_factor)
		target_steering = steer_input * high_speed_limit

	steering = move_toward(steering, target_steering, steering_response * delta)


func _scaled_engine_force(base_force: float, speed: float) -> float:
	if speed < 0.1:
		return base_force * low_speed_boost
	if speed < 5.0:
		return clampf(base_force * 5.0 / speed, base_force, base_force * low_speed_boost)
	return base_force


func _get_grounded_wheel_count() -> int:
	var count := 0
	for wheel in _wheels:
		if wheel.is_in_contact():
			count += 1
	return count


func reset_car(state: PhysicsDirectBodyState3D) -> void:
	state.transform = Transform3D(Basis(), reset_position + Vector3.UP * 1.5)
	state.linear_velocity = Vector3.ZERO
	state.angular_velocity = Vector3.ZERO
	engine_force = 0.0
	brake = 0.0
	steering = 0.0
