extends RefCounted

# Stable simulation IDs stay in code and saves. Everything a player reads can
# be replaced by an era definition without duplicating UI logic.
const DEFAULT_TERMS := {
	"population": "民口",
	"population_unit": "人",
	"residents": "居民",
	"army": "守军",
	"army_registry": "军籍",
	"wounded": "伤员",
	"civilian_food": "百姓口粮",
	"army_food": "军籍粮秣",
	"army_pay": "军饷",
	"wounded_food": "伤员养护",
	"wounded_care": "伤员医药",
	"tax": "赋税",
	"farm_yield": "农收",
	"wood_yield": "轮伐",
	"stone_yield": "开采",
	"ledger_title": "邑中账簿",
	"ledger_desc": "所有生产、民食、军粮与军饷按日公开结算",
	"market_title": "陶朱之市",
	"market_desc": "市集等级越高价格越有利；仓容不足时整笔不成交、不扣款",
	"military_title": "戎车既饬",
	"military_desc": "军籍、军粮、伤员、辎重与来敌编成均可追溯",
	"enemy_intel": "来敌军情",
	"battle_forecast": "守城推演",
	"roster": "军籍与伤营",
	"defense_order": "守城阵令",
	"patrol_name": "出城巡剿",
	"patrol_action": "出征",
	"recruit_action": "征募",
	"recruit_verb": "征募",
	"build_tab": "城建",
	"trade_tab": "市易",
	"military_tab": "军务",
	"governance_tab": "政事",
	"build_action": "建造",
	"upgrade_action": "升级",
	"governance_title": "邑宰案牍",
	"governance_desc": "城池规模与时代积累分别成长，发展和征战共同推动新制",
	"era_progress": "时代积累",
	"day_ledger": "日账",
	"victory_title": "城头凯歌",
	"defeat_title": "烽火入郭",
	"provisions": "军粮",
	"pay": "军饷",
}

const DEFAULT_LOGISTICS := {
	"name": "辎重转输",
	"unit": "载",
	"desc": "仓廪与材场决定运输承载；超载会降低守军训练效能",
	"base_capacity": 42.0,
	"warehouse_capacity": 24.0,
	"woodcut_capacity": 8.0,
	"market_capacity": 4.0,
	"load": {"militia": 1.0, "archer": 1.25, "chariot": 2.4},
	"patrol_cost": {"grain": 6, "coins": 40},
	"patrol_minimum": 10,
	"ready": "转输从容",
	"strained": "转输吃紧",
	"critical": "辎重超载",
}

const DEFAULT_ECONOMY := {
	"production": {"grain": 1.0, "wood": 1.0, "stone": 1.0, "coins": 1.0},
	"grain_capacity_base": 1200.0,
	"grain_capacity_per_warehouse": 800.0,
	"material_capacity_base": 350.0,
	"material_capacity_per_warehouse": 250.0,
	"coins_capacity_base": 5000.0,
	"coins_capacity_per_warehouse": 2500.0,
	"population_base": 90,
	"population_per_house": 60,
	"army_base": 25,
	"army_per_barracks": 20,
}

const DEFAULT_TRADE_LABELS := {
	"sell_grain": "粟米出仓",
	"buy_grain": "购入军粮",
	"sell_wood": "木材发卖",
	"buy_stone": "商队运石",
	"action": "交易",
}

const DEFAULT_POLICIES := {
	"irrigate": {"name": "兴修水利", "effect": "三日粮秣增产35%", "glyph": "渠", "notice": "水利修成：三日内粮秣增产"},
	"tax_relief": {"name": "轻徭薄赋", "effect": "民口与民心上升", "glyph": "民", "notice": "轻徭薄赋：民心与民口上升"},
	"reward_army": {"name": "犒赏三军", "effect": "民心上升，伤员提前归队", "glyph": "赏", "notice": "犒赏三军：士气大振，伤员恢复加快"},
}

const DEFAULT_NARRATIVE := {
	"transition": "青禾保留既有城池、人口、资源和军队规模，同时启用新时期的兵种、城建、阵令、度量与来敌配置。",
}

const DEFAULT_BATTLE_PACING := {
	"attack_interval_bonus": 0,
	"post_defeat_bonus": 2,
}

static func normalize(raw: Dictionary) -> Dictionary:
	var result := raw.duplicate(true)
	result["terms"] = _with_defaults(DEFAULT_TERMS, raw.get("terms", {}))
	result["logistics"] = _with_defaults(DEFAULT_LOGISTICS, raw.get("logistics", {}))
	result["economy"] = _with_defaults(DEFAULT_ECONOMY, raw.get("economy", {}))
	result["trade_labels"] = _with_defaults(DEFAULT_TRADE_LABELS, raw.get("trade_labels", {}))
	result["policies"] = _with_defaults(DEFAULT_POLICIES, raw.get("policies", {}))
	result["narrative"] = _with_defaults(DEFAULT_NARRATIVE, raw.get("narrative", {}))
	result["battle_pacing"] = _with_defaults(DEFAULT_BATTLE_PACING, raw.get("battle_pacing", {}))
	return result

static func _with_defaults(defaults: Dictionary, overrides: Dictionary) -> Dictionary:
	var result := defaults.duplicate(true)
	for key in overrides:
		if result.get(key) is Dictionary and overrides[key] is Dictionary:
			result[key] = _with_defaults(result[key], overrides[key])
		else:
			result[key] = overrides[key]
	return result
