extends RefCounted

# Visual geometry is deliberately separate from economy levels. Placement
# reserves the maximum-stage envelope so an upgrade cannot grow into a neighbor.
const LEVEL_SCALES := [0.90, 0.94, 0.97, 1.00, 1.02, 1.04]
const DEFAULT_PROFILE := {
	"art_size": Vector2(92, 92),
	"base_band": 0.34,
	"base_width": 0.86,
	"minimum_gap": 5.0,
}
const PROFILES := {
	"farm": {"art_size": Vector2(110, 110), "base_band": 0.34, "base_width": 0.90, "minimum_gap": 5.0},
	"woodcut": {"art_size": Vector2(92, 92), "base_band": 0.33, "base_width": 0.86, "minimum_gap": 5.0},
	"quarry": {"art_size": Vector2(92, 92), "base_band": 0.36, "base_width": 0.90, "minimum_gap": 6.0},
	"house": {"art_size": Vector2(92, 92), "base_band": 0.35, "base_width": 0.88, "minimum_gap": 6.0},
	"market": {"art_size": Vector2(101, 101), "base_band": 0.34, "base_width": 0.90, "minimum_gap": 6.0},
	"warehouse": {"art_size": Vector2(101, 101), "base_band": 0.35, "base_width": 0.88, "minimum_gap": 6.0},
	"barracks": {"art_size": Vector2(110, 110), "base_band": 0.37, "base_width": 0.90, "minimum_gap": 7.0},
	"wall": {"art_size": Vector2(110, 110), "base_band": 0.31, "base_width": 0.94, "minimum_gap": 7.0},
}

static func profile(building_type: String) -> Dictionary:
	return PROFILES.get(building_type, DEFAULT_PROFILE)

static func level_scale(level: int) -> float:
	return float(LEVEL_SCALES[clampi(level, 0, LEVEL_SCALES.size() - 1)])

static func art_size(building_type: String, level := 5) -> Vector2:
	return Vector2(profile(building_type).art_size) * level_scale(level)

static func maximum_art_size(building_type: String) -> Vector2:
	return art_size(building_type, LEVEL_SCALES.size() - 1)

static func render_rect(anchor: Vector2, building_type: String, level: int) -> Rect2:
	var size := art_size(building_type, level)
	return Rect2(anchor - Vector2(size.x * 0.5, size.y), size)

static func maximum_render_rect(anchor: Vector2, building_type: String) -> Rect2:
	var size := maximum_art_size(building_type)
	return Rect2(anchor - Vector2(size.x * 0.5, size.y), size)

static func clearance_rect(anchor: Vector2, building_type: String) -> Rect2:
	var visual := maximum_render_rect(anchor, building_type)
	var data := profile(building_type)
	var width := visual.size.x * float(data.base_width)
	var height := visual.size.y * float(data.base_band)
	return Rect2(Vector2(anchor.x - width * 0.5, anchor.y - height), Vector2(width, height))

static func minimum_gap(building_type: String) -> float:
	return float(profile(building_type).minimum_gap)
