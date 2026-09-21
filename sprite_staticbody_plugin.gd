@tool
extends EditorPlugin

const Generator = preload("res://addons/sprite_staticbody_builder/collision_generator.gd")
const Preview = preload("res://addons/sprite_staticbody_builder/collision_preview.gd")

var dock: Control = null

# Live Preview state
var preview_active: bool = false
var preview_polygons: Array[PackedVector2Array] = []
var preview_target_node: CanvasItem = null
var preview_options: Dictionary = {}

func _enter_tree() -> void:
	# 1. Instantiate Dock
	var dock_scene = load("res://addons/sprite_staticbody_builder/sprite_staticbody_dock.tscn")
	if dock_scene:
		dock = dock_scene.instantiate()
		add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)
		
		# Connect dock signals
		dock.request_create_staticbody.connect(_on_create_staticbody)
		dock.request_regenerate_collision.connect(_on_regenerate_collision)
		dock.request_remove_collision.connect(_on_remove_collision)
		dock.preview_toggled.connect(_on_preview_toggled)
		dock.options_changed.connect(_on_options_changed)
		
	# 2. Connect Selection Signal
	var selection = EditorInterface.get_selection()
	if selection:
		selection.selection_changed.connect(_on_selection_changed)
		
	# Initial check
	_on_selection_changed()

func _exit_tree() -> void:
	# Clean up selection signal
	var selection = EditorInterface.get_selection()
	if selection and selection.selection_changed.is_connected(_on_selection_changed):
		selection.selection_changed.disconnect(_on_selection_changed)
		
	# Clean up dock
	if is_instance_valid(dock):
		remove_control_from_docks(dock)
		dock.queue_free()
		dock = null
		
	preview_active = false
	preview_polygons.clear()
	preview_target_node = null
	update_overlays()

# ---------------------------------------------------------
# Selection & Target Tracking
# ---------------------------------------------------------
func _find_sprite_in_node(root: Node) -> Sprite2D:
	for child in root.get_children():
		if child is Sprite2D and child.texture and not child.name.begins_with("Shadow") and not child.name.ends_with("Shadow"):
			return child
	# Check 1 level deeper for nested hierarchies (e.g. Visuals/Sprite2D)
	for child in root.get_children():
		for grandchild in child.get_children():
			if grandchild is Sprite2D and grandchild.texture and not grandchild.name.begins_with("Shadow") and not grandchild.name.ends_with("Shadow"):
				return grandchild
	return null

func _on_selection_changed() -> void:
	if not is_instance_valid(dock):
		return
		
	var selection = EditorInterface.get_selection()
	if not selection:
		dock.clear_target()
		_clear_preview()
		return
		
	var nodes = selection.get_selected_nodes()
	if nodes.is_empty():
		# Check FileSystem selection
		var paths = EditorInterface.get_selected_paths()
		if not paths.is_empty() and _is_image_file(paths[0]):
			var tex = load(paths[0]) as Texture2D
			if tex:
				dock.set_target_texture(paths[0], tex)
				preview_target_node = null
				_update_preview_if_active()
				return
		dock.clear_target()
		_clear_preview()
		return
		
	var node = nodes[0]
	
	# Case 1: Selected node is a Sprite2D
	if node is Sprite2D:
		var parent = node.get_parent()
		if parent is CollisionObject2D:
			dock.set_target_body(parent, node)
			preview_target_node = node
		else:
			dock.set_target_sprite(node)
			preview_target_node = node
		_update_preview_if_active()
		return
		
	# Case 2: Selected node is a CollisionObject2D (StaticBody2D, AnimatableBody2D, Area2D)
	if node is CollisionObject2D:
		var found_sprite = _find_sprite_in_node(node)
		if found_sprite:
			dock.set_target_body(node, found_sprite)
			preview_target_node = found_sprite
			_update_preview_if_active()
			return
			
	# Other node selected
	dock.clear_target()
	_clear_preview()

func _is_image_file(path: String) -> bool:
	var ext = path.get_extension().to_lower()
	return ext in ["png", "jpg", "jpeg", "webp", "svg", "tres", "res"]

# ---------------------------------------------------------
# Viewport Canvas Overlay (Collision Preview)
# ---------------------------------------------------------
func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	if not preview_active:
		return
	if preview_polygons.is_empty():
		return
	var preview_tex = dock.target_texture if (is_instance_valid(dock) and dock.target_texture) else null
	Preview.draw_preview(overlay, preview_target_node, preview_polygons, preview_options, preview_tex)

