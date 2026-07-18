extends RefCounted

const PlacementEngine = preload("res://src/city_placement/placement_engine.gd")
const BuildingProfiles = preload("res://src/city_placement/building_profiles.gd")

static func best_origin(
	building_type: String,
	instances: Array,
	unlocked_count: int,
	preferred: Variant = PlacementEngine.INVALID_ORIGIN,
	ignore_instance_id := ""
) -> Vector2i:
	var ranked := ranked_origins(building_type, instances, unlocked_count, preferred, ignore_instance_id, 1)
	return PlacementEngine.INVALID_ORIGIN if ranked.is_empty() else ranked[0]

static func ranked_origins(
	building_type: String,
	instances: Array,
	unlocked_count: int,
	preferred: Variant = PlacementEngine.INVALID_ORIGIN,
	ignore_instance_id := "",
	limit := 18
) -> Array[Vector2i]:
	var preferred_origin := PlacementEngine.origin_from_value(preferred)
	var preferred_anchor := (
		PlacementEngine.art_anchor(preferred_origin, building_type)
		if preferred_origin != PlacementEngine.INVALID_ORIGIN else PlacementEngine.CITY_SAFE_RECT.get_center()
	)
	var scored := []
	var region := PlacementEngine.unlocked_region(unlocked_count)
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var candidate := Vector2i(x, y)
			if not PlacementEngine.can_place_visually(building_type, candidate, instances, unlocked_count, ignore_instance_id):
				continue
			var score := candidate_score(building_type, candidate, instances, preferred_anchor, ignore_instance_id)
			scored.append({"origin": candidate, "score": score})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _origin_before(a.origin, b.origin) if is_equal_approx(float(a.score), float(b.score)) else float(a.score) < float(b.score)
	)
	var result: Array[Vector2i] = []
	for index in mini(limit, scored.size()):
		result.append(scored[index].origin)
	return result

static func candidate_score(
	building_type: String,
	origin: Vector2i,
	instances: Array,
	preferred_anchor: Vector2,
	ignore_instance_id := ""
) -> float:
	var anchor := PlacementEngine.art_anchor(origin, building_type)
	var active := []
	for raw in instances:
		if raw is Dictionary and str(raw.get("id", "")) != ignore_instance_id:
			active.append(raw)
	var candidate_rect := PlacementEngine.visual_rect(origin, building_type)
	var conflicts := 0
	var total_overlap := 0.0
	var max_overlap := 0.0
	for raw in active:
		var other_type := str(raw.get("type", ""))
		var other_origin := PlacementEngine.instance_origin(raw)
		if PlacementEngine.visual_conflict(building_type, origin, other_type, other_origin):
			conflicts += 1
		var overlap := PlacementEngine.rect_overlap_ratio(
			candidate_rect, PlacementEngine.visual_rect(other_origin, other_type)
		)
		total_overlap += overlap
		max_overlap = maxf(max_overlap, overlap)
	var score := (
		PlacementEngine.visual_outside_ratio(origin, building_type) * 12000.0
		+ float(conflicts) * 12000.0
		+ total_overlap * 720.0
		+ max_overlap * 420.0
	)
	score += PlacementEngine.road_overlap_ratio(origin, building_type) * 4200.0
	if instances.is_empty():
		score += anchor.distance_to(PlacementEngine.CITY_SAFE_RECT.get_center()) * 0.18
	else:
		var nearest := INF
		for raw in active:
			nearest = minf(nearest, anchor.distance_to(PlacementEngine.art_anchor(
				PlacementEngine.instance_origin(raw), str(raw.get("type", ""))
			)))
		score -= minf(nearest, 180.0) * 1.55
	score += anchor.distance_to(preferred_anchor) * 0.045
	return score

static func arrange(raw_instances: Array, unlocked_count: int) -> Array:
	var pending := []
	for index in raw_instances.size():
		var raw = raw_instances[index]
		if raw is not Dictionary or not PlacementEngine.BUILDING_FOOTPRINTS.has(str(raw.get("type", ""))):
			continue
		pending.append({"index": index, "instance": raw.duplicate(true)})
	pending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_type := str(a.instance.get("type", ""))
		var b_type := str(b.instance.get("type", ""))
		var a_size := BuildingProfiles.maximum_art_size(a_type)
		var b_size := BuildingProfiles.maximum_art_size(b_type)
		var a_area := a_size.x * a_size.y
		var b_area := b_size.x * b_size.y
		var a_priority := a_area + (100000.0 if a_type == "wall" else 0.0)
		var b_priority := b_area + (100000.0 if b_type == "wall" else 0.0)
		return int(a.index) < int(b.index) if is_equal_approx(a_priority, b_priority) else a_priority > b_priority
	)
	var solved := _solve_pending(pending, 0, [], {}, unlocked_count, {"remaining": 14000})
	if solved.is_empty():
		return []
	var arranged_by_index: Dictionary = solved.by_index
	var arranged := []
	for index in raw_instances.size():
		if arranged_by_index.has(index):
			arranged.append(arranged_by_index[index])
	return arranged

static func _solve_pending(
	pending: Array,
	entry_index: int,
	placed: Array,
	by_index: Dictionary,
	unlocked_count: int,
	budget: Dictionary
) -> Dictionary:
	if entry_index >= pending.size():
		return {"placed": placed, "by_index": by_index}
	if int(budget.remaining) <= 0:
		return {}
	budget.remaining = int(budget.remaining) - 1
	var entry: Dictionary = pending[entry_index]
	var source: Dictionary = entry.instance
	var building_type := str(source.get("type", ""))
	var candidates := ranked_origins(
		building_type, placed, unlocked_count,
		source.get("grid_origin", source.get("slot_id", PlacementEngine.INVALID_ORIGIN)),
		"", 20
	)
	for origin in candidates:
		var instance := source.duplicate(true)
		instance.grid_origin = PlacementEngine.encode_origin(origin)
		instance.slot_id = PlacementEngine.cell_id(origin)
		var next_placed := placed.duplicate()
		next_placed.append(instance)
		var next_by_index := by_index.duplicate()
		next_by_index[int(entry.index)] = instance
		var solved := _solve_pending(pending, entry_index + 1, next_placed, next_by_index, unlocked_count, budget)
		if not solved.is_empty():
			return solved
	return {}

static func _origin_before(first: Vector2i, second: Vector2i) -> bool:
	return second == PlacementEngine.INVALID_ORIGIN or first.y < second.y or (first.y == second.y and first.x < second.x)
