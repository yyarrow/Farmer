extends RefCounted

const PlacementEngine = preload("res://src/city_placement/placement_engine.gd")
const PlacementSolver = preload("res://src/city_placement/placement_solver.gd")
const RoadNetwork = preload("res://src/city_placement/road_network.gd")
const DefenseLayout = preload("res://src/city_placement/defense_layout.gd")

# One placement model drives rendering, hit testing, persistence and validation.
# The painted era background contains terrain only. Roads, defenses and every
# interactive building are derived from the saved ordinary-building layout.
const MAX_SLOTS := PlacementEngine.MAX_SLOTS
const UNIQUE_BUILDINGS := PlacementEngine.UNIQUE_BUILDINGS
const GRID_SIZE := PlacementEngine.GRID_SIZE
const CELL_SIZE := PlacementEngine.CELL_SIZE
const GRID_ORIGIN := PlacementEngine.GRID_ORIGIN
const ROAD_COLUMN := PlacementEngine.ROAD_COLUMN
const INVALID_ORIGIN := PlacementEngine.INVALID_ORIGIN
const BUILDING_FOOTPRINTS := PlacementEngine.BUILDING_FOOTPRINTS

# v5 saves used twelve named sockets. Their ids remain readable, but each now
# resolves to a real grid origin. New saves persist grid_origin instead.
const LEGACY_ORIGINS := PlacementEngine.LEGACY_ORIGINS
const SLOTS := [
	{"id": "slot_01"}, {"id": "slot_02"}, {"id": "slot_03"}, {"id": "slot_04"},
	{"id": "slot_05"}, {"id": "slot_06"}, {"id": "slot_07"}, {"id": "slot_08"},
	{"id": "slot_09"}, {"id": "slot_10"}, {"id": "slot_11"}, {"id": "slot_12"},
]

const BUILDING_SLOT_DEFAULTS := {
	"farm": "slot_09",
	"woodcut": "slot_01",
	"quarry": "slot_12",
	"house": "slot_07",
	"market": "slot_05",
	"warehouse": "slot_06",
	"barracks": "slot_04",
	"wall": "slot_03",
}

const BUILDING_POSITIONS := {
	"farm": Vector2(84, 326),
	"woodcut": Vector2(180, 218),
	"quarry": Vector2(390, 326),
	"house": Vector2(312, 272),
	"market": Vector2(132, 272),
	"warehouse": Vector2(228, 272),
	"barracks": Vector2(390, 236),
	"wall": Vector2(336, 218),
}
const BUILDING_SIZES := {
	"farm": Vector2(108, 54), "woodcut": Vector2(72, 36),
	"quarry": Vector2(72, 36), "house": Vector2(72, 36),
	"market": Vector2(90, 45), "warehouse": Vector2(90, 45),
	"barracks": Vector2(108, 54), "wall": Vector2(108, 54),
}
const EFFECT_POSITIONS := {
	"trade": Vector2(140, 340), "recruit": Vector2(408, 300),
	"defense_order": Vector2(420, 290), "policy": Vector2(270, 410),
	"siege": Vector2(410, 238), "shortage": Vector2(270, 460),
	"storage_full": Vector2(270, 350),
}

static func footprint(building_type: String) -> Vector2i:
	return PlacementEngine.footprint(building_type)

static func grid_to_screen(cell: Vector2i) -> Vector2:
	return PlacementEngine.grid_to_screen(cell)

static func screen_to_grid(point: Vector2) -> Vector2i:
	return PlacementEngine.screen_to_grid(point)

static func cell_polygon(cell: Vector2i) -> PackedVector2Array:
	return PlacementEngine.cell_polygon(cell)

static func footprint_polygon(origin: Vector2i, building_type: String) -> PackedVector2Array:
	return PlacementEngine.footprint_polygon(origin, building_type)

static func grid_rect_polygon(origin: Vector2i, size: Vector2i) -> PackedVector2Array:
	return PlacementEngine.grid_rect_polygon(origin, size)

