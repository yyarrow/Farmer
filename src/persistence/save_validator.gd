extends RefCounted

const BattleSystem = preload("res://src/systems/battle_system.gd")
const EconomySystem = preload("res://src/systems/economy_system.gd")
const CityLayout = preload("res://src/data/city_layout.gd")

static func valid_number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum

static func valid_numeric_map(value: Variant, allowed_keys: Array, minimum: float, maximum: float) -> bool:
	if value is not Dictionary:
		return false
	for key in value:
		if key not in allowed_keys or not valid_number(value[key], minimum, maximum):
			return false
	return true

static func event_definition(id: String, events: Array) -> Dictionary:
	for event in events:
		if str(event.id) == id:
			return event
	return {}

static func era_definition(data: Dictionary, context: Dictionary) -> Dictionary:
	var id := str(data.get("era_id", context.default_era_id))
	return context.eras.get(id, {})

static func is_consistent_current(data: Dictionary, context: Dictionary) -> bool:
	var era := era_definition(data, context)
	if era.is_empty():
		return false
	var saved_buildings: Dictionary = era.initial_buildings.duplicate(true)
	saved_buildings.merge(data.get("buildings", {}), true)
	var built_count := 0
	if int(data.get("format_version", 1)) >= 5:
		var totals: Dictionary = era.initial_buildings.duplicate(true)
		for id in totals:
			totals[id] = 0
		var occupied := {}
		var placed: Array = []
		var instance_ids := {}
		var unique_types := {}
		var city_level := clampi(int(data.get("city_level", data.get("chapter", 1))), 1, era.city_levels.size())
		var unlocked_slots := int(era.city_levels[city_level - 1].slots)
		for instance in data.get("building_instances", []):
			var instance_id := str(instance.get("id", ""))
			var building_type := str(instance.get("type", ""))
			if not totals.has(building_type):
				return false
			if instance_id.is_empty() or instance_ids.has(instance_id):
				return false
			if int(data.get("format_version", 1)) >= 6:
				var origin := CityLayout.origin_from_value(instance.get("grid_origin", []))
				if not CityLayout.can_place(building_type, origin, placed, unlocked_slots):
					return false
				placed.append(instance)
			else:
				var slot_id := str(instance.get("slot_id", ""))
				var slot_index := -1
				for index in CityLayout.SLOTS.size():
					if str(CityLayout.SLOTS[index].id) == slot_id:
						slot_index = index
						break
				if occupied.has(slot_id) or slot_index < 0 or slot_index >= unlocked_slots:
					return false
				occupied[slot_id] = true
			if building_type in CityLayout.UNIQUE_BUILDINGS and unique_types.has(building_type):
				return false
			instance_ids[instance_id] = true
			unique_types[building_type] = true
			totals[building_type] += int(instance.level)
		built_count = instance_ids.size()
		for id in totals:
			if int(saved_buildings[id]) != int(totals[id]):
				return false
	var warehouse_level := int(saved_buildings.warehouse)
	var saved_resources: Dictionary = era.initial_resources.duplicate(true)
	saved_resources.merge(data.get("resources", {}), true)
	for id in saved_resources:
		if float(saved_resources[id]) > EconomySystem.capacity(id, warehouse_level, era.economy) + 0.001:
			return false

	var saved_units: Dictionary = era.initial_units.duplicate(true)
	saved_units.merge(data.get("units", {}), true)
	var saved_wounded: Dictionary = era.empty_units.duplicate(true)
	saved_wounded.merge(data.get("wounded", {}), true)
	var army_total := BattleSystem.sum_force(saved_units)
	var wounded_total := BattleSystem.sum_force(saved_wounded)
	var saved_population := int(data.get("population", 110))
	if saved_population < 40 or saved_population + army_total + wounded_total > EconomySystem.population_cap(int(saved_buildings.house), era.economy):
		return false
	if army_total + wounded_total > EconomySystem.army_capacity(int(saved_buildings.barracks), era.economy):
		return false

	var queued_wounded: Dictionary = era.empty_units.duplicate(true)
	var saved_day := int(data.get("current_day", 1))
	for entry in data.get("recovery_queue", []):
		if int(entry.return_day) <= saved_day:
			return false
		queued_wounded[entry.unit] += int(entry.count)
	for id in era.units:
		if int(queued_wounded[id]) != int(saved_wounded[id]):
			return false
	if int(data.get("next_attack_day", 7)) <= saved_day:
		return false
	if int(data.get("last_patrol_day", 0)) > saved_day:
		return false
	if int(data.get("patrol_delay_wave", 0)) > int(data.get("attack_wave", 1)):
		return false
	var saved_enemy: Dictionary = data.get("enemy_army", {})
	if not saved_enemy.is_empty():
		if BattleSystem.sum_force(saved_enemy) <= 0:
			return false
		if int(saved_enemy.get("wave", data.get("attack_wave", 1))) != int(data.get("attack_wave", 1)):
			return false
		if not valid_number(saved_enemy.get("tier", 1), 1.0, float(context.max_enemy_tier)):
			return false

	var saved_event: Dictionary = data.get("current_event", {})
	if not saved_event.is_empty():
		var canonical_event := event_definition(str(saved_event.get("id", "")), era.events)
		if canonical_event.is_empty() or saved_event.get("options") != canonical_event.options:
			return false
	if int(data.get("format_version", 1)) >= 4:
		var city_level := clampi(int(data.get("city_level", data.get("chapter", 1))), 1, era.city_levels.size())
		var city_data: Dictionary = era.city_levels[city_level - 1]
		if int(data.get("format_version", 1)) < 5:
			for id in saved_buildings:
				if int(saved_buildings[id]) > 0:
					built_count += 1
		if built_count > int(city_data.slots):
			return false
	return true

