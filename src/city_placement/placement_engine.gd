extends RefCounted

const BuildingProfiles = preload("res://src/city_placement/building_profiles.gd")

# Pure city-placement geometry. Rendering, persistence and UI consume this
# module through CityLayout's compatibility facade.
const MAX_SLOTS := 12
const UNIQUE_BUILDINGS := ["wall"]
const GRID_SIZE := Vector2i(15, 12)
const CELL_SIZE := Vector2(36.0, 18.0)
const GRID_ORIGIN := Vector2(270.0, 220.0)
const ROAD_COLUMN := 7
const INVALID_ORIGIN := Vector2i(-1, -1)
const CITY_SAFE_RECT := Rect2(20, 188, 500, 322)

const BUILDING_FOOTPRINTS := {
	"farm": Vector2i(3, 3),
	"woodcut": Vector2i(2, 2),
	"quarry": Vector2i(2, 2),
	"house": Vector2i(2, 2),
	"market": Vector2i(3, 2),
	"warehouse": Vector2i(3, 2),
	"barracks": Vector2i(3, 3),
	"wall": Vector2i(4, 2),
}

static var _road_overlap_cache := {}

const LEGACY_ORIGINS := [
	Vector2i(2, 1), Vector2i(4, 1), Vector2i(8, 1), Vector2i(10, 1),
	Vector2i(2, 4), Vector2i(4, 4), Vector2i(8, 4), Vector2i(10, 4),
	Vector2i(2, 7), Vector2i(4, 7), Vector2i(8, 7), Vector2i(10, 7),
]

static func footprint(building_type: String) -> Vector2i:
	return BUILDING_FOOTPRINTS.get(building_type, Vector2i(2, 2))

static func grid_to_screen(cell: Vector2i) -> Vector2:
	return GRID_ORIGIN + Vector2(
		float(cell.x - cell.y) * CELL_SIZE.x * 0.5,
		float(cell.x + cell.y) * CELL_SIZE.y * 0.5
	)

static func screen_to_grid(point: Vector2) -> Vector2i:
	var local := point - GRID_ORIGIN
	var gx := local.x / CELL_SIZE.x + local.y / CELL_SIZE.y
	var gy := local.y / CELL_SIZE.y - local.x / CELL_SIZE.x
	return Vector2i(roundi(gx), roundi(gy))

static func cell_polygon(cell: Vector2i) -> PackedVector2Array:
	var center := grid_to_screen(cell)
	var half := CELL_SIZE * 0.5
	return PackedVector2Array([
		center + Vector2(0, -half.y), center + Vector2(half.x, 0),
		center + Vector2(0, half.y), center + Vector2(-half.x, 0),
	])

static func footprint_polygon(origin: Vector2i, building_type: String) -> PackedVector2Array:
	return grid_rect_polygon(origin, footprint(building_type))

static func grid_rect_polygon(origin: Vector2i, size: Vector2i) -> PackedVector2Array:
	var half := CELL_SIZE * 0.5
	return PackedVector2Array([
		grid_to_screen(origin) + Vector2(0, -half.y),
		grid_to_screen(origin + Vector2i(size.x - 1, 0)) + Vector2(half.x, 0),
		grid_to_screen(origin + size - Vector2i.ONE) + Vector2(0, half.y),
		grid_to_screen(origin + Vector2i(0, size.y - 1)) + Vector2(-half.x, 0),
	])

static func art_anchor(origin: Vector2i, building_type: String) -> Vector2:
	return footprint_polygon(origin, building_type)[2]

static func depth(origin: Vector2i, building_type: String) -> int:
	var size := footprint(building_type)
	return (origin.x + size.x + origin.y + size.y) * 10 + origin.x

static func art_scale(building_type: String) -> float:
	var size := footprint(building_type)
	return clampf(0.72 + float(size.x + size.y - 4) * 0.07, 0.72, 0.93)

static func visual_rect(origin: Vector2i, building_type: String, level := 5) -> Rect2:
	return BuildingProfiles.render_rect(art_anchor(origin, building_type), building_type, level)

