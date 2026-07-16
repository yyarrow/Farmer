extends RefCounted

static func daily_ledger(
	season: Dictionary,
	building_levels: Dictionary,
	civilian_population: int,
	units: Dictionary,
	wounded_count: int,
	current_day: int,
	buffs: Dictionary,
	unit_definitions: Dictionary
) -> Dictionary:
	var all_bonus := 1.22 if current_day <= int(buffs.get("all_until", 0)) else 1.0
	var farm_bonus := 1.35 if current_day <= int(buffs.get("farm_until", 0)) else 1.0
	var market_level := int(building_levels.get("market", 0))
	var market_bonus := 1.0 + market_level * 0.08
	var grain_income: float = 20.0 * int(building_levels.get("farm", 0)) * farm_bonus * all_bonus * float(season.grain)
	var wood_income: float = 9.0 * int(building_levels.get("woodcut", 0)) * all_bonus * float(season.wood)
	var stone_income: float = 6.0 * int(building_levels.get("quarry", 0)) * all_bonus * float(season.stone)
	var tax_income: float = (35.0 * int(building_levels.get("house", 0)) + 55.0 * market_level + civilian_population * 0.25) * market_bonus * all_bonus * float(season.coins)
	var civilian_food := civilian_population / 15.0 * float(season.food)
	var army_food := 0.0
	var army_pay := 0.0
	for id in unit_definitions:
		army_food += int(units.get(id, 0)) * float(unit_definitions[id].grain_daily)
		army_pay += int(units.get(id, 0)) * float(unit_definitions[id].coins_daily)
	var wounded_food := wounded_count * 0.08
	var wounded_care := wounded_count * 0.30
	return {
		"grain": {"income": grain_income, "expense": civilian_food + army_food + wounded_food, "net": grain_income - civilian_food - army_food - wounded_food, "details": [["%s季农收 ×%.2f" % [season.name, season.grain], grain_income], ["百姓口粮 ×%.2f" % season.food, -civilian_food], ["军籍粮秣", -army_food], ["伤员养护", -wounded_food]]},
		"wood": {"income": wood_income, "expense": 0.0, "net": wood_income, "details": [["%s季轮伐 ×%.2f" % [season.name, season.wood], wood_income]]},
		"stone": {"income": stone_income, "expense": 0.0, "net": stone_income, "details": [["%s季开采 ×%.2f" % [season.name, season.stone], stone_income]]},
		"coins": {"income": tax_income, "expense": army_pay + wounded_care, "net": tax_income - army_pay - wounded_care, "details": [["%s季赋税 ×%.2f" % [season.name, season.coins], tax_income], ["军饷", -army_pay], ["伤员医药", -wounded_care]]},
	}

static func capacity(resource_id: String, warehouse_level: int) -> float:
	match resource_id:
		"grain": return 1200.0 + warehouse_level * 800.0
		"wood", "stone": return 350.0 + warehouse_level * 250.0
		"coins": return 5000.0 + warehouse_level * 2500.0
	return 1000.0

static func population_cap(house_level: int) -> int:
	return 90 + house_level * 60

static func army_capacity(barracks_level: int) -> int:
	return 25 + barracks_level * 20

static func building_cost(definition: Dictionary, level: int) -> Dictionary:
	var scale := pow(1.55, level)
	var out := {}
	for key in definition.base:
		out[key] = ceili(float(definition.base[key]) * scale)
	return out

static func trade_quote(kind: String, market_level: int) -> Dictionary:
	match kind:
		"sell_grain": return {"cost": {"grain": 55}, "gain": {"coins": 340 + market_level * 30}}
		"buy_grain": return {"cost": {"coins": maxi(340, 460 - market_level * 20)}, "gain": {"grain": 55}}
		"sell_wood": return {"cost": {"wood": 40}, "gain": {"coins": 300 + market_level * 20}}
		"buy_stone": return {"cost": {"coins": maxi(380, 500 - market_level * 20)}, "gain": {"stone": 35}}
	return {}
