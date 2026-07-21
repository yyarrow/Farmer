extends Node

const EraRegistry = preload("res://src/data/era_registry.gd")
const CityLayout = preload("res://src/data/city_layout.gd")
const DefenseLayout = preload("res://src/city_placement/defense_layout.gd")
const BattleSystem = preload("res://src/systems/battle_system.gd")
const EconomySystem = preload("res://src/systems/economy_system.gd")
const ProgressionSystem = preload("res://src/systems/progression_system.gd")
const SaveMigrator = preload("res://src/persistence/save_migrator.gd")
const SaveRepository = preload("res://src/persistence/save_repository.gd")
const SaveValidator = preload("res://src/persistence/save_validator.gd")

signal changed
signal notice(message: String)
signal event_started(event: Dictionary)
signal battle_finished(result: Dictionary)
signal visual_event(kind: String, payload: Dictionary)
signal save_slots_changed
signal time_state_changed

const LEGACY_SAVE_PATH := "user://qinghe_save.json"
const SAVE_DIR := "user://saves"
const AUTO_SAVE_PATH := "user://saves/autosave.json"
const SLOT_COUNT := 3
const FORMAT_VERSION := 9
const DAY_SECONDS := 24.0
const MAX_OFFLINE_SECONDS := 7200.0
const OFFLINE_DAY_SECONDS := 300.0
const MAX_ENEMY_TIER := 8
const FINAL_ENEMY_WAVE := 13
const DAYS_PER_SEASON := 12
var era_id := EraRegistry.DEFAULT_ID
var era_progress := 0
var era_definition := EraRegistry.definition(EraRegistry.DEFAULT_ID)
var SEASONS: Array = era_definition.seasons
var RESOURCE_UNITS: Dictionary = era_definition.resource_units
var BUILDINGS: Dictionary = era_definition.buildings
var UNITS: Dictionary = era_definition.units
var DEFENSE_ORDERS: Dictionary = era_definition.defense_orders
var ENEMY_WAVES: Array = era_definition.enemy_waves
var EVENTS: Array = era_definition.events
var TERMS: Dictionary = era_definition.terms
var LOGISTICS: Dictionary = era_definition.logistics
var TRADE_LABELS: Dictionary = era_definition.trade_labels
var POLICIES: Dictionary = era_definition.policies

var resources: Dictionary = era_definition.initial_resources.duplicate(true)
var buildings: Dictionary = era_definition.initial_buildings.duplicate(true)
var defense_level := int(buildings.get("wall", 0))
var building_instances: Array = []
var _next_building_instance_seq := 1
var units: Dictionary = era_definition.initial_units.duplicate(true)
var wounded: Dictionary = era_definition.empty_units.duplicate(true)
var recovery_queue: Array = []
var population := 110
var morale := 70.0
var current_day := 1
var chapter := 1
var day_progress := 0.0
var next_attack_day := 7
var attack_wave := 1
var enemy_army: Dictionary = {}
var defense_order := "steady"
var last_patrol_day := 0
var patrol_delay_wave := 0
var tutorial_seen := false
var current_event: Dictionary = {}
var last_event_id := ""
var buffs := {"farm_until": 0, "all_until": 0}
var offline_report := ""
var last_day_report := ""
var time_speed := 0.0
var modal_paused := false
var persistence_enabled := true
var game_session_active := false
var rng := RandomNumberGenerator.new()
var _change_accum := 0.0
var _save_accum := 0.0

func _ready() -> void:
	rng.randomize()
	SaveRepository.ensure_directory(SAVE_DIR)
	_migrate_legacy_save()
	if building_instances.is_empty():
		_seed_instances_from_buildings()
	if enemy_army.is_empty():
		enemy_army = _make_enemy_army(attack_wave)
	set_process(true)
	Telemetry.track("game_state_ready", {"day": current_day, "chapter": chapter, "era": era_id, "format": FORMAT_VERSION})

func _process(delta: float) -> void:
	if not game_session_active:
		return
	var simulation_delta := delta * get_effective_time_speed()
	if simulation_delta > 0.0:
		_tick_economy(simulation_delta)
	_change_accum += delta
	_save_accum += delta
	if _change_accum >= 0.35:
		_change_accum = 0.0
		changed.emit()
	if _save_accum >= 10.0:
		_save_accum = 0.0
		save_game()

func _notification(what: int) -> void:
	if game_session_active and (what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED):
		save_game()

func _tick_economy(delta: float) -> void:
	var remaining_seconds := maxf(0.0, delta)
	while remaining_seconds > 0.0001:
		var seconds_to_next_day := maxf(0.0, (1.0 - day_progress) * DAY_SECONDS)
		var step := minf(remaining_seconds, seconds_to_next_day)
		var completed_ledger := get_daily_ledger()
		_produce_resources(step)
		day_progress += step / DAY_SECONDS
		remaining_seconds -= step
		if day_progress < 0.999999:
			break
		day_progress = 0.0
		var siege_due := current_day + 1 >= next_attack_day
		_advance_day(completed_ledger)
		# A long frame must never skip a decision that intentionally stops time.
		if siege_due or not current_event.is_empty():
			break

func _produce_resources(delta: float) -> void:
	var rates := get_rates()
	for key in resources:
		resources[key] = clampf(resources[key] + float(rates.get(key, 0.0)) * delta, 0.0, get_capacity(key))

func _configure_era(id: String) -> void:
	era_id = id if EraRegistry.has(id) else EraRegistry.DEFAULT_ID
	era_definition = EraRegistry.definition(era_id)
	SEASONS = era_definition.seasons
	RESOURCE_UNITS = era_definition.resource_units
	BUILDINGS = era_definition.buildings
	UNITS = era_definition.units
	DEFENSE_ORDERS = era_definition.defense_orders
	ENEMY_WAVES = era_definition.enemy_waves
	EVENTS = era_definition.events
	TERMS = era_definition.terms
	LOGISTICS = era_definition.logistics
	TRADE_LABELS = era_definition.trade_labels
	POLICIES = era_definition.policies
	if not DEFENSE_ORDERS.has(defense_order):
		defense_order = "steady"

func get_era_name() -> String:
	return str(era_definition.display_name)

func term(id: String, fallback := "") -> String:
	return str(TERMS.get(id, fallback if not fallback.is_empty() else id))

func get_transition_text() -> String:
	return str(era_definition.narrative.transition)

func get_trade_label(id: String) -> String:
	return str(TRADE_LABELS.get(id, id))

func get_policy_data(id: String) -> Dictionary:
	return POLICIES.get(id, {})

func get_next_era_id() -> String:
	return str(era_definition.next_id)

func get_next_era_name() -> String:
	var next_id := get_next_era_id()
	return str(EraRegistry.definition(next_id).display_name) if EraRegistry.has(next_id) else ""

func get_era_progress_target() -> int:
	return int(era_definition.era_growth.target)

func get_city_level_data(level := -1) -> Dictionary:
	if level < 1:
		level = chapter
	var levels: Array = era_definition.city_levels
	return levels[clampi(int(level) - 1, 0, levels.size() - 1)]

func get_city_level_name() -> String:
	return str(get_city_level_data().name)

func get_max_city_level() -> int:
	return era_definition.city_levels.size()

func get_building_slot_count() -> int:
	return mini(CityLayout.MAX_SLOTS, int(get_city_level_data().slots))

func get_defense_level() -> int:
	return clampi(maxi(defense_level, int(buildings.get("wall", 0))), 0, int(BUILDINGS.wall.max))

func get_built_building_count() -> int:
	return building_instances.size()

func get_open_building_slots() -> int:
	return maxi(0, get_building_slot_count() - get_built_building_count())

func get_building_instances() -> Array:
	return building_instances.duplicate(true)

func get_building_instance(instance_id: String) -> Dictionary:
	for instance in building_instances:
		if str(instance.get("id", "")) == instance_id:
			return instance
	return {}

func get_building_at_slot(slot_id: String) -> Dictionary:
	return get_building_at_origin(CityLayout.origin_from_value(slot_id))

func get_building_at_origin(origin: Vector2i) -> Dictionary:
	for instance in building_instances:
		if CityLayout.instance_origin(instance) == origin:
			return instance
	return {}

func get_building_at_cell(cell: Vector2i) -> Dictionary:
	for instance in building_instances:
		if cell in CityLayout.occupied_cells(CityLayout.instance_origin(instance), str(instance.get("type", ""))):
			return instance
	return {}

func can_place_building_at(building_type: String, origin: Vector2i, ignore_instance_id := "") -> bool:
	return CityLayout.can_place_visually(building_type, origin, building_instances, get_building_slot_count(), ignore_instance_id)

func building_placement_reason(building_type: String, origin: Vector2i, ignore_instance_id := "") -> String:
	return CityLayout.visual_placement_reason(building_type, origin, building_instances, get_building_slot_count(), ignore_instance_id)

func get_building_instances_of_type(building_type: String) -> Array:
	var result := []
	for instance in building_instances:
		if str(instance.get("type", "")) == building_type:
			result.append(instance)
	return result

func can_place_building_type(building_type: String) -> bool:
	if not BUILDINGS.has(building_type):
		return false
	if building_type == "wall":
		return get_defense_level() <= 0
	if building_type in CityLayout.UNIQUE_BUILDINGS:
		return get_building_instances_of_type(building_type).is_empty()
	return true

func _new_building_instance_id() -> String:
	var id := "building_%04d" % _next_building_instance_seq
	_next_building_instance_seq += 1
	return id

