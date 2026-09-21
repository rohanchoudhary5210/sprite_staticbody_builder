@tool
class_name OneWayMembrane
extends StaticBody2D

## One-Way Jelly Membrane barrier that allows the player slime to pass from one direction but blocks return.

@export var one_way_margin: float = 8.0

func _ready() -> void:
	add_to_group("one_way_membranes")
	_apply_one_way()

func _apply_one_way() -> void:
	for child in get_children():
		if child is CollisionPolygon2D:
			child.one_way_collision = true
			child.one_way_collision_margin = one_way_margin
