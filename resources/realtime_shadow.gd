@tool
class_name RealtimeShadow2D
extends Sprite2D

## Dynamically updates 2D shadow position in real-time when the parent body rotates.
## Keeps shadow cast direction locked to world/screen light coordinates while matching body rotation.
## Provides full editor controls for shadow offset (X,Y), light angle, distance, and anchor base.

enum AnchorMode {
	SPRITE_CENTER = 0,
	BOTTOM_GROUND = 1,
	CUSTOM_OFFSET = 2,
}

@export_group("Shadow Position & Direction")
## World-space displacement offset in pixels (X, Y).
@export var shadow_offset: Vector2 = Vector2(6, 8):
	set(val):
		shadow_offset = val
		_sync_angle_distance_from_offset()
		_update_shadow_transform()

## Direction of the light source in degrees (0° = Right, 90° = Down, 135° = Down-Right, 180° = Left).
@export_range(0.0, 360.0, 1.0, "degrees") var light_angle_deg: float = 53.13:
	set(val):
		light_angle_deg = fposmod(val, 360.0)
		_sync_offset_from_angle_distance()
		_update_shadow_transform()

## Distance of shadow displacement in pixels from the reference anchor point.
@export_range(0.0, 500.0, 0.5, "or_greater") var shadow_distance: float = 10.0:
	set(val):
		shadow_distance = maxf(0.0, val)
		_sync_offset_from_angle_distance()
		_update_shadow_transform()

@export_group("Anchor / Base Position")
## Where the shadow originates relative to the main sprite.
@export var anchor_mode: AnchorMode = AnchorMode.SPRITE_CENTER:
	set(val):
		anchor_mode = val
		_update_shadow_transform()

## Additional custom anchor displacement in pixels from the sprite center (used for fine-tuning).
@export var custom_anchor_offset: Vector2 = Vector2.ZERO:
	set(val):
		custom_anchor_offset = val
		_update_shadow_transform()

@export_group("Transform & Rotation")
## If true, shadow offset is preserved in world coordinates when the body or stage rotates.
@export var maintain_light_direction: bool = true:
	set(val):
		maintain_light_direction = val
		_update_shadow_transform()

## Uniform scale multiplier for the shadow sprite.
@export var shadow_scale: float = 1.0:
	set(val):
		shadow_scale = val
		scale = Vector2.ONE * shadow_scale
		_update_shadow_transform()

@export_group("Visuals")
## Modulate tint & alpha of the shadow.
@export var shadow_color: Color = Color(0, 0, 0, 0.45):
	set(val):
		shadow_color = val
		modulate = shadow_color

## If true, texture, flip, and region settings automatically mirror the main sibling Sprite2D.
@export var auto_sync_sprite: bool = true:
	set(val):
		auto_sync_sprite = val
		if auto_sync_sprite:
			_sync_with_main_sprite()

@export_group("Editor")
## Whether real-time shadow updates execute inside the Godot editor viewport.
@export var active_in_editor: bool = true

## Allow dragging the shadow directly in the Godot 2D editor viewport to change shadow_offset.
@export var drag_to_reposition_in_editor: bool = true

var _internal_sync: bool = false
var _updating: bool = false
var _last_synced_local_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	show_behind_parent = true
	modulate = shadow_color
	scale = Vector2.ONE * shadow_scale
	rotation = 0.0
	_sync_angle_distance_from_offset()
	_sync_with_main_sprite()
	_update_shadow_transform()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and not active_in_editor:
		return
	_sync_with_main_sprite()
	
	# Detect manual mouse dragging in Godot 2D editor viewport
	if Engine.is_editor_hint() and drag_to_reposition_in_editor and not _updating:
		_check_manual_drag_in_editor()
		
	_update_shadow_transform()

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() and not active_in_editor:
		return
	_update_shadow_transform()

## Calculate angle & distance from current offset vector
func _sync_angle_distance_from_offset() -> void:
	if _internal_sync:
		return
	_internal_sync = true
	shadow_distance = shadow_offset.length()
	if shadow_distance > 0.001:
		light_angle_deg = fposmod(rad_to_deg(shadow_offset.angle()), 360.0)
	_internal_sync = false

## Calculate offset vector from angle & distance
func _sync_offset_from_angle_distance() -> void:
	if _internal_sync:
		return
	_internal_sync = true
	var rad = deg_to_rad(light_angle_deg)
	shadow_offset = Vector2(cos(rad), sin(rad)) * shadow_distance
	_internal_sync = false

