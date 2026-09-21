@tool
class_name BumperPad
extends Area2D

## Bumper / Spring Pad that launches the player slime with a bouncy impulse on contact.

signal launched(body: Node2D, launch_velocity: Vector2)

@export var launch_force: float = 650.0
@export var launch_direction: Vector2 = Vector2.UP
@export var use_custom_direction: bool = false
@export var cooldown_seconds: float = 0.15

var _can_bounce: bool = true

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("bumpers")

func _on_body_entered(body: Node2D) -> void:
	if not _can_bounce:
		return
		
	var is_player = body.is_in_group("player") or body.name.to_lower().contains("slime")
	if not is_player and not (body is CharacterBody2D or body is RigidBody2D):
		return
		
	var dir = launch_direction.normalized() if use_custom_direction else -global_transform.y.normalized()
	if dir.is_zero_approx():
		dir = Vector2.UP
		
	var launch_vel = dir * launch_force
	
	if "velocity" in body:
		body.velocity = launch_vel
	elif body is RigidBody2D:
		body.apply_central_impulse(launch_vel)
		
	_can_bounce = false
	launched.emit(body, launch_vel)
	
	# Juicy squash and bounce tween
	var orig_scale = scale
	var tween = create_tween()
	if tween:
		tween.tween_property(self, "scale", orig_scale * Vector2(1.3, 0.7), 0.06)
		tween.tween_property(self, "scale", orig_scale * Vector2(0.9, 1.15), 0.08)
		tween.tween_property(self, "scale", orig_scale, 0.1)
		
	get_tree().create_timer(cooldown_seconds).timeout.connect(func(): _can_bounce = true)
