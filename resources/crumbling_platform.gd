@tool
class_name CrumblingPlatform
extends AnimatableBody2D

## Fragile platform that shakes and collapses when the player steps on it, with optional respawning.

signal platform_crumbling()
signal platform_collapsed()
signal platform_respawned()

@export var collapse_delay: float = 0.8
@export var respawn_time: float = 3.0
@export var shake_intensity: float = 3.0

var _is_crumbling: bool = false
var _orig_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	sync_to_physics = true
	add_to_group("crumbling_platforms")
	_orig_position = position
	
	if not Engine.is_editor_hint():
		# Automatically attach step sensor matching collision polygon geometry
		var sensor = Area2D.new()
		sensor.name = "StepSensor"
		add_child(sensor)
		for child in get_children():
			if child is CollisionPolygon2D:
				var col = CollisionPolygon2D.new()
				col.polygon = child.polygon
				sensor.add_child(col)
		sensor.body_entered.connect(_on_step_entered)

func _on_step_entered(body: Node2D) -> void:
	if _is_crumbling:
		return
	var is_player = body.is_in_group("player") or body.name.to_lower().contains("slime") or body is CharacterBody2D
	if not is_player:
		return
		
	start_crumble()

func start_crumble() -> void:
	if _is_crumbling:
		return
	_is_crumbling = true
	platform_crumbling.emit()
	
	_orig_position = position
	var tween = create_tween()
	var step_count = clampi(int(collapse_delay / 0.05), 4, 30)
	for i in range(step_count):
		var dir = 1.0 if (i % 2 == 0) else -1.0
		var offset = dir * shake_intensity * (1.0 - float(i) / step_count)
		tween.tween_property(self, "position:x", _orig_position.x + offset, 0.05)
		
	tween.tween_property(self, "position:x", _orig_position.x, 0.05)
	tween.tween_callback(_collapse)

func _collapse() -> void:
	# Disable physical collisions
	for child in get_children():
		if child is CollisionPolygon2D or child is CollisionShape2D:
			child.set_deferred("disabled", true)
			
	# Drop slightly and fade out
	var drop_tween = create_tween()
	if drop_tween:
		drop_tween.set_parallel(true)
		drop_tween.tween_property(self, "position:y", _orig_position.y + 14.0, 0.2)
		drop_tween.tween_property(self, "modulate:a", 0.0, 0.2)
		drop_tween.set_parallel(false)
		drop_tween.tween_callback(func():
			platform_collapsed.emit()
			if respawn_time > 0.0:
				get_tree().create_timer(respawn_time).timeout.connect(_respawn)
		)

func _respawn() -> void:
	position = _orig_position
	for child in get_children():
		if child is CollisionPolygon2D or child is CollisionShape2D:
			child.set_deferred("disabled", false)
			
	var respawn_tween = create_tween()
	if respawn_tween:
		respawn_tween.tween_property(self, "modulate:a", 1.0, 0.3)
		respawn_tween.tween_callback(func():
			_is_crumbling = false
			platform_respawned.emit()
		)
	else:
		modulate.a = 1.0
		_is_crumbling = false
		platform_respawned.emit()
