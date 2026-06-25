extends VehicleBody3D

signal inventory_changed(inventory: Dictionary)
signal item_collected(item_id: String, display_name: String, count: int)
signal item_used(item_id: String, display_name: String)

# Quick tuning notes:
# - Faster acceleration: raise engine_force_value, then raise max_speed if it hits the cap too soon.
# - Tighter turning: raise steering_limit or steering_response; lower them if it twitches.
# - Less flipping: lower wheel_roll_influence in BrickCar.tscn, or lower center_of_mass there.
# - More grip: raise wheel_friction_slip on the VehicleWheel3D nodes in BrickCar.tscn.
# - Stronger braking: raise brake_force.
# - Faster coast-down after releasing gas: raise coast_deceleration or rolling_deceleration.
# - Less jump launch: lower max_jump_up_speed or raise extra_air_gravity/ground_stick_force.
# - Less body lean in turns: raise grounded_upright_strength or pitch_roll_damping.

@export var engine_force_value: float = 250.0
@export var reverse_force: float = 65.0
@export var brake_force: float = 8.5
@export var steering_limit: float = 0.38
@export var steering_response: float = 3.0
@export var max_speed: float = 40.0
@export var low_speed_boost: float = 4.0
@export var rolling_deceleration: float = 1.0
@export var coast_deceleration: float = 3.2
@export var ground_stick_force: float = 8.0
@export var extra_air_gravity: float = 4.0
@export var max_jump_up_speed: float = 7.0
@export var air_angular_damping: float = 1.0
@export var grounded_upright_strength: float = 3600.0
@export var pitch_roll_damping: float = 650.0
@export var bullet_scene: PackedScene
@export var muzzle_path: NodePath = ^"Muzzle"
@export var weapon_mount_path: NodePath = ^"WeaponMounts/PrimaryMount"
@export var rocket_launch_path: NodePath = ^"WeaponMounts/PrimaryMount/RocketLaunchPoint"
@export var bullet_speed: float = 300.0
@export var bullet_impact_force: float = 35.0
@export var burst_count: int = 3
@export var burst_interval: float = 0.09
@export var burst_cooldown: float = 0.35
@export var minigun_burst_count: int = 50
@export var minigun_burst_interval: float = 0.035
@export var minigun_bullet_speed: float = 360.0
@export var minigun_bullet_impact_force: float = 28.0
@export var rocket_scene: PackedScene
@export var rocket_speed: float = 42.0
@export var rocket_explosion_radius: float = 7.0
@export var rocket_explosion_force: float = 190.0
@export var rocket_mount_visual_scene: PackedScene
@export var grenade_launcher_visual_scene: PackedScene
@export var grenade_scene: PackedScene
@export var grenade_forward_speed: float = 24.0
@export var grenade_upward_speed: float = 5.0
@export var grenade_gravity: float = 20.0
@export var grenade_fuse_time: float = 2.5
@export var grenade_explosion_radius: float = 5.5
@export var grenade_explosion_force: float = 140.0
@export var grenade_max_bounces: int = 4
@export var grenade_bounce_damping: float = 0.65
@export var grenade_min_bounce_speed: float = 4.0

var reset_position: Vector3
var _wheels: Array[VehicleWheel3D] = []
var _muzzle: Marker3D
var _weapon_mount: Marker3D
var _rocket_launch_point: Marker3D
var _mounted_weapon_visual: Node3D
var _burst_shots_remaining := 0
var _burst_timer := 0.0
var _cooldown_timer := 0.0
var _active_burst_interval := 0.09
var _active_bullet_speed := 300.0
var _active_bullet_impact_force := 35.0
var inventory: Dictionary = {}


func _ready() -> void:
	reset_position = global_position
	can_sleep = false
	_wheels.assign(find_children("*", "VehicleWheel3D", false, false))
	_muzzle = get_node_or_null(muzzle_path) as Marker3D
	_weapon_mount = get_node_or_null(weapon_mount_path) as Marker3D
	_rocket_launch_point = get_node_or_null(rocket_launch_path) as Marker3D
	print("BrickCar VehicleBody scene loaded successfully.")