func _on_preview_toggled(enabled: bool, options: Dictionary) -> void:
	preview_active = enabled
	preview_options = options
	if preview_active:
		_calculate_preview()
	else:
		_clear_preview()

func _on_options_changed(options: Dictionary) -> void:
	preview_options = options
	if preview_active:
		_calculate_preview()

func _update_preview_if_active() -> void:
	if preview_active:
		_calculate_preview()

func _clear_preview() -> void:
	preview_polygons.clear()
	update_overlays()

func _calculate_preview() -> void:
	preview_polygons.clear()
	if not is_instance_valid(dock):
		update_overlays()
		return
		
	var tex: Texture2D = null
	var sprite_props = {}
	
	if is_instance_valid(preview_target_node) and preview_target_node is Sprite2D:
		tex = preview_target_node.texture
		sprite_props = {
			"centered": preview_target_node.centered,
			"offset": preview_target_node.offset,
			"flip_h": preview_target_node.flip_h,
			"flip_v": preview_target_node.flip_v,
			"region_enabled": preview_target_node.region_enabled,
			"region_rect": preview_target_node.region_rect
		}
	elif dock.target_texture:
		tex = dock.target_texture
		sprite_props = {"centered": true, "offset": Vector2.ZERO, "flip_h": false, "flip_v": false}
		
	if tex:
		preview_polygons = Generator.generate_collision_polygons(tex, preview_options, sprite_props)
		var total_pts = 0
		for p in preview_polygons:
			total_pts += p.size()
		dock.set_stats(preview_polygons.size(), total_pts)
		if preview_polygons.is_empty():
			dock.set_status_message("⚠️ Warning: No solid pixels detected at alpha threshold %.2f." % preview_options.get("alpha_threshold", 0.5), true)
		elif total_pts > 256:
			dock.set_status_message("⚠️ High vertex count (%d pts in %d polys). Consider higher simplification." % [total_pts, preview_polygons.size()], false)
	else:
		dock.set_stats(0, 0)
		
	update_overlays()

# ---------------------------------------------------------
# Factory for Presets (StaticBody2D, AnimatableBody2D, Area2D)
# ---------------------------------------------------------
func _create_physics_root(base_name: String, options: Dictionary) -> CollisionObject2D:
	var preset = options.get("preset", 0)
	var root: CollisionObject2D
	match preset:
		1: # Rotating Maze / Obstacle
			var body = AnimatableBody2D.new()
			body.name = "%sRotatingObstacle" % base_name
			var script = load("res://addons/sprite_staticbody_builder/resources/rotating_obstacle.gd")
			if script:
				body.set_script(script)
				body.set("rotation_speed_deg", options.get("rotation_speed", 45.0))
			root = body
		2: # Hazard / Trap
			var area = Area2D.new()
			area.name = "%sHazard" % base_name
			var script = load("res://addons/sprite_staticbody_builder/resources/hazard_area.gd")
			if script:
				area.set_script(script)
			area.add_to_group("hazards")
			root = area
		3: # Goal / Checkered Flag
			var area = Area2D.new()
			area.name = "%sGoal" % base_name
			var script = load("res://addons/sprite_staticbody_builder/resources/goal_area.gd")
			if script:
				area.set_script(script)
			area.add_to_group("goals")
			root = area
		4: # Bumper / Spring Pad
			var area = Area2D.new()
			area.name = "%sBumper" % base_name
			var script = load("res://addons/sprite_staticbody_builder/resources/bumper_pad.gd")
			if script:
				area.set_script(script)
				area.set("launch_force", options.get("bounce_force", 650.0))
			area.add_to_group("bumpers")
			root = area
		5: # One-Way Jelly Membrane
			var body = StaticBody2D.new()
			body.name = "%sOneWayMembrane" % base_name
			var script = load("res://addons/sprite_staticbody_builder/resources/one_way_membrane.gd")
			if script:
				body.set_script(script)
			body.add_to_group("one_way_membranes")
			root = body
		6: # Teleport Portal
			var area = Area2D.new()
			area.name = "%sPortal" % base_name
			var script = load("res://addons/sprite_staticbody_builder/resources/teleport_portal.gd")
			if script:
				area.set_script(script)
			area.add_to_group("portals")
			root = area
		7: # Collectible Star / Gem
			var star_idx: int = options.get("star_index", 1)
			var area = Area2D.new()
			area.name = "%sStar%d" % [base_name, star_idx]
			var script = load("res://addons/sprite_staticbody_builder/resources/collectible_star.gd")
			if script:
				area.set_script(script)
				area.set("star_index", star_idx)
			area.add_to_group("collectibles")
			root = area
		8: # Key Pickup
			var area = Area2D.new()
			var key_id: String = options.get("key_id", "gold")
			area.name = "%sKey_%s" % [base_name, key_id]
			var script = load("res://addons/sprite_staticbody_builder/resources/key_item.gd")
			if script:
				area.set_script(script)
				area.set("key_id", key_id)
			area.add_to_group("keys")
			root = area
		9: # Locked Door
			var body = StaticBody2D.new()
			var key_id: String = options.get("key_id", "gold")
			body.name = "%sDoor_%s" % [base_name, key_id]
			var script = load("res://addons/sprite_staticbody_builder/resources/locked_door.gd")
			if script:
				body.set_script(script)
				body.set("required_key_id", key_id)
			body.add_to_group("locked_doors")
			root = body
		_: # 0: Static Wall / Platform
			var body = StaticBody2D.new()
			body.name = "%sBody" % base_name
			root = body
	return root

