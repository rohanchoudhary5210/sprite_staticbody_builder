extends CharacterBody2D
class_name SlimeJourneyPlayer

@export var speed: float = 240.0
@export var jump_velocity: float = -380.0
@export var gravity: float = 980.0

var start_position: Vector2 = Vector2.ZERO
var won: bool = false
var is_dead: bool = false

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	start_position = global_position
	add_to_group("player")

func _physics_process(delta: float) -> void:
	if is_dead or won:
		return
		
	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
		
	# Controls
	var input_x = Input.get_axis("ui_left", "ui_right")
	if input_x != 0:
		velocity.x = move_toward(velocity.x, input_x * speed, speed * 8.0 * delta)
		if sprite:
			sprite.rotation += input_x * 8.0 * delta # roll effect!
	else:
		velocity.x = move_toward(velocity.x, 0, speed * 10.0 * delta)
		
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up"):
		if is_on_floor():
			velocity.y = jump_velocity
			
	move_and_slide()
	
	# Fall out of bounds check
	if position.y > 1200:
		die_and_respawn()

func die_and_respawn() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	# Quick respawn
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func():
		global_position = start_position
		velocity = Vector2.ZERO
		is_dead = false
		modulate.a = 1.0
	)

func win() -> void:
	won = true
	velocity = Vector2.ZERO