func _seed_instances_from_buildings() -> void:
	var raw_instances := []
	_next_building_instance_seq = 1
	defense_level = clampi(int(buildings.get("wall", defense_level)), 0, int(BUILDINGS.wall.max))
	for id in BUILDINGS:
		var level := int(buildings.get(id, 0))
		if level <= 0 or id == "wall":
			continue
		raw_instances.append({
			"id": _new_building_instance_id(), "type": id, "level": level,
			"slot_id": str(CityLayout.BUILDING_SLOT_DEFAULTS.get(id, "")),
		})
	building_instances = CityLayout.arrange_visual_layout(raw_instances, get_building_slot_count())
	if building_instances.size() != raw_instances.size():
		building_instances = []
		for raw in raw_instances:
			var building_type := str(raw.type)
			var origin := CityLayout.first_open_origin(building_instances, get_building_slot_count(), building_type, raw.slot_id)
			if origin == CityLayout.INVALID_ORIGIN:
				break
			raw.grid_origin = CityLayout.encode_origin(origin)
			raw.slot_id = CityLayout.cell_id(origin)
			building_instances.append(raw)

func _normalize_building_instances(raw_instances: Array) -> void:
	var split := DefenseLayout.split_legacy_wall_instances(raw_instances, get_defense_level())
	defense_level = int(split.defense_level)
	raw_instances = split.ordinary_instances
	building_instances = []
	_next_building_instance_seq = 1
	var unique_types := {}
	for raw in raw_instances:
		if raw is not Dictionary:
			continue
		var building_type := str(raw.get("type", ""))
		if not BUILDINGS.has(building_type):
			continue
		if building_type in CityLayout.UNIQUE_BUILDINGS and unique_types.has(building_type):
			continue
		var preferred: Variant = raw.get("grid_origin", raw.get("slot_id", ""))
		var origin := CityLayout.origin_from_value(preferred)
		if not CityLayout.can_place_geometry(building_type, origin, building_instances, get_building_slot_count()):
			origin = CityLayout.first_open_origin(building_instances, get_building_slot_count(), building_type, preferred)
		if origin == CityLayout.INVALID_ORIGIN:
			continue
		var instance_id := str(raw.get("id", ""))
		if instance_id.is_empty() or not get_building_instance(instance_id).is_empty():
			instance_id = _new_building_instance_id()
		else:
			var suffix := instance_id.trim_prefix("building_")
			if suffix.is_valid_int():
				_next_building_instance_seq = maxi(_next_building_instance_seq, int(suffix) + 1)
		building_instances.append({
			"id": instance_id,
			"type": building_type,
			"level": clampi(int(raw.get("level", 1)), 1, int(BUILDINGS[building_type].max)),
			"grid_origin": CityLayout.encode_origin(origin),
			"slot_id": CityLayout.cell_id(origin),
		})
		unique_types[building_type] = true
	_rebuild_building_totals()

func _rebuild_building_totals() -> void:
	var totals: Dictionary = era_definition.initial_buildings.duplicate(true)
	for id in totals:
		totals[id] = 0
	totals.wall = get_defense_level()
	for instance in building_instances:
		var building_type := str(instance.get("type", ""))
		if totals.has(building_type):
			totals[building_type] += int(instance.get("level", 0))
	buildings = totals

func get_city_view_scale() -> float:
	return float(get_city_level_data().view_scale)

func get_city_map_hint() -> String:
	return str(era_definition.visual.map_hint)

func get_city_background_path() -> String:
	return str(era_definition.visual.background)

func get_era_tint() -> Color:
	return era_definition.visual.tint

func can_advance_era() -> bool:
	return not get_next_era_id().is_empty() and era_progress >= get_era_progress_target() and chapter >= int(era_definition.era_growth.minimum_city_level)

func get_era_advance_block_reason() -> String:
	if get_next_era_id().is_empty():
		return "%s新制已臻完备，继续整饬城邑、积蓄国力" % get_era_name()
	if chapter < int(era_definition.era_growth.minimum_city_level):
		return "城池需达到%s" % str(get_city_level_data(int(era_definition.era_growth.minimum_city_level)).name)
	if era_progress < get_era_progress_target():
		return "时代积累尚差%d" % (get_era_progress_target() - era_progress)
	return ""

func _add_era_progress(amount: int, source: String) -> void:
	if amount <= 0 or get_next_era_id().is_empty():
		return
	var before := era_progress
	era_progress = mini(get_era_progress_target(), era_progress + amount)
	if era_progress != before:
		if source == "active_day" and floori(float(before) * 10.0 / get_era_progress_target()) == floori(float(era_progress) * 10.0 / get_era_progress_target()):
			return
		Telemetry.track("era_progress_gained", {"era": era_id, "source": source, "amount": era_progress - before, "progress": era_progress, "target": get_era_progress_target(), "day": current_day})

func get_daily_ledger() -> Dictionary:
	return _daily_ledger_for(buildings, population)

func _daily_ledger_for(building_levels: Dictionary, civilian_population: int) -> Dictionary:
	return EconomySystem.daily_ledger(
		get_season_data(),
		building_levels,
		civilian_population,
		units,
		get_wounded_count(),
		current_day,
		buffs,
		UNITS,
		TERMS,
		era_definition.economy
	)

func get_calendar() -> Dictionary:
	var absolute_day := maxi(0, current_day - 1)
	var season_index := int(absolute_day / DAYS_PER_SEASON) % SEASONS.size()
	return {
		"year": int(absolute_day / (DAYS_PER_SEASON * SEASONS.size())) + 1,
		"season_index": season_index,
		"season": SEASONS[season_index].id,
		"season_name": SEASONS[season_index].name,
		"day": absolute_day % DAYS_PER_SEASON + 1,
	}

func get_season_data() -> Dictionary:
	return SEASONS[int(get_calendar().season_index)]

func get_rates() -> Dictionary:
	var ledger := get_daily_ledger()
	return {
		"grain": float(ledger.grain.net) / DAY_SECONDS,
		"wood": float(ledger.wood.net) / DAY_SECONDS,
		"stone": float(ledger.stone.net) / DAY_SECONDS,
		"coins": float(ledger.coins.net) / DAY_SECONDS,
	}

func get_effective_time_speed() -> float:
	return 0.0 if modal_paused else time_speed

func set_time_speed(value: float, reason := "player") -> void:
	var normalized := 0.0
	if value >= 1.5:
		normalized = 2.0
	elif value >= 0.5:
		normalized = 1.0
	if is_equal_approx(time_speed, normalized):
		return
	time_speed = normalized
	changed.emit()
	time_state_changed.emit()
	Telemetry.track("time_speed_changed", {"speed": time_speed, "reason": reason, "day": current_day})

func set_modal_paused(value: bool) -> void:
	if modal_paused == value:
		return
	modal_paused = value
	time_state_changed.emit()

func advance_one_day() -> bool:
	if time_speed > 0.0 or modal_paused or not current_event.is_empty():
		notice.emit("请先暂停时间并处理当前事务")
		return false
	var remaining_seconds := maxf(0.0, (1.0 - day_progress) * DAY_SECONDS)
	var completed_ledger := get_daily_ledger()
	_produce_resources(remaining_seconds)
	day_progress = 0.0
	Telemetry.track("day_advanced_manually", {"from_day": current_day})
	_advance_day(completed_ledger)
	return true

func get_capacity(resource_id: String) -> float:
	return _capacity_for_level(resource_id, int(buildings.warehouse))

func _capacity_for_level(resource_id: String, warehouse_level: int) -> float:
	return EconomySystem.capacity(resource_id, warehouse_level, era_definition.economy)

func get_population_cap() -> int:
	return EconomySystem.population_cap(int(buildings.house), era_definition.economy)

func get_households() -> int:
	return ceili(float(population + get_army_count() + get_wounded_count()) / 5.0)

func get_total_residents() -> int:
	return population + get_army_count() + get_wounded_count()

func get_army_capacity() -> int:
	return EconomySystem.army_capacity(int(buildings.barracks), era_definition.economy)

func get_army_count() -> int:
	var total := 0
	for id in UNITS:
		total += int(units.get(id, 0))
	return total

func get_wounded_count() -> int:
	var total := 0
	for id in UNITS:
		total += int(wounded.get(id, 0))
	return total

func get_logistics_status(force: Dictionary = {}, include_wounded := true) -> Dictionary:
	var capacity := float(LOGISTICS.base_capacity)
	capacity += int(buildings.get("warehouse", 0)) * float(LOGISTICS.warehouse_capacity)
	capacity += int(buildings.get("woodcut", 0)) * float(LOGISTICS.woodcut_capacity)
	capacity += int(buildings.get("market", 0)) * float(LOGISTICS.market_capacity)
	var load := 0.0
	var active_force: Dictionary = units if force.is_empty() else force
	for id in UNITS:
		load += (int(active_force.get(id, 0)) + (int(wounded.get(id, 0)) if include_wounded else 0)) * float(LOGISTICS.load.get(id, 1.0))
	var ratio := capacity / maxf(1.0, load)
	var factor := clampf(ratio, 0.82, 1.0)
	var state_label := str(LOGISTICS.ready)
	if ratio < 0.85:
		state_label = str(LOGISTICS.critical)
	elif ratio < 1.0:
		state_label = str(LOGISTICS.strained)
	return {"name": str(LOGISTICS.name), "unit": str(LOGISTICS.unit), "desc": str(LOGISTICS.desc), "capacity": capacity, "load": load, "ratio": ratio, "factor": factor, "state": state_label}

