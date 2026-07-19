extends RefCounted

const PlacementEngine = preload("res://src/city_placement/placement_engine.gd")

# Roads are derived from the saved building layout. The macro placement grid is
# intentionally unchanged; this module owns a 2x micro grid for finer routes.
const MICRO_SCALE := 2
const NORTH := 1
const EAST := 2
const SOUTH := 4
const WEST := 8
const INVALID_CELL := Vector2i(-1, -1)

const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const DIRECTION_MASKS := [NORTH, EAST, SOUTH, WEST]

# The side names use macro-grid axes. Each rule is explicit so standardized art
# can expose its gate at the same socket without adding per-save metadata.
const ENTRANCE_RULES := {
	"farm": {"side": "south", "offset": 0.50},
	"woodcut": {"side": "west", "offset": 0.50},
	"quarry": {"side": "east", "offset": 0.50},
	"house": {"side": "south", "offset": 0.50},
	"market": {"side": "south", "offset": 0.50},
	"warehouse": {"side": "east", "offset": 0.50},
	"barracks": {"side": "south", "offset": 0.50},
	"wall": {"side": "north", "offset": 0.50},
}

static func build(buildings: Array, unlocked_count: int, root: Vector2i = INVALID_CELL) -> Dictionary:
	var region := micro_region(unlocked_count)
	var root_cell: Vector2i = default_gate(unlocked_count) if root == INVALID_CELL else root
	if not region.has_point(root_cell):
		return _failure("invalid_gate", "城门不在已开放城域内", root_cell)

	var normalized := _normalized_buildings(buildings)
	if not bool(normalized.valid):
		return _failure(str(normalized.code), str(normalized.reason), root_cell)
	var entries: Array = normalized.buildings
	var occupied := {}
	for entry in entries:
		for cell in footprint_cells(entry.origin, entry.type):
			if not region.has_point(cell):
				return _failure("building_outside", "%s 超出已开放城域" % entry.id, root_cell, entry.id)
			if occupied.has(cell):
				return _failure("building_overlap", "%s 与 %s 占地重叠" % [entry.id, occupied[cell]], root_cell, entry.id)
			occupied[cell] = entry.id
	if occupied.has(root_cell):
		return _failure("gate_blocked", "建筑占用了城门道路根节点", root_cell, str(occupied[root_cell]))

	var entrances := {}
	for entry in entries:
		var entrance := entrance_cell(entry.type, entry.origin)
		if not region.has_point(entrance):
			return _failure("entrance_outside", "%s 的入口位于已开放城域外" % entry.id, root_cell, entry.id)
		if occupied.has(entrance):
			return _failure("entrance_blocked", "%s 的入口被 %s 占用" % [entry.id, occupied[entrance]], root_cell, entry.id)
		entrances[entry.id] = entrance

	var connected := {root_cell: true}
	for entry in entries:
		var start: Vector2i = entrances[entry.id]
		var path := _route(start, connected, occupied, region)
		if path.is_empty():
			return _failure("unreachable", "%s 无法接入城门道路" % entry.id, root_cell, entry.id, entrances)
		for cell in path:
			connected[cell] = true

	var cells: Array[Vector2i] = []
	for cell in connected:
		cells.append(cell)
	cells.sort_custom(_cell_before)
	return {
		"success": true,
		"code": "ok",
		"reason": "",
		"gate": root_cell,
		"root": root_cell,
		"road_cells": cells,
		"connectivity_masks": _connectivity_masks(cells),
		"entrances": entrances,
		"failed_building_id": "",
	}

static func evaluate_access(
	building_type: String,
	origin: Vector2i,
	buildings: Array,
	unlocked_count: int,
	ignore_instance_id := "",
	root: Vector2i = INVALID_CELL
) -> Dictionary:
	var candidates := []
	for raw in buildings:
		if raw is Dictionary and str(raw.get("id", "")) != ignore_instance_id:
			candidates.append(raw.duplicate(true))
	candidates.append({
		"id": "__candidate__",
		"type": building_type,
		"grid_origin": PlacementEngine.encode_origin(origin),
	})
	var network := build(candidates, unlocked_count, root)
	return {
		"accessible": bool(network.success),
		"code": str(network.code),
		"reason": str(network.reason),
		"network": network,
	}

static func micro_region(unlocked_count: int) -> Rect2i:
	var macro := PlacementEngine.unlocked_region(unlocked_count)
	return Rect2i(macro.position * MICRO_SCALE, macro.size * MICRO_SCALE)

