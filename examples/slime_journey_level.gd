extends Node2D

@onready var maze_container: Node2D = $MazeContainer
@onready var player: CharacterBody2D = $Player
@onready var win_panel: PanelContainer = $CanvasLayer/WinPanel
@onready var info_label: Label = $CanvasLayer/InfoLabel

var maze_rotation_speed: float = 60.0

func _ready() -> void:
	if win_panel:
		win_panel.visible = false
	var goal = find_child("CheckeredFlag", true, false)
	if goal and goal.has_signal("goal_reached"):
		goal.goal_reached.connect(_on_goal_reached)

func _process(delta: float) -> void:
	# Spin maze with Q and E or J and L
	var rot_input = 0.0
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_J):
		rot_input -= 1.0
	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_L):
		rot_input += 1.0
		
	if rot_input != 0.0 and maze_container:
		maze_container.rotation += deg_to_rad(maze_rotation_speed * rot_input) * delta
		
	if Input.is_key_pressed(KEY_R):
		get_tree().reload_current_scene()

func _on_goal_reached(_player: Node2D) -> void:
	if win_panel:
		win_panel.visible = true
