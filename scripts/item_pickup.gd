extends Area3D

@export var item_id: String = "rocket"
@export var display_name: String = "Rocket"
@export var item_count: int = 1
@export var respawn_time: float = 60.0
@export var bob_height: float = 0.18
@export var bob_speed: float = 2.2
@export var spin_speed: float = 1.8
@export var visual_color: Color = Color(0.2, 0.7, 1.0, 1.0)
@export var emission_color: Color = Color(0.1, 0.45, 1.0, 1.0)

var _available := true
var _base_y := 0.0
var _age := 0.0
@onready var _visual := $Visual
@onready var _orb_mesh := $Visual/OrbMesh as MeshInstance3D
@onready var _collision := $CollisionShape3D
@onready var _respawn_timer := $RespawnTimer


func _ready() -> void:
	_base_y = position.y
	_apply_visual_material()
	body_entered.connect(_on_body_entered)
	_respawn_timer.timeout.connect(_respawn)


func _physics_process(delta: float) -> void:
	_age += delta
	position.y = _base_y + sin(_age * bob_speed) * bob_height
	_visual.rotate_y(spin_speed * delta)


func _apply_visual_material() -> void:
	if _orb_mesh == null:
		return

	var pickup_material := StandardMaterial3D.new()
	pickup_material.albedo_color = visual_color
	pickup_material.emission_enabled = true
	pickup_material.emission = emission_color
	pickup_material.emission_energy_multiplier = 0.8
	pickup_material.roughness = 0.25
	_orb_mesh.set_surface_override_material(0, pickup_material)


func _on_body_entered(body: Node3D) -> void:
	if not _available:
		return

	if not body.has_method("add_inventory_item"):
		return

	var was_collected: bool = body.add_inventory_item(item_id, display_name, item_count)
	if not was_collected:
		return

	_available = false
	_visual.visible = false
	_collision.disabled = true
	_respawn_timer.start(respawn_time)


func _respawn() -> void:
	_available = true
	_visual.visible = true
	_collision.disabled = false
