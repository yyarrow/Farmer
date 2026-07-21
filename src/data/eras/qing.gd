extends RefCounted

const SpringAutumn = preload("res://src/data/eras/spring_autumn.gd")

const ID := "qing"
const DISPLAY_NAME := "清"
const NEXT_ID := ""

const CITY_LEVELS := [
	{"level": 1, "name": "保甲村", "slots": 6, "advance_target": 630, "view_scale": 1.00},
	{"level": 2, "name": "县城", "slots": 9, "advance_target": 960, "view_scale": 1.13},
	{"level": 3, "name": "府城", "slots": 12, "advance_target": 1305, "view_scale": 1.25},
	{"level": 4, "name": "道治", "slots": 12, "advance_target": 1665, "view_scale": 1.35},
	{"level": 5, "name": "边疆重镇", "slots": 12, "advance_target": 2040, "view_scale": 1.45},
]

const ERA_GROWTH := {"target": 3300, "minimum_city_level": 5, "daily": 17, "building_base": 41, "city_level": 224, "battle_victory": 162, "patrol_victory": 36}
const BATTLE_PACING := {"attack_interval_bonus": 2, "post_defeat_bonus": 3}
const VISUAL := {"tint": Color("#e4dfd4"), "background": "res://assets/art/terrain_only/city_qing_terrain_only.png", "map_hint": "清代边疆重镇依驿路设置粮台，可左右拖动巡视屯田、常平仓、商埠、绿营汛署和砖城炮台", "identity": {"earth": Color(0.36, 0.37, 0.39, 0.78), "standard": Color("#334f78"), "motif": "banner_bastion"}}
const SEASONS := SpringAutumn.SEASONS

const RESOURCE_UNITS := {
	"grain": {"name": "漕粮", "short": "粮", "unit": "石", "glyph": "粮"},
	"wood": {"name": "官木", "short": "木", "unit": "车", "glyph": "官"},
	"stone": {"name": "城砖", "short": "砖", "unit": "方", "glyph": "城"},
	"coins": {"name": "库平银", "short": "银", "unit": "两", "glyph": "库"},
}

const BUILDINGS := {
	"farm": {"name": "旗民屯田", "glyph": "屯", "desc": "旗屯、民屯和水利共同供粮，平时入仓、军行时前送粮台", "max": 5, "base": {"wood": 138, "stone": 58, "coins": 1480}},
	"woodcut": {"name": "官木厂", "glyph": "木", "desc": "验收官木和民运木料，供应驿车、炮架、城楼与仓廒", "max": 5, "base": {"grain": 102, "stone": 56, "coins": 1700}},
	"quarry": {"name": "砖瓦作", "glyph": "作", "desc": "烧造城砖瓦件，修补府城、炮台、汛署、桥涵和粮台", "max": 5, "base": {"grain": 132, "wood": 106, "coins": 1980}},
	"house": {"name": "保甲街巷", "glyph": "保", "desc": "保甲清册与街巷铺户共同维持户口、夜巡和地方赈济", "max": 5, "base": {"wood": 188, "stone": 106, "coins": 1920}},
	"market": {"name": "商埠行栈", "glyph": "栈", "desc": "行栈联络驿道和河运，粮布、茶马与库平银按行情成交", "max": 5, "base": {"wood": 202, "stone": 114, "coins": 2340}},
	"warehouse": {"name": "常平仓粮台", "glyph": "台", "desc": "常平仓平抑粮价，战时粮台逐站接济前路军队与驮畜", "max": 5, "base": {"wood": 182, "stone": 146, "coins": 1800}},
	"barracks": {"name": "绿营汛署", "glyph": "汛", "desc": "提督标下统练绿营兵、鸟枪兵，并与八旗马甲分汛协防", "max": 5, "base": {"grain": 254, "wood": 242, "stone": 142, "coins": 3600}},
	"wall": {"name": "砖城炮台", "glyph": "炮", "desc": "整修砖城、瓮门、炮台和外汛卡伦，护住粮台与驿路咽喉", "max": 5, "base": {"grain": 148, "wood": 260, "stone": 344, "coins": 3880}},
}

const UNITS := {
	"militia": {"name": "绿营兵", "enemy_name": "营兵", "glyph": "营", "count_unit": "人", "batch_label": "队", "batch": 5, "need": 0, "power": 3.12, "ranged": 0.0, "melee": 3.12, "exposure": 0.59, "cost": {"grain": 46, "coins": 1480}, "grain_daily": 0.36, "coins_daily": 3.18},
	"archer": {"name": "鸟枪兵", "enemy_name": "枪炮兵", "glyph": "枪", "count_unit": "人", "batch_label": "队", "batch": 5, "need": 2, "power": 4.58, "ranged": 5.76, "melee": 1.74, "exposure": 0.30, "cost": {"grain": 62, "wood": 42, "coins": 2620}, "grain_daily": 0.45, "coins_daily": 5.20},
	"chariot": {"name": "八旗马甲", "enemy_name": "边地骑队", "glyph": "旗", "count_unit": "骑", "batch_label": "队", "batch": 5, "need": 3, "power": 6.62, "ranged": 0.92, "melee": 6.20, "exposure": 0.18, "cost": {"grain": 98, "wood": 41, "stone": 15, "coins": 4980}, "grain_daily": 0.94, "coins_daily": 12.65},
}

