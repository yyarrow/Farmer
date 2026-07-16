extends RefCounted

const RESOURCE_META := {
	"grain": {"name": "粮", "glyph": "粟", "unit": "石"},
	"wood": {"name": "木", "glyph": "木", "unit": "车"},
	"stone": {"name": "石", "glyph": "石", "unit": "方"},
	"coins": {"name": "财", "glyph": "币", "unit": "枚"},
}

static func building_effect(preview: Dictionary, resource_units: Dictionary = RESOURCE_META) -> String:
	if preview.is_empty():
		return ""
	match str(preview.kind):
		"farm", "woodcut", "quarry":
			var unit: String = str(resource_units[str(preview.resource)].unit)
			if bool(preview.has_next):
				return "本季产出 %.1f → %.1f%s/日" % [float(preview.current), float(preview.next), unit]
			return "本季产出 %.1f%s/日" % [float(preview.current), unit]
		"house":
			if bool(preview.has_next):
				return "民口上限 %d → %d人 · 赋税 %.1f → %.1f枚/日" % [int(preview.population_cap), int(preview.next_population_cap), float(preview.current), float(preview.next)]
			return "民口上限 %d人 · 赋税 %.1f枚/日" % [int(preview.population_cap), float(preview.current)]
		"market":
			if bool(preview.has_next):
				return "赋税 %.1f → %.1f枚/日 · 市易价格同步改善" % [float(preview.current), float(preview.next)]
			return "赋税 %.1f枚/日 · 市易价格已达最佳" % float(preview.current)
		"warehouse":
			if bool(preview.has_next):
				return "仓容 粮%d→%d石 · 木石%d→%d · 财%d→%d枚" % [int(preview.grain), int(preview.next_grain), int(preview.material), int(preview.next_material), int(preview.coins), int(preview.next_coins)]
			return "仓容 粮%d石 · 木石%d · 财%d枚" % [int(preview.grain), int(preview.material), int(preview.coins)]
		"barracks":
			if bool(preview.has_next):
				return "军籍 %d → %d人 · 训练 +%d%% → +%d%%" % [int(preview.capacity), int(preview.next_capacity), int(preview.training), int(preview.next_training)]
			return "军籍 %d人 · 训练 +%d%%" % [int(preview.capacity), int(preview.training)]
		"wall":
			if bool(preview.has_next):
				return "守军承受敌方杀伤 %d%% → %d%%" % [int(preview.incoming), int(preview.next_incoming)]
			return "守军承受敌方杀伤 %d%%" % int(preview.incoming)
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
	match id:
		"drought":
			var drought_relief := mini(45, floori(state.resources.grain))
			suffix = " · 木28车 石18方" if index == 0 else " · 粮-%d石 民心%s" % [drought_relief, "+4" if drought_relief == 45 else "-4"]
		"refugees":
			var refugee_relief := mini(28, floori(state.resources.grain))
			suffix = " · 粮58石，民口+20" if index == 0 else " · 粮-%d石 民心%s" % [refugee_relief, "+2" if refugee_relief == 28 else "-3"]
		"merchant":
			if index == 0: suffix = " · 财720枚"
			elif index == 1: suffix = " · 粮-75石 财+620枚"
		"scouts": suffix = " · 财320枚，探明并袭扰敌军" if index == 0 else " · 敌军延误一日"
		"harvest": suffix = " · 粮最多+105石" if index == 0 else " · 粮最多+42石 民心+15"
		"flood": suffix = " · 木30车 石18方，农田增产3日" if index == 0 else " · 粮-%d石 民心-4" % mini(60, floori(state.resources.grain))
		"winter_relief": suffix = " · 粮42石 民心+10" if index == 0 else " · 民心-5"
		"craftsmen": suffix = " · 财480枚 木16车，全邑增产3日" if index == 0 else " · 石最多+28方 民心-3"
		"rumors": suffix = " · 财200枚，探明敌军 民心+5" if index == 0 else " · 民心-6"
		"levy": suffix = " · 粮45石 财220枚 民心+3" if index == 0 else " · 敌军提前1日 民心-4"
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
