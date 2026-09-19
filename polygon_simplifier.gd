@tool
class_name SpriteStaticBodySimplifier
extends RefCounted

## Polygon simplifier using Ramer-Douglas-Peucker (RDP) algorithm with closed loop support
## and max-points budget enforcement for 2D physics.

enum Preset {
	LOW = 0,     # High detail, epsilon = 1.0, max_points = 128
	MEDIUM = 1,  # Balanced, epsilon = 2.5, max_points = 64
	HIGH = 2,    # Performance, epsilon = 5.0, max_points = 32
	CUSTOM = 3   # User specified
}

static func get_preset_epsilon(preset: int, custom_eps: float = 2.5) -> float:
	match preset:
		Preset.LOW:
			return 1.0
		Preset.MEDIUM:
			return 2.5
		Preset.HIGH:
			return 5.0
		Preset.CUSTOM:
			return maxf(0.1, custom_eps)
		_:
			return 2.5

static func get_preset_max_points(preset: int, custom_max: int = 64) -> int:
	match preset:
		Preset.LOW:
			return 128
		Preset.MEDIUM:
			return 64
		Preset.HIGH:
			return 32
		Preset.CUSTOM:
			return clampi(custom_max, 4, 512)
		_:
			return 64

## Main entry point to simplify a closed polygon
static func simplify_polygon(points: PackedVector2Array, epsilon: float, max_points: int = 64) -> PackedVector2Array:
	if points.size() <= 3:
		return points
		
	# 1. Clean consecutive duplicate points
	var cleaned = clean_duplicate_points(points)
	if cleaned.size() <= 3:
		return cleaned
		
	# 2. Run initial RDP with base epsilon
	var simplified = rdp_simplify_closed(cleaned, epsilon)
	if simplified.size() < 3:
		simplified = cleaned
		
	# 3. If still over max_points budget, iteratively reduce
	if max_points > 3 and simplified.size() > max_points:
		simplified = enforce_max_points(simplified, max_points)
		
	return simplified

## Clean duplicate or practically identical consecutive vertices
static func clean_duplicate_points(points: PackedVector2Array, min_dist_sq: float = 0.04) -> PackedVector2Array:
	var n = points.size()
	if n <= 3:
		return points
	var result = PackedVector2Array()
	result.append(points[0])
	for i in range(1, n):
		if points[i].distance_squared_to(result[result.size() - 1]) > min_dist_sq:
			result.append(points[i])
	# Also check last to first
	if result.size() > 3 and result[result.size() - 1].distance_squared_to(result[0]) <= min_dist_sq:
		result.remove_at(result.size() - 1)
	return result

## RDP for closed polygon loops
static func rdp_simplify_closed(points: PackedVector2Array, epsilon: float) -> PackedVector2Array:
	var n = points.size()
	if n <= 3:
		return points
		
	# Find point farthest from points[0] to split the closed loop into two open polylines
	var max_d = 0.0
	var split_idx = 1
	for i in range(1, n):
		var d = points[0].distance_squared_to(points[i])
		if d > max_d:
			max_d = d
			split_idx = i
			
	if split_idx == 0 or split_idx >= n:
		return points
		
	# Segment 1: from 0 to split_idx
	var seg1 = points.slice(0, split_idx + 1)
	# Segment 2: from split_idx to n-1 + wrap back to points[0]
	var seg2 = points.slice(split_idx, n)
	seg2.append(points[0])
	
	var r1 = _rdp_open(seg1, epsilon)
	var r2 = _rdp_open(seg2, epsilon)
	
	var result = PackedVector2Array()
	for i in range(r1.size() - 1):
		result.append(r1[i])
	for i in range(r2.size() - 1):
		result.append(r2[i])
		
	if result.size() < 3:
		return points
	return result

## Recursive open polyline RDP
static func _rdp_open(points: PackedVector2Array, epsilon: float) -> PackedVector2Array:
	var n = points.size()
	if n <= 2:
		return points
		
	var dmax = 0.0
	var index = 0
	var start = points[0]
	var end = points[n - 1]
	
	for i in range(1, n - 1):
		var d = _perpendicular_distance(points[i], start, end)
		if d > dmax:
			index = i
			dmax = d
			
	if dmax > epsilon:
		var left = _rdp_open(points.slice(0, index + 1), epsilon)
		var right = _rdp_open(points.slice(index, n), epsilon)
		var res = left.slice(0, left.size() - 1)
		res.append_array(right)
		return res
	else:
		return PackedVector2Array([start, end])

static func _perpendicular_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab = b - a
	var len_ab = ab.length()
	if len_ab < 0.0001:
		return p.distance_to(a)
	return absf((b.y - a.y) * p.x - (b.x - a.x) * p.y + b.x * a.y - b.y * a.x) / len_ab

## Binary search to find epsilon that respects max_points
static func enforce_max_points(points: PackedVector2Array, max_points: int) -> PackedVector2Array:
	if points.size() <= max_points:
		return points
		
	var low_eps = 0.5
	var high_eps = 60.0
	var best = points
	
	for _iter in range(15):
		var mid_eps = (low_eps + high_eps) * 0.5
		var res = rdp_simplify_closed(points, mid_eps)
		if res.size() > max_points:
			low_eps = mid_eps
		else:
			best = res
			high_eps = mid_eps
			if res.size() >= max_points - 2:
				break
				
	return best if best.size() >= 3 else points
