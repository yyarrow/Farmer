extends RefCounted

const CityLayout = preload("res://src/data/city_layout.gd")

static func upgrade(
	data: Dictionary,
	format_version: int,
	default_era_id: String,
	default_era: Dictionary
) -> Dictionary:
	var upgraded := data.duplicate(true)
	var from_version := int(upgraded.get("format_version", 1))
	if from_version >= format_version:
		return {"data": upgraded, "migrated": false, "from": from_version}
	if from_version < 3:
		var old_resources: Dictionary = upgraded.get("resources", {}).duplicate(true)
		old_resources.grain = float(old_resources.get("grain", 180.0)) * 2.0
		old_resources.coins = float(old_resources.get("coins", 150.0)) * 10.0
		upgraded.resources = old_resources
		var old_units: Dictionary = upgraded.get("units", {}).duplicate(true)
		for id in default_era.units:
			old_units[id] = int(old_units.get(id, 0)) * 5
		upgraded.units = old_units
		upgraded.population = int(upgraded.get("population", 22)) * 5
		upgraded.wounded = default_era.empty_units.duplicate(true)
		upgraded.recovery_queue = []
		upgraded.attack_wave = maxi(1, int(upgraded.get("chapter", 1)))
		upgraded.enemy_army = _legacy_enemy_army(int(upgraded.attack_wave), default_era)
		upgraded.last_patrol_day = 0
		upgraded.patrol_delay_wave = 0
	if from_version < 4:
		if upgraded.get("enemy_army", {}).is_empty():
			upgraded.enemy_army = _legacy_enemy_army(int(upgraded.get("attack_wave", 1)), default_era)
		var city_level := clampi(int(upgraded.get("chapter", 1)), 1, default_era.city_levels.size())
		var building_levels := 0
		var built_count := 0
		for level in upgraded.get("buildings", {}).values():
			building_levels += int(level)
			if int(level) > 0:
				built_count += 1
		while city_level < default_era.city_levels.size() and int(default_era.city_levels[city_level - 1].slots) < built_count:
			city_level += 1
		var estimated_progress := (
			maxi(0, int(upgraded.get("current_day", 1)) - 1) * int(default_era.era_growth.daily)
			+ building_levels * int(default_era.era_growth.building_base)
			+ maxi(0, city_level - 1) * int(default_era.era_growth.city_level)
			+ maxi(0, int(upgraded.get("attack_wave", 1)) - 1) * int(default_era.era_growth.battle_victory)
		)
		upgraded.era_id = default_era_id
		upgraded.era_progress = mini(int(default_era.era_growth.target), estimated_progress)
		upgraded.city_level = city_level
		upgraded.chapter = city_level
	if from_version < 5:
		var instances := []
		var slot_index := 0
		var saved_buildings: Dictionary = upgraded.get("buildings", {})
		for building_type in saved_buildings:
			var level := int(saved_buildings[building_type])
			if level <= 0 or slot_index >= CityLayout.MAX_SLOTS:
				continue
			instances.append({
				"id": "building_%04d" % (slot_index + 1),
				"type": str(building_type),
				"level": level,
				"slot_id": str(CityLayout.SLOTS[slot_index].id),
			})
			slot_index += 1
		upgraded.building_instances = instances
	upgraded.format_version = format_version
	return {"data": upgraded, "migrated": true, "from": from_version}

static func _legacy_enemy_army(wave: int, era: Dictionary) -> Dictionary:
	var index := clampi(wave - 1, 0, era.enemy_waves.size() - 1)
	var army: Dictionary = era.enemy_waves[index].duplicate(true)
	army.tier = index + 1
	army.wave = wave
	army.scouted = false
	return army
