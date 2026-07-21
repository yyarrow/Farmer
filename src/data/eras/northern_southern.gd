extends RefCounted

const SpringAutumn = preload("res://src/data/eras/spring_autumn.gd")

const ID := "northern_southern"
const DISPLAY_NAME := "南北朝"
const NEXT_ID := "sui"

const CITY_LEVELS := [
	{"level": 1, "name": "三长里", "slots": 6, "advance_target": 390, "view_scale": 1.00},
	{"level": 2, "name": "镇戍县", "slots": 9, "advance_target": 600, "view_scale": 1.11},
	{"level": 3, "name": "州镇", "slots": 12, "advance_target": 825, "view_scale": 1.22},
	{"level": 4, "name": "军府城", "slots": 12, "advance_target": 1065, "view_scale": 1.32},
	{"level": 5, "name": "南北雄镇", "slots": 12, "advance_target": 1320, "view_scale": 1.42},
]

const ERA_GROWTH := {"target": 2700, "minimum_city_level": 5, "daily": 10, "building_base": 27, "city_level": 140, "battle_victory": 106, "patrol_victory": 22}
const VISUAL := {"tint": Color("#dce7e4"), "background": "res://assets/art/terrain_only/city_northern_southern_terrain_only.png", "map_hint": "北朝镇城纵深开阔，可左右拖动巡视均田、关市、镇仓与军府马苑", "identity": {"earth": Color(0.43, 0.34, 0.24, 0.70), "standard": Color("#a0523c"), "motif": "cataphract"}}
const SEASONS := SpringAutumn.SEASONS

const RESOURCE_UNITS := {
	"grain": {"name": "租粟", "short": "粟", "unit": "斛", "glyph": "租"},
	"wood": {"name": "营造材", "short": "材", "unit": "车", "glyph": "材"},
	"stone": {"name": "镇城砖", "short": "砖", "unit": "方", "glyph": "镇"},
	"coins": {"name": "永安五铢", "short": "钱", "unit": "枚", "glyph": "安"},
}

const BUILDINGS := {
	"farm": {"name": "均田渠陌", "glyph": "均", "desc": "按户口授田、修治渠陌，征收租粟供给边镇", "max": 5, "base": {"wood": 82, "stone": 36, "coins": 680}},
	"woodcut": {"name": "官牧材场", "glyph": "牧", "desc": "统筹林材、牧草与马苑用料，供应军府和商旅", "max": 5, "base": {"grain": 62, "stone": 34, "coins": 810}},
	"quarry": {"name": "砖瓦石作", "glyph": "石", "desc": "烧砖凿石，修筑州镇、军府、仓窖与佛寺工役", "max": 5, "base": {"grain": 80, "wood": 66, "coins": 970}},
	"house": {"name": "三长里坊", "glyph": "长", "desc": "以邻、里、党三长整顿户籍与均田人口", "max": 5, "base": {"wood": 112, "stone": 64, "coins": 930}},
	"market": {"name": "边镇关市", "glyph": "关", "desc": "汇聚南北商旅、胡商驼队、马匹与永安五铢", "max": 5, "base": {"wood": 122, "stone": 70, "coins": 1160}},
	"warehouse": {"name": "镇仓", "glyph": "镇", "desc": "储藏租粟、调帛与军资，维系镇戍转饷", "max": 5, "base": {"wood": 110, "stone": 88, "coins": 850}},
	"barracks": {"name": "镇戍军府", "glyph": "府", "desc": "整训镇戍兵、强弩兵与甲骑具装，管理军马甲械", "max": 5, "base": {"grain": 152, "wood": 146, "stone": 84, "coins": 1740}},
	"wall": {"name": "镇城障垒", "glyph": "障", "desc": "营筑镇城、角楼、烽候与障塞，拱卫关市均田", "max": 5, "base": {"grain": 88, "wood": 158, "stone": 206, "coins": 1880}},
}

const UNITS := {
	"militia": {"name": "镇戍兵", "enemy_name": "步军", "glyph": "戍", "count_unit": "人", "batch_label": "伍", "batch": 5, "need": 0, "power": 1.88, "ranged": 0.0, "melee": 1.88, "exposure": 0.70, "cost": {"grain": 26, "coins": 650}, "grain_daily": 0.22, "coins_daily": 1.48},
	"archer": {"name": "强弩兵", "enemy_name": "弩军", "glyph": "弩", "count_unit": "人", "batch_label": "伍", "batch": 5, "need": 2, "power": 2.74, "ranged": 3.46, "melee": 1.04, "exposure": 0.40, "cost": {"grain": 36, "wood": 25, "coins": 1240}, "grain_daily": 0.27, "coins_daily": 2.55},
	"chariot": {"name": "甲骑具装", "enemy_name": "具装甲骑", "glyph": "甲", "count_unit": "骑", "batch_label": "队", "batch": 5, "need": 3, "power": 3.98, "ranged": 0.0, "melee": 3.98, "exposure": 0.25, "cost": {"grain": 58, "wood": 24, "stone": 8, "coins": 2440}, "grain_daily": 0.55, "coins_daily": 6.20},
}

