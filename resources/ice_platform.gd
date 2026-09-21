@tool
class_name IcePlatform
extends StaticBody2D

## Zero-friction icy platform that accelerates the slime and prevents braking.

@export var friction: float = 0.0:
	set(val):
		friction = val
		_apply_physics_material()

@export var bounce: float = 0.15:
	set(val):
		bounce = val
		_apply_physics_material()

func _ready() -> void:
	add_to_group("ice_surfaces")
	_apply_physics_material()

func _apply_physics_material() -> void:
	var mat = physics_material_override
	if not mat:
		mat = PhysicsMaterial.new()
		physics_material_override = mat
	mat.friction = friction
	mat.rough = false
	mat.bounce = bounce