func get_training() -> float:
	return 1.0 + buildings.barracks * 0.06

func _morale_factor(value: float) -> float:
	return BattleSystem.morale_factor(value)

func _force_power(force: Dictionary, force_morale: float, training: float) -> int:
	return BattleSystem.force_power(force, force_morale, training, UNITS)

func get_army_power() -> int:
	return _force_power(units, morale, get_training() * float(get_logistics_status().factor))

func get_defense() -> int:
	return get_army_power()

func get_defense_order_data() -> Dictionary:
	return DEFENSE_ORDERS.get(defense_order, DEFENSE_ORDERS.steady)

func set_defense_order(id: String) -> bool:
	if not DEFENSE_ORDERS.has(id) or id == defense_order:
		return false
	var previous := defense_order
	defense_order = id
	changed.emit()
	notice.emit("%s改为「%s」" % [term("defense_order", "守城阵令"), DEFENSE_ORDERS[id].name])
	visual_event.emit("defense_order", {"order": id, "previous": previous})
	Audio.play_sfx("command")
	Telemetry.track("defense_order_changed", {"from": previous, "to": id, "day": current_day, "wave": attack_wave, "army": units.duplicate()})
	save_game()
	return true

func get_enemy_power() -> int:
	if enemy_army.is_empty():
		return 0
	return _force_power(enemy_army, float(enemy_army.morale), float(enemy_army.training))

func get_next_enemy_power() -> int:
	return get_enemy_power()

func days_until_attack() -> int:
	return maxi(0, next_attack_day - current_day)

func get_prosperity() -> int:
	return ProgressionSystem.prosperity(buildings, population, get_army_count(), chapter)

func get_chapter_target() -> int:
	return int(get_city_level_data().advance_target)

func building_cost(id: String) -> Dictionary:
	if id == "wall":
		return EconomySystem.building_cost(BUILDINGS.wall, get_defense_level())
	var instances := get_building_instances_of_type(id)
	var level := int(instances[0].level) if not instances.is_empty() else int(buildings.get(id, 0))
	return EconomySystem.building_cost(BUILDINGS[id], level)

func new_building_cost(id: String) -> Dictionary:
	return EconomySystem.building_cost(BUILDINGS[id], 0) if BUILDINGS.has(id) else {}

func building_instance_cost(instance_id: String) -> Dictionary:
	var instance := get_building_instance(instance_id)
	if instance.is_empty():
		return {}
	return EconomySystem.building_cost(BUILDINGS[str(instance.type)], int(instance.level))

func get_building_effect_preview(id: String, instance_id := "") -> Dictionary:
	if not BUILDINGS.has(id):
		return {}
	var instance := get_building_instance(instance_id) if not instance_id.is_empty() else {}
	var level := int(instance.level) if not instance.is_empty() else int(buildings[id])
	var next_level := mini(level + 1, int(BUILDINGS[id].max))
	var next_buildings: Dictionary = buildings.duplicate(true)
	if next_level > level:
		next_buildings[id] = int(buildings[id]) + 1
	var next_population := population
	if id == "house" and next_level > level:
			next_population = mini(EconomySystem.population_cap(int(next_buildings[id]), era_definition.economy) - get_army_count() - get_wounded_count(), population + 5)
	var current_ledger := _daily_ledger_for(buildings, population)
	var next_ledger := _daily_ledger_for(next_buildings, next_population)
	var preview := {"kind": id, "level": level, "next_level": next_level, "has_next": next_level > level}
	match id:
		"farm":
			preview.merge({"resource": "grain", "current": current_ledger.grain.income, "next": next_ledger.grain.income})
		"woodcut":
			preview.merge({"resource": "wood", "current": current_ledger.wood.income, "next": next_ledger.wood.income})
		"quarry":
			preview.merge({"resource": "stone", "current": current_ledger.stone.income, "next": next_ledger.stone.income})
		"house", "market":
			preview.merge({"current": current_ledger.coins.income, "next": next_ledger.coins.income, "population_cap": get_population_cap(), "next_population_cap": EconomySystem.population_cap(int(next_buildings[id]), era_definition.economy)})
		"warehouse":
			preview.merge({
				"grain": _capacity_for_level("grain", int(buildings[id])), "next_grain": _capacity_for_level("grain", int(next_buildings[id])),
				"material": _capacity_for_level("wood", int(buildings[id])), "next_material": _capacity_for_level("wood", int(next_buildings[id])),
				"coins": _capacity_for_level("coins", int(buildings[id])), "next_coins": _capacity_for_level("coins", int(next_buildings[id])),
			})
		"barracks":
			preview.merge({"capacity": EconomySystem.army_capacity(int(buildings[id]), era_definition.economy), "next_capacity": EconomySystem.army_capacity(int(next_buildings[id]), era_definition.economy), "training": int(buildings[id]) * 6, "next_training": int(next_buildings[id]) * 6})
		"wall":
			preview.merge({"incoming": roundi(maxf(0.52, 1.0 - int(buildings[id]) * 0.09) * 100.0), "next_incoming": roundi(maxf(0.52, 1.0 - int(next_buildings[id]) * 0.09) * 100.0)})
	return preview

func can_afford(cost: Dictionary) -> bool:
	for key in cost:
		if resources.get(key, 0.0) + 0.001 < float(cost[key]):
			return false
	return true

func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		notice.emit("物资不足，请查看每日账本安排生产")
		Telemetry.track("resource_shortage", {"cost": cost, "resources": resources.duplicate()})
		visual_event.emit("shortage", {"cost": cost})
		return false
	for key in cost:
		resources[key] = maxf(0.0, float(resources[key]) - float(cost[key]))
	return true

func upgrade_building(id: String) -> bool:
	if not BUILDINGS.has(id):
		return false
	if id == "wall":
		return upgrade_defense()
	var instances := get_building_instances_of_type(id)
	if instances.is_empty():
		var origin := CityLayout.best_visual_origin(
			building_instances, get_building_slot_count(), id,
			str(CityLayout.BUILDING_SLOT_DEFAULTS.get(id, ""))
		)
		if origin == CityLayout.INVALID_ORIGIN and get_open_building_slots() > 0 and can_afford(new_building_cost(id)):
			origin = _reflow_for_automatic_build(id)
		return place_building(id, origin)
	return upgrade_building_instance(str(instances[0].id))

func _reflow_for_automatic_build(id: String) -> Vector2i:
	var placeholder_id := "__auto_build__"
	var pending := building_instances.duplicate(true)
	pending.append({"id": placeholder_id, "type": id, "level": 1})
	var arranged := CityLayout.arrange_visual_layout(pending, get_building_slot_count())
	if arranged.size() != pending.size():
		return CityLayout.INVALID_ORIGIN
	var origin := CityLayout.INVALID_ORIGIN
	var existing := []
	for instance in arranged:
		if str(instance.get("id", "")) == placeholder_id:
			origin = CityLayout.instance_origin(instance)
		else:
			existing.append(instance)
	if origin != CityLayout.INVALID_ORIGIN:
		building_instances = existing
	return origin

func place_building(id: String, placement: Variant) -> bool:
	if not BUILDINGS.has(id):
		return false
	if id == "wall":
		notice.emit("城防沿城域边界营建，不占用城内地块")
		return false
	if not can_place_building_type(id):
		notice.emit("%s只能营造一处" % BUILDINGS[id].name)
		return false
	if get_open_building_slots() <= 0:
		notice.emit("城内用地已满，请先提升城池等级")
		visual_event.emit("slot_full", {"building": id, "city_level": chapter})
		return false
	var origin := CityLayout.origin_from_value(placement)
	var placement_error := building_placement_reason(id, origin)
	if not placement_error.is_empty():
		notice.emit(placement_error)
		return false
	var cost := new_building_cost(id)
	if not spend(cost):
		return false
	var instance_id := _new_building_instance_id()
	building_instances.append({
		"id": instance_id, "type": id, "level": 1,
		"grid_origin": CityLayout.encode_origin(origin), "slot_id": CityLayout.cell_id(origin),
	})
	_rebuild_building_totals()
	_apply_building_reward(id)
	_add_era_progress(int(era_definition.era_growth.building_base) + 4, "building")
	changed.emit()
	notice.emit("建成 %s" % BUILDINGS[id].name)
	visual_event.emit("build", {"building": id, "instance_id": instance_id, "grid_origin": CityLayout.encode_origin(origin), "level": 1})
	Audio.play_sfx("build")
	Telemetry.track("building_build", {"building": id, "instance_id": instance_id, "grid_origin": CityLayout.encode_origin(origin), "to": 1, "cost": cost})
	save_game()
	return true

func upgrade_building_instance(instance_id: String) -> bool:
	var instance := get_building_instance(instance_id)
	if instance.is_empty():
		return false
	var id := str(instance.type)
	var level := int(instance.level)
	if level >= int(BUILDINGS[id].max):
		notice.emit("此建筑已臻完善")
		return false
	var cost := building_instance_cost(instance_id)
	if not spend(cost):
		return false
	instance.level = level + 1
	_rebuild_building_totals()
	_apply_building_reward(id)
	_add_era_progress(int(era_definition.era_growth.building_base) + int(instance.level) * 4, "building")
	changed.emit()
	notice.emit("升级 %s" % BUILDINGS[id].name)
	visual_event.emit("upgrade", {"building": id, "instance_id": instance_id, "grid_origin": instance.grid_origin, "level": instance.level})
	Audio.play_sfx("upgrade")
	Telemetry.track("building_upgrade", {"building": id, "instance_id": instance_id, "from": level, "to": instance.level, "cost": cost})
	save_game()
	return true

