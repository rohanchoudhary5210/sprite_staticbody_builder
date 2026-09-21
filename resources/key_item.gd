@tool
class_name KeyItem
extends Area2D

## Key collectible that unlocks matching colored doors or barriers.

signal key_collected(key_id: String)

@export var key_id: String = "gold"
@export var bobbing: bool = true

var _collected: bool = false
var _base_y: float = 0.0
var _time_passed: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("keys")
	_base_y = position.y

func _process(delta: float) -> void:
	if not bobbing or _collected:
		return
	_time_passed += delta
	position.y = _base_y + sin(_time_passed * 3.0) * 3.0

func _on_body_entered(body: Node2D) -> void:
	if _collected:
		return
		
	var is_player = body.is_in_group("player") or body.name.to_lower().contains("slime") or body is CharacterBody2D
	if not is_player:
		return
		
	_collected = true
	
	# If player has key management method or inventory array
	if body.has_method("add_key"):
		body.add_key(key_id)
	elif "keys" in body and body.keys is Array:
		body.keys.append(key_id)
	elif body.has_meta("keys"):
		var k: Array = body.get_meta("keys")
		k.append(key_id)
		body.set_meta("keys", k)
	else:
		body.set_meta("keys", [key_id])
		
	key_collected.emit(key_id)
	
	# Pickup pop tween
	var tween = create_tween()
	if tween:
		tween.set_parallel(true)
		tween.tween_property(self, "scale", scale * 1.4, 0.16)
		tween.tween_property(self, "modulate:a", 0.0, 0.16)
		tween.set_parallel(false)
		tween.tween_callback(queue_free)
	else:
		queue_free()