func _build_shadow_sprite(sprite: Sprite2D, options: Dictionary) -> Sprite2D:
	if not options.get("add_shadow", true):
		return null
	var shadow = Sprite2D.new()
	shadow.name = "%sShadow" % sprite.name
	shadow.texture = sprite.texture
	shadow.centered = sprite.centered
	shadow.offset = sprite.offset
	shadow.flip_h = sprite.flip_h
	shadow.flip_v = sprite.flip_v
	shadow.region_enabled = sprite.region_enabled
	shadow.region_rect = sprite.region_rect
	
	var offset: Vector2 = options.get("shadow_offset", Vector2(6, 8))
	var color: Color = options.get("shadow_color", Color(0, 0, 0, 0.45))
	var scale_mult: float = options.get("shadow_scale", 1.0)
	var realtime_shadow: bool = options.get("realtime_shadow", true)
	var anchor_mode: int = options.get("anchor_mode", 0)
	var custom_anchor: Vector2 = options.get("custom_anchor_offset", Vector2.ZERO)
	var light_angle: float = options.get("light_angle", 53.13)
	var shadow_dist: float = options.get("shadow_distance", 10.0)
	
	var shadow_script = load("res://addons/sprite_staticbody_builder/resources/realtime_shadow.gd")
	if shadow_script:
		shadow.set_script(shadow_script)
		shadow.set("anchor_mode", anchor_mode)
		shadow.set("custom_anchor_offset", custom_anchor)
		shadow.set("shadow_offset", offset)
		shadow.set("light_angle_deg", light_angle)
		shadow.set("shadow_distance", shadow_dist)
		shadow.set("maintain_light_direction", realtime_shadow)
		shadow.set("shadow_scale", scale_mult)
		shadow.set("shadow_color", color)
		shadow.set("active_in_editor", true)
		shadow.set("auto_sync_sprite", true)
	
	shadow.position = offset
	shadow.scale = Vector2.ONE * scale_mult
	shadow.rotation = 0.0
	shadow.modulate = color
	shadow.show_behind_parent = true
	return shadow

# ---------------------------------------------------------
# Create StaticBody Workflow (with Undo/Redo)
# ---------------------------------------------------------
func _on_create_staticbody(options: Dictionary) -> void:
	var scene_root = EditorInterface.get_edited_scene_root()
	if not scene_root:
		dock.set_status_message("No open scene to create StaticBody in.", true)
		return
		
	# Check whether we are converting a Sprite2D or creating from FileSystem texture
	if is_instance_valid(dock.target_sprite):
		_convert_sprite_to_body(dock.target_sprite, options, scene_root)
	elif dock.target_texture:
		_create_body_from_texture(dock.target_texture, dock.target_texture_path, options, scene_root)
	elif is_instance_valid(dock.target_body):
		# Body already exists -> regenerate collision
		_on_regenerate_collision(options)
	else:
		dock.set_status_message("Select a Sprite2D or texture first.", true)

