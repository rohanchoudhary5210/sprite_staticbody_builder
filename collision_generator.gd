@tool
class_name SpriteStaticBodyCollisionGenerator
extends RefCounted

const Simplifier = preload("res://addons/sprite_staticbody_builder/polygon_simplifier.gd")

enum CollisionMode {
	SINGLE_POLYGON = 0,
	CONVEX_DECOMPOSITION = 1
}

enum BuildMode {
	SOLIDS = 0,
	SEGMENTS = 1
}

## Main generation function
static func generate_collision_polygons(texture: Texture2D, options: Dictionary = {}, sprite_props: Dictionary = {}) -> Array[PackedVector2Array]:
	if not texture:
		return []
		
	var image: Image = texture.get_image()
	if not image or image.is_empty():
		return []
		
	# Ensure RGBA8 format for reliable alpha reading
	if image.get_format() != Image.FORMAT_RGBA8:
		image = image.duplicate()
		image.convert(Image.FORMAT_RGBA8)
		
	# Handle Sprite2D region_rect if enabled
	var is_region: bool = sprite_props.get("region_enabled", false)
	var region_rect: Rect2 = sprite_props.get("region_rect", Rect2())
	if is_region and region_rect.size.x > 0 and region_rect.size.y > 0:
		var r_pos = Vector2i(region_rect.position)
		var r_size = Vector2i(region_rect.size)
		# Clamp within image bounds
		r_pos.x = clampi(r_pos.x, 0, image.get_width() - 1)
		r_pos.y = clampi(r_pos.y, 0, image.get_height() - 1)
		r_size.x = clampi(r_size.x, 1, image.get_width() - r_pos.x)
		r_size.y = clampi(r_size.y, 1, image.get_height() - r_pos.y)
		image = image.get_region(Rect2i(r_pos, r_size))
		
	var w = image.get_width()
	var h = image.get_height()
	if w <= 0 or h <= 0 or image.is_invisible():
		return []
		
	var alpha_threshold: float = options.get("alpha_threshold", 0.5)
	var preset: int = options.get("simplification_preset", Simplifier.Preset.MEDIUM)
	var custom_eps: float = options.get("custom_epsilon", 2.5)
	var max_points: int = options.get("max_points", 64)
	var collision_mode: int = options.get("collision_mode", CollisionMode.SINGLE_POLYGON)
	
	var epsilon = Simplifier.get_preset_epsilon(preset, custom_eps)
	var point_budget = Simplifier.get_preset_max_points(preset, max_points)
	
	# 1. Detect internal transparent holes via boundary flood fill
	var hole_polys: Array[PackedVector2Array] = _detect_holes(image, alpha_threshold)
	
	# 2. Extract outer contours using BitMap
	var outer_bm = BitMap.new()
	outer_bm.create_from_image_alpha(image, alpha_threshold)
	var raw_polys = outer_bm.opaque_to_polygons(Rect2i(0, 0, w, h), 0.5)
	
	if raw_polys.is_empty():
		return []
		
	# 3. Cut holes from outer polygons to keep holes empty in solid collision
	var solid_polys: Array[PackedVector2Array] = []
	if not hole_polys.is_empty():
		for p in raw_polys:
			var cut_parts = _cut_holes_from_poly(p, hole_polys)
			solid_polys.append_array(cut_parts)
	else:
		solid_polys = raw_polys
		
	# 4. Simplify each polygon and enforce max_points budget
	var simplified_polys: Array[PackedVector2Array] = []
	for poly in solid_polys:
		if poly.size() < 3:
			continue
		var s = Simplifier.simplify_polygon(poly, epsilon, point_budget)
		if s.size() >= 3 and _polygon_area(s) > 1.0:
			simplified_polys.append(s)
			
	# 5. Handle Convex Decomposition if selected
	var decomposed_polys: Array[PackedVector2Array] = []
	if collision_mode == CollisionMode.CONVEX_DECOMPOSITION:
		for poly in simplified_polys:
			var convex_parts = Geometry2D.decompose_polygon_in_convex(poly)
			if convex_parts.is_empty():
				decomposed_polys.append(poly)
			else:
				for cp in convex_parts:
					if cp.size() >= 3 and _polygon_area(cp) > 1.0:
						decomposed_polys.append(cp)
	else:
		decomposed_polys = simplified_polys
		
	# 6. Transform polygon points from Image pixel space into Sprite2D local coordinate space
	var centered: bool = sprite_props.get("centered", true)
	var offset: Vector2 = sprite_props.get("offset", Vector2.ZERO)
	var flip_h: bool = sprite_props.get("flip_h", false)
	var flip_v: bool = sprite_props.get("flip_v", false)
	
	var final_polygons: Array[PackedVector2Array] = []
	for poly in decomposed_polys:
		var xformed = _transform_polygon(poly, w, h, centered, offset, flip_h, flip_v)
		if xformed.size() >= 3 and _polygon_area(xformed) > 1.0:
			final_polygons.append(xformed)
			
	return final_polygons

