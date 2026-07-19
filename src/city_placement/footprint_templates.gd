extends RefCounted

# Authoring-space contract for standardized building art. Every footprint is
# projected with the same 2:1 isometric transform and fills the same 324x162
# ground bounds inside a 384x384 stage frame.
const FRAME_SIZE := Vector2i(384, 384)
const GROUND_WIDTH := 324.0
const FRONT_Y := 350.0
const GRID_CELL := Vector2(36.0, 18.0)

static func source_quad(footprint: Vector2i) -> PackedVector2Array:
	var logical := _logical_quad(footprint)
	var bounds := _bounds(logical)
	var scale := GROUND_WIDTH / bounds.size.x
	var x_offset := (FRAME_SIZE.x - GROUND_WIDTH) * 0.5 - bounds.position.x * scale
	var y_offset := FRONT_Y - logical[2].y * scale
	var result := PackedVector2Array()
	for point in logical:
		result.append(point * scale + Vector2(x_offset, y_offset))
	return result

static func source_socket(footprint: Vector2i) -> Vector2:
	return source_quad(footprint)[2]

static func screen_scale(footprint: Vector2i) -> float:
	return _bounds(_logical_quad(footprint)).size.x / GROUND_WIDTH

static func frame_display_size(footprint: Vector2i) -> Vector2:
	return Vector2(FRAME_SIZE) * screen_scale(footprint)

static func _logical_quad(size: Vector2i) -> PackedVector2Array:
	var half := GRID_CELL * 0.5
	return PackedVector2Array([
		Vector2(0, -half.y),
		Vector2(size.x * half.x, (size.x - 1) * half.y),
		Vector2((size.x - size.y) * half.x, (size.x + size.y - 1) * half.y),
		Vector2(-size.y * half.x, (size.y - 1) * half.y),
	])

static func _bounds(points: PackedVector2Array) -> Rect2:
	var result := Rect2(points[0], Vector2.ZERO)
	for point in points:
		result = result.expand(point)
	return result