func _convert_sprite_to_body(sprite: Sprite2D, options: Dictionary, scene_root: Node) -> void:
	if not sprite.texture:
		dock.set_status_message("Sprite2D has no texture assigned.", true)
		return
		
	var orig_parent = sprite.get_parent()
	var orig_index = sprite.get_index()
	var orig_xform = sprite.transform
	
	var create_body: bool = options.get("create_static_body", true)
	var keep_sprite: bool = options.get("keep_sprite", true)
	var auto_col: bool = options.get("auto_collision", true)
	
	var body: CollisionObject2D = null
	if create_body:
		body = _create_physics_root(sprite.name, options)
		body.transform = orig_xform
	
	# Build shadow sprite if requested
	var shadow_sprite: Sprite2D = _build_shadow_sprite(sprite, options)
	
	# Generate collision polygons in sprite's local coordinates
	var col_nodes: Array[CollisionPolygon2D] = []
	if auto_col:
		var sprite_props = {
			"centered": sprite.centered,
			"offset": sprite.offset,
			"flip_h": sprite.flip_h,
			"flip_v": sprite.flip_v,
			"region_enabled": sprite.region_enabled,
			"region_rect": sprite.region_rect
		}
		var polys = Generator.generate_collision_polygons(sprite.texture, options, sprite_props)
		if polys.is_empty():
			dock.set_status_message("⚠️ Warning: No solid pixels detected at alpha threshold %.2f." % options.get("alpha_threshold", 0.5), true)
			
		var build_mode = CollisionPolygon2D.BUILD_SEGMENTS if options.get("build_mode", 0) == 1 else CollisionPolygon2D.BUILD_SOLIDS
		var is_one_way = (options.get("preset", 0) == 5)
		for i in range(polys.size()):
			var col = CollisionPolygon2D.new()
			col.name = "CollisionPolygon2D" if i == 0 else "CollisionPolygon2D_%d" % (i + 1)
			col.polygon = polys[i]
			col.build_mode = build_mode
			if is_one_way:
				col.one_way_collision = true
				col.one_way_collision_margin = 8.0
			col_nodes.append(col)
		
	# Execute via Undo/Redo with add_do_reference (No free() calls on undo to prevent Redo crashes!)
	var ur = get_undo_redo()
	ur.create_action("Convert Sprite to Physics Body")
	ur.add_do_method(self, "_do_convert_sprite", orig_parent, orig_index, body, sprite, shadow_sprite, col_nodes, scene_root, keep_sprite)
	ur.add_undo_method(self, "_undo_convert_sprite", orig_parent, orig_index, body, sprite, shadow_sprite, col_nodes, orig_xform, keep_sprite)
	
	if is_instance_valid(body):
		ur.add_do_reference(body)
	if is_instance_valid(shadow_sprite):
		ur.add_do_reference(shadow_sprite)
	for col in col_nodes:
		ur.add_do_reference(col)
		
	ur.commit_action()
	
	var shadow_msg = " + Real Shadow" if is_instance_valid(shadow_sprite) else ""
	var target_name = body.name if is_instance_valid(body) else sprite.name
	dock.set_status_message("'%s' created with %d collision polygon(s)%s!" % [target_name, col_nodes.size(), shadow_msg])
	EditorInterface.get_selection().clear()
	if is_instance_valid(body):
		EditorInterface.get_selection().add_node(body)
	else:
		EditorInterface.get_selection().add_node(sprite)

func _do_convert_sprite(orig_parent: Node, orig_index: int, body: CollisionObject2D, sprite: Sprite2D, shadow_sprite: Sprite2D, col_nodes: Array[CollisionPolygon2D], scene_root: Node, keep_sprite: bool) -> void:
	if is_instance_valid(body):
		orig_parent.add_child(body)
		orig_parent.move_child(body, orig_index)
		body.owner = scene_root
		
		# Add shadow sprite first (so it naturally renders underneath main sprite)
		if is_instance_valid(shadow_sprite):
			body.add_child(shadow_sprite)
			shadow_sprite.owner = scene_root
			
		# Reparent main sprite under body if keep_sprite is enabled
		if keep_sprite:
			if sprite.get_parent() != null:
				sprite.get_parent().remove_child(sprite)
			body.add_child(sprite)
			sprite.owner = scene_root
			sprite.position = Vector2.ZERO
			sprite.rotation = 0.0
			sprite.scale = Vector2.ONE
		else:
			if sprite.get_parent() != null:
				sprite.get_parent().remove_child(sprite)
		
		# Add collision polygon siblings under body
		for col in col_nodes:
			body.add_child(col)
			col.owner = scene_root
	else:
		# Direct attachment without wrapping in a new body
		if is_instance_valid(shadow_sprite):
			orig_parent.add_child(shadow_sprite)
			orig_parent.move_child(shadow_sprite, orig_index)
			shadow_sprite.owner = scene_root
		for col in col_nodes:
			sprite.add_child(col)
			col.owner = scene_root

