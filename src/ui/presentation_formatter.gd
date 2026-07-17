extends RefCounted

const RESOURCE_META := {
	"grain": {"name": "粮", "glyph": "粟", "unit": "石"},
	"wood": {"name": "木", "glyph": "木", "unit": "车"},
	"stone": {"name": "石", "glyph": "石", "unit": "方"},
	"coins": {"name": "财", "glyph": "币", "unit": "枚"},
}

static func building_effect(preview: Dictionary, resource_units: Dictionary = RESOURCE_META, terms: Dictionary = {}) -> String:
	if preview.is_empty():
		return ""
	var population_name := str(terms.get("population", "民口"))
	var people_unit := str(terms.get("population_unit", "人"))
	var tax_name := str(terms.get("tax", "赋税"))
	var registry_name := str(terms.get("army_registry", "军籍"))
	var army_name := str(terms.get("army", "守军"))
	var coin_unit := str(resource_units.coins.unit)
	match str(preview.kind):
		"farm", "woodcut", "quarry":
			var unit: String = str(resource_units[str(preview.resource)].unit)
			if bool(preview.has_next):
				return "本季产出 %.1f → %.1f%s/日" % [float(preview.current), float(preview.next), unit]
			return "本季产出 %.1f%s/日" % [float(preview.current), unit]
		"house":
			if bool(preview.has_next):
				return "%s上限 %d → %d%s · %s %.1f → %.1f%s/日" % [population_name, int(preview.population_cap), int(preview.next_population_cap), people_unit, tax_name, float(preview.current), float(preview.next), coin_unit]
			return "%s上限 %d%s · %s %.1f%s/日" % [population_name, int(preview.population_cap), people_unit, tax_name, float(preview.current), coin_unit]
		"market":
			if bool(preview.has_next):
				return "%s %.1f → %.1f%s/日 · 市易价格同步改善" % [tax_name, float(preview.current), float(preview.next), coin_unit]
			return "%s %.1f%s/日 · 市易价格已达最佳" % [tax_name, float(preview.current), coin_unit]
		"warehouse":
			var grain: Dictionary = resource_units.grain
			var wood: Dictionary = resource_units.wood
			var stone: Dictionary = resource_units.stone
			var coins: Dictionary = resource_units.coins
			if bool(preview.has_next):
				return "仓容 %s%d→%d%s · %s/%s%d→%d%s · %s%d→%d%s" % [grain.short, int(preview.grain), int(preview.next_grain), grain.unit, wood.short, stone.short, int(preview.material), int(preview.next_material), wood.unit, coins.short, int(preview.coins), int(preview.next_coins), coins.unit]
			return "仓容 %s%d%s · %s/%s%d%s · %s%d%s" % [grain.short, int(preview.grain), grain.unit, wood.short, stone.short, int(preview.material), wood.unit, coins.short, int(preview.coins), coins.unit]
		"barracks":
			if bool(preview.has_next):
				return "%s %d → %d%s · 训练 +%d%% → +%d%%" % [registry_name, int(preview.capacity), int(preview.next_capacity), people_unit, int(preview.training), int(preview.next_training)]
			return "%s %d%s · 训练 +%d%%" % [registry_name, int(preview.capacity), people_unit, int(preview.training)]
		"wall":
			if bool(preview.has_next):
				return "%s承受敌方杀伤 %d%% → %d%%" % [army_name, int(preview.incoming), int(preview.next_incoming)]
			return "%s承受敌方杀伤 %d%%" % [army_name, int(preview.incoming)]
	return ""

static func cost(cost_data: Dictionary, resource_units: Dictionary = RESOURCE_META) -> String:
	var parts: Array[String] = []
	for id in ["grain", "wood", "stone", "coins"]:
		if cost_data.has(id):
			var meta: Dictionary = resource_units[id]
			parts.append("%s%d%s" % [meta.get("short", meta.get("name", id)), int(cost_data[id]), meta.unit])
	return "  ".join(parts)

static func chinese_number(value: int) -> String:
	return ["零", "一", "二", "三", "四", "五"][clampi(value, 0, 5)]

static func save_time(unix_time: float) -> String:
	var time_zone := Time.get_time_zone_from_system()
	return save_time_with_bias(unix_time, int(time_zone.get("bias", 0)))