const DEFENSE_ORDERS := {
	"steady": {"name": "汛台协守", "glyph": "汛", "desc": "绿营、鸟枪与马甲依汛台协守，攻守无额外修正", "incoming": 1.00, "ranged": 1.00, "melee": 1.00},
	"fortify": {"name": "炮台固守", "glyph": "炮", "desc": "敌方杀伤-31%，我方远射-3%、近战-32%", "incoming": 0.69, "ranged": 0.97, "melee": 0.68},
	"volley": {"name": "枪炮齐发", "glyph": "枪", "desc": "鸟枪兵远射+64%，近战-25%，敌方杀伤+11%", "incoming": 1.11, "ranged": 1.64, "melee": 0.75},
	"sally": {"name": "马甲追击", "glyph": "旗", "desc": "近战杀伤+53%，远射-26%，敌方杀伤+31%", "incoming": 1.31, "ranged": 0.74, "melee": 1.53},
}

const ENEMY_WAVES := [
	{"name": "山地啸聚", "militia": 208, "archer": 96, "chariot": 48, "morale": 78.0, "training": 1.23},
	{"name": "边地骑队", "militia": 164, "archer": 98, "chariot": 118, "morale": 81.0, "training": 1.26},
	{"name": "邻省乱军", "militia": 222, "archer": 110, "chariot": 76, "morale": 84.0, "training": 1.29},
	{"name": "高原游骑", "militia": 172, "archer": 108, "chariot": 136, "morale": 87.0, "training": 1.32},
	{"name": "围堡枪炮军", "militia": 244, "archer": 126, "chariot": 92, "morale": 90.0, "training": 1.35},
	{"name": "多路会攻军", "militia": 280, "archer": 144, "chariot": 104, "morale": 93.0, "training": 1.38},
]
const LATE_ENEMY_NAMES := ["边地骑队", "邻省乱军", "截断粮台军"]

const EVENTS := [
	{"id": "drought", "title": "屯渠断流", "body": "旗民屯田水渠断流，若不发官木修闸，常平仓和前路粮台都会少粮。", "options": ["合力修渠", "开仓济屯"], "seasons": ["summer", "autumn"]},
	{"id": "refugees", "title": "灾民入保", "body": "邻县灾民抵达关外，请求编入保甲街巷并承垦空闲屯地。", "options": ["编保授田", "给粮遣行"]},
	{"id": "merchant", "title": "行商投栈", "body": "行商携茶布、驮畜和库平银入栈，愿承运粮台军需与官木。", "options": ["采办驿具", "发粮收银", "闭栈查验"]},
	{"id": "scouts", "title": "驿报驰至", "body": "驿骑报告边地骑队接近外汛，提督尚未核清人数和枪炮配置。", "options": ["遣马甲哨探", "撤汛封卡"]},
	{"id": "harvest", "title": "屯田秋收", "body": "旗民屯田一同报熟，可封入常平仓前送粮台，也可留粮稳定保甲。", "options": ["入仓备运", "留粮安民"], "seasons": ["spring", "autumn"]},
	{"id": "flood", "title": "河涨逼台", "body": "洪水逼近仓廒和驿道，砖木合修可护住粮台，否则须舍外屯保府城。", "options": ["修堤护台", "弃屯护城"], "seasons": ["summer"]},
	{"id": "winter_relief", "title": "常平冬赈", "body": "寒潮截断驿路，贫户、汛兵和驮畜都缺粮。道台可开仓，也可封存军需。", "options": ["按保平粜", "封仓备警"], "seasons": ["winter"]},
	{"id": "craftsmen", "title": "炮匠赴汛", "body": "善修鸟枪、铸炮、制药和造驿车的工匠来到府城，汛署请求给银留用。", "options": ["给银设作", "役修炮台"], "seasons": ["spring", "summer"]},
	{"id": "rumors", "title": "塘报疑云", "body": "商埠传言外汛已经失守，尚未经塘报与驿报互证，行栈开始囤粮闭门。", "options": ["核报安埠", "任其自息"]},
	{"id": "levy", "title": "军台催饷", "body": "前路军台催发漕粮、枪药和库平银，拖延会使逐站转运在边口断裂。", "options": ["接站拨运", "详文缓发"], "seasons": ["autumn", "winter"]},
]

