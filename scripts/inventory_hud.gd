extends CanvasLayer

@export var target_path: NodePath
@export var flash_duration: float = 2.0

@onready var _inventory_label := $InventoryLabel as Label
@onready var _flash_label := $PickupFlash as Label

var _target: Node
var _inventory: Dictionary = {}
var _flash_timer := 0.0


func _ready() -> void:
	_target = get_node_or_null(target_path)
	if _target != null:
		_target.inventory_changed.connect(_on_inventory_changed)
		_target.item_collected.connect(_on_item_collected)
		_target.item_used.connect(_on_item_used)

	_flash_label.visible = false
	_update_inventory_label()


func _process(delta: float) -> void:
	if _flash_timer <= 0.0:
		return

	_flash_timer -= delta
	if _flash_timer <= 0.0:
		_flash_label.visible = false


func _on_inventory_changed(new_inventory: Dictionary) -> void:
	_inventory = new_inventory
	_update_inventory_label()


func _on_item_collected(_item_id: String, display_name: String, count: int) -> void:
	_flash_label.text = "%s acquired x%d" % [display_name, count]
	_flash_label.visible = true
	_flash_timer = flash_duration


func _on_item_used(_item_id: String, display_name: String) -> void:
	_flash_label.text = "%s fired" % display_name
	_flash_label.visible = true
	_flash_timer = flash_duration


func _update_inventory_label() -> void:
	if _inventory.is_empty():
		_inventory_label.text = "Inventory: Empty"
		return

	var parts: Array[String] = []
	for item_id in _inventory.keys():
		var item_data := _inventory[item_id] as Dictionary
		var display_name := str(item_data.get("display_name", str(item_id).capitalize()))
		var count := int(item_data.get("count", 1))
		parts.append("%s x%d" % [display_name, count])

	_inventory_label.text = "Inventory: " + ", ".join(parts)
