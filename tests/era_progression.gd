extends SceneTree

const EraRegistry = preload("res://src/data/era_registry.gd")
const CityLayout = preload("res://src/data/city_layout.gd")

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
	_check(state.chapter == 2 and state.get_building_slot_count() == 9 and state.get_open_building_slots() == 3, "Spring and Autumn mid-tier city opens three new lots")
	_check(state.upgrade_building("market"), "newly opened lot accepts construction")
	var duplicate_origin := CityLayout.first_open_origin(state.building_instances, state.get_building_slot_count(), "farm")
	_check(state.place_building("farm", duplicate_origin), "repeatable building types can occupy a second footprint")
	_check(int(state.buildings.farm) == 2 and state.get_built_building_count() == 8, "duplicate farm contributes its own level and consumes one lot")
	var duplicate_farm: Dictionary = state.get_building_at_origin(duplicate_origin)
	var move_origin := CityLayout.first_open_origin(state.building_instances, state.get_building_slot_count(), "farm", CityLayout.INVALID_ORIGIN, str(duplicate_farm.id))
	_check(state.move_building_instance(str(duplicate_farm.id), move_origin), "placed building can move between valid open footprints")
	_check(state.get_building_at_origin(duplicate_origin).is_empty() and str(state.get_building_at_origin(move_origin).id) == str(duplicate_farm.id), "moving preserves identity and frees the old footprint")
	_check(not state.place_building("wall", duplicate_origin), "unique city wall cannot be placed twice")

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
	_check(state.get_building_slot_count() == 12 and state.get_open_building_slots() == 4, "era transition never relocks occupied city lots")
	_check(state.era_progress == 0 and state.get_max_city_level() == 5 and is_equal_approx(state.get_city_view_scale(), 1.16), "new era resets its track and extends city growth")

	var warring_snapshot: Dictionary = state.get_snapshot()
	_check(state._is_valid_save_data(warring_snapshot), "Warring States snapshot passes v5 validation")
	state.reset_game()
	state._apply_snapshot(warring_snapshot, false)
	_check(state.era_id == "warring_states" and state.UNITS.militia.name == "甲士", "v5 load restores the saved era before its catalogs")
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
	_check(state.get_next_era_id() == "three_kingdoms" and str(state.get_city_background_path()).contains("city_han"), "Han exposes Three Kingdoms as its configured successor")
	state.chapter = 5
	state.era_progress = state.get_era_progress_target()
	_normalize_resources(state)
	_check(state.advance_era(), "Han transition enters Three Kingdoms")
	_check(state.era_id == "three_kingdoms" and state.UNITS.archer.name == "强弩士" and state.BUILDINGS.farm.name == "军屯阡陌", "Three Kingdoms activates military farming and strong-crossbow catalogs")
	_check(state.RESOURCE_UNITS.coins.name == "魏五铢" and state.get_logistics_status().name == "军屯转饷" and str(state.get_city_background_path()).contains("city_three_kingdoms"), "Three Kingdoms activates currency, logistics, and painted city")
	state.chapter = 5
	state.era_progress = state.get_era_progress_target()
	_normalize_resources(state)
	_check(state.advance_era(), "Three Kingdoms transition enters Jin")
	_check(state.era_id == "jin" and state.UNITS.chariot.name == "具装骑" and state.BUILDINGS.house.name == "侨户里坊", "Jin activates armored cavalry and refugee-registration catalogs")
	_check(state.get_logistics_status().name == "州郡转输" and str(state.get_city_background_path()).contains("city_jin"), "Jin activates logistics and painted city")
	state.chapter = 5
	state.era_progress = state.get_era_progress_target()
	_normalize_resources(state)
	_check(state.advance_era(), "Jin transition enters Northern and Southern Dynasties")
	_check(state.era_id == "northern_southern" and state.UNITS.chariot.name == "甲骑具装" and state.BUILDINGS.house.name == "三长里坊", "Northern and Southern Dynasties activates cataphracts and three-elders household catalog")
	_check(state.RESOURCE_UNITS.coins.name == "永安五铢" and state.get_logistics_status().name == "镇戍转饷", "Northern and Southern Dynasties activates currency and garrison logistics")
	_check(state.get_next_era_id() == "sui" and str(state.get_city_background_path()).contains("city_northern_southern"), "Northern and Southern Dynasties exposes Sui as its configured successor")
	state.chapter = 5
	state.era_progress = state.get_era_progress_target()
	_normalize_resources(state)
	_check(state.advance_era(), "Northern and Southern Dynasties transition enters Sui")
	_check(state.era_id == "sui" and state.UNITS.militia.name == "府兵" and state.BUILDINGS.warehouse.name == "漕渠官仓", "Sui activates fubing and canal granary catalogs")
	_check(state.RESOURCE_UNITS.coins.name == "隋五铢" and state.get_logistics_status().name == "漕河转输" and str(state.get_city_background_path()).contains("city_sui"), "Sui activates currency, logistics, and painted city")
	state.chapter = 5
	state.era_progress = state.get_era_progress_target()
	_normalize_resources(state)
	_check(state.advance_era(), "Sui transition enters Tang")
	_check(state.era_id == "tang" and state.UNITS.chariot.name == "轻骑" and state.BUILDINGS.barracks.name == "折冲府", "Tang activates light cavalry and Zhechong-fu catalogs")
	_check(state.RESOURCE_UNITS.coins.name == "开元通宝" and state.RESOURCE_UNITS.coins.unit == "文" and state.get_logistics_status().name == "馆驿漕运", "Tang activates treasure coin unit and courier logistics")
	state.chapter = 5
	state.era_progress = state.get_era_progress_target()
	_normalize_resources(state)
	_check(state.advance_era(), "Tang transition enters Five Dynasties")
	_check(state.era_id == "five_dynasties" and state.UNITS.chariot.name == "牙军骑" and state.BUILDINGS.barracks.name == "节度军府", "Five Dynasties activates household cavalry and military governor catalogs")
	_check(state.RESOURCE_UNITS.coins.name == "诸道通宝" and state.get_logistics_status().name == "藩镇转饷", "Five Dynasties activates mixed coinage and regional logistics")
	_check(state.get_next_era_id() == "song" and str(state.get_city_background_path()).contains("city_five_dynasties"), "Five Dynasties exposes Song as its configured successor")
	state.chapter = 5
	state.era_progress = state.get_era_progress_target()
	_normalize_resources(state)
	_check(state.advance_era(), "Five Dynasties transition enters Song")
	_check(state.era_id == "song" and state.UNITS.archer.name == "神臂弓手" and state.BUILDINGS.warehouse.name == "转般仓", "Song activates crossbow and transfer-granary catalogs")
	_check(state.RESOURCE_UNITS.coins.name == "年号钱" and state.get_logistics_status().name == "纲运转般", "Song activates reign coinage and gang transport")
	state.chapter = 5
	state.era_progress = state.get_era_progress_target()
	_normalize_resources(state)
	_check(state.advance_era(), "Song transition enters Yuan")
	_check(state.era_id == "yuan" and state.UNITS.chariot.name == "蒙古骑军" and state.BUILDINGS.barracks.name == "万户府", "Yuan activates mounted and myriarchy catalogs")
	_check(state.RESOURCE_UNITS.coins.name == "至元钞" and state.RESOURCE_UNITS.coins.unit == "贯" and state.get_logistics_status().name == "站赤漕运", "Yuan activates paper currency and relay logistics")
	state.chapter = 5
	state.era_progress = state.get_era_progress_target()
	_normalize_resources(state)
	_check(state.advance_era(), "Yuan transition enters Ming")
	_check(state.era_id == "ming" and state.UNITS.archer.name == "神机铳手" and state.BUILDINGS.barracks.name == "卫所军署", "Ming activates firearm and guard catalogs")
	_check(state.RESOURCE_UNITS.coins.name == "库银" and state.RESOURCE_UNITS.coins.unit == "两" and state.get_logistics_status().name == "漕运军需", "Ming activates silver accounting and canal supplies")
	state.chapter = 5
	state.era_progress = state.get_era_progress_target()
	_normalize_resources(state)
	_check(state.advance_era(), "Ming transition enters Qing")
	_check(state.era_id == "qing" and state.UNITS.chariot.name == "八旗马甲" and state.BUILDINGS.warehouse.name == "常平仓粮台", "Qing activates mounted banner and grain-platform catalogs")
	_check(state.RESOURCE_UNITS.coins.name == "库平银" and state.get_logistics_status().name == "驿站粮台", "Qing activates treasury silver and relay grain platforms")
	_check(state.get_next_era_id().is_empty() and str(state.get_city_background_path()).contains("city_qing"), "Qing is the finite implemented end of the chain")

	state.reset_game()
	var v3_snapshot: Dictionary = state.get_snapshot()
	v3_snapshot.format_version = 3
	v3_snapshot.erase("era_id")
	v3_snapshot.erase("era_progress")
	v3_snapshot.erase("city_level")
	var migrated: Dictionary = state._upgrade_snapshot(v3_snapshot)
	_check(int(migrated.format_version) == 6 and migrated.era_id == "spring_autumn", "v3 save migrates into the default era")
	_check(migrated.building_instances is Array and migrated.building_instances.size() == 4, "legacy buildings migrate into placed instances")
	_check(migrated.building_instances.all(func(instance): return instance.has("grid_origin")), "legacy sockets migrate to grid origins")
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
	var required := ["id", "display_name", "next_id", "city_levels", "era_growth", "battle_pacing", "visual", "seasons", "resource_units", "buildings", "units", "defense_orders", "enemy_waves", "events", "terms", "logistics", "economy", "trade_labels", "policies", "narrative", "initial_resources", "initial_buildings", "initial_units", "empty_units"]
	for era_id in EraRegistry.ORDER:
		var era: Dictionary = EraRegistry.definition(era_id)
		for key in required:
			_check(era.has(key), "%s era defines %s" % [era_id, key])
		_check(str(era.id) == era_id, "%s registry id matches definition" % era_id)
		_check(era.initial_resources.keys() == era.resource_units.keys(), "%s resource defaults match catalog" % era_id)
		_check(era.initial_buildings.keys() == era.buildings.keys(), "%s building defaults match catalog" % era_id)
		_check(era.initial_units.keys() == era.units.keys() and era.empty_units.keys() == era.units.keys(), "%s unit rosters match catalog" % era_id)
		_check(ResourceLoader.exists(str(era.visual.background)), "%s era background exists" % era_id)
		_check(str(era.visual.background).contains("_terrain.png"), "%s uses a road-free terrain background" % era_id)
		var anchors := {}
		for slot_definition in CityLayout.SLOTS:
			var slot: Dictionary = CityLayout.slot(str(slot_definition.id), era_id)
			var anchor: Vector2 = slot.anchor
			anchors[anchor] = true
			_check(slot.plot_polygon.size() == 4, "%s %s maps legacy saves onto the shared ground plane" % [era_id, slot.id])
			_check(anchor.x >= 0.0 and anchor.x <= 540.0 and anchor.y >= 184.0 and anchor.y <= 500.0, "%s %s anchor stays inside the visible city" % [era_id, slot.id])
			_check(int(slot.z) > 20, "%s %s depth derives from its frontmost grid cell" % [era_id, slot.id])
		_check(anchors.size() == CityLayout.MAX_SLOTS, "%s keeps twelve distinct legacy migration origins" % era_id)
		for building_id in era.buildings:
			var art_path := "res://assets/art/buildings/eras/%s/%s_stages.png" % [era_id, building_id]
			_check(ResourceLoader.exists(art_path), "%s %s has era-matched four-stage art" % [era_id, building_id])
		for term in ["population", "army_registry", "ledger_title", "military_title", "governance_title", "era_progress"]:
			_check(not str(era.terms.get(term, "")).is_empty(), "%s defines visible term %s" % [era_id, term])
		_check(era.logistics.load.keys() == era.units.keys(), "%s logistics load matches unit roles" % era_id)
		_check(float(era.logistics.base_capacity) > 0.0 and not era.logistics.patrol_cost.is_empty(), "%s logistics has capacity and patrol cost" % era_id)
		_check(int(era.battle_pacing.attack_interval_bonus) >= 0 and int(era.battle_pacing.post_defeat_bonus) >= 2, "%s battle pacing preserves recovery windows" % era_id)
		_check(int(era.economy.army_base) > 0 and int(era.economy.army_per_barracks) > 0 and float(era.economy.production.grain) > 0.0, "%s economy defines growth and military capacity" % era_id)
		for unit_id in era.units:
			_check(float(era.units[unit_id].power) > 0.0 and not str(era.units[unit_id].name).is_empty(), "%s unit %s has stats and label" % [era_id, unit_id])
		var previous_slots := 0
		for level_index in era.city_levels.size():
			var city: Dictionary = era.city_levels[level_index]
			_check(int(city.level) == level_index + 1 and int(city.slots) >= previous_slots, "%s city levels are ordered and never lose lots" % era_id)
			previous_slots = int(city.slots)
		_check(int(era.city_levels[0].slots) == 6 and int(era.city_levels[1].slots) == 9 and int(era.city_levels[2].slots) == 12, "%s unlocks lots globally as 6, 9, 12" % era_id)
		_check(previous_slots == 12, "%s highest city level opens all twelve lots" % era_id)
	var expected_chain := ["spring_autumn", "warring_states", "qin", "han", "three_kingdoms", "jin", "northern_southern", "sui", "tang", "five_dynasties", "song", "yuan", "ming", "qing"]
	_check(EraRegistry.ORDER == expected_chain, "era chain order is explicit")
	for index in expected_chain.size() - 1:
		_check(EraRegistry.next_id(expected_chain[index]) == expected_chain[index + 1], "%s links to %s" % [expected_chain[index], expected_chain[index + 1]])
	_check(EraRegistry.next_id(expected_chain[-1]).is_empty(), "era chain has a finite implemented end")

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
