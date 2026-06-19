extends Node3D

@export var build_collision_on_ready: bool = true
@export var collision_friction: float = 0.05
@export var collision_bounce: float = 0.0
@export_flags_3d_physics var collision_layer: int = 1
@export_flags_3d_physics var collision_mask: int = 1

var _collision_built := false


func _ready() -> void:
	if build_collision_on_ready:
		call_deferred("build_collision")


func build_collision() -> void:
	if _collision_built:
		return

	var physics_material := PhysicsMaterial.new()
	physics_material.friction = collision_friction
	physics_material.bounce = collision_bounce

	var built_shapes := 0
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue

		var shape := CollisionShape3D.new()
		shape.name = "%sCollisionShape" % mesh_instance.name
		shape.shape = mesh_instance.mesh.create_trimesh_shape()

		var static_body := StaticBody3D.new()
		static_body.name = "%sCollision" % mesh_instance.name
		static_body.collision_layer = collision_layer
		static_body.collision_mask = collision_mask
		static_body.physics_material_override = physics_material

		var mesh_parent := mesh_instance.get_parent()
		mesh_parent.add_child(static_body)
		static_body.transform = mesh_instance.transform
		static_body.add_child(shape)
		built_shapes += 1

	_collision_built = true
	print("TruckTown collision built from %d mesh nodes." % built_shapes)
