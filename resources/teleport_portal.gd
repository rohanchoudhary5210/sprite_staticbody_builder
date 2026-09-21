@tool
class_name TeleportPortal
extends Area2D

## Teleport Portal that transports the player slime between paired gateways while preserving momentum.

signal teleported(body: Node2D, destination: Vector2)

@export_node_path("Area2D") var target_portal: NodePath
@export var preserve_velocity: bool = true
@export var cooldown_seconds: float = 0.4

var _can_teleport: bool = true

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("portals")

func _on_body_entered(body: Node2D) -> void:
	if not _can_teleport:
		return
		
	var is_player = body.is_in_group("player") or body.name.to_lower().contains("slime") or body is CharacterBody2D
	if not is_player:
		return
		
	if target_portal.is_empty():
		return
		
	var target = get_node_or_null(target_portal) as Area2D
	if not is_instance_valid(target) or target == self:
		return
		
	_can_teleport = false
	if "receive_teleport" in target:
		target.receive_teleport(body, body.velocity if "velocity" in body else Vector2.ZERO)
	else:
		body.global_position = target.global_position
		
	teleported.emit(body, target.global_position)
	
	# Portal warp visual tween
	var tween = create_tween()
	if tween:
		tween.tween_property(self, "scale", scale * 1.2, 0.08)
		tween.tween_property(self, "scale", scale, 0.12)
		
	get_tree().create_timer(cooldown_seconds).timeout.connect(func(): _can_teleport = true)

func receive_teleport(body: Node2D, incoming_velocity: Vector2) -> void:
	_can_teleport = false
	body.global_position = global_position
	
	if preserve_velocity and "velocity" in body:
		# Optionally rotate velocity by the portal's orientation difference
		body.velocity = incoming_velocity
		
	# Exit warp tween
	var tween = create_tween()
	if tween:
		tween.tween_property(self, "scale", scale * 1.25, 0.08)
		tween.tween_property(self, "scale", scale, 0.12)
		
	get_tree().create_timer(cooldown_seconds).timeout.connect(func(): _can_teleport = true)
