@tool
class_name SpriteStaticBodyCollisionPreview
extends RefCounted

## Manages and draws the live 2D editor viewport overlay preview for generated collision geometry.

static var fill_color: Color = Color(0.15, 0.85, 0.45, 0.28)
static var border_color: Color = Color(0.2, 1.0, 0.55, 0.95)
static var vertex_outer_color: Color = Color(1.0, 0.95, 0.2, 1.0)
static var vertex_inner_color: Color = Color(0.1, 0.1, 0.1, 1.0)

## Draw collision polygons on editor canvas overlay
static func draw_preview(overlay: Control, target_node: CanvasItem, polygons: Array[PackedVector2Array], options: Dictionary = {}) -> void:
	if not overlay or not is_instance_valid(target_node) or not target_node.is_inside_tree():
		return
	if polygons.is_empty():
		return
		
	# Compute transform from target local coordinates to editor viewport overlay coordinates
	var canvas_xform = target_node.get_viewport_transform()
	var global_xform = target_node.get_global_transform()
	var xform = canvas_xform * global_xform
	
	# Draw Shadow Preview if enabled in options
	if options.get("add_shadow", false):
		var shadow_off: Vector2 = options.get("shadow_offset", Vector2(6, 8))
		var shadow_scale: float = options.get("shadow_scale", 1.0)
		var shadow_col: Color = options.get("shadow_color", Color(0, 0, 0, 0.4))
		var realtime: bool = options.get("realtime_shadow", true)
		
		var anchor_mode: int = options.get("anchor_mode", 0)
		var anchor_disp: Vector2 = Vector2.ZERO
		if anchor_mode == 1 and target_node is Sprite2D and target_node.texture:
			var half_h: float = (target_node.texture.get_height() * 0.5) if target_node.centered else float(target_node.texture.get_height())
			anchor_disp = xform.basis_xform(Vector2(0, half_h))
		
		# Compute screen-space shadow offset
		var screen_shadow_offset: Vector2
		if realtime:
			# Offset remains constant in world/screen space regardless of target rotation
			screen_shadow_offset = canvas_xform.basis_xform(shadow_off)
		else:
			# Offset rotates with target node
			screen_shadow_offset = xform.basis_xform(shadow_off)
			
		for poly in polygons:
			if poly.size() < 3:
				continue
			var shadow_pts = PackedVector2Array()
			for pt in poly:
				var s_pt = (xform * (pt * shadow_scale)) + anchor_disp + screen_shadow_offset
				shadow_pts.append(s_pt)
			overlay.draw_colored_polygon(shadow_pts, shadow_col)
			var closed_shadow = shadow_pts.duplicate()
			closed_shadow.append(shadow_pts[0])
			overlay.draw_polyline(closed_shadow, Color(0.15, 0.15, 0.2, 0.6), 1.5, true)
	
	var total_vertices = 0
	var min_screen_pos = Vector2(INF, INF)
	
	for poly in polygons:
		if poly.size() < 3:
			continue
			
		var screen_pts = PackedVector2Array()
		for pt in poly:
			var s_pt = xform * pt
			screen_pts.append(s_pt)
			min_screen_pos.x = minf(min_screen_pos.x, s_pt.x)
			min_screen_pos.y = minf(min_screen_pos.y, s_pt.y)
			
		total_vertices += screen_pts.size()
		
		# 1. Draw semi-transparent polygon fill
		overlay.draw_colored_polygon(screen_pts, fill_color)
		
		# 2. Draw outline border
		var closed_pts = screen_pts.duplicate()
		closed_pts.append(screen_pts[0])
		overlay.draw_polyline(closed_pts, border_color, 2.0, true)
		
		# 3. Draw vertex indicators
		for s_pt in screen_pts:
			overlay.draw_circle(s_pt, 3.5, vertex_outer_color)
			overlay.draw_circle(s_pt, 1.5, vertex_inner_color)
			
	# Draw little stats tag above the object
	if total_vertices > 0 and min_screen_pos.x != INF:
		var tag_pos = min_screen_pos + Vector2(0, -14)
		var font = overlay.get_theme_default_font()
		var font_size = 11
		var text = "Collision: %d polys, %d pts" % [polygons.size(), total_vertices]
		var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size) if font else Vector2(120, 14)
		var rect = Rect2(tag_pos.x - 4, tag_pos.y - text_size.y, text_size.x + 8, text_size.y + 4)
		overlay.draw_rect(rect, Color(0.1, 0.12, 0.15, 0.85), true, 3.0)
		overlay.draw_rect(rect, border_color, false, 1.0, 3.0)
		if font:
			overlay.draw_string(font, tag_pos + Vector2(0, -2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.9, 1.0, 0.9))