static func save_time_with_bias(unix_time: float, utc_bias_minutes: int) -> String:
	var date := Time.get_datetime_dict_from_unix_time(int(unix_time) + utc_bias_minutes * 60)
	return "%04d-%02d-%02d  %02d:%02d" % [date.year, date.month, date.day, date.hour, date.minute]

static func event_option_caption(state: Node, id: String, index: int, base: String) -> String:
	var suffix := ""
	var amount := func(resource_id: String, value: int, sign := "") -> String:
		var meta: Dictionary = state.RESOURCE_UNITS[resource_id]
		return "%s%s%d%s" % [meta.short, sign, value, meta.unit]
	match id:
		"drought":
			var drought_relief := mini(45, floori(state.resources.grain))
			suffix = " · %s %s" % [amount.call("wood", 28), amount.call("stone", 18)] if index == 0 else " · %s 民心%s" % [amount.call("grain", drought_relief, "-"), "+4" if drought_relief == 45 else "-4"]
		"refugees":
			var refugee_relief := mini(28, floori(state.resources.grain))
			suffix = " · %s，%s+20" % [amount.call("grain", 58), state.term("population", "民口")] if index == 0 else " · %s 民心%s" % [amount.call("grain", refugee_relief, "-"), "+2" if refugee_relief == 28 else "-3"]
		"merchant":
			if index == 0: suffix = " · %s" % amount.call("coins", 720)
			elif index == 1: suffix = " · %s %s" % [amount.call("grain", 75, "-"), amount.call("coins", 620, "+")]
		"scouts": suffix = " · %s，探明并袭扰敌军" % amount.call("coins", 320) if index == 0 else " · 敌军延误一日"
		"harvest": suffix = " · %s最多+105%s" % [state.RESOURCE_UNITS.grain.short, state.RESOURCE_UNITS.grain.unit] if index == 0 else " · %s最多+42%s 民心+15" % [state.RESOURCE_UNITS.grain.short, state.RESOURCE_UNITS.grain.unit]
		"flood": suffix = " · %s %s，农田增产3日" % [amount.call("wood", 30), amount.call("stone", 18)] if index == 0 else " · %s 民心-4" % amount.call("grain", mini(60, floori(state.resources.grain)), "-")
		"winter_relief": suffix = " · %s 民心+10" % amount.call("grain", 42) if index == 0 else " · 民心-5"
		"craftsmen": suffix = " · %s %s，全邑增产3日" % [amount.call("coins", 480), amount.call("wood", 16)] if index == 0 else " · %s最多+28%s 民心-3" % [state.RESOURCE_UNITS.stone.short, state.RESOURCE_UNITS.stone.unit]
		"rumors": suffix = " · %s，探明敌军 民心+5" % amount.call("coins", 200) if index == 0 else " · 民心-6"
		"levy": suffix = " · %s %s 民心+3" % [amount.call("grain", 45), amount.call("coins", 220)] if index == 0 else " · 敌军提前1日 民心-4"
	return base + suffix

static func battle_breakdown(result: Dictionary, unit_definitions: Dictionary) -> String:
	if not result.has("player_losses_by_type") or not result.has("enemy_losses_by_type"):
		return ""
	var player_parts: Array[String] = []
	for id in unit_definitions:
		var before := int(result.player_before.get(id, 0))
		var dead := int(result.killed.get(id, 0))
		var injured := int(result.wounded.get(id, 0))
		if before > 0 or dead + injured > 0:
			player_parts.append("%s %d亡 %d伤 %d余" % [unit_definitions[id].name, dead, injured, int(result.player_survivors.get(id, 0))])
	var enemy_parts: Array[String] = []
	for id in unit_definitions:
		var before := int(result.enemy_before.get(id, 0))
		var lost := int(result.enemy_losses_by_type.get(id, 0))
		if before > 0 or lost > 0:
			enemy_parts.append("%s %d损 %d余" % [unit_definitions[id].get("enemy_name", unit_definitions[id].name), lost, int(result.enemy_survivors.get(id, 0))])
	var player_text := " · ".join(player_parts.slice(0, 2))
	if player_parts.size() > 2:
		player_text += "\n　　　" + " · ".join(player_parts.slice(2))
	return "我军：" + player_text + "\n敌军：" + " · ".join(enemy_parts)
