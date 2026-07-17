extends RefCounted

const SpringAutumn = preload("res://src/data/eras/spring_autumn.gd")

const ID := "sui"
const DISPLAY_NAME := "隋"
const NEXT_ID := "tang"

const CITY_LEVELS := [
	{"level": 1, "name": "里坊聚", "slots": 6, "advance_target": 430, "view_scale": 1.00},
	{"level": 2, "name": "县治", "slots": 7, "advance_target": 660, "view_scale": 1.12},
	{"level": 3, "name": "郡治", "slots": 8, "advance_target": 905, "view_scale": 1.23},
	{"level": 4, "name": "运河州城", "slots": 9, "advance_target": 1165, "view_scale": 1.33},
	{"level": 5, "name": "通济重镇", "slots": 10, "advance_target": 1440, "view_scale": 1.43},
]

const ERA_GROWTH := {"target": 2950, "minimum_city_level": 5, "daily": 11, "building_base": 29, "city_level": 152, "battle_victory": 114, "patrol_victory": 24}
const VISUAL := {"tint": Color("#e5e8df"), "background": "res://assets/art/city_sui.png", "map_hint": "隋代运河州城沿漕渠展开，可左右拖动巡视官仓、里坊、军府与水陆驿路", "identity": {"earth": Color(0.40, 0.38, 0.32, 0.68), "standard": Color("#304d63"), "motif": "canal_axis"}}
const SEASONS := SpringAutumn.SEASONS

const RESOURCE_UNITS := {
	"grain": {"name": "输粟", "short": "粟", "unit": "斛", "glyph": "输"},
	"wood": {"name": "官营材", "short": "材", "unit": "车", "glyph": "材"},
	"stone": {"name": "州城砖", "short": "砖", "unit": "方", "glyph": "城"},
	"coins": {"name": "隋五铢", "short": "钱", "unit": "枚", "glyph": "隋"},
}

const BUILDINGS := {
	"farm": {"name": "均田渠亩", "glyph": "田", "desc": "整顿均田与渠亩，按户输粟供给州县和漕仓", "max": 5, "base": {"wood": 92, "stone": 40, "coins": 820}},
	"woodcut": {"name": "官营材场", "glyph": "营", "desc": "官营采运木材，供应舟楫、桥梁、官署和城防", "max": 5, "base": {"grain": 70, "stone": 38, "coins": 960}},
	"quarry": {"name": "砖瓦官作", "glyph": "作", "desc": "烧造州城砖瓦，营建里坊、仓城与运河堤闸", "max": 5, "base": {"grain": 90, "wood": 74, "coins": 1140}},
	"house": {"name": "州县里坊", "glyph": "坊", "desc": "编定州县户籍，以坊墙与街衢安置统一后的军民", "max": 5, "base": {"wood": 126, "stone": 72, "coins": 1100}},
	"market": {"name": "运河市", "glyph": "市", "desc": "漕舟与陆商交汇，以隋五铢核算粮材、舟车与马匹", "max": 5, "base": {"wood": 138, "stone": 78, "coins": 1360}},
	"warehouse": {"name": "漕渠官仓", "glyph": "仓", "desc": "分窖登记输粟与军资，衔接水陆漕运和州县度支", "max": 5, "base": {"wood": 124, "stone": 98, "coins": 1010}},
	"barracks": {"name": "鹰扬军府", "glyph": "鹰", "desc": "兵农相兼，整训府兵、劲弩手与骁骑并检校军籍", "max": 5, "base": {"grain": 172, "wood": 164, "stone": 94, "coins": 2060}},
	"wall": {"name": "州城关防", "glyph": "关", "desc": "修筑罗城、城门、望楼与运河关津，拱卫仓城里坊", "max": 5, "base": {"grain": 100, "wood": 178, "stone": 232, "coins": 2220}},
}

const UNITS := {
	"militia": {"name": "府兵", "enemy_name": "步军", "glyph": "府", "count_unit": "人", "batch_label": "伍", "batch": 5, "need": 0, "power": 2.04, "ranged": 0.0, "melee": 2.04, "exposure": 0.68, "cost": {"grain": 30, "coins": 790}, "grain_daily": 0.24, "coins_daily": 1.76},
	"archer": {"name": "劲弩手", "enemy_name": "弩军", "glyph": "弩", "count_unit": "人", "batch_label": "伍", "batch": 5, "need": 2, "power": 2.96, "ranged": 3.72, "melee": 1.14, "exposure": 0.38, "cost": {"grain": 41, "wood": 28, "coins": 1480}, "grain_daily": 0.29, "coins_daily": 2.96},
	"chariot": {"name": "骁骑", "enemy_name": "精骑", "glyph": "骁", "count_unit": "骑", "batch_label": "队", "batch": 5, "need": 3, "power": 4.28, "ranged": 0.0, "melee": 4.28, "exposure": 0.24, "cost": {"grain": 66, "wood": 27, "stone": 9, "coins": 2870}, "grain_daily": 0.61, "coins_daily": 7.20},
}

