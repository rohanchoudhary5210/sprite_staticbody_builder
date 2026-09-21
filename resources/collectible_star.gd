@tool
class_name CollectibleStar
extends Area2D

## Collectible Star item for 3-star level completion ratings and score pickup.

signal star_collected(star_index: int, score_value: int)

@export_range(1, 3) var star_index: int = 1
@export var score_value: int = 100
@export var bobbing: bool = true
@export var bob_amplitude: float = 4.0
@export var bob_speed: float = 3.5

var _collected: bool = false
var _base_y: float = 0.0
var _time_passed: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("collectibles")
	_base_y = position.y

func _process(delta: float) -> void:
	if not bobbing or _collected:
		return
	_time_passed += delta
	position.y = _base_y + sin(_time_passed * bob_speed) * bob_amplitude

func _on_body_entered(body: Node2D) -> void:
	if _collected:
		return
		
	var is_player = body.is_in_group("player") or body.name.to_lower().contains("slime") or body is CharacterBody2D
	if not is_player:
		return
		
	_collected = true
	star_collected.emit(star_index, score_value)
	
	# Pickup celebration pop tween
	var tween = create_tween()
	if tween:
		tween.set_parallel(true)
		tween.tween_property(self, "scale", scale * 1.5, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "modulate:a", 0.0, 0.18)
		tween.set_parallel(false)
		tween.tween_callback(queue_free)
	else:
		queue_free()