static func visual_clearance_rect(origin: Vector2i, building_type: String) -> Rect2:
	return BuildingProfiles.clearance_rect(art_anchor(origin, building_type), building_type)

static func rect_overlap_ratio(first: Rect2, second: Rect2) -> float:
	if not first.intersects(second):
		return 0.0
	var overlap := first.intersection(second)
	var denominator := minf(first.get_area(), second.get_area())
	return 0.0 if denominator <= 0.0 else overlap.get_area() / denominator

static func visual_conflict(
	building_type: String,
	origin: Vector2i,
	other_type: String,
	other_origin: Vector2i
) -> bool:
	var gap := maxf(BuildingProfiles.minimum_gap(building_type), BuildingProfiles.minimum_gap(other_type))
	return rect_overlap_ratio(
		visual_clearance_rect(origin, building_type).grow(gap * 0.5),
		visual_clearance_rect(other_origin, other_type).grow(gap * 0.5)
	) > 0.18

static func visual_outside_ratio(origin: Vector2i, building_type: String) -> float:
	var rect := visual_rect(origin, building_type)
	var visible := rect.intersection(CITY_SAFE_RECT)
	return 1.0 if rect.get_area() <= 0.0 else 1.0 - visible.get_area() / rect.get_area()

static func layout_visual_metrics(instances: Array) -> Dictionary:
	var conflicts := 0
	var total_overlap := 0.0
	var max_overlap := 0.0
	var outside := 0.0
	for index in instances.size():
		var instance = instances[index]
		if instance is not Dictionary:
			continue
		var building_type := str(instance.get("type", ""))
		var origin := instance_origin(instance)
		outside += visual_outside_ratio(origin, building_type)
		for other_index in range(index + 1, instances.size()):
			var other = instances[other_index]
			if other is not Dictionary:
				continue
			var other_type := str(other.get("type", ""))
			var other_origin := instance_origin(other)
			if visual_conflict(building_type, origin, other_type, other_origin):
				conflicts += 1
			var overlap := rect_overlap_ratio(
				visual_rect(origin, building_type), visual_rect(other_origin, other_type)
			)
			total_overlap += overlap
			max_overlap = maxf(max_overlap, overlap)
	return {
		"conflicts": conflicts,
		"total_overlap": total_overlap,
		"max_overlap": max_overlap,
		"outside": outside,
	}

static func unlocked_region(unlocked_count: int) -> Rect2i:
	if unlocked_count <= 6:
		return Rect2i(2, 1, 11, 10)
	if unlocked_count <= 9:
		return Rect2i(1, 0, 13, 12)
	return Rect2i(Vector2i.ZERO, GRID_SIZE)

static func road_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in GRID_SIZE.y:
		result.append(Vector2i(ROAD_COLUMN, y))
	return result

static func is_road(cell: Vector2i) -> bool:
	return cell.x == ROAD_COLUMN and cell.y >= 0 and cell.y < GRID_SIZE.y

static func is_cell_unlocked(cell: Vector2i, unlocked_count: int) -> bool:
	return unlocked_region(unlocked_count).has_point(cell) and not is_road(cell)

static func has_road_clearance(origin: Vector2i, building_type: String) -> bool:
	return road_overlap_ratio(origin, building_type) <= 0.18

static func road_overlap_ratio(origin: Vector2i, building_type: String) -> float:
	var cache_key := "%s:%d:%d" % [building_type, origin.x, origin.y]
	if _road_overlap_cache.has(cache_key):
		return float(_road_overlap_cache[cache_key])
	var clearance := visual_clearance_rect(origin, building_type)
	if clearance.get_area() <= 0.0:
		return 0.0
	var clearance_polygon := PackedVector2Array([
		clearance.position,
		Vector2(clearance.end.x, clearance.position.y),
		clearance.end,
		Vector2(clearance.position.x, clearance.end.y),
	])
	var overlap_area := 0.0
	for cell in road_cells():
		for polygon in Geometry2D.intersect_polygons(clearance_polygon, cell_polygon(cell)):
			overlap_area += absf(_polygon_area(polygon))
	var ratio := overlap_area / clearance.get_area()
	_road_overlap_cache[cache_key] = ratio
	return ratio

