extends RigidBody3D

signal inventory_changed(inventory: Dictionary)
signal item_collected(item_id: String, display_name: String, count: int)
signal item_used(item_id: String, display_name: String)

# Quick tuning notes:
# - Faster acceleration: raise engine_acceleration, then raise max_speed if it hits the cap too soon.
# - Tighter turning: raise max_turn_rate/high_speed_turn_rate; lower yaw_response if it snaps too hard.
# - More sideways grip: raise lateral_grip; lower handbrake_lateral_grip for looser slides.
# - Stronger suspension: raise suspension_strength; raise suspension_damping if it bounces.
# - Less flipping: lower center_of_mass in BrickCar.tscn or raise grounded_upright_strength.
# - Airborne wings: lower wing_max_fall_speed for more float, raise it for faster drops.

@export var max_speed: float = 48.0
@export var max_reverse_speed: float = 16.0
@export var engine_acceleration: float = 34.0
@export var reverse_acceleration: float = 16.0
@export var brake_deceleration: float = 38.0
@export var handbrake_deceleration: float = 8.0
@export var low_speed_boost: float = 1.35
@export var rolling_deceleration: float = 0.5
@export var coast_deceleration: float = 2.2
@export var lateral_grip: float = 6.5
@export var handbrake_lateral_grip: float = 2.0
@export var max_turn_rate: float = 1.9
@export var high_speed_turn_rate: float = 1.05
@export var steering_response: float = 5.5
@export var steering_return_response: float = 8.0
@export var yaw_response: float = 7.0
@export var minimum_turn_authority: float = 0.28
@export var steering_sign: float = 1.0
@export var no_steer_yaw_damping: float = 4.0
@export var wheel_ray_length: float = 0.85
@export var suspension_rest_length: float = 0.45
@export var suspension_strength: float = 34.0
@export var suspension_damping: float = 6.5
@export var grounded_upright_strength: float = 18.0
@export var pitch_roll_damping: float = 7.0
@export var extra_air_gravity: float = 4.0
@export var max_jump_up_speed: float = 7.0
@export var air_angular_damping: float = 1.0
@export var bullet_scene: PackedScene
@export var muzzle_path: NodePath = ^"Muzzle"
@export var weapon_mount_path: NodePath = ^"WeaponMounts/PrimaryMount"
@export var rocket_launch_path: NodePath = ^"WeaponMounts/PrimaryMount/RocketLaunchPoint"
@export var wing_input_action: StringName = &"handbrake"
@export var left_wing_mount_path: NodePath = ^"WingMounts/LeftWingMount"
@export var right_wing_mount_path: NodePath = ^"WingMounts/RightWingMount"
@export var wing_visual_scene: PackedScene
@export var wing_deploy_speed: float = 8.0
@export var wing_retract_speed: float = 12.0
@export var wing_max_fall_speed: float = 6.0
@export var wing_descent_brake: float = 35.0
@export var wing_extra_gravity_scale: float = 0.2
@export var wing_air_angular_damping: float = 2.4
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
var _wheel_probes: Array[RayCast3D] = []
var _front_wheel_probes: Array[RayCast3D] = []
var _rear_wheel_probes: Array[RayCast3D] = []
var _grounded_wheel_count := 0
var _grounded_ratio := 0.0
var _ground_normal := Vector3.UP
var _grounded := false
var _forward_speed := 0.0
var _side_speed := 0.0
var _horizontal_speed := 0.0
var _steering_amount := 0.0
var _muzzle: Marker3D
var _weapon_mount: Marker3D
var _rocket_launch_point: Marker3D
var _mounted_weapon_visual: Node3D
var _left_wing_mount: Marker3D
var _right_wing_mount: Marker3D
var _left_wing_visual: Node3D
var _right_wing_visual: Node3D
var _wing_deploy_amount := 0.0
var _wings_active := false
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
	_wheel_probes.assign(find_children("*", "RayCast3D", false, false))
	_assign_wheel_probes()
	_configure_wheel_probes()
	_muzzle = get_node_or_null(muzzle_path) as Marker3D
	_weapon_mount = get_node_or_null(weapon_mount_path) as Marker3D
	_rocket_launch_point = get_node_or_null(rocket_launch_path) as Marker3D
	_left_wing_mount = get_node_or_null(left_wing_mount_path) as Marker3D
	_right_wing_mount = get_node_or_null(right_wing_mount_path) as Marker3D
	print("BrickCar RigidBody raycast scene loaded successfully.")