## Allows user to reposition the shadow by dragging it with Godot's 2D transform gizmo
func _check_manual_drag_in_editor() -> void:
	if _last_synced_local_pos.is_zero_approx():
		_last_synced_local_pos = position
		return
		
	if not position.is_equal_approx(_last_synced_local_pos):
		var parent = get_parent() as CanvasItem
		if not is_instance_valid(parent):
			return
		var parent_xform = parent.get_global_transform()
		var current_global_pos = parent_xform * position
		var ref_origin = _get_ref_global_origin()
		var new_offset = current_global_pos - ref_origin
		
		if not shadow_offset.is_equal_approx(new_offset):
			_internal_sync = true
			shadow_offset = new_offset
			shadow_distance = shadow_offset.length()
			if shadow_distance > 0.001:
				light_angle_deg = fposmod(rad_to_deg(shadow_offset.angle()), 360.0)
			_internal_sync = false
			_last_synced_local_pos = position

## Finds the primary visual Sprite2D sibling under the same parent
func _find_main_sprite() -> Sprite2D:
	var parent = get_parent()
	if not is_instance_valid(parent):
		return null
	for child in parent.get_children():
		if child is Sprite2D and child != self and not child.name.begins_with("Shadow") and not child.name.ends_with("Shadow"):
			return child
	return null

## Computes reference origin according to anchor mode (Center, Ground/Bottom, Custom)
func _get_ref_global_origin() -> Vector2:
	var parent = get_parent() as CanvasItem
	if not is_instance_valid(parent):
		return Vector2.ZERO
		
	var parent_xform = parent.get_global_transform()
	var main_sprite = _find_main_sprite()
	
	if not is_instance_valid(main_sprite) or not main_sprite.texture:
		return parent_xform.origin
		
	var base_origin = main_sprite.global_position
	var tex_size = main_sprite.texture.get_size() * main_sprite.scale
	
	match anchor_mode:
		AnchorMode.SPRITE_CENTER:
			if custom_anchor_offset != Vector2.ZERO:
				return base_origin + parent_xform.basis_xform(custom_anchor_offset)
			return base_origin
		AnchorMode.BOTTOM_GROUND:
			var half_h = (tex_size.y * 0.5) if main_sprite.centered else tex_size.y
			var down_offset = parent_xform.basis_xform(Vector2(0, half_h) + custom_anchor_offset)
			return base_origin + down_offset
		AnchorMode.CUSTOM_OFFSET:
			return base_origin + parent_xform.basis_xform(custom_anchor_offset)
		_:
			return base_origin

## Synchronize texture, offset, centered, flip, and region with sibling Sprite2D
func _sync_with_main_sprite() -> void:
	if not auto_sync_sprite:
		return
	var main_sprite = _find_main_sprite()
	if not is_instance_valid(main_sprite) or not main_sprite.texture:
		return
		
	if texture != main_sprite.texture:
		texture = main_sprite.texture
	if centered != main_sprite.centered:
		centered = main_sprite.centered
	if offset != main_sprite.offset:
		offset = main_sprite.offset
	if flip_h != main_sprite.flip_h:
		flip_h = main_sprite.flip_h
	if flip_v != main_sprite.flip_v:
		flip_v = main_sprite.flip_v
	if region_enabled != main_sprite.region_enabled:
		region_enabled = main_sprite.region_enabled
	if region_rect != main_sprite.region_rect:
		region_rect = main_sprite.region_rect

## Recalculates local position to keep the world-space shadow displacement constant
func _update_shadow_transform() -> void:
	if _updating or not is_inside_tree():
		return
		
	var parent = get_parent() as CanvasItem
	if not is_instance_valid(parent):
		return
		
	var parent_xform = parent.get_global_transform()
	var ref_origin = _get_ref_global_origin()
	
	if not maintain_light_direction:
		var non_rot_local = (ref_origin - parent_xform.origin) + shadow_offset
		if not position.is_equal_approx(non_rot_local):
			_updating = true
			position = non_rot_local
			_last_synced_local_pos = position
			_updating = false
		return
		
	var target_global_pos = ref_origin + shadow_offset
	var target_local_pos = parent_xform.affine_inverse() * target_global_pos
	
	if not position.is_equal_approx(target_local_pos):
		_updating = true
		position = target_local_pos
		_last_synced_local_pos = position
		_updating = false