func _undo_convert_sprite(orig_parent: Node, orig_index: int, body: CollisionObject2D, sprite: Sprite2D, shadow_sprite: Sprite2D, col_nodes: Array[CollisionPolygon2D], orig_xform: Transform2D, keep_sprite: bool) -> void:
	if is_instance_valid(body):
		# Remove collision nodes without freeing (managed by add_do_reference)
		for col in col_nodes:
			if is_instance_valid(col) and col.get_parent() == body:
				body.remove_child(col)
				
		# Remove shadow sprite without freeing
		if is_instance_valid(shadow_sprite) and shadow_sprite.get_parent() == body:
			body.remove_child(shadow_sprite)
				
		# Restore sprite back to original parent
		if is_instance_valid(sprite):
			if sprite.get_parent() == body:
				body.remove_child(sprite)
			if sprite.get_parent() != orig_parent:
				orig_parent.add_child(sprite)
				orig_parent.move_child(sprite, orig_index)
			sprite.owner = EditorInterface.get_edited_scene_root()
			sprite.transform = orig_xform
		
		# Remove body without freeing
		if body.get_parent() == orig_parent:
			orig_parent.remove_child(body)
	else:
		for col in col_nodes:
			if is_instance_valid(col) and col.get_parent() == sprite:
				sprite.remove_child(col)
		if is_instance_valid(shadow_sprite) and shadow_sprite.get_parent() == orig_parent:
			orig_parent.remove_child(shadow_sprite)

# ---------------------------------------------------------
# Create StaticBody from FileSystem Texture
# ---------------------------------------------------------
func _create_body_from_texture(texture: Texture2D, path: String, options: Dictionary, scene_root: Node) -> void:
	var base_name = path.get_file().get_basename().capitalize().replace(" ", "")
	var body = _create_physics_root(base_name, options)
	
	# Place at editor viewport center
	var vp = EditorInterface.get_editor_viewport_2d()
	if vp:
		var center = vp.get_visible_rect().get_center()
		var full_xform = vp.global_canvas_transform
		body.position = full_xform.affine_inverse() * center
	else:
		body.position = Vector2(200, 200)
		
	var keep_sprite: bool = options.get("keep_sprite", true)
	var auto_col: bool = options.get("auto_collision", true)
	
	var sprite = Sprite2D.new()
	sprite.name = "%sSprite" % base_name
	sprite.texture = texture
	sprite.centered = true
	
	var shadow_sprite: Sprite2D = _build_shadow_sprite(sprite, options)
	
	var col_nodes: Array[CollisionPolygon2D] = []
	if auto_col:
		var sprite_props = {"centered": true, "offset": Vector2.ZERO, "flip_h": false, "flip_v": false}
		var polys = Generator.generate_collision_polygons(texture, options, sprite_props)
		if polys.is_empty():
			dock.set_status_message("⚠️ Warning: No solid pixels detected at alpha threshold %.2f." % options.get("alpha_threshold", 0.5), true)
		var build_mode = CollisionPolygon2D.BUILD_SEGMENTS if options.get("build_mode", 0) == 1 else CollisionPolygon2D.BUILD_SOLIDS
		var is_one_way = (options.get("preset", 0) == 5)
		for i in range(polys.size()):
			var col = CollisionPolygon2D.new()
			col.name = "CollisionPolygon2D" if i == 0 else "CollisionPolygon2D_%d" % (i + 1)
			col.polygon = polys[i]
			col.build_mode = build_mode
			if is_one_way:
				col.one_way_collision = true
				col.one_way_collision_margin = 8.0
			col_nodes.append(col)
		
	var ur = get_undo_redo()
	ur.create_action("Create Physics Body from Texture")
	ur.add_do_method(self, "_do_add_body_tree", scene_root, body, sprite if keep_sprite else null, shadow_sprite, col_nodes)
	ur.add_undo_method(self, "_undo_add_body_tree", scene_root, body)
	
	ur.add_do_reference(body)
	if keep_sprite:
		ur.add_do_reference(sprite)
	if is_instance_valid(shadow_sprite):
		ur.add_do_reference(shadow_sprite)
	for col in col_nodes:
		ur.add_do_reference(col)
		
	ur.commit_action()
	
	var shadow_msg = " + Real Shadow" if is_instance_valid(shadow_sprite) else ""
	dock.set_status_message("Created '%s' with %d collision polygon(s)%s!" % [body.name, col_nodes.size(), shadow_msg])
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(body)