const DEFENSE_ORDERS := {
	"steady": {"name": "军府持阵", "glyph": "府", "desc": "步弩骑军依府列阵，攻守无额外修正", "incoming": 1.00, "ranged": 1.00, "melee": 1.00},
	"fortify": {"name": "罗城闭守", "glyph": "城", "desc": "敌方杀伤-25%，我方远射-7%、近战-26%", "incoming": 0.75, "ranged": 0.93, "melee": 0.74},
	"volley": {"name": "劲弩连发", "glyph": "弩", "desc": "劲弩远射+52%，近战-19%，敌方杀伤+8%", "incoming": 1.08, "ranged": 1.52, "melee": 0.81},
	"sally": {"name": "骁骑出关", "glyph": "骁", "desc": "近战杀伤+40%，远射-20%，敌方杀伤+25%", "incoming": 1.25, "ranged": 0.80, "melee": 1.40},
}

const ENEMY_WAVES := [
	{"name": "江淮余寇", "militia": 128, "archer": 56, "chariot": 26, "morale": 74.0, "training": 1.15},
	{"name": "突厥游骑", "militia": 104, "archer": 58, "chariot": 60, "morale": 77.0, "training": 1.18},
	{"name": "河北叛军", "militia": 142, "archer": 68, "chariot": 38, "morale": 80.0, "training": 1.21},
	{"name": "草原骑阵", "militia": 110, "archer": 66, "chariot": 72, "morale": 83.0, "training": 1.24},
	{"name": "运河截粮军", "militia": 156, "archer": 78, "chariot": 48, "morale": 86.0, "training": 1.27},
	{"name": "天下逐鹿军", "militia": 178, "archer": 88, "chariot": 56, "morale": 89.0, "training": 1.30},
]
const LATE_ENEMY_NAMES := ["漕渠游军", "突厥余骑", "州郡叛部"]

const EVENTS := [
	{"id": "drought", "title": "均田渠浅", "body": "新定州县的均田渠亩缺水，若不发官材疏浚，输粟与漕仓都将减收。", "options": ["发役通渠", "开仓赈户"], "seasons": ["summer", "autumn"]},
	{"id": "refugees", "title": "编户归里", "body": "统一后的流散军民来到州城，请求编入里坊并授给耕地。", "options": ["检籍授田", "给粟遣行"]},
	{"id": "merchant", "title": "运河舟商", "body": "漕渠舟商带来农具和官材，愿以隋五铢换取官仓余粟。", "options": ["购置农具", "发粟收钱", "闭市谢客"]},
	{"id": "scouts", "title": "关津急报", "body": "水陆驿卒发现可疑骑队窥测漕舟与仓城，军府尚未查明来路。", "options": ["遣骑追候", "闭关断津"]},
	{"id": "harvest", "title": "输粟盈仓", "body": "州县输粟丰足，可分窖封存备运，也可按籍赐粮安定新附军民。", "options": ["铭窖封仓", "赐粟安众"], "seasons": ["spring", "autumn"]},
	{"id": "flood", "title": "漕堤决溢", "body": "暴雨冲开漕渠堤闸，修复可保舟道和均田，否则只能弃低田护官仓。", "options": ["发材固堤", "弃田护仓"], "seasons": ["summer"]},
	{"id": "winter_relief", "title": "里坊寒赈", "body": "寒潮阻断水陆驿路，新附里坊缺粮。州府可依籍赈粟，也可封仓待敌。", "options": ["按籍赈粟", "封仓待春"], "seasons": ["winter"]},
	{"id": "craftsmen", "title": "官作征匠", "body": "善造舟楫、弩机与砖瓦的工匠应募入城，官作请求给值留用。", "options": ["给钱安匠", "役作罗城"], "seasons": ["spring", "summer"]},
	{"id": "rumors", "title": "漕市讹言", "body": "运河市传言叛军将截断漕路，未经驿报核实已使里坊人心浮动。", "options": ["遣吏核报", "任其自息"]},
	{"id": "levy", "title": "行台催运", "body": "行台催取输粟与五铢供远征军，缓发会使截粮敌军更快逼近。", "options": ["水陆转输", "申牒缓发"], "seasons": ["autumn", "winter"]},
]

