extends RefCounted

const SpringAutumn = preload("res://src/data/eras/spring_autumn.gd")

const ID := "warring_states"
const DISPLAY_NAME := "战国"
const NEXT_ID := "qin"

const CITY_LEVELS := [
	{"level": 1, "name": "县聚", "slots": 6, "advance_target": 190, "view_scale": 1.00},
	{"level": 2, "name": "戍邑", "slots": 9, "advance_target": 300, "view_scale": 1.08},
	{"level": 3, "name": "县城", "slots": 12, "advance_target": 420, "view_scale": 1.16},
	{"level": 4, "name": "郡治", "slots": 12, "advance_target": 555, "view_scale": 1.24},
	{"level": 5, "name": "雄城", "slots": 12, "advance_target": 700, "view_scale": 1.32},
]

const ERA_GROWTH := {
	"target": 1400,
	"minimum_city_level": 5,
	"daily": 5,
	"building_base": 16,
	"city_level": 80,
	"battle_victory": 66,
	"patrol_victory": 12,
}

const VISUAL := {"tint": Color("#fff4e4"), "background": "res://assets/art/city_warring_states_terrain.png", "map_hint": "战国城郭已扩展，可左右拖动巡视自由营造区", "identity": {"earth": Color(0.37, 0.24, 0.17, 0.66), "standard": Color("#963e35"), "motif": "rammed_earth"}}
const SEASONS := SpringAutumn.SEASONS

const RESOURCE_UNITS := {
	"grain": {"name": "军粮", "short": "粮", "unit": "石", "glyph": "粟"},
	"wood": {"name": "材木", "short": "木", "unit": "车", "glyph": "木"},
	"stone": {"name": "版筑料", "short": "筑", "unit": "方", "glyph": "石"},
	"coins": {"name": "刀布财", "short": "币", "unit": "枚", "glyph": "布"},
}

const BUILDINGS := {
	"farm": {"name": "阡陌", "glyph": "田", "desc": "推行阡陌与水利，供应常备军粮", "max": 5, "base": {"wood": 42, "stone": 16, "coins": 240}},
	"woodcut": {"name": "材官署", "glyph": "木", "desc": "统筹山林材木，供应车械与版筑", "max": 5, "base": {"grain": 28, "stone": 14, "coins": 290}},
	"quarry": {"name": "版筑场", "glyph": "筑", "desc": "烧制夯土与石料，扩建战国城郭", "max": 5, "base": {"grain": 38, "wood": 30, "coins": 360}},
	"house": {"name": "闾里", "glyph": "闾", "desc": "编户齐民，提高民口与赋税基础", "max": 5, "base": {"wood": 52, "stone": 24, "coins": 330}},
	"market": {"name": "互市", "glyph": "市", "desc": "汇集刀布与商旅，改善财货交换", "max": 5, "base": {"wood": 58, "stone": 28, "coins": 440}},
	"warehouse": {"name": "府库", "glyph": "府", "desc": "分仓储备军粮、材木与刀布财", "max": 5, "base": {"wood": 50, "stone": 38, "coins": 280}},
	"barracks": {"name": "武备营", "glyph": "武", "desc": "训练甲士、劲弩与轻骑，扩充军籍", "max": 5, "base": {"grain": 70, "wood": 68, "stone": 34, "coins": 620}},
	"wall": {"name": "夯土城", "glyph": "城", "desc": "以版筑加固城郭，压低守军伤亡", "max": 5, "base": {"grain": 38, "wood": 74, "stone": 92, "coins": 680}},
}

const UNITS := {
	"militia": {"name": "甲士", "enemy_name": "甲兵", "glyph": "甲", "batch": 5, "need": 0, "power": 1.18, "ranged": 0.0, "melee": 1.18, "exposure": 0.88, "cost": {"grain": 11, "coins": 180}, "grain_daily": 0.12, "coins_daily": 0.58},
	"archer": {"name": "劲弩士", "enemy_name": "弩手", "glyph": "弩", "batch": 5, "need": 2, "power": 1.72, "ranged": 2.2, "melee": 0.62, "exposure": 0.56, "cost": {"grain": 16, "wood": 11, "coins": 430}, "grain_daily": 0.15, "coins_daily": 1.05},
	"chariot": {"name": "轻骑", "enemy_name": "骑卒", "glyph": "骑", "batch": 5, "need": 3, "power": 2.48, "ranged": 0.0, "melee": 2.48, "exposure": 0.43, "cost": {"grain": 25, "wood": 10, "stone": 4, "coins": 820}, "grain_daily": 0.28, "coins_daily": 2.45},
}

