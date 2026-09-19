@tool
class_name GoalArea
extends Area2D

## Checkered flag goal area that detects player arrival and triggers level complete (Slime Journey mechanic).

signal goal_reached(player)

var reached: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if reached:
		return
	if body.is_in_group("player") or body.name.to_lower().contains("slime"):
		reached = true
		goal_reached.emit(body)
		if body.has_method("win"):
			body.win()