static func is_valid(data: Dictionary, context: Dictionary) -> bool:
	if data.is_empty() or not valid_number(data.get("format_version", 1), 1.0, float(context.format_version)):
		return false
	var format_version := int(data.get("format_version", 1))
	var era := era_definition(data, context)
	if era.is_empty():
		return false
	if format_version >= 4:
		if not data.has("era_id") or str(data.era_id) not in context.eras:
			return false
		if not valid_number(data.get("era_progress"), 0.0, float(era.era_growth.target)):
			return false
		if not valid_number(data.get("city_level", data.get("chapter")), 1.0, float(era.city_levels.size())):
			return false
	if data.has("resources") and not valid_numeric_map(data.resources, era.resource_units.keys(), 0.0, 1000000000.0):
		return false
	if data.has("buildings"):
		if data.buildings is not Dictionary:
			return false
		for id in data.buildings:
			if not era.buildings.has(id) or not valid_number(data.buildings[id], 0.0, float(era.buildings[id].max) * CityLayout.MAX_SLOTS):
				return false
	if format_version >= 5:
		if data.get("building_instances") is not Array or data.building_instances.size() > CityLayout.MAX_SLOTS:
			return false
		for instance in data.building_instances:
			if instance is not Dictionary:
				return false
			var building_type := str(instance.get("type", ""))
			if not era.buildings.has(building_type) or instance.get("id") is not String or instance.get("slot_id") is not String:
				return false
			if format_version >= 6:
				var origin = instance.get("grid_origin")
				if origin is not Array or origin.size() != 2 or not valid_number(origin[0], 0.0, float(CityLayout.GRID_SIZE.x - 1)) or not valid_number(origin[1], 0.0, float(CityLayout.GRID_SIZE.y - 1)):
					return false
			if not valid_number(instance.get("level"), 1.0, float(era.buildings[building_type].max)):
				return false
	for roster_key in ["units", "wounded"]:
		if data.has(roster_key) and not valid_numeric_map(data[roster_key], era.units.keys(), 0.0, 10000.0):
			return false
	var numeric_ranges := {
		"population": [0.0, 1000000.0],
		"morale": [0.0, 100.0],
		"current_day": [1.0, 10000000.0],
		"chapter": [1.0, float(era.city_levels.size())],
		"city_level": [1.0, float(era.city_levels.size())],
		"era_progress": [0.0, float(era.era_growth.target)],
		"day_progress": [0.0, 1.0],
		"next_attack_day": [1.0, 10000000.0],
		"attack_wave": [1.0, 10000000.0],
		"last_patrol_day": [0.0, 10000000.0],
		"patrol_delay_wave": [0.0, 10000000.0],
		"saved_at": [0.0, 100000000000.0],
	}
	for key in numeric_ranges:
		if data.has(key) and not valid_number(data[key], numeric_ranges[key][0], numeric_ranges[key][1]):
			return false
	if data.has("tutorial_seen") and data.tutorial_seen is not bool:
		return false
	if data.has("defense_order") and str(data.defense_order) not in era.defense_orders:
		return false
	if data.has("buffs") and not valid_numeric_map(data.buffs, ["farm_until", "all_until"], 0.0, 10000000.0):
		return false
	if data.has("recovery_queue"):
		if data.recovery_queue is not Array or data.recovery_queue.size() > 1000:
			return false
		for entry in data.recovery_queue:
			if entry is not Dictionary or str(entry.get("unit", "")) not in era.units:
				return false
			if not valid_number(entry.get("count"), 1.0, 10000.0) or not valid_number(entry.get("return_day"), 1.0, 10000000.0):
				return false
	if data.has("enemy_army"):
		if data.enemy_army is not Dictionary or (format_version >= int(context.format_version) and data.enemy_army.is_empty()):
			return false
		if not data.enemy_army.is_empty():
			if data.enemy_army.get("name") is not String or str(data.enemy_army.name).length() > 80:
				return false
			if not valid_numeric_map(
				{
					"militia": data.enemy_army.get("militia"),
					"archer": data.enemy_army.get("archer"),
					"chariot": data.enemy_army.get("chariot"),
				},
				["militia", "archer", "chariot"], 0.0, 10000.0
			):
				return false
			if not valid_number(data.enemy_army.get("morale"), 0.0, 100.0) or not valid_number(data.enemy_army.get("training"), 0.1, 3.0):
				return false
			if data.enemy_army.get("scouted") is not bool:
				return false
	if data.has("current_event"):
		if data.current_event is not Dictionary:
			return false
		if not data.current_event.is_empty():
			if event_definition(str(data.current_event.get("id", "")), era.events).is_empty() or data.current_event.get("options") is not Array:
				return false
			if data.current_event.get("title") is not String or str(data.current_event.title).length() > 80:
				return false
			if data.current_event.get("body") is not String or str(data.current_event.body).length() > 500:
				return false
			for option in data.current_event.options:
				if option is not String or str(option).length() > 100:
					return false
	if data.has("last_event_id"):
		if data.last_event_id is not String:
			return false
		var valid_last_ids: Array[String] = [""]
		for event in era.events:
			valid_last_ids.append(str(event.id))
		if str(data.last_event_id) not in valid_last_ids:
			return false
	if format_version >= int(context.format_version) and not is_consistent_current(data, context):
		return false
	return true
