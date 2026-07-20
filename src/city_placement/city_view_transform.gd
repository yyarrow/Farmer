extends RefCounted

const HUD_BOTTOM := 184.0
# Maximum-tier defense reaches x=568.3. This canvas keeps the terrain source's
# aspect ratio while covering the complete horizontal inspection range.
const CANVAS_SIZE := Vector2(570.0, 1015.0)

static func scale_for_capacity(capacity: int, configured_scale: float) -> float:
	var maximum := 1.0
	if capacity >= 12:
		maximum = 1.08
	elif capacity >= 9:
		maximum = 1.04
	return minf(configured_scale, maximum)

static func horizontal_bounds(
	viewport_width: float,
	scale: float,
	content_bounds := Rect2()
) -> Vector2:
	var bounds := Rect2(content_bounds)
	if bounds.size.x <= 0.0:
		bounds = Rect2(0.0, 0.0, viewport_width, 1.0)
	var scaled_width := bounds.size.x * scale
	if scaled_width <= viewport_width:
		var centered := (viewport_width - (bounds.position.x + bounds.end.x) * scale) * 0.5
		return Vector2(centered, centered)
	var minimum := viewport_width - bounds.end.x * scale
	var maximum := -bounds.position.x * scale
	return Vector2(minimum, maximum)

static func centered_pan(viewport_width: float, scale: float, content_bounds := Rect2()) -> float:
	var bounds := horizontal_bounds(viewport_width, scale, content_bounds)
	return (bounds.x + bounds.y) * 0.5

static func world_position(pan_x: float, scale: float) -> Vector2:
	return Vector2(pan_x, HUD_BOTTOM * (1.0 - scale))
