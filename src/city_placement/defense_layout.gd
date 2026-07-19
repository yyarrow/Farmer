extends RefCounted

const PlacementEngine = preload("res://src/city_placement/placement_engine.gd")

# City defense lives on a persistent 2x micro-grid around the ordinary city.
# The shell is reserved even at level zero so a later wall upgrade never needs
# to evict a player building. Roads may cross the shell only through a gate.
const MICRO_SCALE := 2
const MICRO_GRID_SIZE := Vector2i(
	PlacementEngine.GRID_SIZE.x * MICRO_SCALE,
	PlacementEngine.GRID_SIZE.y * MICRO_SCALE
)
const MAX_LEVEL := 5
const GATE_SIDE := "south"
const GATE_WIDTH := 4
const GATE_START := (MICRO_GRID_SIZE.x - GATE_WIDTH) / 2
const GATE_END := GATE_START + GATE_WIDTH
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

static func micro_cell_to_grid(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) / float(MICRO_SCALE)

static func micro_vertex_to_grid(vertex: Vector2i) -> Vector2:
	return Vector2(vertex) / float(MICRO_SCALE)

static func grid_point_to_screen(point: Vector2) -> Vector2:
	return PlacementEngine.GRID_ORIGIN + Vector2(
		(point.x - point.y) * PlacementEngine.CELL_SIZE.x * 0.5,
		(point.x + point.y) * PlacementEngine.CELL_SIZE.y * 0.5
	)

static func micro_cell_to_screen(cell: Vector2i) -> Vector2:
	return grid_point_to_screen(micro_cell_to_grid(cell))

static func micro_vertex_to_screen(vertex: Vector2i) -> Vector2:
	return grid_point_to_screen(micro_vertex_to_grid(vertex))

static func primary_gate() -> Dictionary:
	var road_x := GATE_START + GATE_WIDTH / 2
	return {
		"id": PRIMARY_GATE_ID,
		"side": GATE_SIDE,
		"opening": Rect2i(GATE_START, MICRO_GRID_SIZE.y - 1, GATE_WIDTH, 1),
		"road_root": Vector2i(road_x, MICRO_GRID_SIZE.y - 2),
		"boundary_cell": Vector2i(road_x, MICRO_GRID_SIZE.y - 1),
		"outside_cell": Vector2i(road_x, MICRO_GRID_SIZE.y),
		"screen_anchor": micro_vertex_to_screen(Vector2i(road_x, MICRO_GRID_SIZE.y)),
	}

static func gate_road_micro_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	# Two ordinary cells of guaranteed approach space inside the gate.
	for y in range(MICRO_GRID_SIZE.y - 4, MICRO_GRID_SIZE.y):
		for x in range(GATE_START, GATE_END):
			result.append(Vector2i(x, y))
	return result

static func wall_micro_cells(level: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if level <= 0:
		return result
	for y in MICRO_GRID_SIZE.y:
		for x in MICRO_GRID_SIZE.x:
			if x != 0 and x != MICRO_GRID_SIZE.x - 1 and y != 0 and y != MICRO_GRID_SIZE.y - 1:
				continue
			if y == MICRO_GRID_SIZE.y - 1 and x >= GATE_START and x < GATE_END:
				continue
			result.append(Vector2i(x, y))
	return result

static func wall_segments(level: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if level <= 0:
		return result
	_append_side_segments(result, "north", Vector2i(0, 0), Vector2i(MICRO_GRID_SIZE.x, 0), -1, -1)
	_append_side_segments(result, "east", Vector2i(MICRO_GRID_SIZE.x, 0), MICRO_GRID_SIZE, -1, -1)
	_append_side_segments(result, "south", MICRO_GRID_SIZE, Vector2i(0, MICRO_GRID_SIZE.y), GATE_START, GATE_END)
	_append_side_segments(result, "west", Vector2i(0, MICRO_GRID_SIZE.y), Vector2i.ZERO, -1, -1)
	return result

static func tower_nodes(level: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if level < 2:
		return result
	var points := [
		{"id": "south_west", "vertex": Vector2i(0, MICRO_GRID_SIZE.y), "min_level": 2},
		{"id": "south_east", "vertex": MICRO_GRID_SIZE, "min_level": 2},
		{"id": "north_west", "vertex": Vector2i.ZERO, "min_level": 3},
		{"id": "north_east", "vertex": Vector2i(MICRO_GRID_SIZE.x, 0), "min_level": 3},
		{"id": "west_mid", "vertex": Vector2i(0, MICRO_GRID_SIZE.y / 2), "min_level": 4},
		{"id": "east_mid", "vertex": Vector2i(MICRO_GRID_SIZE.x, MICRO_GRID_SIZE.y / 2), "min_level": 4},
		{"id": "north_mid", "vertex": Vector2i(MICRO_GRID_SIZE.x / 2, 0), "min_level": 5},
	]
	for point in points:
		if level >= int(point.min_level):
			result.append({
				"id": point.id,
				"vertex": point.vertex,
				"screen": micro_vertex_to_screen(point.vertex),
				"tier": int(level_style(level).tower_tier),
			})
	return result

static func reserved_ordinary_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var seen := {}
	# The outer ordinary-cell band is the permanent construction easement.
	for y in PlacementEngine.GRID_SIZE.y:
		for x in PlacementEngine.GRID_SIZE.x:
			if x == 0 or y == 0 or x == PlacementEngine.GRID_SIZE.x - 1 or y == PlacementEngine.GRID_SIZE.y - 1:
				_append_unique_cell(result, seen, Vector2i(x, y))
	# Keep a two-cell-deep mouth for roads, carts and the gate upgrade animation.
	for micro_cell in gate_road_micro_cells():
		_append_unique_cell(result, seen, Vector2i(
			micro_cell.x / MICRO_SCALE, micro_cell.y / MICRO_SCALE
		))
	return result

static func ordinary_conflicts_with_defense(building_type: String, origin: Vector2i) -> bool:
	var reserved := {}
	for cell in reserved_ordinary_cells():
		reserved[cell] = true
	for cell in PlacementEngine.occupied_cells(origin, building_type):
		if reserved.has(cell):
			return true
	return false

static func conflicting_instance_ids(instances: Array) -> Array[String]:
	var result: Array[String] = []
	for raw in instances:
		if raw is not Dictionary or str(raw.get("type", "")) == "wall":
			continue
		if ordinary_conflicts_with_defense(str(raw.get("type", "")), PlacementEngine.instance_origin(raw)):
			result.append(str(raw.get("id", "")))
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
		result.append({
			"id": "%s_%02d" % [side, index],
			"side": side,
			"from": from,
			"to": to,
			"screen_from": micro_vertex_to_screen(from),
			"screen_to": micro_vertex_to_screen(to),
		})

static func _append_unique_cell(result: Array[Vector2i], seen: Dictionary, cell: Vector2i) -> void:
	if not seen.has(cell):
		seen[cell] = true
		result.append(cell)