const TERMS := {
	"population": "编户", "residents": "州县军民", "army": "府军", "army_registry": "军籍", "wounded": "伤兵",
	"civilian_food": "编户口粮", "army_food": "府军粮秣", "army_pay": "军费五铢", "wounded_food": "伤兵给粟", "wounded_care": "伤兵医钱",
	"tax": "租调", "farm_yield": "输粟入仓", "wood_yield": "官材入场", "stone_yield": "州砖入作",
	"ledger_title": "州县度支", "ledger_desc": "租调、口粮、军费、伤兵与漕运逐日核算",
	"market_title": "运河互市", "market_desc": "水陆商旅以隋五铢互易；仓容不足时整笔不成交",
	"military_title": "鹰扬治军", "military_desc": "军籍、粮秣、伤兵、漕运与关津军报均可核验",
	"enemy_intel": "关津军报", "battle_forecast": "军府料敌", "roster": "军籍与伤营", "defense_order": "鹰扬军令",
	"patrol_name": "巡护漕渠", "patrol_action": "遣骑", "recruit_action": "点兵", "recruit_verb": "点兵",
	"build_tab": "营城", "trade_tab": "运河市", "military_tab": "军府", "governance_tab": "州政",
	"build_action": "营建", "upgrade_action": "增修", "governance_title": "州县治事", "governance_desc": "州城营建与一统经略分别成长，均田、漕运和战功共同推动唐制",
	"era_progress": "一统经略", "day_ledger": "度支日计", "victory_title": "关津奏捷", "defeat_title": "叛军入城", "provisions": "粮秣", "pay": "军费",
}
const LOGISTICS := {
	"name": "漕河转输", "unit": "舶载", "desc": "漕渠官仓、官营材场与运河市支撑水陆转输；骁骑马料与弩械负载更高",
	"base_capacity": 82.0, "warehouse_capacity": 45.0, "woodcut_capacity": 16.0, "market_capacity": 14.0,
	"load": {"militia": 1.1, "archer": 1.75, "chariot": 3.8}, "patrol_cost": {"grain": 13, "coins": 150}, "patrol_minimum": 10,
	"ready": "漕驿通达", "strained": "转输壅滞", "critical": "漕粮将断",
}
const ECONOMY := {"production": {"grain": 1.34, "wood": 1.32, "stone": 1.33, "coins": 1.35}, "grain_capacity_base": 2450.0, "grain_capacity_per_warehouse": 1400.0, "material_capacity_base": 740.0, "material_capacity_per_warehouse": 490.0, "coins_capacity_base": 12300.0, "coins_capacity_per_warehouse": 5550.0, "population_base": 150, "population_per_house": 86, "army_base": 56, "army_per_barracks": 34}
const TRADE_LABELS := {"sell_grain": "输粟出仓", "buy_grain": "漕市籴粟", "sell_wood": "官材发卖", "buy_stone": "舟运州砖", "action": "互市"}
const POLICIES := {
	"irrigate": {"name": "疏浚均田渠", "effect": "三日输粟增产35%", "glyph": "渠", "notice": "均田渠疏浚：三日内输粟增产"},
	"tax_relief": {"name": "宽减租调", "effect": "编户与民心上升", "glyph": "宽", "notice": "宽减租调：州县编户安定"},
	"reward_army": {"name": "赐食府军", "effect": "民心上升，伤兵提前归队", "glyph": "赐", "notice": "赐食府军：将士振奋，伤兵恢复加快"},
}
const NARRATIVE := {"transition": "南北归一，青禾编定州县里坊，重开均田渠亩与漕运驿路。漕渠官仓分窖纳粟，鹰扬军府统摄府兵、劲弩与骁骑，隋五铢成为统一度支的最后一种五铢钱。"}

static func initial_resources() -> Dictionary: return {"grain": 950.0, "wood": 350.0, "stone": 265.0, "coins": 5700.0}
static func initial_buildings() -> Dictionary: return SpringAutumn.initial_buildings()
static func initial_units() -> Dictionary: return {"militia": 55, "archer": 10, "chariot": 5}
static func empty_units() -> Dictionary: return {"militia": 0, "archer": 0, "chariot": 0}

static func definition() -> Dictionary:
	return {"id": ID, "display_name": DISPLAY_NAME, "next_id": NEXT_ID, "city_levels": CITY_LEVELS, "era_growth": ERA_GROWTH, "visual": VISUAL, "seasons": SEASONS, "resource_units": RESOURCE_UNITS, "buildings": BUILDINGS, "units": UNITS, "defense_orders": DEFENSE_ORDERS, "enemy_waves": ENEMY_WAVES, "late_enemy_names": LATE_ENEMY_NAMES, "events": EVENTS, "terms": TERMS, "logistics": LOGISTICS, "economy": ECONOMY, "trade_labels": TRADE_LABELS, "policies": POLICIES, "narrative": NARRATIVE, "initial_resources": initial_resources(), "initial_buildings": initial_buildings(), "initial_units": initial_units(), "empty_units": empty_units()}