## Detect internal holes unreachable from image boundary
static func _detect_holes(image: Image, threshold: float) -> Array[PackedVector2Array]:
	var w = image.get_width()
	var h = image.get_height()
	if w < 3 or h < 3:
		return []
		
	# Create solid 2D mask: 1 = solid, 0 = transparent
	# visited: 0 = unvisited, 2 = exterior transparent
	var visited = PackedByteArray()
	visited.resize(w * h)
	visited.fill(0)
	
	# Solid mask
	var solid = PackedByteArray()
	solid.resize(w * h)
	for y in range(h):
		for x in range(w):
			if image.get_pixel(x, y).a >= threshold:
				solid[y * w + x] = 1
			else:
				solid[y * w + x] = 0
				
	# BFS queue for exterior transparent pixels
	var queue: Array[Vector2i] = []
	for x in range(w):
		if solid[x] == 0:
			visited[x] = 2
			queue.append(Vector2i(x, 0))
		var bot_idx = (h - 1) * w + x
		if solid[bot_idx] == 0:
			visited[bot_idx] = 2
			queue.append(Vector2i(x, h - 1))
	for y in range(h):
		var l_idx = y * w
		if solid[l_idx] == 0:
			visited[l_idx] = 2
			queue.append(Vector2i(0, y))
		var r_idx = y * w + (w - 1)
		if solid[r_idx] == 0:
			visited[r_idx] = 2
			queue.append(Vector2i(w - 1, y))
			
	var head = 0
	var dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while head < queue.size():
		var pt = queue[head]
		head += 1
		for d in dirs:
			var nx = pt.x + d.x
			var ny = pt.y + d.y
			if nx >= 0 and nx < w and ny >= 0 and ny < h:
				var idx = ny * w + nx
				if solid[idx] == 0 and visited[idx] == 0:
					visited[idx] = 2
					queue.append(Vector2i(nx, ny))
					
	# Find unvisited transparent pixels (internal holes)
	var hole_bm = BitMap.new()
	hole_bm.create(Vector2i(w, h))
	var has_holes = false
	for y in range(h):
		for x in range(w):
			var idx = y * w + x
			if solid[idx] == 0 and visited[idx] == 0:
				hole_bm.set_bit(x, y, true)
				has_holes = true
				
	if not has_holes:
		return []
		
	var raw_hole_polys = hole_bm.opaque_to_polygons(Rect2i(0, 0, w, h), 0.5)
	var valid_holes: Array[PackedVector2Array] = []
	for hp in raw_hole_polys:
		if hp.size() >= 3 and _polygon_area(hp) >= 4.0:
			valid_holes.append(hp)
	return valid_holes

## Slices polygon across hole centers and subtracts hole geometry
static func _cut_holes_from_poly(outer: PackedVector2Array, holes: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var current_polys: Array[PackedVector2Array] = [outer]
	var huge = 500000.0
	
	for hole in holes:
		var h_rect = _get_bounds(hole)
		var mid_y = h_rect.get_center().y
		
		var top_box = PackedVector2Array([
			Vector2(-huge, -huge), Vector2(huge, -huge),
			Vector2(huge, mid_y), Vector2(-huge, mid_y)
		])
		var bot_box = PackedVector2Array([
			Vector2(-huge, mid_y), Vector2(huge, mid_y),
			Vector2(huge, huge), Vector2(-huge, huge)
		])
		
		var next_polys: Array[PackedVector2Array] = []
		for poly in current_polys:
			var p_rect = _get_bounds(poly)
			if not p_rect.intersects(h_rect):
				next_polys.append(poly)
				continue
				
			var top_parts = Geometry2D.intersect_polygons(poly, top_box)
			var bot_parts = Geometry2D.intersect_polygons(poly, bot_box)
			
			for tp in top_parts:
				var clipped = Geometry2D.clip_polygons(tp, hole)
				for cp in clipped:
					if cp.size() >= 3 and _polygon_area(cp) > 1.0:
						next_polys.append(cp)
						
			for bp in bot_parts:
				var clipped = Geometry2D.clip_polygons(bp, hole)
				for cp in clipped:
					if cp.size() >= 3 and _polygon_area(cp) > 1.0:
						next_polys.append(cp)
						
		if not next_polys.is_empty():
			current_polys = next_polys
			
	return current_polys

## Transforms points from texture pixels to Sprite2D local coordinate space
static func _transform_polygon(poly: PackedVector2Array, w: int, h: int, centered: bool, offset: Vector2, flip_h: bool, flip_v: bool) -> PackedVector2Array:
	var result = PackedVector2Array()
	var center_shift = Vector2(w, h) * 0.5 if centered else Vector2.ZERO
	
	for pt in poly:
		var x = pt.x
		var y = pt.y
		
		if flip_h:
			x = float(w) - x
		if flip_v:
			y = float(h) - y
			
		var local_pt = Vector2(x, y) - center_shift + offset
		result.append(local_pt)
		
	return result

static func _get_bounds(poly: PackedVector2Array) -> Rect2:
	if poly.is_empty():
		return Rect2()
	var r = Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	return r

static func _polygon_area(poly: PackedVector2Array) -> float:
	var n = poly.size()
	if n < 3:
		return 0.0
	var area = 0.0
	for i in range(n):
		var j = (i + 1) % n
		area += poly[i].x * poly[j].y
		area -= poly[j].x * poly[i].y
	return absf(area) * 0.5
