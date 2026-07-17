extends RefCounted

static func daily_ledger(
	season: Dictionary,
	building_levels: Dictionary,
	civilian_population: int,
	units: Dictionary,
	wounded_count: int,
	current_day: int,
	buffs: Dictionary,
	unit_definitions: Dictionary,
	terms: Dictionary = {},
	economy: Dictionary = {}
) -> Dictionary:
	var all_bonus := 1.22 if current_day <= int(buffs.get("all_until", 0)) else 1.0
	var farm_bonus := 1.35 if current_day <= int(buffs.get("farm_until", 0)) else 1.0
	var market_level := int(building_levels.get("market", 0))
	var market_bonus := 1.0 + market_level * 0.08
	var production: Dictionary = economy.get("production", {})
	var grain_income: float = 20.0 * float(production.get("grain", 1.0)) * int(building_levels.get("farm", 0)) * farm_bonus * all_bonus * float(season.grain)
	var wood_income: float = 9.0 * float(production.get("wood", 1.0)) * int(building_levels.get("woodcut", 0)) * all_bonus * float(season.wood)
	var stone_income: float = 6.0 * float(production.get("stone", 1.0)) * int(building_levels.get("quarry", 0)) * all_bonus * float(season.stone)
	var tax_income: float = (35.0 * int(building_levels.get("house", 0)) + 55.0 * market_level + civilian_population * 0.25) * float(production.get("coins", 1.0)) * market_bonus * all_bonus * float(season.coins)
	var civilian_food := civilian_population / 15.0 * float(season.food)
	var army_food := 0.0
	var army_pay := 0.0
	for id in unit_definitions:
		army_food += int(units.get(id, 0)) * float(unit_definitions[id].grain_daily)
		army_pay += int(units.get(id, 0)) * float(unit_definitions[id].coins_daily)
	var wounded_food := wounded_count * 0.08
	var wounded_care := wounded_count * 0.30
	var label := func(key: String, fallback: String) -> String: return str(terms.get(key, fallback))
	return {
		"grain": {"income": grain_income, "expense": civilian_food + army_food + wounded_food, "net": grain_income - civilian_food - army_food - wounded_food, "details": [["%s季%s ×%.2f" % [season.name, label.call("farm_yield", "农收"), season.grain], grain_income], ["%s ×%.2f" % [label.call("civilian_food", "百姓口粮"), season.food], -civilian_food], [label.call("army_food", "军籍粮秣"), -army_food], [label.call("wounded_food", "伤员养护"), -wounded_food]]},
		"wood": {"income": wood_income, "expense": 0.0, "net": wood_income, "details": [["%s季%s ×%.2f" % [season.name, label.call("wood_yield", "轮伐"), season.wood], wood_income]]},
		"stone": {"income": stone_income, "expense": 0.0, "net": stone_income, "details": [["%s季%s ×%.2f" % [season.name, label.call("stone_yield", "开采"), season.stone], stone_income]]},
		"coins": {"income": tax_income, "expense": army_pay + wounded_care, "net": tax_income - army_pay - wounded_care, "details": [["%s季%s ×%.2f" % [season.name, label.call("tax", "赋税"), season.coins], tax_income], [label.call("army_pay", "军饷"), -army_pay], [label.call("wounded_care", "伤员医药"), -wounded_care]]},
	}

static func capacity(resource_id: String, warehouse_level: int, economy: Dictionary = {}) -> float:
	match resource_id:
		"grain": return float(economy.get("grain_capacity_base", 1200.0)) + warehouse_level * float(economy.get("grain_capacity_per_warehouse", 800.0))
		"wood", "stone": return float(economy.get("material_capacity_base", 350.0)) + warehouse_level * float(economy.get("material_capacity_per_warehouse", 250.0))
		"coins": return float(economy.get("coins_capacity_base", 5000.0)) + warehouse_level * float(economy.get("coins_capacity_per_warehouse", 2500.0))
	return 1000.0

static func population_cap(house_level: int, economy: Dictionary = {}) -> int:
	return int(economy.get("population_base", 90)) + house_level * int(economy.get("population_per_house", 60))

static func army_capacity(barracks_level: int, economy: Dictionary = {}) -> int:
	return int(economy.get("army_base", 25)) + barracks_level * int(economy.get("army_per_barracks", 20))

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