static func art_anchor(origin: Vector2i, building_type: String) -> Vector2:
	return PlacementEngine.art_anchor(origin, building_type)

static func front_contact_grid(origin: Vector2i, building_type: String) -> Vector2:
	return PlacementEngine.front_contact_grid(origin, building_type)

static func depth(origin: Vector2i, building_type: String) -> int:
	return PlacementEngine.depth(origin, building_type)

static func art_scale(building_type: String) -> float:
	return PlacementEngine.art_scale(building_type)

static func unlocked_region(unlocked_count: int) -> Rect2i:
	return PlacementEngine.unlocked_region(unlocked_count)

static func road_cells() -> Array[Vector2i]:
	return PlacementEngine.road_cells()

static func is_road(cell: Vector2i) -> bool:
	return PlacementEngine.is_road(cell)

static func is_cell_unlocked(cell: Vector2i, unlocked_count: int) -> bool:
	return PlacementEngine.is_cell_unlocked(cell, unlocked_count)

static func occupied_cells(origin: Vector2i, building_type: String) -> Array[Vector2i]:
	return PlacementEngine.occupied_cells(origin, building_type)

static func origin_from_value(value: Variant) -> Vector2i:
	return PlacementEngine.origin_from_value(value)

static func encode_origin(origin: Vector2i) -> Array[int]:
	return PlacementEngine.encode_origin(origin)

static func cell_id(origin: Vector2i) -> String:
	return PlacementEngine.cell_id(origin)

static func instance_origin(instance: Dictionary) -> Vector2i:
	return PlacementEngine.instance_origin(instance)

static func can_place(
	building_type: String,
	origin: Vector2i,
	instances: Array,
	unlocked_count: int,
	ignore_instance_id := ""
) -> bool:
	if not PlacementEngine.can_place(building_type, origin, instances, unlocked_count, ignore_instance_id):
		return false
	return _infrastructure_allows(building_type, origin, instances, unlocked_count, ignore_instance_id)

static func can_place_visually(
	building_type: String,
	origin: Vector2i,
	instances: Array,
	unlocked_count: int,
	ignore_instance_id := ""
) -> bool:
	if not PlacementEngine.can_place_visually(building_type, origin, instances, unlocked_count, ignore_instance_id):
		return false
	return _infrastructure_allows(building_type, origin, instances, unlocked_count, ignore_instance_id)

static func can_place_geometry(
	building_type: String,
	origin: Vector2i,
	instances: Array,
	unlocked_count: int,
	require_visual := false,
	ignore_instance_id := ""
) -> bool:
	var geometry_valid := PlacementEngine.can_place_visually(
		building_type, origin, instances, unlocked_count, ignore_instance_id
	) if require_visual else PlacementEngine.can_place(
		building_type, origin, instances, unlocked_count, ignore_instance_id
	)
	return geometry_valid and not DefenseLayout.ordinary_conflicts_with_defense(
		building_type, origin, unlocked_count
	)

static func is_valid_layout(instances: Array, unlocked_count: int, require_visual := true) -> bool:
	var placed: Array = []
	for raw in instances:
		if raw is not Dictionary:
			return false
		var building_type := str(raw.get("type", ""))
		var origin := instance_origin(raw)
		if not can_place_geometry(building_type, origin, placed, unlocked_count, require_visual):
			return false
		placed.append(raw)
	return bool(infrastructure_network(placed, unlocked_count).success)

static func placement_reason(
	building_type: String,
	origin: Vector2i,
	instances: Array,
	unlocked_count: int,
	ignore_instance_id := ""
) -> String:
	var reason := PlacementEngine.placement_reason(building_type, origin, instances, unlocked_count, ignore_instance_id)
	if not reason.is_empty():
		return reason
	return _infrastructure_reason(building_type, origin, instances, unlocked_count, ignore_instance_id)

static func visual_placement_reason(
	building_type: String,
	origin: Vector2i,
	instances: Array,
	unlocked_count: int,
	ignore_instance_id := ""
) -> String:
	var reason := PlacementEngine.visual_placement_reason(building_type, origin, instances, unlocked_count, ignore_instance_id)
	if not reason.is_empty():
		return reason
	return _infrastructure_reason(building_type, origin, instances, unlocked_count, ignore_instance_id)

