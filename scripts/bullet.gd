extends Area3D

@export var speed: float = 55.0
@export var lifetime: float = 2.0
@export var impact_force: float = 18.0

var direction := Vector3.FORWARD
var inherited_velocity := Vector3.ZERO
var _age := 0.0


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
		_hit_body(hit.get("collider") as Node3D, hit.get("position", next_position) as Vector3)
		return

	global_position = next_position
	_age += delta
	if _age >= lifetime:
		queue_free()


func _hit_body(body: Node3D, hit_position: Vector3) -> void:
	var rigid_body := body as RigidBody3D
	if rigid_body != null:
		var impulse_position := hit_position - rigid_body.global_position
		rigid_body.apply_impulse(direction * impact_force, impulse_position)

	queue_free()


func _on_body_entered(body: Node3D) -> void:
	_hit_body(body, global_position)


func _on_area_entered(_area: Area3D) -> void:
	queue_free()
