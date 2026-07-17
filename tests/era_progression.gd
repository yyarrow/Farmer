extends SceneTree

const EraRegistry = preload("res://src/data/era_registry.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("Audio").shutdown()
	var state := root.get_node("State")
	state.persistence_enabled = false
	state.reset_game()
	_check_era_definitions()

	_check(state.era_id == "spring_autumn" and state.get_era_name() == "春秋", "new game uses Spring and Autumn configuration")
	_check(state.get_building_slot_count() == 6 and state.get_built_building_count() == 4, "village begins with four of six lots occupied")

	_fill_resources(state)
	_check(state.upgrade_building("quarry"), "fifth lot can be constructed")
	_check(state.upgrade_building("wall"), "sixth lot can be constructed")
	var blocked_resources: Dictionary = state.resources.duplicate(true)
	_check(not state.upgrade_building("market"), "seventh building waits for a larger city")
	_check(state.resources == blocked_resources, "blocked construction charges no resources")

	for id in ["farm", "woodcut", "house", "warehouse"]:
		state.buildings[id] = 3
	_fill_resources(state)
	_check(state.advance_chapter(), "prosperous village advances to a city")
	_check(state.chapter == 2 and state.get_building_slot_count() == 7 and state.get_open_building_slots() == 1, "city level opens exactly one new lot")
	_check(state.upgrade_building("market"), "newly opened lot accepts construction")

	var progress_before_day := int(state.era_progress)
	state.current_day = 1
	state.next_attack_day = 99
	state.current_event = {}
	state._advance_day()
	_check(state.era_progress == progress_before_day + int(state.era_definition.era_growth.daily), "an actively settled day advances the era")

	state.chapter = 3
	state.era_progress = state.get_era_progress_target()
	_normalize_resources(state)
	var population_before := int(state.population)
	var army_before: Dictionary = state.units.duplicate(true)
	var city_before := int(state.chapter)
	_check(state.can_advance_era(), "completed Spring and Autumn run can enter Warring States")
	_check(state.advance_era(), "era transition succeeds")
	_check(state.era_id == "warring_states" and state.get_era_name() == "战国", "Warring States configuration becomes active")
	_check(state.UNITS.militia.name == "甲士" and state.UNITS.archer.name == "劲弩士" and state.UNITS.chariot.name == "轻骑", "unit catalog is era-configured")
	_check(state.BUILDINGS.barracks.name == "武备营" and state.RESOURCE_UNITS.stone.name == "版筑料", "building and resource labels are era-configured")
	_check(state.population == population_before and state.units == army_before and state.chapter == city_before, "era transition preserves residents, army, and city level")
	_check(state.era_progress == 0 and state.get_max_city_level() == 5 and is_equal_approx(state.get_city_view_scale(), 1.16), "new era resets its track and extends city growth")

	var warring_snapshot: Dictionary = state.get_snapshot()
	_check(state._is_valid_save_data(warring_snapshot), "Warring States snapshot passes v4 validation")
	state.reset_game()
	state._apply_snapshot(warring_snapshot, false)
	_check(state.era_id == "warring_states" and state.UNITS.militia.name == "甲士", "v4 load restores the saved era before its catalogs")
	state.chapter = 5
	state.era_progress = state.get_era_progress_target()
	_normalize_resources(state)
	_check(state.advance_era(), "Warring States transition enters Qin")
	_check(state.era_id == "qin" and state.UNITS.archer.name == "弩卒" and state.RESOURCE_UNITS.coins.name == "半两钱", "Qin military and currency catalogs become active")
	_check(state.BUILDINGS.warehouse.name == "县仓少内" and state.term("population") == "黔首" and state.get_logistics_status().name == "委输载粟", "Qin administration and logistics terminology become active")
	_check(str(state.get_city_background_path()).contains("city_qin"), "Qin painted city becomes active")
	state.chapter = 5
	state.era_progress = state.get_era_progress_target()
	_normalize_resources(state)
	_check(state.advance_era(), "Qin transition enters Han")
	_check(state.era_id == "han" and state.UNITS.militia.name == "材官" and state.UNITS.archer.name == "蹶张士" and state.UNITS.chariot.name == "边郡骑士", "Han unit catalog becomes active")
	_check(state.BUILDINGS.barracks.name == "武库营" and state.RESOURCE_UNITS.coins.name == "五铢钱" and state.get_logistics_status().name == "传舍转输", "Han buildings, currency, and logistics become active")
	_check(state.get_next_era_id().is_empty() and str(state.get_city_background_path()).contains("city_han"), "Han is the current finite end of the implemented chain")

	state.reset_game()
	var v3_snapshot: Dictionary = state.get_snapshot()
	v3_snapshot.format_version = 3
	v3_snapshot.erase("era_id")
	v3_snapshot.erase("era_progress")
	v3_snapshot.erase("city_level")
	var migrated: Dictionary = state._upgrade_snapshot(v3_snapshot)
	_check(int(migrated.format_version) == 4 and migrated.era_id == "spring_autumn", "v3 save migrates into the default era")
	_check(int(migrated.city_level) == int(migrated.chapter) and int(migrated.era_progress) > 0, "migration derives city and era progress")
	_check(state._is_valid_save_data(migrated), "migrated save passes current validation")

	var era_before_invalid: String = str(state.era_id)
	var invalid: Dictionary = state.get_snapshot()
	invalid.era_id = "unknown_era"
	state._apply_snapshot(invalid, false)
	_check(state.era_id == era_before_invalid, "unknown era snapshot is rejected without mutating the live game")

	state.reset_game()
	if failures.is_empty():
		print("ERA_PROGRESSION_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _fill_resources(state: Node) -> void:
	state.resources = {"grain": 100000.0, "wood": 100000.0, "stone": 100000.0, "coins": 100000.0}

func _normalize_resources(state: Node) -> void:
	for id in state.resources:
		state.resources[id] = state.get_capacity(id) * 0.45

func _check_era_definitions() -> void:
	var required := ["id", "display_name", "next_id", "city_levels", "era_growth", "visual", "seasons", "resource_units", "buildings", "units", "defense_orders", "enemy_waves", "events", "terms", "logistics", "economy", "trade_labels", "policies", "narrative", "initial_resources", "initial_buildings", "initial_units", "empty_units"]
	for era_id in EraRegistry.ORDER:
		var era: Dictionary = EraRegistry.definition(era_id)
		for key in required:
			_check(era.has(key), "%s era defines %s" % [era_id, key])
		_check(str(era.id) == era_id, "%s registry id matches definition" % era_id)
		_check(era.initial_resources.keys() == era.resource_units.keys(), "%s resource defaults match catalog" % era_id)
		_check(era.initial_buildings.keys() == era.buildings.keys(), "%s building defaults match catalog" % era_id)
		_check(era.initial_units.keys() == era.units.keys() and era.empty_units.keys() == era.units.keys(), "%s unit rosters match catalog" % era_id)
		_check(ResourceLoader.exists(str(era.visual.background)), "%s era background exists" % era_id)
		for term in ["population", "army_registry", "ledger_title", "military_title", "governance_title", "era_progress"]:
			_check(not str(era.terms.get(term, "")).is_empty(), "%s defines visible term %s" % [era_id, term])
		_check(era.logistics.load.keys() == era.units.keys(), "%s logistics load matches unit roles" % era_id)
		_check(float(era.logistics.base_capacity) > 0.0 and not era.logistics.patrol_cost.is_empty(), "%s logistics has capacity and patrol cost" % era_id)
		_check(int(era.economy.army_base) > 0 and int(era.economy.army_per_barracks) > 0 and float(era.economy.production.grain) > 0.0, "%s economy defines growth and military capacity" % era_id)
		for unit_id in era.units:
			_check(float(era.units[unit_id].power) > 0.0 and not str(era.units[unit_id].name).is_empty(), "%s unit %s has stats and label" % [era_id, unit_id])
		var previous_slots := 0
		for level_index in era.city_levels.size():
			var city: Dictionary = era.city_levels[level_index]
			_check(int(city.level) == level_index + 1 and int(city.slots) >= previous_slots, "%s city levels are ordered and never lose lots" % era_id)
			previous_slots = int(city.slots)
	_check(EraRegistry.next_id("spring_autumn") == "warring_states" and EraRegistry.next_id("warring_states") == "qin" and EraRegistry.next_id("qin") == "han" and EraRegistry.next_id("han").is_empty(), "era chain is explicit and finite")

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
