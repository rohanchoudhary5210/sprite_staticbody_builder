@tool
class_name LockedDoor
extends StaticBody2D

## Locked Door or Barrier that slides or dissolves open when the matching key is held by the player.

signal door_unlocked(key_id: String)

@export var required_key_id: String = "gold"
@export var slide_direction: Vector2 = Vector2.UP
@export var slide_distance: float = 64.0
@export var unlock_duration: float = 0.4

var is_open: bool = false

func _ready() -> void:
	add_to_group("locked_doors")
	# Create a tiny touch sensor area to detect player with key
	if not Engine.is_editor_hint():
		var sensor = Area2D.new()
		sensor.name = "KeySensor"
		add_child(sensor)
		for child in get_children():
			if child is CollisionPolygon2D:
				var sensor_col = CollisionPolygon2D.new()
				sensor_col.polygon = child.polygon
				sensor.add_child(sensor_col)
		sensor.body_entered.connect(_on_sensor_body_entered)

func _on_sensor_body_entered(body: Node2D) -> void:
	if is_open:
		return
	var is_player = body.is_in_group("player") or body.name.to_lower().contains("slime") or body is CharacterBody2D
	if not is_player:
		return
		
	var has_key = false
	if body.has_method("has_key"):
		has_key = body.has_key(required_key_id)
	elif "keys" in body and body.keys is Array:
		has_key = required_key_id in body.keys
	elif body.has_meta("keys"):
		var k: Array = body.get_meta("keys")
		has_key = required_key_id in k
		
	if has_key:
		unlock()

func unlock() -> void:
	if is_open:
		return
	is_open = true
	door_unlocked.emit(required_key_id)
	
	# Disable physical collisions
	for child in get_children():
		if child is CollisionPolygon2D or child is CollisionShape2D:
			child.set_deferred("disabled", true)
			
	# Smooth open animation (slide + fade)
	var target_pos = position + slide_direction.normalized() * slide_distance
	var tween = create_tween()
	if tween:
		tween.set_parallel(true)
		tween.tween_property(self, "position", target_pos, unlock_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "modulate:a", 0.15, unlock_duration)