func upgrade_defense() -> bool:
	var level := get_defense_level()
	if level >= int(BUILDINGS.wall.max):
		notice.emit("城防已臻完善")
		return false
	var cost := EconomySystem.building_cost(BUILDINGS.wall, level)
	if not spend(cost):
		return false
	defense_level = level + 1
	buildings.wall = defense_level
	_add_era_progress(int(era_definition.era_growth.building_base) + defense_level * 4, "defense")
	changed.emit()
	notice.emit(("营建" if level == 0 else "加固") + " %s" % BUILDINGS.wall.name)
	visual_event.emit("defense_upgrade", {"building": "wall", "from": level, "level": defense_level})
	Audio.play_sfx("upgrade" if level > 0 else "build")
	Telemetry.track("defense_upgrade", {"from": level, "to": defense_level, "cost": cost})
	save_game()
	return true

func move_building_instance(instance_id: String, placement: Variant) -> bool:
	var instance := get_building_instance(instance_id)
	if instance.is_empty():
		return false
	var origin := CityLayout.origin_from_value(placement)
	var placement_error := building_placement_reason(str(instance.type), origin, instance_id)
	if not placement_error.is_empty():
		notice.emit(placement_error)
		return false
	var previous := CityLayout.instance_origin(instance)
	instance.grid_origin = CityLayout.encode_origin(origin)
	instance.slot_id = CityLayout.cell_id(origin)
	changed.emit()
	visual_event.emit("move", {"building": instance.type, "instance_id": instance_id, "from_origin": CityLayout.encode_origin(previous), "grid_origin": CityLayout.encode_origin(origin)})
	Audio.play_sfx("ui_tap")
	Telemetry.track("building_moved", {"building": instance.type, "instance_id": instance_id, "from": CityLayout.encode_origin(previous), "to": CityLayout.encode_origin(origin)})
	save_game()
	return true

func _apply_building_reward(id: String) -> void:
	if id == "house":
		population = mini(get_population_cap() - get_army_count() - get_wounded_count(), population + 5)
	if id == "barracks":
		morale = minf(100.0, morale + 4.0)

func recruit(id: String) -> bool:
	if not UNITS.has(id):
		return false
	var data: Dictionary = UNITS[id]
	if buildings.barracks < int(data.need):
		notice.emit("%s需要达到 %d 级" % [BUILDINGS.barracks.name, int(data.need)])
		return false
	var batch := int(data.batch)
	if get_army_count() + get_wounded_count() + batch > get_army_capacity():
		notice.emit("%s已满，请升级%s" % [term("army_registry", "军籍"), BUILDINGS.barracks.name])
		return false
	if population - batch < 40:
		notice.emit("%s丁口不足，无法继续%s" % [term("population", "民间"), term("recruit_verb", "征募")])
		return false
	if not spend(data.cost):
		return false
	population -= batch
	units[id] += batch
	morale = maxf(35.0, morale - 0.5)
	changed.emit()
	notice.emit("%s一%s%s：%d%s转入%s" % [term("recruit_verb", "征募"), str(data.get("batch_label", "伍")), data.name, batch, str(data.get("count_unit", term("population_unit", "人"))), term("army_registry", "军籍")])
	visual_event.emit("recruit", {"unit": id, "count": units[id], "batch": batch})
	Audio.play_sfx("recruit")
	Telemetry.track("unit_recruited", {"unit": id, "batch": batch, "count": units[id], "army_power": get_army_power(), "daily_upkeep": get_daily_ledger()})
	save_game()
	return true

func get_trade_quote(kind: String) -> Dictionary:
	return EconomySystem.trade_quote(kind, int(buildings.market))

func trade(kind: String) -> bool:
	var quote := get_trade_quote(kind)
	if quote.is_empty():
		return false
	for resource in quote.gain:
		var amount := float(quote.gain[resource])
		if float(resources.get(resource, 0.0)) + amount > get_capacity(resource) + 0.001:
			notice.emit("仓容不足：需留出%d%s%s空间，本次不扣款" % [roundi(amount), RESOURCE_UNITS[resource].unit, RESOURCE_UNITS[resource].short])
			visual_event.emit("storage_full", {"resource": resource, "amount": amount})
			Telemetry.track("trade_blocked_capacity", {"kind": kind, "resource": resource, "amount": amount, "stored": resources.get(resource, 0.0), "capacity": get_capacity(resource)})
			return false
	if not spend(quote.cost):
		return false
	for resource in quote.gain:
		resources[resource] += float(quote.gain[resource])
	changed.emit()
	notice.emit("%s完成" % str(TRADE_LABELS.action))
	visual_event.emit("trade", {"trade": kind})
	Audio.play_sfx("trade")
	Telemetry.track("trade_completed", {"kind": kind, "quote": quote, "resources": resources.duplicate()})
	save_game()
	return true

func get_policy_cost(id: String) -> Dictionary:
	match id:
		"irrigate": return {"wood": 35, "stone": 24, "coins": 280}
		"tax_relief": return {"coins": 650, "grain": 35}
		"reward_army": return {"grain": 60, "coins": 450}
	return {}

func get_policy_preview(id: String) -> Dictionary:
	match id:
		"irrigate":
			return {"active_days": maxi(0, current_day + 3 - int(buffs.farm_until))}
		"tax_relief":
			var civilian_room := maxi(0, get_population_cap() - get_army_count() - get_wounded_count() - population)
			return {"population_gain": mini(15, civilian_room), "morale_gain": minf(12.0, 100.0 - morale)}
		"reward_army":
			var expedited_wounded := 0
			for entry in recovery_queue:
				if int(entry.return_day) > current_day + 1:
					expedited_wounded += int(entry.count)
			return {"morale_gain": minf(18.0, 100.0 - morale), "expedited_wounded": expedited_wounded}
	return {}

func get_policy_block_reason(id: String) -> String:
	if get_policy_cost(id).is_empty():
		return "未知政令"
	var preview := get_policy_preview(id)
	if id == "irrigate" and int(preview.active_days) <= 0:
		return "水利增产已达三日"
	if id == "tax_relief":
		if int(preview.population_gain) <= 0 and float(preview.morale_gain) <= 0.001:
			return "民口与民心均已满"
	if id == "reward_army":
		if float(preview.morale_gain) <= 0.001 and int(preview.expedited_wounded) <= 0:
			return "士气已满且伤员无法再提早归队"
	return ""

func enact_policy(id: String) -> bool:
	var block_reason := get_policy_block_reason(id)
	if not block_reason.is_empty():
		notice.emit(block_reason + "，本次不扣物资")
		Telemetry.track("policy_blocked", {"policy": id, "reason": block_reason, "day": current_day})
		return false
	var cost := get_policy_cost(id)
	if not spend(cost):
		return false
	match id:
		"irrigate":
			buffs.farm_until = current_day + 3
		"tax_relief":
			population = mini(get_population_cap() - get_army_count() - get_wounded_count(), population + 15)
			morale = minf(100.0, morale + 12.0)
		"reward_army":
			morale = minf(100.0, morale + 18.0)
			for entry in recovery_queue:
				entry.return_day = maxi(current_day + 1, int(entry.return_day) - 1)
	notice.emit(str(POLICIES[id].notice))
	changed.emit()
	visual_event.emit("policy", {"policy": id})
	Audio.play_sfx("event")
	Telemetry.track("policy_enacted", {"policy": id, "day": current_day, "cost": cost})
	save_game()
	return true

func patrol() -> bool:
	if last_patrol_day == current_day:
		notice.emit("今日已派出巡骑")
		return false
	var patrol_minimum := int(LOGISTICS.patrol_minimum)
	if get_army_count() < patrol_minimum:
		notice.emit("至少需要%d%s可战%s才能%s" % [patrol_minimum, term("population_unit", "人"), term("army", "士卒"), term("patrol_name", "出城巡剿")])
		return false
	if not spend(LOGISTICS.patrol_cost):
		return false
	last_patrol_day = current_day
	var scout_power := maxf(1.0, get_enemy_power() * 0.55)
	var chance := clampf(0.24 + get_army_power() / (get_army_power() + scout_power) * 0.68, 0.25, 0.88)
	var won := rng.randf() <= chance
	enemy_army.scouted = true
	var player_losses := 0
	var enemy_losses := 0
	var player_loss_detail := {}
	var enemy_losses_by_type := {"militia": 0, "archer": 0, "chariot": 0}
	var delayed := false
	var field_victory := false
	if won:
		_add_era_progress(int(era_definition.era_growth.patrol_victory), "patrol_victory")
		enemy_losses = rng.randi_range(2, 5)
		var lost := _deal_losses(enemy_army, enemy_losses, rng)
		enemy_losses = _sum_force(lost)
		enemy_losses_by_type = lost
		if patrol_delay_wave != attack_wave:
			next_attack_day += 1
			patrol_delay_wave = attack_wave
			delayed = true
		morale = minf(100.0, morale + 3.0)
		if _sum_force(enemy_army) <= 0:
			field_victory = true
			attack_wave += 1
			next_attack_day = current_day + _next_attack_interval(true)
			enemy_army = _make_enemy_army(attack_wave)
			notice.emit("%s大捷：歼敌%d%s（%s），下一支敌军已在集结" % [term("patrol_name", "巡剿"), enemy_losses, term("population_unit", "人"), _loss_summary(lost, true)])
		else:
			notice.emit("%s得胜：敌军折损%d%s（%s）%s" % [term("patrol_name", "巡剿"), enemy_losses, term("population_unit", "人"), _loss_summary(lost, true), "，行军延误一日" if delayed else ""])
		visual_event.emit("patrol_win", {"enemy_losses": enemy_losses, "enemy_losses_by_type": lost, "delayed": delayed, "field_victory": field_victory})
		Audio.play_sfx("battle_win")
	else:
		player_losses = rng.randi_range(1, 3)
		player_loss_detail = _apply_field_losses(player_losses, 0.20)
		morale = maxf(20.0, morale - 5.0)
		notice.emit("%s失利：%s，但已探明敌军编成" % [term("patrol_name", "巡剿"), _casualty_summary(player_loss_detail.killed, player_loss_detail.wounded)])
		visual_event.emit("patrol_loss", {"player_losses": player_losses, "killed": player_loss_detail.killed, "wounded": player_loss_detail.wounded})
		Audio.play_sfx("battle_loss")
	changed.emit()
	Telemetry.track("patrol_resolved", {"won": won, "chance": chance, "player_losses": player_losses, "player_loss_detail": player_loss_detail, "enemy_losses": enemy_losses, "enemy_losses_by_type": enemy_losses_by_type, "delayed": delayed, "field_victory": field_victory, "enemy": enemy_army.duplicate(true)})
	save_game()
	return true