const DEFENSE_ORDERS := {
	"steady": {"name": "军府持阵", "glyph": "府", "desc": "步骑分屯、军府持阵，攻守无额外修正", "incoming": 1.00, "ranged": 1.00, "melee": 1.00},
	"fortify": {"name": "镇城闭守", "glyph": "镇", "desc": "敌方杀伤-24%，我方远射-7%、近战-25%", "incoming": 0.76, "ranged": 0.93, "melee": 0.75},
	"volley": {"name": "强弩排射", "glyph": "排", "desc": "强弩远射+50%，近战-18%，敌方杀伤+8%", "incoming": 1.08, "ranged": 1.50, "melee": 0.82},
	"sally": {"name": "甲骑陷阵", "glyph": "骑", "desc": "近战杀伤+38%，远射-19%，敌方杀伤+24%", "incoming": 1.24, "ranged": 0.81, "melee": 1.38},
}

const ENEMY_WAVES := [
	{"name": "六镇乱军", "militia": 120, "archer": 52, "chariot": 24, "morale": 74.0, "training": 1.15},
	{"name": "柔然游骑", "militia": 98, "archer": 54, "chariot": 52, "morale": 77.0, "training": 1.18},
	{"name": "关陇军镇", "militia": 132, "archer": 64, "chariot": 34, "morale": 80.0, "training": 1.21},
	{"name": "草原具装骑", "militia": 104, "archer": 62, "chariot": 64, "morale": 83.0, "training": 1.24},
	{"name": "南朝北伐军", "militia": 146, "archer": 74, "chariot": 44, "morale": 86.0, "training": 1.27},
	{"name": "南北会战军", "militia": 166, "archer": 82, "chariot": 50, "morale": 89.0, "training": 1.30},
]
const LATE_ENEMY_NAMES := ["边镇游军", "柔然余骑", "关陇转饷军"]

const EVENTS := [
	{"id": "drought", "title": "均田渠涸", "body": "均田渠陌水量不足，三长请军府发材疏浚，否则租粟难足镇仓。", "options": ["发役修渠", "开仓赈户"], "seasons": ["summer", "autumn"]},
	{"id": "refugees", "title": "流民编户", "body": "战乱流民与迁徙部落来到镇门，请求编入三长里坊并受均田。", "options": ["三长著籍", "给粟遣行"]},
	{"id": "merchant", "title": "关市胡商", "body": "西来胡商以驼队载入良马和铁器，愿用永安五铢换取镇仓租粟。", "options": ["购置器马", "发粟收钱", "闭关不易"]},
	{"id": "scouts", "title": "烽候见骑", "body": "山口烽候发现成队骑兵窥伺均田与转饷道路，来历尚未查明。", "options": ["遣骑候望", "闭塞断道"]},
	{"id": "harvest", "title": "租调入仓", "body": "均田户租粟丰足，镇将请示实仓备边，或出粟安抚军民部落。", "options": ["封仓备边", "赐粟安众"], "seasons": ["spring", "autumn"]},
	{"id": "flood", "title": "河渠决溢", "body": "暴雨冲开镇外渠堤，修筑可保均田和关道，否则只能舍弃低田护镇仓。", "options": ["发材塞决", "弃田护仓"], "seasons": ["summer"]},
	{"id": "winter_relief", "title": "边镇寒赈", "body": "北风封山，三长里坊与商旅都缺粮。军府可发租粟，也可封仓待敌。", "options": ["按籍赈粟", "封仓待春"], "seasons": ["winter"]},
	{"id": "craftsmen", "title": "石作聚匠", "body": "善造甲骑器、砖瓦与石刻的各族工匠来到关市，请求留镇营作。", "options": ["给钱安匠", "役作镇城"], "seasons": ["spring", "summer"]},
	{"id": "rumors", "title": "镇中边谣", "body": "关市流传柔然骑军已越山口，未经烽候核实便引起里坊惊惧。", "options": ["军吏验报", "任其自息"]},
	{"id": "levy", "title": "军镇征调", "body": "上级军府要求青禾输送租粟五铢支援边镇；迟发会使敌骑提前南下。", "options": ["转饷应调", "申表缓发"], "seasons": ["autumn", "winter"]},
]

