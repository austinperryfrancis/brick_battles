extends Camera3D

@export var target_path: NodePath
@export var distance: float = 6.0
@export var height: float = 4.0
@export var smoothing: float = 8.0
@export var look_ahead: float = 1.5

var target: Node3D


func _ready() -> void:
	current = true
	target = get_node_or_null(target_path) as Node3D


func _physics_process(delta: float) -> void:
	if target == null:
		return

	var target_basis := target.global_transform.basis.orthonormalized()
	var target_forward := -target_basis.z.normalized()
	var desired_position := target.global_position - target_forward * distance + Vector3.UP * height
	var follow_weight := 1.0 - exp(-smoothing * delta)

	global_position = global_position.lerp(desired_position, follow_weight)
	look_at(target.global_position + target_forward * look_ahead + Vector3.UP * 0.75, Vector3.UP)