func _advance_day(completed_ledger: Dictionary = {}) -> void:
	current_day += 1
	_add_era_progress(int(era_definition.era_growth.daily), "active_day")
	var recovered := _recover_wounded()
	var ledger := completed_ledger if not completed_ledger.is_empty() else get_daily_ledger()
	last_day_report = "第%d日账：%s %+.1f%s  %s %+.1f%s  %s %+.1f%s  %s %+.0f%s" % [current_day, RESOURCE_UNITS.grain.short, ledger.grain.net, RESOURCE_UNITS.grain.unit, RESOURCE_UNITS.wood.short, ledger.wood.net, RESOURCE_UNITS.wood.unit, RESOURCE_UNITS.stone.short, ledger.stone.net, RESOURCE_UNITS.stone.unit, RESOURCE_UNITS.coins.short, ledger.coins.net, RESOURCE_UNITS.coins.unit]
	var civil_food := maxf(1.0, population / 15.0)
	if resources.grain > civil_food * 5.0 and get_total_residents() < get_population_cap() and morale >= 55.0:
		population += 1
	elif resources.grain < civil_food * 0.5:
		var lost_people := maxi(1, roundi(population * 0.02))
		population = maxi(40, population - lost_people)
		morale = maxf(10.0, morale - 7.0)
		notice.emit("%s告急：%d%s%s离邑" % [RESOURCE_UNITS.grain.name, lost_people, term("population_unit", "人"), term("population", "百姓")])
	morale = clampf(morale + (0.6 if float(ledger.grain.net) >= 0.0 else -1.2), 10.0, 100.0)
	if current_day >= next_attack_day:
		_resolve_siege()
	elif current_event.is_empty() and current_day % 3 == 0:
		_start_random_event()
	changed.emit()
	visual_event.emit("day", {"ledger": ledger, "recovered": recovered})
	Telemetry.track("day_settled", {"day": current_day, "ledger": ledger, "population": population, "army": units.duplicate(), "wounded": wounded.duplicate()})
	save_game()

func _recover_wounded() -> int:
	var remaining: Array = []
	var recovered := 0
	for entry in recovery_queue:
		if int(entry.return_day) <= current_day:
			var id: String = entry.unit
			var count := int(entry.count)
			wounded[id] = maxi(0, int(wounded[id]) - count)
			units[id] += count
			recovered += count
		else:
			remaining.append(entry)
	recovery_queue = remaining
	if recovered > 0:
		notice.emit("伤营有%d人康复归队" % recovered)
	return recovered

func _start_random_event() -> void:
	set_time_speed(0.0, "random_event")
	var season_id := str(get_calendar().season)
	var available := _events_for_current_season()
	var candidates := available.filter(func(event: Dictionary): return str(event.id) != last_event_id)
	if candidates.is_empty():
		candidates = available
	current_event = candidates[rng.randi_range(0, candidates.size() - 1)].duplicate(true)
	last_event_id = str(current_event.id)
	Audio.play_sfx("event")
	visual_event.emit("event", {"id": current_event.id})
	Telemetry.track("random_event_started", {"id": current_event.id, "day": current_day, "season": season_id})
	event_started.emit(current_event)

func _events_for_current_season() -> Array:
	var season_id := str(get_calendar().season)
	var available: Array = []
	for event in EVENTS:
		if not event.has("seasons") or season_id in event.seasons:
			available.append(event)
	return available

func _event_choice_cost(id: String, choice: int) -> Dictionary:
	match id:
		"drought":
			if choice == 0: return {"wood": 28, "stone": 18}
		"refugees":
			if choice == 0: return {"grain": 58}
		"merchant":
			if choice == 0: return {"coins": 720}
			if choice == 1: return {"grain": 75}
		"scouts":
			if choice == 0: return {"coins": 320}
		"flood":
			if choice == 0: return {"wood": 30, "stone": 18}
		"winter_relief":
			if choice == 0: return {"grain": 42}
		"craftsmen":
			if choice == 0: return {"coins": 480, "wood": 16}
		"rumors":
			if choice == 0: return {"coins": 200}
		"levy":
			if choice == 0: return {"grain": 45, "coins": 220}
	return {}

func get_event_choice_block_reason(choice: int) -> String:
	if current_event.is_empty() or choice < 0 or choice >= int(current_event.get("options", []).size()):
		return "选项无效"
	var id := str(current_event.get("id", ""))
	var cost := _event_choice_cost(id, choice)
	if not cost.is_empty() and not can_afford(cost):
		return "物资不足"
	if id == "refugees" and choice == 0:
		var civilian_room := get_population_cap() - get_army_count() - get_wounded_count() - population
		if civilian_room < 20:
			return "需20%s%s空位" % [term("population_unit", "人"), term("population", "民口")]
	if id == "merchant" and choice == 1 and resources.coins + 620.0 > get_capacity("coins") + 0.001:
		return "需620%s%s空位" % [RESOURCE_UNITS.coins.unit, RESOURCE_UNITS.coins.name]
	return ""

func is_event_choice_available(choice: int) -> bool:
	return get_event_choice_block_reason(choice).is_empty()

func resolve_event(choice: int) -> bool:
	if current_event.is_empty() or choice < 0 or choice >= int(current_event.get("options", []).size()):
		return false
	var block_reason := get_event_choice_block_reason(choice)
	if not block_reason.is_empty():
		notice.emit(block_reason + "，无法执行这项处置")
		Telemetry.track("event_choice_unavailable", {"id": current_event.get("id", ""), "choice": choice, "reason": block_reason, "resources": resources.duplicate()})
		return false
	var id: String = current_event.id
	var cost := _event_choice_cost(id, choice)
	if not cost.is_empty() and not spend(cost):
		return false
	match id:
		"drought":
			if choice == 0:
				buffs.farm_until = current_day + 3
				notice.emit("旧渠复通，农田转危为安")
			else:
				var relief := mini(45, floori(resources.grain))
				resources.grain -= relief
				if relief == 45:
					morale = minf(100.0, morale + 4.0)
					notice.emit("开仓赈济，百姓得以安心")
				else:
					morale = maxf(10.0, morale - 4.0)
					notice.emit("%s不足，仅赈出%d%s，乡里仍有不安" % [RESOURCE_UNITS.grain.name, relief, RESOURCE_UNITS.grain.unit])
		"refugees":
			if choice == 0:
				population += 20
				morale = minf(100.0, morale + 6.0)
				notice.emit("新民入籍，田野更添生气")
			else:
				var relief := mini(28, floori(resources.grain))
				resources.grain -= relief
				morale = minf(100.0, morale + 2.0) if relief == 28 else maxf(10.0, morale - 3.0)
				notice.emit("备粮送行，流民转赴他邑" if relief == 28 else "粮少难赈，流民失望离去")
		"merchant":
			if choice == 0:
				buffs.all_until = current_day + 3
				notice.emit("新农具使全邑生产加快")
			elif choice == 1:
				resources.coins += 620.0
				notice.emit("商队购入%s75%s，%s入库620%s" % [RESOURCE_UNITS.grain.name, RESOURCE_UNITS.grain.unit, RESOURCE_UNITS.coins.name, RESOURCE_UNITS.coins.unit])
			else:
				notice.emit("商队另赴他邑，青禾物资未有变动")
		"scouts":
			if choice == 0:
				enemy_army.scouted = true
				var losses := _deal_losses(enemy_army, 3, rng)
				notice.emit("反侦得手：探明敌军并使其折损%d人" % _sum_force(losses))
			else:
				next_attack_day += 1
				morale = maxf(10.0, morale - 3.0)
				notice.emit("封关戒严：敌军行军延误一日")
		"harvest":
			if choice == 0:
				resources.grain = minf(get_capacity("grain"), resources.grain + 105.0)
				notice.emit("嘉禾入仓，粮储充盈")
			else:
				resources.grain = minf(get_capacity("grain"), resources.grain + 42.0)
				morale = minf(100.0, morale + 15.0)
				notice.emit("与民同乐，举邑欢腾")
		"flood":
			if choice == 0:
				buffs.farm_until = maxi(int(buffs.farm_until), current_day + 3)
				morale = minf(100.0, morale + 2.0)
				notice.emit("堤渠相济，三日内农田增产")
			else:
				var lost_grain := mini(60, floori(resources.grain))
				resources.grain -= lost_grain
				morale = maxf(10.0, morale - 4.0)
				notice.emit("低田受淹，损失%s%d%s，民心受挫" % [RESOURCE_UNITS.grain.short, lost_grain, RESOURCE_UNITS.grain.unit])
		"winter_relief":
			if choice == 0:
				morale = minf(100.0, morale + 10.0)
				notice.emit("粥棚炊烟不绝，民心得安")
			else:
				morale = maxf(10.0, morale - 5.0)
				notice.emit("仓门紧闭，乡里颇有怨言")
		"craftsmen":
			if choice == 0:
				buffs.all_until = maxi(int(buffs.all_until), current_day + 3)
				notice.emit("百工安居，三日内全邑增产")
			else:
				resources.stone = minf(get_capacity("stone"), resources.stone + 28.0)
				morale = maxf(10.0, morale - 3.0)
				notice.emit("城工告成，却留下役使怨言")
		"rumors":
			if choice == 0:
				enemy_army.scouted = true
				morale = minf(100.0, morale + 5.0)
				notice.emit("吏卒查明军情，流言渐息")
			else:
				morale = maxf(10.0, morale - 6.0)
				notice.emit("流言蔓延，民心浮动")
		"levy":
			if choice == 0:
				morale = minf(100.0, morale + 3.0)
				notice.emit("使者受礼而去，边境暂安")
			else:
				next_attack_day = maxi(current_day + 1, next_attack_day - 1)
				morale = maxf(10.0, morale - 4.0)
				notice.emit("邻侯震怒，敌军行程提前一日")
	current_event = {}
	changed.emit()
	visual_event.emit("event_choice", {"id": id, "choice": choice})
	Telemetry.track("random_event_resolved", {"id": id, "choice": choice, "resources": resources.duplicate()})
	save_game()
	return true

