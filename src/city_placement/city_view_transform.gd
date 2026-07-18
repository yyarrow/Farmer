extends RefCounted

const HUD_BOTTOM := 184.0

static func scale_for_capacity(capacity: int, configured_scale: float) -> float:
	var maximum := 1.0
	if capacity >= 12:
		maximum = 1.08
	elif capacity >= 9:
		maximum = 1.04
	return minf(configured_scale, maximum)

static func horizontal_bounds(viewport_width: float, scale: float) -> Vector2:
	var minimum := viewport_width - viewport_width * scale
	return Vector2(minimum, 0.0)

static func centered_pan(viewport_width: float, scale: float) -> float:
	var bounds := horizontal_bounds(viewport_width, scale)
	return (bounds.x + bounds.y) * 0.5

static func world_position(pan_x: float, scale: float) -> Vector2:
	return Vector2(pan_x, HUD_BOTTOM * (1.0 - scale))
