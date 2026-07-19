extends RefCounted

const PlacementEngine = preload("res://src/city_placement/placement_engine.gd")
const PlacementSolver = preload("res://src/city_placement/placement_solver.gd")
const RoadNetwork = preload("res://src/city_placement/road_network.gd")

# City defense shares RoadNetwork's 2x micro-grid. Its perimeter follows the
# currently unlocked macro region (6/9/12 lots), so expansion deterministically
# rebuilds a larger shell without changing the saved defense level.
const MICRO_SCALE := RoadNetwork.MICRO_SCALE
const MAX_LEVEL := 5
const GATE_SIDE := "south"
const GATE_WIDTH := 4
const PRIMARY_GATE_ID := "south_gate"

const LEVEL_STYLES := {
	0: {"id": "open_ground", "wall_tier": 0, "tower_tier": 0},
	1: {"id": "palisade", "wall_tier": 1, "tower_tier": 0},
	2: {"id": "earthwork", "wall_tier": 2, "tower_tier": 1},
	3: {"id": "continuous_wall", "wall_tier": 3, "tower_tier": 2},
	4: {"id": "fortified_gate", "wall_tier": 4, "tower_tier": 3},
	5: {"id": "citadel_perimeter", "wall_tier": 5, "tower_tier": 4},
}

static func level_style(level: int) -> Dictionary:
	return LEVEL_STYLES[clampi(level, 0, MAX_LEVEL)].duplicate(true)

static func micro_region(unlocked_count: int) -> Rect2i:
	return RoadNetwork.micro_region(unlocked_count)

static func micro_cell_to_grid(cell: Vector2i) -> Vector2:
	# Must remain identical to RoadNetwork.micro_to_screen's macro position.
	return (Vector2(cell) + Vector2.ONE * 0.5) / float(MICRO_SCALE) - Vector2.ONE * 0.5

static func micro_vertex_to_grid(vertex: Vector2i) -> Vector2:
	# Micro vertices bound the child diamonds; vertex (0,0) is the outer corner
	# of micro cell (0,0), half a macro cell outside macro center (0,0).
	return Vector2(vertex) / float(MICRO_SCALE) - Vector2.ONE * 0.5

static func grid_point_to_screen(point: Vector2) -> Vector2:
	return PlacementEngine.GRID_ORIGIN + Vector2(
		(point.x - point.y) * PlacementEngine.CELL_SIZE.x * 0.5,
		(point.x + point.y) * PlacementEngine.CELL_SIZE.y * 0.5
	)

static func micro_cell_to_screen(cell: Vector2i) -> Vector2:
	return RoadNetwork.micro_to_screen(cell)

static func micro_vertex_to_screen(vertex: Vector2i) -> Vector2:
	return grid_point_to_screen(micro_vertex_to_grid(vertex))

static func primary_gate(unlocked_count: int) -> Dictionary:
	var region := micro_region(unlocked_count)
	var road_root := RoadNetwork.default_gate(unlocked_count)
	var gate_start := road_root.x - GATE_WIDTH / 2
	var outside := Vector2i(road_root.x, region.end.y)
	return {
		"id": PRIMARY_GATE_ID,
		"side": GATE_SIDE,
		"opening": Rect2i(gate_start, region.end.y, GATE_WIDTH, 1),
		"road_root": road_root,
		"boundary_cell": road_root,
		"outside_cell": outside,
		"screen_anchor": micro_vertex_to_screen(outside),
		"sort_depth": _grid_depth(micro_vertex_to_grid(outside)),
	}

