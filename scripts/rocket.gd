extends Area3D

@export var speed: float = 38.0
@export var lifetime: float = 4.0
@export var explosion_radius: float = 7.0
@export var explosion_force: float = 190.0
@export var upward_force: float = 0.65
@export var minimum_force_ratio: float = 0.28
@export var direct_hit_multiplier: float = 1.65
@export var explosion_scene: PackedScene

var direction := Vector3.FORWARD
var inherited_velocity := Vector3.ZERO
var _age := 0.0
var _exploded := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func launch(new_direction: Vector3, shooter_velocity: Vector3 = Vector3.ZERO) -> void:
	direction = new_direction.normalized()
	inherited_velocity = shooter_velocity
	look_at(global_position + direction, Vector3.UP)


func _physics_process(delta: float) -> void:
	var velocity := direction * speed + inherited_velocity
	var next_position := global_position + velocity * delta
	var ray_params := PhysicsRayQueryParameters3D.create(global_position, next_position)
	ray_params.exclude = [self]
	ray_params.collide_with_areas = false
	ray_params.collide_with_bodies = true

	var hit := get_world_3d().direct_space_state.intersect_ray(ray_params)
	if not hit.is_empty():
		_explode(hit.get("position", next_position) as Vector3, hit.get("collider") as Node3D)
		return

	global_position = next_position
	_age += delta
	if _age >= lifetime:
		_explode(global_position)


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


func _on_body_entered(_body: Node3D) -> void:
	_explode(global_position)


func _on_area_entered(_area: Area3D) -> void:
	_explode(global_position)