const TERMS := {
	"population": "均田户", "residents": "镇民", "army": "镇军", "army_registry": "军籍", "wounded": "伤兵",
	"civilian_food": "均田户口粮", "army_food": "镇军粮秣", "army_pay": "军费五铢", "wounded_food": "伤兵给粟", "wounded_care": "伤兵医钱",
	"tax": "租调", "farm_yield": "租粟入仓", "wood_yield": "营材入场", "stone_yield": "镇砖入作",
	"ledger_title": "军镇计帐", "ledger_desc": "租调、口粮、军费、伤兵与镇戍转饷逐日核算",
	"market_title": "边镇关市", "market_desc": "关市通用永安五铢；仓容不足时整笔不成交",
	"military_title": "军府治戍", "military_desc": "军籍、粮秣、伤兵、转饷与南北军报均可核验",
	"enemy_intel": "烽候军报", "battle_forecast": "镇将料敌", "roster": "军籍与伤营", "defense_order": "军府将令",
	"patrol_name": "出塞候骑", "patrol_action": "遣骑", "recruit_action": "发兵", "recruit_verb": "发兵",
	"build_tab": "营镇", "trade_tab": "关市", "military_tab": "军府", "governance_tab": "镇政",
	"build_action": "营作", "upgrade_action": "增筑", "governance_title": "军镇治事", "governance_desc": "镇城营作与南北经略分别成长，均田、关市和边功共同积蓄统一之势",
	"era_progress": "南北经略", "day_ledger": "军镇日计", "victory_title": "镇城奏捷", "defeat_title": "敌骑入镇", "provisions": "粮秣", "pay": "军费",
}
const LOGISTICS := {
	"name": "镇戍转饷", "unit": "载", "desc": "镇仓、官牧材场与关市支撑转饷；甲骑具装的马甲和饲粮负载最高",
	"base_capacity": 76.0, "warehouse_capacity": 42.0, "woodcut_capacity": 15.0, "market_capacity": 12.0,
	"load": {"militia": 1.1, "archer": 1.7, "chariot": 3.6}, "patrol_cost": {"grain": 12, "coins": 130}, "patrol_minimum": 10,
	"ready": "镇道通达", "strained": "转饷迟滞", "critical": "军粮将绝",
}
const ECONOMY := {"production": {"grain": 1.30, "wood": 1.28, "stone": 1.29, "coins": 1.31}, "grain_capacity_base": 2200.0, "grain_capacity_per_warehouse": 1300.0, "material_capacity_base": 660.0, "material_capacity_per_warehouse": 450.0, "coins_capacity_base": 10800.0, "coins_capacity_per_warehouse": 5000.0, "population_base": 140, "population_per_house": 82, "army_base": 52, "army_per_barracks": 32}
const TRADE_LABELS := {"sell_grain": "租粟出仓", "buy_grain": "关市籴粟", "sell_wood": "营材发卖", "buy_stone": "驼运镇砖", "action": "关市"}
const POLICIES := {
	"irrigate": {"name": "修治均田渠", "effect": "三日租粟增产35%", "glyph": "均", "notice": "均田渠修治：三日内租粟增产"},
	"tax_relief": {"name": "宽减租调", "effect": "均田户与民心上升", "glyph": "调", "notice": "宽减租调：均田户安定"},
	"reward_army": {"name": "赐食劳镇军", "effect": "民心上升，伤兵提前归队", "glyph": "食", "notice": "赐食劳军：镇军振奋，伤兵恢复加快"},
}
const NARRATIVE := {"transition": "晋室南迁后，南北政权长期对峙。青禾改行均田与三长里坊，设边镇关市、镇戍军府和镇戍转饷；永安五铢、强弩与甲骑具装共同塑造新的北朝军镇。"}

static func initial_resources() -> Dictionary: return {"grain": 840.0, "wood": 310.0, "stone": 230.0, "coins": 4800.0}
static func initial_buildings() -> Dictionary: return SpringAutumn.initial_buildings()
static func initial_units() -> Dictionary: return {"militia": 50, "archer": 10, "chariot": 5}
static func empty_units() -> Dictionary: return {"militia": 0, "archer": 0, "chariot": 0}

static func definition() -> Dictionary:
	return {"id": ID, "display_name": DISPLAY_NAME, "next_id": NEXT_ID, "city_levels": CITY_LEVELS, "era_growth": ERA_GROWTH, "visual": VISUAL, "seasons": SEASONS, "resource_units": RESOURCE_UNITS, "buildings": BUILDINGS, "units": UNITS, "defense_orders": DEFENSE_ORDERS, "enemy_waves": ENEMY_WAVES, "late_enemy_names": LATE_ENEMY_NAMES, "events": EVENTS, "terms": TERMS, "logistics": LOGISTICS, "economy": ECONOMY, "trade_labels": TRADE_LABELS, "policies": POLICIES, "narrative": NARRATIVE, "initial_resources": initial_resources(), "initial_buildings": initial_buildings(), "initial_units": initial_units(), "empty_units": empty_units()}
