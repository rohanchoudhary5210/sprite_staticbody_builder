@tool
class_name RotatingObstacle
extends AnimatableBody2D

## Rotates a level obstacle or maze segment continuously (Slime Journey mechanic).
## Uses AnimatableBody2D with sync_to_physics so kinematic characters interact cleanly without tunneling.

@export var rotation_speed_deg: float = 45.0
@export var clockwise: bool = true
@export var active_in_editor: bool = false

func _ready() -> void:
	sync_to_physics = true

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() and not active_in_editor:
		return
	var dir = 1.0 if clockwise else -1.0
	rotation += deg_to_rad(rotation_speed_deg * dir) * delta