func _make_enemy_army(wave: int) -> Dictionary:
	var tier := _enemy_tier_for_wave(wave)
	var index := mini(tier - 1, ENEMY_WAVES.size() - 1)
	var army: Dictionary = ENEMY_WAVES[index].duplicate(true)
	if tier > ENEMY_WAVES.size():
		var extra := tier - ENEMY_WAVES.size()
		army.militia += extra * 8
		army.archer += extra * 4
		army.chariot += extra * 5 if extra % 2 == 0 else 0
		army.morale = minf(88.0, float(army.morale) + extra * 2.0)
		army.training = minf(1.30, float(army.training) + extra * 0.03)
	if wave > FINAL_ENEMY_WAVE:
		var late_names: Array = era_definition.get("late_enemy_names", ["列国游军", "边军会师", "诸侯征粮师"])
		army.name = late_names[(wave - FINAL_ENEMY_WAVE - 1) % late_names.size()]
		match wave % 3:
			0:
				army.militia += 8
				army.archer -= 4
				army.chariot -= 1
			1:
				army.militia -= 8
				army.archer += 4
				army.chariot += 1
	army.tier = tier
	army.wave = wave
	army.scouted = false
	return army

func _enemy_tier_for_wave(wave: int) -> int:
	if wave <= 3:
		return clampi(wave, 1, MAX_ENEMY_TIER)
	return mini(MAX_ENEMY_TIER, 3 + int((wave - 3) / 2))

func _next_attack_interval(won: bool) -> int:
	var pacing: Dictionary = era_definition.get("battle_pacing", {})
	var interval := maxi(5, 8 - chapter) + int(pacing.get("attack_interval_bonus", 0))
	if attack_wave > FINAL_ENEMY_WAVE:
		interval += 2
	if not won:
		interval += int(pacing.get("post_defeat_bonus", 2))
	return interval

func get_enemy_display() -> Dictionary:
	var total := _sum_force(enemy_army)
	var people_unit := term("population_unit", "人")
	if bool(enemy_army.get("scouted", false)):
		return {"name": enemy_army.name, "known": true, "total": total, "range": "%d%s" % [total, people_unit], "composition": "%s%d%s  %s%d%s  %s%d%s" % [UNITS.militia.enemy_name, enemy_army.militia, str(UNITS.militia.get("count_unit", people_unit)), UNITS.archer.enemy_name, enemy_army.archer, str(UNITS.archer.get("count_unit", people_unit)), UNITS.chariot.enemy_name, enemy_army.chariot, str(UNITS.chariot.get("count_unit", people_unit))]}
	var low := maxi(1, floori(total * 0.78))
	var high := ceili(total * 1.22)
	return {"name": enemy_army.name, "known": false, "total": total, "range": "%d～%d%s" % [low, high, people_unit], "composition": "编成未明，%s可探查" % term("patrol_name", "巡剿")}

func get_battle_forecast(iterations := 120) -> Dictionary:
	var wins := 0
	var losses: Array[int] = []
	var forecast_rng := RandomNumberGenerator.new()
	forecast_rng.seed = int(current_day * 10007 + attack_wave * 7919 + get_army_count() * 97 + buildings.wall * 31)
	for _i in iterations:
		var result := _simulate_battle(units, morale, enemy_army, forecast_rng)
		if bool(result.won):
			wins += 1
		losses.append(int(result.player_losses))
	losses.sort()
	var low_index := clampi(floori(losses.size() * 0.15), 0, losses.size() - 1)
	var high_index := clampi(floori(losses.size() * 0.85), 0, losses.size() - 1)
	return {"win_rate": float(wins) / maxf(1.0, iterations), "loss_low": losses[low_index], "loss_high": losses[high_index]}

func _simulate_battle(player_force: Dictionary, player_morale: float, enemy_force: Dictionary, sim_rng: RandomNumberGenerator) -> Dictionary:
	return BattleSystem.simulate(
		player_force,
		player_morale,
		enemy_force,
		sim_rng,
		UNITS,
		int(buildings.wall),
		defense_order,
		get_defense_order_data(),
		get_training() * float(get_logistics_status(player_force, player_force == units).factor)
	)

func _resolve_siege() -> void:
	set_time_speed(0.0, "siege")
	var resolved_wave := attack_wave
	var enemy_before := enemy_army.duplicate(true)
	var result := _simulate_battle(units, morale, enemy_army, rng)
	units = result.player_survivors.duplicate(true)
	morale = float(result.player_morale_after)
	_add_wounded(result.wounded)
	var loss_text := "阵亡%d%s，负伤%d%s；敌军折损%d%s。" % [result.killed_total, term("population_unit", "人"), result.wounded_total, term("population_unit", "人"), result.enemy_losses, term("population_unit", "人")]
	if bool(result.won):
		_add_era_progress(int(era_definition.era_growth.battle_victory) + mini(18, resolved_wave * 2), "battle_victory")
		var spoils := 180.0 + attack_wave * 40.0
		resources.coins = minf(get_capacity("coins"), resources.coins + spoils)
		morale = minf(100.0, morale + 7.0)
		loss_text += " %s得胜，缴获%s%d%s。" % [term("army", "守军"), RESOURCE_UNITS.coins.name, roundi(spoils), RESOURCE_UNITS.coins.unit]
		if resolved_wave == FINAL_ENEMY_WAVE:
			loss_text += " 来敌主力受挫，此后边患转为间歇游军。"
	else:
		var protection := 1.0 - minf(0.66, buildings.warehouse * 0.10 + buildings.wall * 0.06)
		var lost_grain := minf(resources.grain, (45.0 + attack_wave * 8.0) * protection)
		var lost_coins := minf(resources.coins, (280.0 + attack_wave * 55.0) * protection)
		resources.grain -= lost_grain
		resources.coins -= lost_coins
		morale = maxf(10.0, morale - 12.0)
		loss_text += " 城外仓舍受损，损失%s%d%s、%s%d%s。" % [RESOURCE_UNITS.grain.short, roundi(lost_grain), RESOURCE_UNITS.grain.unit, RESOURCE_UNITS.coins.short, roundi(lost_coins), RESOURCE_UNITS.coins.unit]
	result.loss_text = loss_text
	result.enemy_name = enemy_before.name
	result.enemy_total = _sum_force(enemy_before)
	if bool(result.won):
		attack_wave += 1
	next_attack_day = current_day + _next_attack_interval(bool(result.won))
	patrol_delay_wave = 0
	if bool(result.won):
		enemy_army = _make_enemy_army(attack_wave)
	else:
		# A defeated garrison still consumes the besieging army. Keep its actual
		# survivors for the renewed attack instead of silently restoring a full
		# formation; this makes reported enemy losses strategically meaningful.
		enemy_army = enemy_before.duplicate(true)
		for id in UNITS:
			enemy_army[id] = int(result.enemy_survivors.get(id, 0))
		enemy_army.morale = minf(float(enemy_before.morale), maxf(40.0, float(result.enemy_morale_after) + 12.0))
		enemy_army.scouted = false
	visual_event.emit("siege_win" if result.won else "siege_loss", result)
	Audio.play_sfx("battle_win" if result.won else "battle_loss")
	Telemetry.track("siege_resolved", result.merged({"day": current_day, "chapter": chapter, "wave": resolved_wave}))
	battle_finished.emit(result)