const TERMS := {
	"population": "保甲户", "residents": "府道军民", "army": "汛防军", "army_registry": "营旗册", "wounded": "伤兵",
	"civilian_food": "保甲口粮", "army_food": "汛兵口粮", "army_pay": "兵饷银", "wounded_food": "伤兵给粮", "wounded_care": "伤兵医银",
	"tax": "钱粮", "farm_yield": "屯粮入仓", "wood_yield": "官木入厂", "stone_yield": "城砖入作",
	"ledger_title": "道府钱粮", "ledger_desc": "钱粮、仓储、兵饷、粮台与驿运逐日核算",
	"market_title": "商埠行栈", "market_desc": "库平银按两核价；仓容不足时整笔不成交",
	"military_title": "提督治军", "military_desc": "营旗册、口粮、伤兵、粮台负载与塘驿军报均可核验",
	"enemy_intel": "塘驿军报", "battle_forecast": "提督料敌", "roster": "营旗与伤棚", "defense_order": "汛防号令",
	"patrol_name": "马甲巡汛", "patrol_action": "出汛", "recruit_action": "挑补", "recruit_verb": "挑补",
	"build_tab": "营缮", "trade_tab": "商埠", "military_tab": "提督", "governance_tab": "道府",
	"build_action": "修建", "upgrade_action": "增缮", "governance_title": "道府筹办", "governance_desc": "重镇营缮与道府积累分别成长，屯田、商埠、驿运和边功共同维持新制",
	"era_progress": "道府积累", "day_ledger": "钱粮日计", "victory_title": "重镇奏捷", "defeat_title": "敌军入关", "provisions": "口粮", "pay": "兵饷",
}
const LOGISTICS := {
	"name": "驿站粮台", "unit": "站载", "desc": "常平仓、官木厂与行栈逐站接济军需；枪炮弹药和马甲草料负载最高",
	"base_capacity": 118.0, "warehouse_capacity": 63.0, "woodcut_capacity": 22.0, "market_capacity": 26.0,
	"load": {"militia": 1.40, "archer": 2.20, "chariot": 4.95}, "patrol_cost": {"grain": 19, "coins": 265}, "patrol_minimum": 10,
	"ready": "粮台接济", "strained": "驿运壅滞", "critical": "前路断粮",
}
const ECONOMY := {"production": {"grain": 1.58, "wood": 1.56, "stone": 1.57, "coins": 1.62}, "grain_capacity_base": 3580.0, "grain_capacity_per_warehouse": 1920.0, "material_capacity_base": 1100.0, "material_capacity_per_warehouse": 715.0, "coins_capacity_base": 20600.0, "coins_capacity_per_warehouse": 8800.0, "population_base": 210, "population_per_house": 118, "army_base": 80, "army_per_barracks": 46}
const TRADE_LABELS := {"sell_grain": "漕粮出仓", "buy_grain": "行栈籴粮", "sell_wood": "官木发卖", "buy_stone": "驿车运砖", "action": "贸易"}
const POLICIES := {
	"irrigate": {"name": "兴修屯渠", "effect": "三日漕粮增产35%", "glyph": "渠", "notice": "屯渠兴修：三日内漕粮增产"},
	"tax_relief": {"name": "蠲缓钱粮", "effect": "保甲户与民心上升", "glyph": "缓", "notice": "蠲缓钱粮：府道保甲安定"},
	"reward_army": {"name": "犒赏汛兵", "effect": "民心上升，伤兵提前归队", "glyph": "犒", "notice": "犒赏汛兵：汛防军振奋，伤兵恢复加快"},
}
const NARRATIVE := {"transition": "明代卫所与里甲旧册经过整编，青禾转由道府、保甲和提督标营协同治理。常平仓在平时调剂粮价，边警时则以驿站粮台逐段前送；绿营鸟枪、八旗马甲和砖城炮台都依赖稳定的钱粮与塘驿信息。"}

static func initial_resources() -> Dictionary: return {"grain": 1440.0, "wood": 525.0, "stone": 400.0, "coins": 10200.0}
static func initial_buildings() -> Dictionary: return SpringAutumn.initial_buildings()
static func initial_units() -> Dictionary: return {"militia": 80, "archer": 14, "chariot": 6}
static func empty_units() -> Dictionary: return {"militia": 0, "archer": 0, "chariot": 0}

static func definition() -> Dictionary:
	return {"id": ID, "display_name": DISPLAY_NAME, "next_id": NEXT_ID, "city_levels": CITY_LEVELS, "era_growth": ERA_GROWTH, "battle_pacing": BATTLE_PACING, "visual": VISUAL, "seasons": SEASONS, "resource_units": RESOURCE_UNITS, "buildings": BUILDINGS, "units": UNITS, "defense_orders": DEFENSE_ORDERS, "enemy_waves": ENEMY_WAVES, "late_enemy_names": LATE_ENEMY_NAMES, "events": EVENTS, "terms": TERMS, "logistics": LOGISTICS, "economy": ECONOMY, "trade_labels": TRADE_LABELS, "policies": POLICIES, "narrative": NARRATIVE, "initial_resources": initial_resources(), "initial_buildings": initial_buildings(), "initial_units": initial_units(), "empty_units": empty_units()}