func _do_add_body_tree(parent: Node, body: CollisionObject2D, sprite: Sprite2D, shadow_sprite: Sprite2D, col_nodes: Array[CollisionPolygon2D]) -> void:
	var root = EditorInterface.get_edited_scene_root()
	parent.add_child(body)
	body.owner = root
	if is_instance_valid(shadow_sprite):
		body.add_child(shadow_sprite)
		shadow_sprite.owner = root
	if is_instance_valid(sprite):
		body.add_child(sprite)
		sprite.owner = root
	for col in col_nodes:
		body.add_child(col)
		col.owner = root

func _undo_add_body_tree(parent: Node, body: CollisionObject2D) -> void:
	if is_instance_valid(body) and body.get_parent() == parent:
		parent.remove_child(body)
		# DO NOT call queue_free(); add_do_reference manages lifetime for clean redo!

# ---------------------------------------------------------
# Regenerate Collision Workflow (with Undo/Redo)
# ---------------------------------------------------------
func _on_regenerate_collision(options: Dictionary) -> void:
	var body = dock.target_body
	var sprite = dock.target_sprite
	if not is_instance_valid(body):
		if is_instance_valid(sprite) and sprite.get_parent() is CollisionObject2D:
			body = sprite.get_parent()
		else:
			dock.set_status_message("No physics body selected to regenerate collision.", true)
			return
			
	if not is_instance_valid(sprite) or not sprite.texture:
		dock.set_status_message("Target has no valid Sprite2D with texture.", true)
		return
		
	# Find old collision nodes
	var old_col_nodes: Array[CollisionPolygon2D] = []
	for child in body.get_children():
		if child is CollisionPolygon2D:
			old_col_nodes.append(child)
			
	# Check shadow sprite
	var old_shadow: Sprite2D = null
	for child in body.get_children():
		if child is Sprite2D and child != sprite and (child.name.begins_with("Shadow") or child.name.ends_with("Shadow")):
			old_shadow = child
			break
	var new_shadow: Sprite2D = _build_shadow_sprite(sprite, options)
			
	# Generate new collision polygons
	var sprite_props = {
		"centered": sprite.centered,
		"offset": sprite.offset,
		"flip_h": sprite.flip_h,
		"flip_v": sprite.flip_v,
		"region_enabled": sprite.region_enabled,
		"region_rect": sprite.region_rect
	}
	var polys = Generator.generate_collision_polygons(sprite.texture, options, sprite_props)
	if polys.is_empty():
		dock.set_status_message("⚠️ Warning: No solid pixels detected at alpha threshold %.2f." % options.get("alpha_threshold", 0.5), true)
		
	var new_col_nodes: Array[CollisionPolygon2D] = []
	var build_mode = CollisionPolygon2D.BUILD_SEGMENTS if options.get("build_mode", 0) == 1 else CollisionPolygon2D.BUILD_SOLIDS
	var is_one_way = (options.get("preset", 0) == 5)
	for i in range(polys.size()):
		var col = CollisionPolygon2D.new()
		col.name = "CollisionPolygon2D" if i == 0 else "CollisionPolygon2D_%d" % (i + 1)
		col.polygon = polys[i]
		col.build_mode = build_mode
		if is_one_way:
			col.one_way_collision = true
			col.one_way_collision_margin = 8.0
		new_col_nodes.append(col)
		
	var scene_root = EditorInterface.get_edited_scene_root()
	var ur = get_undo_redo()
	ur.create_action("Regenerate Collision & Shadow")
	ur.add_do_method(self, "_do_replace_collisions", body, old_col_nodes, new_col_nodes, old_shadow, new_shadow, scene_root)
	ur.add_undo_method(self, "_undo_replace_collisions", body, old_col_nodes, new_col_nodes, old_shadow, new_shadow, scene_root)
	
	for old in old_col_nodes:
		ur.add_undo_reference(old)
	if is_instance_valid(old_shadow):
		ur.add_undo_reference(old_shadow)
	for new_col in new_col_nodes:
		ur.add_do_reference(new_col)
	if is_instance_valid(new_shadow):
		ur.add_do_reference(new_shadow)
		
	ur.commit_action()
	
	var shadow_status = " + Shadow updated" if is_instance_valid(new_shadow) else ""
	dock.set_status_message("Regenerated %d collision polygon(s) on '%s'%s!" % [new_col_nodes.size(), body.name, shadow_status])
	_calculate_preview()