func _physics_process(delta: float) -> void:
	var grounded := _get_grounded_wheel_count() > 0
	var speed := linear_velocity.length()
	var forward_speed := linear_velocity.dot(global_transform.basis.z)

	_update_drive(speed, forward_speed, grounded)
	_update_steering(delta, speed, grounded)
	_update_weapon(delta)
	_update_inventory_item()
	_apply_grounded_stability(grounded)
	_apply_ground_drag(grounded)

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
		var high_speed_limit := lerpf(steering_limit, steering_limit * 0.35, speed_factor)
		target_steering = steer_input * high_speed_limit

	steering = move_toward(steering, target_steering, steering_response * delta)


func _scaled_engine_force(base_force: float, speed: float) -> float:
	if speed < 0.1:
		return base_force * low_speed_boost
	if speed < 5.0:
		return clampf(base_force * 5.0 / speed, base_force, base_force * low_speed_boost)
	return base_force


func _update_weapon(delta: float) -> void:
	_cooldown_timer = maxf(_cooldown_timer - delta, 0.0)

	if Input.is_action_just_pressed("fire") and _cooldown_timer <= 0.0 and _burst_shots_remaining <= 0:
		_start_bullet_burst(burst_count, burst_interval, bullet_speed, bullet_impact_force)
		_cooldown_timer = burst_cooldown

	if _burst_shots_remaining <= 0:
		return

	_burst_timer -= delta
	if _burst_timer > 0.0:
		return

	_fire_bullet()
	_burst_shots_remaining -= 1
	_burst_timer = _active_burst_interval


func _fire_bullet() -> void:
	if bullet_scene == null or _muzzle == null:
		return

	var bullet := bullet_scene.instantiate()
	var bullet_parent := get_tree().current_scene
	if bullet_parent == null:
		bullet_parent = get_parent()
	bullet_parent.add_child(bullet)
	bullet.global_transform = _muzzle.global_transform

	var forward := global_transform.basis.z.normalized()
	bullet.speed = _active_bullet_speed
	bullet.impact_force = _active_bullet_impact_force
	if bullet.has_method("launch"):
		bullet.launch(forward, linear_velocity)


func _start_bullet_burst(count: int, interval: float, speed: float, impact_force: float) -> bool:
	if bullet_scene == null or _muzzle == null or _burst_shots_remaining > 0:
		return false

	_burst_shots_remaining = maxi(count, 1)
	_burst_timer = 0.0
	_active_burst_interval = maxf(interval, 0.01)
	_active_bullet_speed = speed
	_active_bullet_impact_force = impact_force
	return true


func _update_inventory_item() -> void:
	if Input.is_action_just_pressed("use_item"):
		use_inventory_item()


func use_inventory_item() -> bool:
	if inventory.is_empty():
		return false

	var item_id := str(inventory.keys()[0])
	var display_name := str(inventory[item_id].get("display_name", item_id.capitalize()))

	match item_id:
		"minigun":
			if not _start_bullet_burst(
				minigun_burst_count,
				minigun_burst_interval,
				minigun_bullet_speed,
				minigun_bullet_impact_force
			):
				return false
		"rocket":
			if not _fire_rocket():
				return false
		"grenade_launcher":
			if not _fire_grenade():
				return false
		_:
			return false

	var item_data := inventory[item_id] as Dictionary
	var remaining_count := int(item_data.get("count", 1)) - 1
	if remaining_count > 0:
		item_data["count"] = remaining_count
		inventory[item_id] = item_data
	else:
		inventory.clear()

	if inventory.is_empty():
		_clear_mounted_weapon_visual()

	item_used.emit(item_id, display_name)
	inventory_changed.emit(inventory.duplicate())
	return true


func _fire_rocket() -> bool:
	var launch_point := _rocket_launch_point
	if launch_point == null:
		launch_point = _muzzle

	if rocket_scene == null or launch_point == null:
		return false

	var rocket := rocket_scene.instantiate()
	var rocket_parent := get_tree().current_scene
	if rocket_parent == null:
		rocket_parent = get_parent()
	rocket_parent.add_child(rocket)
	rocket.global_transform = launch_point.global_transform

	var forward := global_transform.basis.z.normalized()
	rocket.speed = rocket_speed
	rocket.explosion_radius = rocket_explosion_radius
	rocket.explosion_force = rocket_explosion_force
	if rocket.has_method("launch"):
		rocket.launch(forward, linear_velocity)
	return true