const DEFENSE_ORDERS := {
	"steady": {"name": "中军", "glyph": "中", "desc": "军阵持中，杀伤与战损均无修正", "incoming": 1.00, "ranged": 1.00, "melee": 1.00},
	"fortify": {"name": "坚阵", "glyph": "盾", "desc": "敌方杀伤-18%，我方远射-10%、近战-18%", "incoming": 0.82, "ranged": 0.90, "melee": 0.82},
	"volley": {"name": "弩阵", "glyph": "弩", "desc": "劲弩远射+36%，近战-14%，敌方杀伤+5%", "incoming": 1.05, "ranged": 1.36, "melee": 0.86},
	"sally": {"name": "锐阵", "glyph": "锐", "desc": "近战杀伤+24%，远射-14%，敌方杀伤+18%", "incoming": 1.18, "ranged": 0.86, "melee": 1.24},
}

const ENEMY_WAVES := [
	{"name": "边邑甲兵", "militia": 48, "archer": 18, "chariot": 5, "morale": 64.0, "training": 1.04},
	{"name": "变法新军", "militia": 54, "archer": 22, "chariot": 5, "morale": 68.0, "training": 1.08},
	{"name": "合纵偏师", "militia": 60, "archer": 26, "chariot": 10, "morale": 72.0, "training": 1.12},
	{"name": "连横锐卒", "militia": 68, "archer": 32, "chariot": 10, "morale": 76.0, "training": 1.16},
	{"name": "强国武卒", "militia": 76, "archer": 36, "chariot": 15, "morale": 80.0, "training": 1.20},
	{"name": "诸侯会战军", "militia": 86, "archer": 42, "chariot": 15, "morale": 84.0, "training": 1.24},
]

const EVENTS := SpringAutumn.EVENTS

const TERMS := {
	"population": "编户",
	"army": "县卒",
	"army_registry": "军籍",
	"army_food": "军粮",
	"army_pay": "军饷",
	"tax": "赋入",
	"ledger_title": "府库计簿",
	"market_title": "刀布互市",
	"military_title": "武备整军",
	"patrol_name": "出郭巡边",
	"governance_title": "县廷治事",
	"build_tab": "营城", "trade_tab": "互市", "military_tab": "武备", "governance_tab": "县政",
	"era_progress": "兼并之势",
}

const LOGISTICS := {
	"name": "辎车转运",
	"desc": "府库、材官署与互市共同支撑辎车；轻骑与劲弩所需转运更重",
	"base_capacity": 48.0,
	"warehouse_capacity": 27.0,
	"woodcut_capacity": 9.0,
	"market_capacity": 5.0,
	"load": {"militia": 1.0, "archer": 1.35, "chariot": 2.1},
	"patrol_cost": {"grain": 7, "coins": 55},
}
const ECONOMY := {"production": {"grain": 1.04, "wood": 1.05, "stone": 1.06, "coins": 1.05}, "army_base": 27, "army_per_barracks": 21, "population_base": 95, "population_per_house": 62}

const TRADE_LABELS := {"sell_grain": "军粮出廪", "buy_grain": "商旅籴粮", "sell_wood": "材木发卖", "buy_stone": "购入版筑料", "action": "互市"}
const POLICIES := {
	"irrigate": {"name": "修治沟洫", "effect": "三日军粮增产35%", "glyph": "洫"},
	"tax_relief": {"name": "宽赋安民", "effect": "编户与民心上升", "glyph": "户"},
	"reward_army": {"name": "飨士厉兵", "effect": "民心上升，伤卒提前归队", "glyph": "飨"},
}
const NARRATIVE := {"transition": "诸侯兼并，县邑军政日益严密。青禾保留旧有规模，改用战国编户、武备、刀布互市与辎车转运之制。"}

static func initial_resources() -> Dictionary:
	return {"grain": 420.0, "wood": 150.0, "stone": 100.0, "coins": 1800.0}

static func initial_buildings() -> Dictionary:
	return SpringAutumn.initial_buildings()

static func initial_units() -> Dictionary:
	return {"militia": 25, "archer": 5, "chariot": 0}

static func empty_units() -> Dictionary:
	return {"militia": 0, "archer": 0, "chariot": 0}

static func definition() -> Dictionary:
	return {
		"id": ID,
		"display_name": DISPLAY_NAME,
		"next_id": NEXT_ID,
		"city_levels": CITY_LEVELS,
		"era_growth": ERA_GROWTH,
		"visual": VISUAL,
		"seasons": SEASONS,
		"resource_units": RESOURCE_UNITS,
		"buildings": BUILDINGS,
		"units": UNITS,
		"defense_orders": DEFENSE_ORDERS,
		"enemy_waves": ENEMY_WAVES,
		"events": EVENTS,
		"terms": TERMS,
		"logistics": LOGISTICS,
		"economy": ECONOMY,
		"trade_labels": TRADE_LABELS,
		"policies": POLICIES,
		"narrative": NARRATIVE,
		"initial_resources": initial_resources(),
		"initial_buildings": initial_buildings(),
		"initial_units": initial_units(),
		"empty_units": empty_units(),
	}
