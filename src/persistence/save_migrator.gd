extends RefCounted

static func upgrade(
	data: Dictionary,
	format_version: int,
	unit_definitions: Dictionary,
	empty_units: Dictionary,
	enemy_factory: Callable
) -> Dictionary:
	var upgraded := data.duplicate(true)
	var from_version := int(upgraded.get("format_version", 1))
	if from_version >= format_version:
		return {"data": upgraded, "migrated": false, "from": from_version}
	var old_resources: Dictionary = upgraded.get("resources", {}).duplicate(true)
	old_resources.grain = float(old_resources.get("grain", 180.0)) * 2.0
	old_resources.coins = float(old_resources.get("coins", 150.0)) * 10.0
	upgraded.resources = old_resources
	var old_units: Dictionary = upgraded.get("units", {}).duplicate(true)
	for id in unit_definitions:
		old_units[id] = int(old_units.get(id, 0)) * 5
	upgraded.units = old_units
	upgraded.population = int(upgraded.get("population", 22)) * 5
	upgraded.wounded = empty_units.duplicate(true)
	upgraded.recovery_queue = []
	upgraded.attack_wave = maxi(1, int(upgraded.get("chapter", 1)))
	upgraded.enemy_army = enemy_factory.call(int(upgraded.attack_wave))
	upgraded.last_patrol_day = 0
	upgraded.patrol_delay_wave = 0
	upgraded.format_version = format_version
	return {"data": upgraded, "migrated": true, "from": from_version}