func _fire_grenade() -> bool:
	if grenade_scene == null or _muzzle == null:
		return false

	var grenade := grenade_scene.instantiate()
	var grenade_parent := get_tree().current_scene
	if grenade_parent == null:
		grenade_parent = get_parent()
	grenade_parent.add_child(grenade)
	grenade.global_transform = _muzzle.global_transform

	var forward := global_transform.basis.z.normalized()
	grenade.forward_speed = grenade_forward_speed
	grenade.upward_speed = grenade_upward_speed
	grenade.arc_gravity = grenade_gravity
	grenade.fuse_time = grenade_fuse_time
	grenade.explosion_radius = grenade_explosion_radius
	grenade.explosion_force = grenade_explosion_force
	grenade.max_bounces = grenade_max_bounces
	grenade.bounce_damping = grenade_bounce_damping
	grenade.min_bounce_speed = grenade_min_bounce_speed
	if grenade.has_method("launch"):
		grenade.launch(forward, linear_velocity)
	return true


func _apply_grounded_stability(grounded: bool) -> void:
	if not grounded:
		return

	var grounded_ratio := clampf(float(_get_grounded_wheel_count()) / 4.0, 0.25, 1.0)
	var up := global_transform.basis.y.normalized()
	var tilt_axis := up.cross(Vector3.UP)

	if tilt_axis.length_squared() > 0.0001:
		apply_torque(tilt_axis * grounded_upright_strength * grounded_ratio)

	var yaw_velocity := Vector3.UP * angular_velocity.dot(Vector3.UP)
	var pitch_roll_velocity := angular_velocity - yaw_velocity
	apply_torque(-pitch_roll_velocity * pitch_roll_damping * grounded_ratio)


func _apply_ground_drag(grounded: bool) -> void:
	if not grounded:
		return

	var horizontal_velocity := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	var horizontal_speed := horizontal_velocity.length()
	if horizontal_speed < 0.1:
		return

	var throttle := Input.get_action_strength("accelerate")
	var brake_input := Input.get_action_strength("brake")
	var deceleration := rolling_deceleration
	if throttle < 0.05 and brake_input < 0.05:
		deceleration += coast_deceleration

	apply_central_force(-horizontal_velocity.normalized() * deceleration * mass)


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


func add_inventory_item(item_id: String, display_name: String = "", item_count: int = 1) -> bool:
	if not inventory.is_empty():
		return false

	if display_name.is_empty():
		display_name = item_id.capitalize()

	var clamped_count := maxi(item_count, 1)
	inventory[item_id] = {
		"display_name": display_name,
		"count": clamped_count,
	}
	_update_mounted_weapon_visual(item_id)

	item_collected.emit(item_id, display_name, clamped_count)
	inventory_changed.emit(inventory.duplicate())
	return true


func get_inventory_count(item_id: String) -> int:
	if not inventory.has(item_id):
		return 0

	return int(inventory[item_id].get("count", 0))


func _update_mounted_weapon_visual(item_id: String) -> void:
	match item_id:
		"rocket":
			_mount_weapon_visual(rocket_mount_visual_scene)
		"grenade_launcher":
			_mount_weapon_visual(grenade_launcher_visual_scene)
		_:
			_clear_mounted_weapon_visual()


func _mount_weapon_visual(scene: PackedScene) -> void:
	_clear_mounted_weapon_visual()

	if scene == null or _weapon_mount == null:
		return

	var visual := scene.instantiate() as Node3D
	if visual == null:
		return

	_weapon_mount.add_child(visual)
	visual.transform = Transform3D.IDENTITY
	_mounted_weapon_visual = visual


func _clear_mounted_weapon_visual() -> void:
	if _mounted_weapon_visual == null:
		return

	_mounted_weapon_visual.queue_free()
	_mounted_weapon_visual = null