static func _polygon_area(polygon: PackedVector2Array) -> float:
	var area := 0.0
	for index in polygon.size():
		var next := (index + 1) % polygon.size()
		area += polygon[index].x * polygon[next].y - polygon[next].x * polygon[index].y
	return area * 0.5

static func occupied_cells(origin: Vector2i, building_type: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var size := footprint(building_type)
	for y in size.y:
		for x in size.x:
			result.append(origin + Vector2i(x, y))
	return result

static func origin_from_value(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(roundi(value.x), roundi(value.y))
	if value is Array and value.size() == 2:
		return Vector2i(int(value[0]), int(value[1]))
	var id := str(value)
	if id.begins_with("slot_"):
		var index := int(id.trim_prefix("slot_")) - 1
		return LEGACY_ORIGINS[index] if index >= 0 and index < LEGACY_ORIGINS.size() else INVALID_ORIGIN
	if id.begins_with("cell_"):
		var parts := id.trim_prefix("cell_").split("_")
		if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
			return Vector2i(int(parts[0]), int(parts[1]))
	return INVALID_ORIGIN

static func encode_origin(origin: Vector2i) -> Array[int]:
	return [origin.x, origin.y]

static func cell_id(origin: Vector2i) -> String:
	return "cell_%02d_%02d" % [origin.x, origin.y]

static func instance_origin(instance: Dictionary) -> Vector2i:
	if instance.has("grid_origin"):
		return origin_from_value(instance.grid_origin)
	return origin_from_value(instance.get("slot_id", ""))

static func can_place(
	building_type: String,
	origin: Vector2i,
	instances: Array,
	unlocked_count: int,
	ignore_instance_id := ""
) -> bool:
	if not BUILDING_FOOTPRINTS.has(building_type) or origin == INVALID_ORIGIN:
		return false
	var candidate := {}
	for cell in occupied_cells(origin, building_type):
		if not is_cell_unlocked(cell, unlocked_count):
			return false
		candidate[cell] = true
	for raw in instances:
		if raw is not Dictionary or str(raw.get("id", "")) == ignore_instance_id:
			continue
		var other_type := str(raw.get("type", ""))
		for cell in occupied_cells(instance_origin(raw), other_type):
			if candidate.has(cell):
				return false
	return true

static func can_place_visually(
	building_type: String,
	origin: Vector2i,
	instances: Array,
	unlocked_count: int,
	ignore_instance_id := ""
) -> bool:
	if not can_place(building_type, origin, instances, unlocked_count, ignore_instance_id):
		return false
	if visual_outside_ratio(origin, building_type) > 0.065 or road_overlap_ratio(origin, building_type) > 0.18:
		return false
	for raw in instances:
		if raw is not Dictionary or str(raw.get("id", "")) == ignore_instance_id:
			continue
		var other_type := str(raw.get("type", ""))
		if visual_conflict(building_type, origin, other_type, instance_origin(raw)):
			return false
	return true

static func placement_reason(
	building_type: String,
	origin: Vector2i,
	instances: Array,
	unlocked_count: int,
	ignore_instance_id := ""
) -> String:
	if origin == INVALID_ORIGIN:
		return "请选择城内空地"
	for cell in occupied_cells(origin, building_type):
		if is_road(cell):
			return "建筑占地不能压住城内道路"
		if not unlocked_region(unlocked_count).has_point(cell):
			return "这片土地尚未随城池扩建开放"
	if not can_place(building_type, origin, instances, unlocked_count, ignore_instance_id):
		return "建筑占地与现有建筑重叠"
	return ""

static func visual_placement_reason(
	building_type: String,
	origin: Vector2i,
	instances: Array,
	unlocked_count: int,
	ignore_instance_id := ""
) -> String:
	var logical_reason := placement_reason(building_type, origin, instances, unlocked_count, ignore_instance_id)
	if not logical_reason.is_empty():
		return logical_reason
	if visual_outside_ratio(origin, building_type) > 0.065:
		return "建筑会被城景边缘或上方界面遮挡"
	if road_overlap_ratio(origin, building_type) > 0.18:
		return "建筑院落会遮住城内大道"
	for raw in instances:
		if raw is not Dictionary or str(raw.get("id", "")) == ignore_instance_id:
			continue
		if visual_conflict(building_type, origin, str(raw.get("type", "")), instance_origin(raw)):
			return "建筑院落与现有建筑过于拥挤"
	return ""

static func first_open_origin(
	instances: Array,
	unlocked_count: int,
	building_type: String,
	preferred: Variant = INVALID_ORIGIN,
	ignore_instance_id := ""
) -> Vector2i:
	var ignored_origin := INVALID_ORIGIN
	if not ignore_instance_id.is_empty():
		for instance in instances:
			if instance is Dictionary and str(instance.get("id", "")) == ignore_instance_id:
				ignored_origin = instance_origin(instance)
				break
	var preferred_origin := origin_from_value(preferred)
	if preferred_origin != ignored_origin and can_place(building_type, preferred_origin, instances, unlocked_count, ignore_instance_id):
		return preferred_origin
	var region := unlocked_region(unlocked_count)
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var candidate := Vector2i(x, y)
			if candidate != ignored_origin and can_place(building_type, candidate, instances, unlocked_count, ignore_instance_id):
				return candidate
	return INVALID_ORIGIN

static func repair_instance_layout(raw_instances: Array, unlocked_count: int) -> Array:
	var pending := []
	for index in raw_instances.size():
		var raw = raw_instances[index]
		if raw is not Dictionary or not BUILDING_FOOTPRINTS.has(str(raw.get("type", ""))):
			continue
		pending.append({"index": index, "instance": raw.duplicate(true)})
	pending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_type := str(a.instance.get("type", ""))
		var b_type := str(b.instance.get("type", ""))
		var a_size := footprint(a_type)
		var b_size := footprint(b_type)
		var a_score := a_size.x * a_size.y + (100 if a_type == "wall" else 0)
		var b_score := b_size.x * b_size.y + (100 if b_type == "wall" else 0)
		return int(a.index) < int(b.index) if a_score == b_score else a_score > b_score
	)
	var placed := []
	var repaired_by_index := {}
	for entry in pending:
		var instance: Dictionary = entry.instance
		var building_type := str(instance.get("type", ""))
		var origin := INVALID_ORIGIN
		for candidate in repair_origin_candidates(unlocked_count):
			if can_place(building_type, candidate, placed, unlocked_count):
				origin = candidate
				break
		if origin == INVALID_ORIGIN:
			origin = first_open_origin(placed, unlocked_count, building_type)
		if origin == INVALID_ORIGIN:
			continue
		instance.grid_origin = encode_origin(origin)
		instance.slot_id = cell_id(origin)
		placed.append(instance)
		repaired_by_index[int(entry.index)] = instance
	var repaired := []
	for index in raw_instances.size():
		if repaired_by_index.has(index):
			repaired.append(repaired_by_index[index])
	return repaired

static func repair_origin_candidates(unlocked_count: int) -> Array[Vector2i]:
	if unlocked_count <= 6:
		return [
			Vector2i(2, 1), Vector2i(8, 1),
			Vector2i(2, 4), Vector2i(8, 4),
			Vector2i(2, 7), Vector2i(8, 7),
		]
	var left := 1 if unlocked_count <= 9 else 0
	return [
		Vector2i(left, 1), Vector2i(8, 1),
		Vector2i(left + 3, 4), Vector2i(11, 4),
		Vector2i(left, 7), Vector2i(8, 7),
		Vector2i(left + 3, 1), Vector2i(11, 1),
		Vector2i(left, 4), Vector2i(8, 4),
		Vector2i(left + 3, 7), Vector2i(11, 7),
	]