func _physics_process(delta: float) -> void:
	_update_ground_probe_state()
	_update_drive_state()
	_apply_suspension_forces()
	_apply_drive_forces()
	_update_arcade_steering(delta)
	_apply_grounded_stability(_grounded)
	_apply_ground_drag(_grounded)
	_update_weapon(delta)
	_update_inventory_item()
	_update_wings(delta, _grounded)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if Input.is_action_just_pressed("reset_car"):
		reset_car(state)
		return

	if _grounded:
		return

	var wings_active := _is_wing_input_active()
	var velocity := state.linear_velocity
	if velocity.y > max_jump_up_speed:
		velocity.y = max_jump_up_speed

	var extra_gravity_scale := wing_extra_gravity_scale if wings_active else 1.0
	velocity += Vector3.DOWN * extra_air_gravity * extra_gravity_scale * state.step
	if wings_active and velocity.y < -wing_max_fall_speed:
		velocity.y = move_toward(velocity.y, -wing_max_fall_speed, wing_descent_brake * state.step)

	state.linear_velocity = velocity
	var angular_damping := wing_air_angular_damping if wings_active else air_angular_damping
	state.angular_velocity = state.angular_velocity.lerp(
		Vector3.ZERO,
		clampf(angular_damping * state.step, 0.0, 1.0)
	)


func _update_drive_state() -> void:
	var horizontal_velocity := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	var forward := global_transform.basis.z.normalized()
	var right := global_transform.basis.x.normalized()

	_horizontal_speed = horizontal_velocity.length()
	_forward_speed = horizontal_velocity.dot(forward)
	_side_speed = horizontal_velocity.dot(right)


func _update_ground_probe_state() -> void:
	_grounded_wheel_count = 0
	_ground_normal = Vector3.ZERO

	for probe in _wheel_probes:
		probe.force_raycast_update()
		if probe.is_colliding():
			_grounded_wheel_count += 1
			_ground_normal += probe.get_collision_normal()

	_grounded = _grounded_wheel_count > 0
	_grounded_ratio = clampf(float(_grounded_wheel_count) / maxf(float(_wheel_probes.size()), 1.0), 0.0, 1.0)

	if _grounded and _ground_normal.length_squared() > 0.0001:
		_ground_normal = _ground_normal.normalized()
	else:
		_ground_normal = Vector3.UP


func _apply_suspension_forces() -> void:
	if _wheel_probes.is_empty():
		return

	var rest_length := maxf(suspension_rest_length, 0.01)

	for probe in _wheel_probes:
		if not probe.is_colliding():
			continue

		var hit_normal := probe.get_collision_normal().normalized()
		var hit_distance := probe.global_position.distance_to(probe.get_collision_point())
		var compression := clampf((wheel_ray_length - hit_distance) / rest_length, 0.0, 1.0)
		var force_offset := probe.global_position - global_position
		var point_velocity := linear_velocity + angular_velocity.cross(force_offset)
		var spring_velocity := point_velocity.dot(hit_normal)
		var force_amount := (compression * suspension_strength - spring_velocity * suspension_damping) * mass

		if force_amount > 0.0:
			apply_force(hit_normal * force_amount, force_offset)


func _apply_drive_forces() -> void:
	if not _grounded:
		return

	var throttle := Input.get_action_strength("accelerate")
	var brake_input := Input.get_action_strength("brake")
	var handbrake_on := Input.is_action_pressed("handbrake")
	var horizontal_velocity := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	var forward := global_transform.basis.z.normalized()
	var right := global_transform.basis.x.normalized()
	var speed_ratio := clampf(maxf(_forward_speed, 0.0) / maxf(max_speed, 0.01), 0.0, 1.0)

	if throttle > 0.0 and _forward_speed < max_speed:
		var throttle_curve := lerpf(low_speed_boost, 0.25, speed_ratio)
		apply_central_force(forward * engine_acceleration * throttle_curve * throttle * mass)

	if brake_input > 0.0:
		if _forward_speed > 1.0:
			apply_central_force(-forward * brake_deceleration * brake_input * mass)
		elif _forward_speed > -max_reverse_speed:
			apply_central_force(-forward * reverse_acceleration * brake_input * mass)

	if handbrake_on and horizontal_velocity.length_squared() > 0.01:
		apply_central_force(-horizontal_velocity.normalized() * handbrake_deceleration * mass)

	var grip := handbrake_lateral_grip if handbrake_on else lateral_grip
	apply_central_force(-right * _side_speed * grip * mass * _grounded_ratio)


func _update_arcade_steering(delta: float) -> void:
	var steer_input := _get_steer_input()
	var response := steering_response if absf(steer_input) > absf(_steering_amount) else steering_return_response
	_steering_amount = move_toward(_steering_amount, steer_input, response * delta)

	if not _grounded:
		return

	var yaw_axis := _ground_normal
	var current_yaw := angular_velocity.dot(yaw_axis)

	if absf(_steering_amount) < 0.04:
		var damping := clampf(no_steer_yaw_damping * delta, 0.0, 1.0)
		angular_velocity -= yaw_axis * current_yaw * damping
		return

	var speed_factor := clampf(absf(_forward_speed) / maxf(max_speed, 0.01), 0.0, 1.0)
	var speed_authority := clampf(absf(_forward_speed) / 6.0, 0.0, 1.0)
	var turn_authority := lerpf(minimum_turn_authority, 1.0, speed_authority)
	var reverse_sign := -1.0 if _forward_speed < -0.5 else 1.0
	var target_turn_rate := _steering_amount * lerpf(max_turn_rate, high_speed_turn_rate, speed_factor) * turn_authority * reverse_sign
	var new_yaw := move_toward(current_yaw, target_turn_rate, yaw_response * delta)
	angular_velocity += yaw_axis * (new_yaw - current_yaw)


