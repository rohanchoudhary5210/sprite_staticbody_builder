@tool
class_name HazardArea
extends Area2D

## Traps and hazards that defeat the player upon contact (Slime Journey mechanic).

signal player_hit(player)

@export var damage: int = 1

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name.to_lower().contains("slime"):
		player_hit.emit(body)
		if body.has_method("die_and_respawn"):
			body.die_and_respawn()