static func default_gate(unlocked_count: int) -> Vector2i:
	var region := micro_region(unlocked_count)
	return Vector2i(region.position.x + floori(float(region.size.x) / 2.0), region.end.y - 1)

static func micro_to_screen(cell: Vector2i) -> Vector2:
	# A macro cell at (x, y) owns micro cells (2x, 2y)..(2x+1, 2y+1).
	# The half-cell offset makes their four diamonds tile the macro diamond.
	var macro_position := (
		(Vector2(cell) + Vector2.ONE * 0.5) / float(MICRO_SCALE)
		- Vector2.ONE * 0.5
	)
	return PlacementEngine.GRID_ORIGIN + Vector2(
		(macro_position.x - macro_position.y) * PlacementEngine.CELL_SIZE.x * 0.5,
		(macro_position.x + macro_position.y) * PlacementEngine.CELL_SIZE.y * 0.5
	)

static func micro_cell_polygon(cell: Vector2i) -> PackedVector2Array:
	var center := micro_to_screen(cell)
	var half := PlacementEngine.CELL_SIZE * (0.5 / float(MICRO_SCALE))
	return PackedVector2Array([
		center + Vector2(0, -half.y), center + Vector2(half.x, 0),
		center + Vector2(0, half.y), center + Vector2(-half.x, 0),
	])

static func footprint_cells(origin: Vector2i, building_type: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var top_left := origin * MICRO_SCALE
	var size := PlacementEngine.footprint(building_type) * MICRO_SCALE
	for y in range(top_left.y, top_left.y + size.y):
		for x in range(top_left.x, top_left.x + size.x):
			result.append(Vector2i(x, y))
	return result

static func entrance_cell(building_type: String, origin: Vector2i) -> Vector2i:
	var rule: Dictionary = ENTRANCE_RULES.get(building_type, {"side": "south", "offset": 0.50})
	var top_left := origin * MICRO_SCALE
	var size := PlacementEngine.footprint(building_type) * MICRO_SCALE
	var offset := clampf(float(rule.offset), 0.0, 1.0)
	var side := str(rule.side)
	if side == "north":
		return Vector2i(top_left.x + _edge_offset(size.x, offset), top_left.y - 1)
	if side == "east":
		return Vector2i(top_left.x + size.x, top_left.y + _edge_offset(size.y, offset))
	if side == "west":
		return Vector2i(top_left.x - 1, top_left.y + _edge_offset(size.y, offset))
	return Vector2i(top_left.x + _edge_offset(size.x, offset), top_left.y + size.y)

static func _edge_offset(length: int, ratio: float) -> int:
	return clampi(roundi(float(length - 1) * ratio), 0, length - 1)

static func _normalized_buildings(buildings: Array) -> Dictionary:
	var result := []
	var ids := {}
	for index in buildings.size():
		var raw = buildings[index]
		if raw is not Dictionary:
			return {"valid": false, "code": "invalid_building", "reason": "建筑数据格式无效"}
		var building_type := str(raw.get("type", ""))
		if not PlacementEngine.BUILDING_FOOTPRINTS.has(building_type):
			return {"valid": false, "code": "invalid_building", "reason": "未知建筑类型：%s" % building_type}
		var origin := PlacementEngine.instance_origin(raw)
		if origin == PlacementEngine.INVALID_ORIGIN:
			return {"valid": false, "code": "invalid_building", "reason": "建筑缺少有效坐标"}
		var fallback_id := "%s_%02d_%02d" % [building_type, origin.x, origin.y]
		var building_id := str(raw.get("id", fallback_id))
		if building_id.is_empty():
			building_id = fallback_id
		if ids.has(building_id):
			return {"valid": false, "code": "duplicate_id", "reason": "建筑编号重复：%s" % building_id}
		ids[building_id] = true
		result.append({"id": building_id, "type": building_type, "origin": origin})
	result.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		if first.origin != second.origin:
			return _cell_before(first.origin, second.origin)
		if first.type != second.type:
			return first.type < second.type
		return first.id < second.id
	)
	return {"valid": true, "buildings": result}