func _get_steer_input() -> float:
	return (Input.get_action_strength("steer_left") - Input.get_action_strength("steer_right")) * steering_sign


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


func _update_wings(delta: float, grounded: bool) -> void:
	_wings_active = not grounded and _is_wing_input_active()
	var target_amount := 1.0 if _wings_active else 0.0
	var deploy_speed := wing_deploy_speed if target_amount > _wing_deploy_amount else wing_retract_speed
	_wing_deploy_amount = move_toward(_wing_deploy_amount, target_amount, deploy_speed * delta)

	if _wing_deploy_amount > 0.0 and _left_wing_visual == null and _right_wing_visual == null:
		_mount_wing_visuals()

	_apply_wing_visual_state()

	if _wing_deploy_amount <= 0.0 and not _wings_active:
		_clear_wing_visuals()


func _is_wing_input_active() -> bool:
	return Input.is_action_pressed(wing_input_action)


func _mount_wing_visuals() -> void:
	_clear_wing_visuals()

	if wing_visual_scene == null:
		return

	if _left_wing_mount != null:
		_left_wing_visual = _instantiate_wing_visual(_left_wing_mount)

	if _right_wing_mount != null:
		_right_wing_visual = _instantiate_wing_visual(_right_wing_mount)


func _instantiate_wing_visual(mount: Marker3D) -> Node3D:
	var visual := wing_visual_scene.instantiate() as Node3D
	if visual == null:
		return null

	mount.add_child(visual)
	visual.transform = Transform3D.IDENTITY
	return visual


func _apply_wing_visual_state() -> void:
	_apply_wing_visual(_left_wing_visual, _wing_deploy_amount, false)
	_apply_wing_visual(_right_wing_visual, _wing_deploy_amount, true)


func _apply_wing_visual(visual: Node3D, deploy_amount: float, mirror: bool) -> void:
	if visual == null:
		return

	var side_sign := -1.0 if mirror else 1.0
	visual.visible = deploy_amount > 0.01
	if visual.has_method("set_deploy_amount"):
		visual.call("set_deploy_amount", deploy_amount, side_sign)
		return

	visual.scale = Vector3.ONE

	var hinge := visual.get_node_or_null("Hinge") as Node3D
	if hinge != null:
		hinge.position.x = side_sign * 0.08

	var panel := visual.get_node_or_null("Panel") as Node3D
	if panel != null:
		panel.position.x = side_sign * lerpf(0.22, 1.05, deploy_amount)
		panel.scale = Vector3(lerpf(0.12, 1.0, deploy_amount), 1.0, 1.0)
		return

	var extend_scale := lerpf(0.05, 1.0, deploy_amount)
	visual.scale = Vector3(side_sign * extend_scale, 1.0, 1.0)


func _clear_wing_visuals() -> void:
	if _left_wing_visual != null:
		_left_wing_visual.queue_free()
		_left_wing_visual = null

	if _right_wing_visual != null:
		_right_wing_visual.queue_free()
		_right_wing_visual = null


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

	var grounded_ratio := maxf(_grounded_ratio, 0.25)
	var up := global_transform.basis.y.normalized()
	var tilt_axis := up.cross(_ground_normal)

	if grounded_upright_strength > 0.0 and tilt_axis.length_squared() > 0.0001:
		apply_torque(tilt_axis * grounded_upright_strength * mass * grounded_ratio)

	var yaw_velocity := _ground_normal * angular_velocity.dot(_ground_normal)
	var pitch_roll_velocity := angular_velocity - yaw_velocity
	apply_torque(-pitch_roll_velocity * pitch_roll_damping * mass * grounded_ratio)


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
	return _grounded_wheel_count


func _configure_wheel_probes() -> void:
	for probe in _wheel_probes:
		probe.enabled = true
		probe.target_position = Vector3.DOWN * wheel_ray_length
		probe.exclude_parent = true

func _assign_wheel_probes() -> void:
	_front_wheel_probes.clear()
	_rear_wheel_probes.clear()

	for probe in _wheel_probes:
		if probe.name.begins_with("Front"):
			_front_wheel_probes.append(probe)
		else:
			_rear_wheel_probes.append(probe)


func reset_car(state: PhysicsDirectBodyState3D) -> void:
	state.transform = Transform3D(Basis(), reset_position + Vector3.UP * 1.5)
	state.linear_velocity = Vector3.ZERO
	state.angular_velocity = Vector3.ZERO
	_steering_amount = 0.0
	_grounded_wheel_count = 0
	_grounded_ratio = 0.0
	_grounded = false
	_ground_normal = Vector3.UP
	_wings_active = false
	_wing_deploy_amount = 0.0
	_clear_wing_visuals()


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
