extends Node3D

@export var duration: float = 0.28
@export var max_scale: float = 5.0

var _age := 0.0


func _process(delta: float) -> void:
	_age += delta
	var progress := clampf(_age / duration, 0.0, 1.0)
	scale = Vector3.ONE * lerpf(0.25, max_scale, progress)

	if _age >= duration:
		queue_free()