func _add_wounded(injured: Dictionary) -> void:
	for id in UNITS:
		var count := int(injured.get(id, 0))
		if count <= 0:
			continue
		wounded[id] += count
		recovery_queue.append({"unit": id, "count": count, "return_day": current_day + rng.randi_range(2, 4)})

func _apply_field_losses(count: int, killed_ratio: float) -> Dictionary:
	var force := units.duplicate(true)
	var lost := _deal_losses(force, count, rng)
	units = force
	var killed := {"militia": 0, "archer": 0, "chariot": 0}
	var injured := {"militia": 0, "archer": 0, "chariot": 0}
	for id in UNITS:
		var dead := _stochastic_round(int(lost[id]) * killed_ratio, rng)
		killed[id] = dead
		injured[id] = int(lost[id]) - dead
	_add_wounded(injured)
	return {"lost": lost, "killed": killed, "wounded": injured}

func _loss_summary(losses: Dictionary, enemy := false) -> String:
	var parts: Array[String] = []
	for id in UNITS:
		var count := int(losses.get(id, 0))
		if count > 0:
			parts.append("%s%d%s" % [UNITS[id].enemy_name if enemy else UNITS[id].name, count, str(UNITS[id].get("count_unit", term("population_unit", "人")))])
	return "、".join(parts) if not parts.is_empty() else "无"

func _casualty_summary(killed: Dictionary, injured: Dictionary) -> String:
	var parts: Array[String] = []
	for id in UNITS:
		var dead := int(killed.get(id, 0))
		var wounded_count := int(injured.get(id, 0))
		if dead + wounded_count > 0:
			parts.append("%s亡%d伤%d%s" % [UNITS[id].name, dead, wounded_count, str(UNITS[id].get("count_unit", term("population_unit", "人")))])
	return "、".join(parts) if not parts.is_empty() else "无人伤亡"

func _deal_losses(force: Dictionary, requested: int, sim_rng: RandomNumberGenerator) -> Dictionary:
	return BattleSystem.deal_losses(force, requested, sim_rng, UNITS)

func _stochastic_round(value: float, sim_rng: RandomNumberGenerator) -> int:
	return BattleSystem.stochastic_round(value, sim_rng)

func _sum_force(force: Dictionary) -> int:
	return BattleSystem.sum_force(force)

func _merge_force_counts(target: Dictionary, addition: Dictionary) -> void:
	BattleSystem.merge_force_counts(target, addition, UNITS)

func advance_chapter() -> bool:
	if chapter >= get_max_city_level():
		notice.emit("%s时期的城池规模已至上限" % get_era_name())
		return false
	if get_prosperity() < get_chapter_target():
		notice.emit("繁荣度尚不足以扩建城邑")
		return false
	chapter += 1
	_add_era_progress(int(era_definition.era_growth.city_level), "city_level")
	set_time_speed(0.0, "chapter_advanced")
	resources.coins = minf(get_capacity("coins"), resources.coins + 1200.0)
	resources.grain = minf(get_capacity("grain"), resources.grain + 150.0)
	population = mini(get_population_cap() - get_army_count() - get_wounded_count(), population + 10)
	next_attack_day = mini(next_attack_day, current_day + 4)
	patrol_delay_wave = 0
	enemy_army = _make_enemy_army(attack_wave)
	notice.emit("城池晋升为%s：可建区域与建设容量已经扩展" % get_city_level_name())
	changed.emit()
	visual_event.emit("chapter", {"chapter": chapter})
	Audio.play_sfx("upgrade")
	Telemetry.track("chapter_advanced", {"chapter": chapter, "prosperity": get_prosperity()})
	save_game()
	return true

func advance_era() -> bool:
	var block_reason := get_era_advance_block_reason()
	if not block_reason.is_empty():
		notice.emit(block_reason)
		return false
	var previous_era := era_id
	var next_era := get_next_era_id()
	set_time_speed(0.0, "era_advanced")
	_configure_era(next_era)
	era_progress = 0
	for id in BUILDINGS:
		if not buildings.has(id):
			buildings[id] = 0
	for id in UNITS:
		if not units.has(id):
			units[id] = 0
		if not wounded.has(id):
			wounded[id] = 0
	defense_order = "steady"
	attack_wave = 1
	patrol_delay_wave = 0
	last_patrol_day = 0
	next_attack_day = current_day + 7
	enemy_army = _make_enemy_army(attack_wave)
	morale = minf(100.0, morale + 8.0)
	resources.coins = minf(get_capacity("coins"), resources.coins + 1200.0)
	resources.grain = minf(get_capacity("grain"), resources.grain + 180.0)
	current_event = {}
	last_event_id = ""
	changed.emit()
	visual_event.emit("era", {"from": previous_era, "to": era_id, "name": get_era_name()})
	Audio.play_sfx("upgrade")
	Telemetry.track("era_advanced", {"from": previous_era, "to": era_id, "day": current_day, "city_level": chapter})
	notice.emit("时代更迭：青禾进入%s，度量、城建、军制与转输体系已经启用" % get_era_name())
	save_game()
	return true

func mark_tutorial_seen() -> void:
	tutorial_seen = true
	Telemetry.track("tutorial_completed", {"day": current_day})
	save_game()

func save_game() -> void:
	if not persistence_enabled or not game_session_active:
		return
	if _write_save(AUTO_SAVE_PATH, get_snapshot()):
		Telemetry.track("autosave", {"day": current_day, "chapter": chapter})

func load_game() -> bool:
	if not FileAccess.file_exists(AUTO_SAVE_PATH):
		return false
	var data := _read_save(AUTO_SAVE_PATH)
	if data.is_empty():
		Telemetry.track_error("autosave_invalid", "自动存档无法解析")
		return false
	if not _apply_snapshot(data, true):
		Telemetry.track_error("autosave_migration_failed", "自动存档迁移后无法载入")
		return false
	game_session_active = true
	changed.emit()
	visual_event.emit("load", {"slot": 0})
	Telemetry.track("autosave_loaded", {"day": current_day, "chapter": chapter})
	save_game()
	return true

func get_autosave_info() -> Dictionary:
	var data := _read_save(AUTO_SAVE_PATH)
	if data.is_empty():
		return {"exists": false}
	var upgraded := _upgrade_snapshot(data)
	if not _is_valid_save_data(upgraded):
		return {"exists": false}
	var saved_era := str(upgraded.get("era_id", EraRegistry.DEFAULT_ID))
	return {
		"exists": true,
		"day": int(upgraded.get("current_day", 1)),
		"chapter": int(upgraded.get("city_level", upgraded.get("chapter", 1))),
		"era_name": str(EraRegistry.definition(saved_era).display_name),
		"prosperity": int(upgraded.get("prosperity", 0)),
		"saved_at": float(upgraded.get("saved_at", 0.0)),
	}

func get_snapshot() -> Dictionary:
	# Instance placement is authoritative. Reconcile the compatibility aggregate
	# before persistence so diagnostics or tests cannot serialize a split state.
	_rebuild_building_totals()
	return {
		"format_version": FORMAT_VERSION,
		"era_id": era_id,
		"era_progress": era_progress,
		"city_level": chapter,
		"resources": resources.duplicate(true),
		"buildings": buildings.duplicate(true),
		"defense_level": get_defense_level(),
		"building_instances": building_instances.duplicate(true),
		"units": units.duplicate(true),
		"wounded": wounded.duplicate(true),
		"recovery_queue": recovery_queue.duplicate(true),
		"population": population,
		"morale": morale,
		"current_day": current_day,
		"chapter": chapter,
		"day_progress": day_progress,
		"next_attack_day": next_attack_day,
		"attack_wave": attack_wave,
		"enemy_army": enemy_army.duplicate(true),
		"defense_order": defense_order,
		"last_patrol_day": last_patrol_day,
		"patrol_delay_wave": patrol_delay_wave,
		"tutorial_seen": tutorial_seen,
		"current_event": current_event.duplicate(true),
		"last_event_id": last_event_id,
		"buffs": buffs.duplicate(true),
		"prosperity": get_prosperity(),
		"saved_at": Time.get_unix_time_from_system(),
	}

func _upgrade_snapshot(data: Dictionary) -> Dictionary:
	var result := SaveMigrator.upgrade(data, FORMAT_VERSION, EraRegistry.DEFAULT_ID, EraRegistry.definition(EraRegistry.DEFAULT_ID))
	if bool(result.migrated):
		Telemetry.track("save_format_migrated", {"from": result.from, "to": FORMAT_VERSION})
	return result.data

