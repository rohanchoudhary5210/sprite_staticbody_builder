@tool
class_name WindVent
extends Area2D

## Air Vent or Fan that exerts a continuous directional wind force on the player slime.

signal wind_applied(body: Node2D, force: Vector2)

@export var wind_force: float = 500.0
@export var wind_direction: Vector2 = Vector2.UP
@export var use_local_orientation: bool = true
@export var active: bool = true

var _bodies_in_stream: Array[Node2D] = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	add_to_group("wind_vents")

func _on_body_entered(body: Node2D) -> void:
	if body not in _bodies_in_stream:
		_bodies_in_stream.append(body)

func _on_body_exited(body: Node2D) -> void:
	_bodies_in_stream.erase(body)

func _physics_process(delta: float) -> void:
	if not active or _bodies_in_stream.is_empty():
		return
		
	var dir = -global_transform.y.normalized() if use_local_orientation else wind_direction.normalized()
	if dir.is_zero_approx():
		dir = Vector2.UP
		
	var force_vec = dir * wind_force
	
	for body in _bodies_in_stream:
		if not is_instance_valid(body):
			continue
		if "velocity" in body:
			body.velocity += force_vec * delta
		elif body is RigidBody2D:
			body.apply_central_force(force_vec)
		wind_applied.emit(body, force_vec)
