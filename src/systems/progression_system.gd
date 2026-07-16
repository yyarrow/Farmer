extends RefCounted

static func prosperity(building_levels: Dictionary, population: int, army_count: int, city_tier: int) -> int:
	var building_score := 0
	for id in building_levels:
		building_score += int(building_levels[id]) * 10
	return building_score + roundi(population / 5.0) + army_count + city_tier * 10

static func city_tier_target(city_tier: int) -> int:
	return 150 + (city_tier - 1) * 95