func _do_replace_collisions(body: CollisionObject2D, old_nodes: Array[CollisionPolygon2D], new_nodes: Array[CollisionPolygon2D], old_shadow: Sprite2D, new_shadow: Sprite2D, root: Node) -> void:
	for old in old_nodes:
		if is_instance_valid(old) and old.get_parent() == body:
			body.remove_child(old)
	for new_node in new_nodes:
		body.add_child(new_node)
		new_node.owner = root
		
	if is_instance_valid(old_shadow) and old_shadow.get_parent() == body:
		body.remove_child(old_shadow)
	if is_instance_valid(new_shadow):
		body.add_child(new_shadow)
		new_shadow.owner = root
		body.move_child(new_shadow, 0)

func _undo_replace_collisions(body: CollisionObject2D, old_nodes: Array[CollisionPolygon2D], new_nodes: Array[CollisionPolygon2D], old_shadow: Sprite2D, new_shadow: Sprite2D, root: Node) -> void:
	for new_node in new_nodes:
		if is_instance_valid(new_node) and new_node.get_parent() == body:
			body.remove_child(new_node)
	for old in old_nodes:
		if is_instance_valid(old):
			body.add_child(old)
			old.owner = root
			
	if is_instance_valid(new_shadow) and new_shadow.get_parent() == body:
		body.remove_child(new_shadow)
	if is_instance_valid(old_shadow):
		body.add_child(old_shadow)
		old_shadow.owner = root
		body.move_child(old_shadow, 0)

# ---------------------------------------------------------
# Remove Collision Workflow (with Undo/Redo)
# ---------------------------------------------------------
func _on_remove_collision() -> void:
	var body = dock.target_body
	if not is_instance_valid(body) and is_instance_valid(dock.target_sprite) and dock.target_sprite.get_parent() is CollisionObject2D:
		body = dock.target_sprite.get_parent()
		
	if not is_instance_valid(body):
		dock.set_status_message("No physics body selected.", true)
		return
		
	var col_nodes: Array[CollisionPolygon2D] = []
	for child in body.get_children():
		if child is CollisionPolygon2D:
			col_nodes.append(child)
			
	if col_nodes.is_empty():
		dock.set_status_message("No CollisionPolygon2D nodes to remove.", false)
		return
		
	var scene_root = EditorInterface.get_edited_scene_root()
	var ur = get_undo_redo()
	ur.create_action("Remove Collision")
	ur.add_do_method(self, "_do_remove_collisions", body, col_nodes)
	ur.add_undo_method(self, "_undo_remove_collisions", body, col_nodes, scene_root)
	
	for col in col_nodes:
		ur.add_undo_reference(col)
		
	ur.commit_action()
	
	dock.set_status_message("Removed %d collision polygon(s) from '%s'." % [col_nodes.size(), body.name])
	_clear_preview()

func _do_remove_collisions(body: CollisionObject2D, col_nodes: Array[CollisionPolygon2D]) -> void:
	for col in col_nodes:
		if is_instance_valid(col) and col.get_parent() == body:
			body.remove_child(col)

func _undo_remove_collisions(body: CollisionObject2D, col_nodes: Array[CollisionPolygon2D], root: Node) -> void:
	for col in col_nodes:
		if is_instance_valid(col):
			body.add_child(col)
			col.owner = root