static func _route(start: Vector2i, goals: Dictionary, occupied: Dictionary, region: Rect2i) -> Array[Vector2i]:
	if goals.has(start):
		return [start]
	var initial := {
		"cell": start,
		"direction": Vector2i.ZERO,
		"new_cells": 0 if goals.has(start) else 1,
		"turns": 0,
		"length": 0,
	}
	var heap := [initial]
	var initial_key := _state_key(start, Vector2i.ZERO)
	var best := {initial_key: _state_cost(initial)}
	var previous := {initial_key: ""}
	var states := {initial_key: initial}
	var goal_key := ""

	while not heap.is_empty():
		var current: Dictionary = _heap_pop(heap)
		var current_key := _state_key(current.cell, current.direction)
		if not best.has(current_key) or Vector3i(best[current_key]) != _state_cost(current):
			continue
		if goals.has(current.cell):
			goal_key = current_key
			break
		for direction in DIRECTIONS:
			var next_cell: Vector2i = current.cell + direction
			if not region.has_point(next_cell) or occupied.has(next_cell):
				continue
			var next_turns := int(current.turns)
			if current.direction != Vector2i.ZERO and current.direction != direction:
				next_turns += 1
			var next_new := int(current.new_cells) + (0 if goals.has(next_cell) else 1)
			var next_length := int(current.length) + 1
			var next_key := _state_key(next_cell, direction)
			var next := {
				"cell": next_cell,
				"direction": direction,
				"new_cells": next_new,
				"turns": next_turns,
				"length": next_length,
			}
			var next_cost := _state_cost(next)
			if best.has(next_key) and not _cost_before(next_cost, Vector3i(best[next_key])):
				continue
			best[next_key] = next_cost
			previous[next_key] = current_key
			states[next_key] = next
			_heap_push(heap, next)

	if goal_key.is_empty():
		return []
	var reversed: Array[Vector2i] = []
	var cursor := goal_key
	while not cursor.is_empty():
		reversed.append(states[cursor].cell)
		cursor = str(previous[cursor])
	reversed.reverse()
	return reversed

static func _heap_push(heap: Array, value: Dictionary) -> void:
	heap.append(value)
	var index := heap.size() - 1
	while index > 0:
		var parent := floori(float(index - 1) / 2.0)
		if not _state_before(value, heap[parent]):
			break
		heap[index] = heap[parent]
		index = parent
	heap[index] = value

static func _heap_pop(heap: Array) -> Dictionary:
	var result: Dictionary = heap[0]
	var tail: Dictionary = heap.pop_back()
	if heap.is_empty():
		return result
	var index := 0
	while true:
		var left := index * 2 + 1
		if left >= heap.size():
			break
		var right := left + 1
		var child := left
		if right < heap.size() and _state_before(heap[right], heap[left]):
			child = right
		if not _state_before(heap[child], tail):
			break
		heap[index] = heap[child]
		index = child
	heap[index] = tail
	return result

static func _state_before(first: Dictionary, second: Dictionary) -> bool:
	var first_cost := _state_cost(first)
	var second_cost := _state_cost(second)
	if first_cost != second_cost:
		return _cost_before(first_cost, second_cost)
	if first.cell != second.cell:
		return _cell_before(first.cell, second.cell)
	return _cell_before(first.direction, second.direction)

static func _state_cost(state: Dictionary) -> Vector3i:
	return Vector3i(int(state.new_cells), int(state.turns), int(state.length))

static func _cost_before(first: Vector3i, second: Vector3i) -> bool:
	if first.x != second.x:
		return first.x < second.x
	if first.y != second.y:
		return first.y < second.y
	return first.z < second.z

static func _state_key(cell: Vector2i, direction: Vector2i) -> String:
	return "%d:%d:%d:%d" % [cell.x, cell.y, direction.x, direction.y]

static func _connectivity_masks(cells: Array[Vector2i]) -> Dictionary:
	var present := {}
	for cell in cells:
		present[cell] = true
	var result := {}
	for cell in cells:
		var mask := 0
		for index in DIRECTIONS.size():
			if present.has(cell + DIRECTIONS[index]):
				mask |= int(DIRECTION_MASKS[index])
		result[cell] = mask
	return result

static func _failure(
	code: String,
	reason: String,
	gate: Vector2i,
	failed_building_id := "",
	entrances := {}
) -> Dictionary:
	return {
		"success": false,
		"code": code,
		"reason": reason,
		"gate": gate,
		"root": gate,
		"road_cells": [] as Array[Vector2i],
		"connectivity_masks": {},
		"entrances": entrances,
		"failed_building_id": failed_building_id,
	}

static func _cell_before(first: Vector2i, second: Vector2i) -> bool:
	return first.y < second.y or (first.y == second.y and first.x < second.x)