func _apply_snapshot(data: Dictionary, apply_offline: bool) -> bool:
	if not _is_valid_save_data(data):
		Telemetry.track_error("save_snapshot_rejected", "存档结构或数值范围无效")
		return false
	var snapshot := _upgrade_snapshot(data)
	if not _is_valid_save_data(snapshot):
		Telemetry.track_error("save_migration_rejected", "迁移后的存档状态不一致")
		return false
	_configure_era(str(snapshot.get("era_id", EraRegistry.DEFAULT_ID)))
	era_progress = int(snapshot.get("era_progress", 0))
	resources = era_definition.initial_resources.duplicate(true)
	resources.merge(snapshot.get("resources", {}), true)
	buildings = era_definition.initial_buildings.duplicate(true)
	buildings.merge(snapshot.get("buildings", {}), true)
	defense_level = clampi(int(snapshot.get("defense_level", buildings.get("wall", 0))), 0, int(BUILDINGS.wall.max))
	buildings.wall = defense_level
	chapter = int(snapshot.get("city_level", snapshot.get("chapter", 1)))
	var saved_instances: Array = snapshot.get("building_instances", [])
	if saved_instances.is_empty():
		_seed_instances_from_buildings()
	else:
		_normalize_building_instances(saved_instances)
	units = era_definition.initial_units.duplicate(true)
	units.merge(snapshot.get("units", {}), true)
	wounded = era_definition.empty_units.duplicate(true)
	wounded.merge(snapshot.get("wounded", {}), true)
	recovery_queue = snapshot.get("recovery_queue", []).duplicate(true)
	population = int(snapshot.get("population", 110))
	morale = float(snapshot.get("morale", 70.0))
	current_day = int(snapshot.get("current_day", 1))
	day_progress = float(snapshot.get("day_progress", 0.0))
	next_attack_day = int(snapshot.get("next_attack_day", 7))
	attack_wave = int(snapshot.get("attack_wave", 1))
	enemy_army = snapshot.get("enemy_army", _make_enemy_army(attack_wave)).duplicate(true)
	defense_order = str(snapshot.get("defense_order", "steady"))
	last_patrol_day = int(snapshot.get("last_patrol_day", 0))
	patrol_delay_wave = int(snapshot.get("patrol_delay_wave", 0))
	tutorial_seen = bool(snapshot.get("tutorial_seen", tutorial_seen))
	time_speed = 0.0
	buffs = {"farm_until": 0, "all_until": 0}
	buffs.merge(snapshot.get("buffs", {}), true)
	var saved_event: Dictionary = snapshot.get("current_event", {})
	current_event = _event_definition(str(saved_event.get("id", ""))).duplicate(true) if not saved_event.is_empty() else {}
	last_event_id = str(snapshot.get("last_event_id", ""))
	offline_report = ""
	last_day_report = ""
	if apply_offline:
		_apply_offline_progress(snapshot)
	return true

func _apply_offline_progress(data: Dictionary) -> void:
	var elapsed := clampf(Time.get_unix_time_from_system() - float(data.get("saved_at", Time.get_unix_time_from_system())), 0.0, MAX_OFFLINE_SECONDS)
	if elapsed < 30.0:
		return
	var rewarded_days := minf(24.0, elapsed / OFFLINE_DAY_SECONDS)
	var ledger := get_daily_ledger()
	var gains := []
	for key in resources:
		var potential_gain: float = maxf(0.0, float(ledger[key].net)) * rewarded_days * 0.45
		var before: float = resources[key]
		resources[key] = minf(get_capacity(key), before + potential_gain)
		var actual_gain: float = resources[key] - before
		if actual_gain >= 1.0:
			gains.append("%s +%d%s" % [_resource_name(key), roundi(actual_gain), _resource_unit(key)])
	if not gains.is_empty():
		offline_report = "离城期间只结算安全生产：" + "  ".join(gains)
		Telemetry.track("offline_rewards", {"elapsed": roundi(elapsed), "rewarded_days": rewarded_days, "gains": gains})

func manual_save(slot: int) -> bool:
	if slot < 1 or slot > SLOT_COUNT:
		return false
	var data := get_snapshot()
	data.slot = slot
	var ok := _write_save(_slot_path(slot), data)
	if ok:
		notice.emit("进度已保存到档位 %d" % slot)
		Audio.play_sfx("ui_tap")
		Telemetry.track("manual_save", {"slot": slot, "day": current_day, "chapter": chapter})
		save_slots_changed.emit()
	else:
		notice.emit("档位 %d 保存失败，诊断记录已保留" % slot)
	return ok

func load_slot(slot: int) -> bool:
	var path := _slot_path(slot)
	var had_save_file := FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")
	var data := _read_save(path)
	if data.is_empty():
		notice.emit("该档位存档损坏且无可用备份" if had_save_file else "该档位尚无存档")
		return false
	if not _apply_snapshot(data, true):
		notice.emit("该档位迁移失败，原存档未覆盖")
		return false
	game_session_active = true
	changed.emit()
	save_game()
	notice.emit("已载入档位 %d" % slot)
	visual_event.emit("load", {"slot": slot})
	Telemetry.track("manual_load", {"slot": slot, "day": current_day, "chapter": chapter})
	return true

func delete_slot(slot: int) -> bool:
	var path := _slot_path(slot)
	var result := SaveRepository.delete_save(path)
	if not bool(result.get("found", false)):
		notice.emit("该档位尚无存档")
		return false
	if not bool(result.get("ok", false)):
		Telemetry.track_error("save_delete_failed", error_string(int(result.error)), {"slot": slot, "path": result.path})
		notice.emit("档位 %d 删除失败，诊断记录已保留" % slot)
		return false
	Telemetry.track("manual_save_deleted", {"slot": slot})
	save_slots_changed.emit()
	return true

func list_save_slots() -> Array:
	var slots: Array = []
	for slot in range(1, SLOT_COUNT + 1):
		var path := _slot_path(slot)
		var data := _read_save(path)
		if data.is_empty():
			slots.append({"slot": slot, "exists": false})
		else:
			slots.append({"slot": slot, "exists": true, "day": int(data.get("current_day", 1)), "chapter": int(data.get("city_level", data.get("chapter", 1))), "era_id": str(data.get("era_id", EraRegistry.DEFAULT_ID)), "era_name": str(EraRegistry.definition(str(data.get("era_id", EraRegistry.DEFAULT_ID))).display_name), "prosperity": int(data.get("prosperity", 0)), "saved_at": float(data.get("saved_at", 0.0))})
	return slots

func _slot_path(slot: int) -> String:
	return SaveRepository.slot_path(SAVE_DIR, slot)

func _write_save(path: String, data: Dictionary) -> bool:
	var result := SaveRepository.write_save(path, data, Callable(self, "_is_valid_save_data"))
	if bool(result.get("ok", false)):
		return true
	Telemetry.track_error(str(result.event), str(result.message), result.context)
	return false

func _valid_number(value: Variant, minimum: float, maximum: float) -> bool:
	return SaveValidator.valid_number(value, minimum, maximum)

func _valid_numeric_map(value: Variant, allowed_keys: Array, minimum: float, maximum: float) -> bool:
	return SaveValidator.valid_numeric_map(value, allowed_keys, minimum, maximum)

func _event_definition(id: String) -> Dictionary:
	for event in EVENTS:
		if str(event.id) == id:
			return event
	return {}

func _save_validation_context() -> Dictionary:
	return {
		"format_version": FORMAT_VERSION,
		"max_enemy_tier": MAX_ENEMY_TIER,
		"default_era_id": EraRegistry.DEFAULT_ID,
		"eras": EraRegistry.definitions(),
	}

func _is_consistent_current_save(data: Dictionary) -> bool:
	return SaveValidator.is_consistent_current(data, _save_validation_context())

func _is_valid_save_data(data: Dictionary) -> bool:
	return SaveValidator.is_valid(data, _save_validation_context())

func _read_save_file(path: String) -> Dictionary:
	return SaveRepository.read_save_file(path, Callable(self, "_is_valid_save_data"))

func _read_save(path: String) -> Dictionary:
	var result := SaveRepository.read_save(path, Callable(self, "_is_valid_save_data"))
	if bool(result.recovered_backup):
		Telemetry.track("save_backup_recovered", {"path": path})
	if bool(result.invalid_primary):
		Telemetry.track_error("save_invalid", "存档与备份均无法解析或未通过结构校验", {"path": path})
	return result.data

func _migrate_legacy_save() -> void:
	if FileAccess.file_exists(AUTO_SAVE_PATH) or not FileAccess.file_exists(LEGACY_SAVE_PATH):
		return
	var data := _read_save(LEGACY_SAVE_PATH)
	if not data.is_empty() and _write_save(AUTO_SAVE_PATH, data):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LEGACY_SAVE_PATH))
		Telemetry.track("legacy_save_migrated", {"format": data.get("format_version", 1)})

func reset_game() -> void:
	game_session_active = true
	_configure_era(EraRegistry.DEFAULT_ID)
	era_progress = 0
	resources = era_definition.initial_resources.duplicate(true)
	buildings = era_definition.initial_buildings.duplicate(true)
	defense_level = int(buildings.get("wall", 0))
	chapter = 1
	_seed_instances_from_buildings()
	units = era_definition.initial_units.duplicate(true)
	wounded = era_definition.empty_units.duplicate(true)
	recovery_queue = []
	population = 110
	morale = 70.0
	current_day = 1
	day_progress = 0.0
	next_attack_day = 7
	attack_wave = 1
	enemy_army = _make_enemy_army(attack_wave)
	defense_order = "steady"
	last_patrol_day = 0
	patrol_delay_wave = 0
	tutorial_seen = false
	current_event = {}
	last_event_id = ""
	buffs = {"farm_until": 0, "all_until": 0}
	offline_report = ""
	last_day_report = ""
	time_speed = 0.0
	modal_paused = false
	changed.emit()
	visual_event.emit("new_game", {})
	Telemetry.track("new_game", {"format": FORMAT_VERSION})
	save_game()

func _resource_name(id: String) -> String:
	return str(RESOURCE_UNITS.get(id, {}).get("short", id))

func _resource_unit(id: String) -> String:
	return str(RESOURCE_UNITS.get(id, {}).get("unit", ""))