static func best_visual_origin(
	instances: Array,
	unlocked_count: int,
	building_type: String,
	preferred: Variant = INVALID_ORIGIN,
	ignore_instance_id := ""
) -> Vector2i:
	for origin in PlacementSolver.ranked_origins(
		building_type, instances, unlocked_count, preferred, ignore_instance_id, 96
	):
		if _infrastructure_allows(building_type, origin, instances, unlocked_count, ignore_instance_id):
			return origin
	return INVALID_ORIGIN

static func arrange_visual_layout(instances: Array, unlocked_count: int) -> Array:
	return DefenseLayout.arrange_ordinary(instances, unlocked_count)

static func visual_rect(origin: Vector2i, building_type: String, level := 5) -> Rect2:
	return PlacementEngine.visual_rect(origin, building_type, level)

static func visual_clearance_rect(origin: Vector2i, building_type: String) -> Rect2:
	return PlacementEngine.visual_clearance_rect(origin, building_type)

static func layout_visual_metrics(instances: Array) -> Dictionary:
	return PlacementEngine.layout_visual_metrics(instances)

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
	return DefenseLayout.arrange_ordinary(raw_instances, unlocked_count)

static func infrastructure_network(instances: Array, unlocked_count: int) -> Dictionary:
	var network := RoadNetwork.build(instances, unlocked_count, DefenseLayout.primary_gate(unlocked_count).road_root)
	network["gate_approach_cells"] = DefenseLayout.gate_approach_micro_cells(unlocked_count) \
		if bool(network.get("success", false)) else []
	return network

static func _infrastructure_allows(
	building_type: String,
	origin: Vector2i,
	instances: Array,
	unlocked_count: int,
	ignore_instance_id := ""
) -> bool:
	if DefenseLayout.ordinary_conflicts_with_defense(building_type, origin, unlocked_count):
		return false
	return bool(RoadNetwork.evaluate_access(
		building_type, origin, instances, unlocked_count, ignore_instance_id,
		DefenseLayout.primary_gate(unlocked_count).road_root
	).accessible)

static func _infrastructure_reason(
	building_type: String,
	origin: Vector2i,
	instances: Array,
	unlocked_count: int,
	ignore_instance_id := ""
) -> String:
	if DefenseLayout.ordinary_conflicts_with_defense(building_type, origin, unlocked_count):
		return "这里是城门与入城道路的营建范围"
	var access := RoadNetwork.evaluate_access(
		building_type, origin, instances, unlocked_count, ignore_instance_id,
		DefenseLayout.primary_gate(unlocked_count).road_root
	)
	return "" if bool(access.accessible) else str(access.reason)

static func repair_origin_candidates(unlocked_count: int) -> Array[Vector2i]:
	return PlacementEngine.repair_origin_candidates(unlocked_count)

# Compatibility helpers for v5 tests and migration callers.
static func slot(id: String, _era_id := "") -> Dictionary:
	var origin := origin_from_value(id)
	if origin == INVALID_ORIGIN:
		return {}
	var polygon := footprint_polygon(origin, "house")
	var anchor := art_anchor(origin, "house")
	return {
		"id": id, "grid_origin": encode_origin(origin), "anchor": anchor,
		"art_anchor": anchor, "plot_polygon": polygon, "position": anchor - Vector2(55, 82),
		"size": Vector2(110, 82), "footprint": Vector2(72, 36),
		"art_scale": art_scale("house"), "z": depth(origin, "house"),
	}

static func unlocked_slots(count: int) -> Array:
	return SLOTS.slice(0, clampi(count, 0, MAX_SLOTS))

static func first_open_slot(instances: Array, unlocked_count: int, preferred := "") -> String:
	var origin := first_open_origin(instances, unlocked_count, "house", preferred)
	return "" if origin == INVALID_ORIGIN else cell_id(origin)
