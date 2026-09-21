@tool
class_name PressurePlate
extends Area2D

## Floor switch or pressure plate that sinks when stepped on and triggers linked level mechanisms.

signal plate_pressed()
signal plate_released()

@export_node_path("Node") var target_mechanism: NodePath
@export var toggle_mode: bool = false
@export var press_depth: float = 4.0

var _is_pressed: bool = false
var _occupant_count: int = 0
var _orig_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	add_to_group("pressure_plates")
	_orig_position = position

func _on_body_entered(body: Node2D) -> void:
	var is_player = body.is_in_group("player") or body.name.to_lower().contains("slime") or body is CharacterBody2D or body is RigidBody2D
	if not is_player:
		return
		
	_occupant_count += 1
	if _occupant_count == 1:
		_press()

func _on_body_exited(body: Node2D) -> void:
	var is_player = body.is_in_group("player") or body.name.to_lower().contains("slime") or body is CharacterBody2D or body is RigidBody2D
	if not is_player:
		return
		
	_occupant_count = max(0, _occupant_count - 1)
	if _occupant_count == 0 and not toggle_mode:
		_release()

func _press() -> void:
	if _is_pressed and toggle_mode:
		_release()
		return
		
	_is_pressed = true
	plate_pressed.emit()
	
	# Downward press sink tween
	var down_offset = transform.basis_xform(Vector2(0, press_depth))
	var tween = create_tween()
	if tween:
		tween.tween_property(self, "position", _orig_position + down_offset, 0.08)
		
	_trigger_target(true)

func _release() -> void:
	_is_pressed = false
	plate_released.emit()
	
	# Upward return tween
	var tween = create_tween()
	if tween:
		tween.tween_property(self, "position", _orig_position, 0.1)
		
	_trigger_target(false)

func _trigger_target(active: bool) -> void:
	if target_mechanism.is_empty():
		return
	var target = get_node_or_null(target_mechanism)
	if not is_instance_valid(target):
		return
		
	if active:
		if target.has_method("unlock"):
			target.unlock()
		elif target.has_method("activate"):
			target.activate()
		elif target.has_method("open"):
			target.open()
		elif target.has_method("toggle"):
			target.toggle()
	else:
		if target.has_method("lock"):
			target.lock()
		elif target.has_method("deactivate"):
			target.deactivate()
		elif target.has_method("close"):
			target.close()