static func gate_road_micro_cells(unlocked_count: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var region := micro_region(unlocked_count)
	var gate: Dictionary = primary_gate(unlocked_count)
	var opening: Rect2i = gate.opening
	for y in range(maxi(region.position.y, region.end.y - 4), region.end.y):
		for x in range(opening.position.x, opening.end.x):
			result.append(Vector2i(x, y))
	return result

static func wall_micro_cells(level: int, unlocked_count: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if level <= 0:
		return result
	var region := micro_region(unlocked_count)
	var opening: Rect2i = primary_gate(unlocked_count).opening
	# The fortification shell occupies the micro-cell ring immediately outside
	# the buildable region. Edge lots may touch a wall, but can never replace it.
	for x in range(region.position.x, region.end.x):
		result.append(Vector2i(x, region.position.y - 1))
		var south_cell := Vector2i(x, region.end.y)
		if not opening.has_point(south_cell):
			result.append(south_cell)
	for y in range(region.position.y, region.end.y):
		result.append(Vector2i(region.position.x - 1, y))
		result.append(Vector2i(region.end.x, y))
	return result

static func wall_segments(level: int, unlocked_count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if level <= 0:
		return result
	var region := micro_region(unlocked_count)
	var top_left := region.position
	var top_right := Vector2i(region.end.x, region.position.y)
	var bottom_right := region.end
	var bottom_left := Vector2i(region.position.x, region.end.y)
	var opening: Rect2i = primary_gate(unlocked_count).opening
	_append_side_segments(result, "north", top_left, top_right, -1, -1)
	_append_side_segments(result, "east", top_right, bottom_right, -1, -1)
	_append_side_segments(result, "south", bottom_right, bottom_left, opening.position.x, opening.end.x)
	_append_side_segments(result, "west", bottom_left, top_left, -1, -1)
	return result

static func tower_nodes(level: int, unlocked_count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if level < 2:
		return result
	var region := micro_region(unlocked_count)
	var left := region.position.x
	var right := region.end.x
	var top := region.position.y
	var bottom := region.end.y
	var mid_x := left + region.size.x / 2
	var mid_y := top + region.size.y / 2
	var points := [
		{"id": "south_west", "vertex": Vector2i(left, bottom), "min_level": 2},
		{"id": "south_east", "vertex": Vector2i(right, bottom), "min_level": 2},
		{"id": "north_west", "vertex": Vector2i(left, top), "min_level": 3},
		{"id": "north_east", "vertex": Vector2i(right, top), "min_level": 3},
		{"id": "west_mid", "vertex": Vector2i(left, mid_y), "min_level": 4},
		{"id": "east_mid", "vertex": Vector2i(right, mid_y), "min_level": 4},
		{"id": "north_mid", "vertex": Vector2i(mid_x, top), "min_level": 5},
	]
	for point in points:
		if level >= int(point.min_level):
			var grid_position := micro_vertex_to_grid(point.vertex)
			result.append({
				"id": point.id,
				"vertex": point.vertex,
				"screen": micro_vertex_to_screen(point.vertex),
				"tier": int(level_style(level).tower_tier),
				"sort_depth": _grid_depth(grid_position),
			})
	return result

static func reserved_ordinary_cells(unlocked_count: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var seen := {}
	# The wall itself is outside the ordinary grid. Only the gate mouth is a
	# permanent construction easement, allowing roads and upgrade animation.
	for micro_cell in gate_road_micro_cells(unlocked_count):
		_append_unique_cell(result, seen, Vector2i(
			micro_cell.x / MICRO_SCALE, micro_cell.y / MICRO_SCALE
		))
	return result

static func ordinary_conflicts_with_defense(building_type: String, origin: Vector2i, unlocked_count: int) -> bool:
	var reserved := {}
	for cell in reserved_ordinary_cells(unlocked_count):
		reserved[cell] = true
	for cell in PlacementEngine.occupied_cells(origin, building_type):
		if reserved.has(cell):
			return true
	return false

static func conflicting_instance_ids(instances: Array, unlocked_count: int) -> Array[String]:
	var result: Array[String] = []
	for raw in instances:
		if raw is not Dictionary or str(raw.get("type", "")) == "wall":
			continue
		if ordinary_conflicts_with_defense(str(raw.get("type", "")), PlacementEngine.instance_origin(raw), unlocked_count):
			result.append(str(raw.get("id", "")))
	return result

static func arrange_ordinary(raw_instances: Array, unlocked_count: int) -> Array:
	var pending := []
	for index in raw_instances.size():
		var raw = raw_instances[index]
		if raw is Dictionary and str(raw.get("type", "")) != "wall":
			pending.append({"index": index, "instance": raw.duplicate(true)})
	pending.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		var first_size := PlacementEngine.footprint(str(first.instance.type))
		var second_size := PlacementEngine.footprint(str(second.instance.type))
		var first_area := first_size.x * first_size.y
		var second_area := second_size.x * second_size.y
		return int(first.index) < int(second.index) if first_area == second_area else first_area > second_area
	)
	var solved := _solve_ordinary(pending, 0, [], {}, unlocked_count, {"remaining": 18000})
	if solved.is_empty():
		return []
	var result := []
	for index in raw_instances.size():
		if solved.by_index.has(index):
			result.append(solved.by_index[index])
	return result

static func split_legacy_wall_instances(instances: Array, aggregate_wall_level := 0) -> Dictionary:
	var ordinary := []
	var sources: Array[String] = []
	var defense_level := clampi(int(aggregate_wall_level), 0, MAX_LEVEL)
	for raw in instances:
		if raw is Dictionary and str(raw.get("type", "")) == "wall":
			defense_level = maxi(defense_level, clampi(int(raw.get("level", 0)), 0, MAX_LEVEL))
			sources.append(str(raw.get("id", "")))
		else:
			ordinary.append(raw.duplicate(true) if raw is Dictionary else raw)
	return {
		"defense_level": defense_level,
		"ordinary_instances": ordinary,
		"removed_wall_instance_ids": sources,
	}

static func _solve_ordinary(
	pending: Array, index: int, placed: Array, by_index: Dictionary,
	unlocked_count: int, budget: Dictionary
) -> Dictionary:
	if index >= pending.size():
		return {"placed": placed, "by_index": by_index}
	if int(budget.remaining) <= 0:
		return {}
	budget.remaining = int(budget.remaining) - 1
	var entry: Dictionary = pending[index]
	var source: Dictionary = entry.instance
	var building_type := str(source.type)
	var candidates := PlacementSolver.ranked_origins(
		building_type, placed, unlocked_count,
		source.get("grid_origin", source.get("slot_id", PlacementEngine.INVALID_ORIGIN)), "", 96
	)
	for origin in candidates:
		if ordinary_conflicts_with_defense(building_type, origin, unlocked_count):
			continue
		var access := RoadNetwork.evaluate_access(
			building_type, origin, placed, unlocked_count, "",
			primary_gate(unlocked_count).road_root
		)
		if not bool(access.accessible):
			continue
		var instance := source.duplicate(true)
		instance.grid_origin = PlacementEngine.encode_origin(origin)
		instance.slot_id = PlacementEngine.cell_id(origin)
		var next_placed := placed.duplicate()
		next_placed.append(instance)
		var next_by_index := by_index.duplicate()
		next_by_index[int(entry.index)] = instance
		var solved := _solve_ordinary(pending, index + 1, next_placed, next_by_index, unlocked_count, budget)
		if not solved.is_empty():
			return solved
	return {}

static func _append_side_segments(
	result: Array[Dictionary], side: String, start: Vector2i, finish: Vector2i,
	skip_start: int, skip_end: int
) -> void:
	var delta := finish - start
	var length := absi(delta.x) + absi(delta.y)
	var step := Vector2i(signi(delta.x), signi(delta.y))
	for index in length:
		var from := start + step * index
		var to := from + step
		var axis_position := mini(from.x, to.x) if side == "south" else index
		if skip_start >= 0 and axis_position >= skip_start and axis_position < skip_end:
			continue
		var midpoint := (micro_vertex_to_grid(from) + micro_vertex_to_grid(to)) * 0.5
		result.append({
			"id": "%s_%02d" % [side, index],
			"side": side,
			"from": from,
			"to": to,
			"screen_from": micro_vertex_to_screen(from),
			"screen_to": micro_vertex_to_screen(to),
			"sort_depth": _grid_depth(midpoint),
		})

static func _grid_depth(point: Vector2) -> int:
	return 20 + roundi((point.x + point.y) * 10.0 + point.x)

static func _append_unique_cell(result: Array[Vector2i], seen: Dictionary, cell: Vector2i) -> void:
	if not seen.has(cell):
		seen[cell] = true
		result.append(cell)
