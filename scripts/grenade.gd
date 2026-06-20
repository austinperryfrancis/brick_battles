extends Area3D

@export var forward_speed: float = 28.0
@export var upward_speed: float = 12.0
@export var arc_gravity: float = 18.0
@export var fuse_time: float = 2.5
@export var explosion_radius: float = 5.5
@export var explosion_force: float = 140.0
@export var upward_force: float = 0.75
@export var minimum_force_ratio: float = 0.25
@export var direct_hit_multiplier: float = 1.3
@export var max_bounces: int = 4
@export var bounce_damping: float = 0.65
@export var min_bounce_speed: float = 4.0
@export var explosion_scene: PackedScene

var velocity := Vector3.ZERO
var _age := 0.0
var _exploded := false
var _bounce_count := 0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func launch(forward: Vector3, shooter_velocity: Vector3 = Vector3.ZERO) -> void:
	velocity = forward.normalized() * forward_speed + Vector3.UP * upward_speed + shooter_velocity
	_face_velocity()


func _physics_process(delta: float) -> void:
	velocity += Vector3.DOWN * arc_gravity * delta
	var next_position := global_position + velocity * delta
	var ray_params := PhysicsRayQueryParameters3D.create(global_position, next_position)
	ray_params.exclude = [self]
	ray_params.collide_with_areas = false
	ray_params.collide_with_bodies = true

	var hit := get_world_3d().direct_space_state.intersect_ray(ray_params)
	if not hit.is_empty():
		_handle_impact(hit, delta)
		return

	global_position = next_position
	_face_velocity()

	_age += delta
	if _age >= fuse_time:
		_explode(global_position)


func _handle_impact(hit: Dictionary, delta: float) -> void:
	var collider := hit.get("collider") as Node3D
	var hit_position := hit.get("position", global_position) as Vector3
	var hit_normal := hit.get("normal", Vector3.UP) as Vector3

	if collider is RigidBody3D:
		_explode(hit_position, collider)
		return

	_bounce_count += 1
	if _bounce_count > max_bounces or velocity.length() < min_bounce_speed:
		_explode(hit_position, collider)
		return

	global_position = hit_position + hit_normal * 0.05
	velocity = velocity.bounce(hit_normal) * bounce_damping
	velocity += hit_normal * 0.6
	_face_velocity()

	_age += delta
	if _age >= fuse_time:
		_explode(global_position)


func _face_velocity() -> void:
	if velocity.length_squared() < 0.001:
		return

	look_at(global_position + velocity.normalized(), Vector3.UP)


func _explode(explosion_position: Vector3, direct_hit_body: Node3D = null) -> void:
	if _exploded:
		return

	_exploded = true
	_spawn_explosion_flash(explosion_position)
	_apply_explosion_impulse(explosion_position, direct_hit_body)
	queue_free()


func _spawn_explosion_flash(explosion_position: Vector3) -> void:
	if explosion_scene == null:
		return

	var flash := explosion_scene.instantiate() as Node3D
	var flash_parent := get_tree().current_scene
	if flash_parent == null:
		flash_parent = get_parent()
	flash_parent.add_child(flash)
	flash.global_position = explosion_position
	flash.set("max_scale", explosion_radius)


func _apply_explosion_impulse(explosion_position: Vector3, direct_hit_body: Node3D = null) -> void:
	var shape := SphereShape3D.new()
	shape.radius = explosion_radius

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), explosion_position)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [self]

	var results := get_world_3d().direct_space_state.intersect_shape(query, 32)
	for result in results:
		var body := result.get("collider") as RigidBody3D
		if body == null:
			continue

		var offset := body.global_position - explosion_position
		var distance := maxf(offset.length(), 0.1)
		if distance > explosion_radius:
			continue

		var normalized_distance := distance / explosion_radius
		var falloff := clampf(1.0 - normalized_distance * normalized_distance, minimum_force_ratio, 1.0)
		var impulse_direction := (offset.normalized() + Vector3.UP * upward_force).normalized()
		var force_multiplier := 1.0
		if body == direct_hit_body:
			force_multiplier = direct_hit_multiplier

		var impulse := impulse_direction * explosion_force * falloff * force_multiplier
		body.apply_impulse(impulse, explosion_position - body.global_position)


func _on_body_entered(body: Node3D) -> void:
	_explode(global_position, body)


func _on_area_entered(_area: Area3D) -> void:
	_explode(global_position)
