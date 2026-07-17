extends RefCounted

const SpringAutumn = preload("res://src/data/eras/spring_autumn.gd")

const ID := "three_kingdoms"
const DISPLAY_NAME := "三国"
const NEXT_ID := "jin"

const CITY_LEVELS := [
	{"level": 1, "name": "屯田聚", "slots": 6, "advance_target": 310, "view_scale": 1.00},
	{"level": 2, "name": "坞堡", "slots": 7, "advance_target": 480, "view_scale": 1.10},
	{"level": 3, "name": "郡县治", "slots": 8, "advance_target": 665, "view_scale": 1.20},
	{"level": 4, "name": "州府", "slots": 9, "advance_target": 865, "view_scale": 1.30},
	{"level": 5, "name": "州郡重城", "slots": 10, "advance_target": 1080, "view_scale": 1.40},
]

const ERA_GROWTH := {"target": 2200, "minimum_city_level": 5, "daily": 8, "building_base": 23, "city_level": 116, "battle_victory": 90, "patrol_victory": 18}
const VISUAL := {"tint": Color("#e6e5dc"), "background": "res://assets/art/city_three_kingdoms.png", "map_hint": "魏郡坞城与军屯铺展，可左右拖动巡视军仓、武库和马苑", "identity": {"earth": Color(0.29, 0.28, 0.25, 0.70), "standard": Color("#344c60"), "motif": "palisade"}}
const SEASONS := SpringAutumn.SEASONS

const RESOURCE_UNITS := {
	"grain": {"name": "军屯粟", "short": "屯粟", "unit": "斛", "glyph": "屯"},
	"wood": {"name": "营造材", "short": "材", "unit": "车", "glyph": "材"},
	"stone": {"name": "坞城砖", "short": "砖", "unit": "方", "glyph": "砖"},
	"coins": {"name": "魏五铢", "short": "钱", "unit": "枚", "glyph": "魏"},
}

const BUILDINGS := {
	"farm": {"name": "军屯阡陌", "glyph": "屯", "desc": "屯田客耕守相兼，向军仓稳定输送军粮", "max": 5, "base": {"wood": 64, "stone": 28, "coins": 460}},
	"woodcut": {"name": "官作材场", "glyph": "作", "desc": "官作采办营造材，供应楼橹、兵械、舟车和坞壁", "max": 5, "base": {"grain": 48, "stone": 26, "coins": 560}},
	"quarry": {"name": "砖瓦作", "glyph": "瓦", "desc": "烧造城砖瓦件，修缮州郡官署与坞城墙垣", "max": 5, "base": {"grain": 62, "wood": 50, "coins": 680}},
	"house": {"name": "坞堡户里", "glyph": "坞", "desc": "聚居编户、屯田客与避乱流民，扩充郡县人力", "max": 5, "base": {"wood": 86, "stone": 48, "coins": 650}},
	"market": {"name": "军市", "glyph": "市", "desc": "军民互市，以魏五铢核算粮材、马匹与兵械", "max": 5, "base": {"wood": 94, "stone": 52, "coins": 820}},
	"warehouse": {"name": "州郡军仓", "glyph": "仓", "desc": "收纳屯租、军资和官物，衔接前线转饷", "max": 5, "base": {"wood": 84, "stone": 68, "coins": 590}},
	"barracks": {"name": "中军武库", "glyph": "武", "desc": "检修甲械弩机，整训州郡兵、强弩士与宿卫骑", "max": 5, "base": {"grain": 118, "wood": 112, "stone": 64, "coins": 1220}},
	"wall": {"name": "坞城壁垒", "glyph": "垒", "desc": "增筑坞壁、门楼、望橹与鹿角，保护军屯和州治", "max": 5, "base": {"grain": 68, "wood": 122, "stone": 158, "coins": 1340}},
}

const UNITS := {
	"militia": {"name": "州郡兵", "enemy_name": "步军", "glyph": "郡", "count_unit": "人", "batch_label": "伍", "batch": 5, "need": 0, "power": 1.58, "ranged": 0.0, "melee": 1.58, "exposure": 0.76, "cost": {"grain": 20, "coins": 410}, "grain_daily": 0.18, "coins_daily": 1.05},
	"archer": {"name": "强弩士", "enemy_name": "弩兵", "glyph": "弩", "count_unit": "人", "batch_label": "伍", "batch": 5, "need": 2, "power": 2.30, "ranged": 2.94, "melee": 0.86, "exposure": 0.45, "cost": {"grain": 28, "wood": 19, "coins": 850}, "grain_daily": 0.22, "coins_daily": 1.86},
	"chariot": {"name": "宿卫骑", "enemy_name": "精骑", "glyph": "骑", "count_unit": "骑", "batch_label": "队", "batch": 5, "need": 3, "power": 3.30, "ranged": 0.0, "melee": 3.30, "exposure": 0.33, "cost": {"grain": 44, "wood": 18, "stone": 6, "coins": 1660}, "grain_daily": 0.44, "coins_daily": 4.50},
}

const DEFENSE_ORDERS := {
	"steady": {"name": "中军持阵", "glyph": "中", "desc": "部曲分屯、中军持阵，攻守无额外修正", "incoming": 1.00, "ranged": 1.00, "melee": 1.00},
	"fortify": {"name": "坞壁固守", "glyph": "坞", "desc": "敌方杀伤-22%，我方远射-8%、近战-23%", "incoming": 0.78, "ranged": 0.92, "melee": 0.77},
	"volley": {"name": "强弩攒射", "glyph": "弩", "desc": "强弩远射+46%，近战-16%，敌方杀伤+7%", "incoming": 1.07, "ranged": 1.46, "melee": 0.84},
	"sally": {"name": "精骑突阵", "glyph": "突", "desc": "近战杀伤+32%，远射-17%，敌方杀伤+22%", "incoming": 1.22, "ranged": 0.83, "melee": 1.32},
}

const ENEMY_WAVES := [
	{"name": "青徐流寇", "militia": 105, "archer": 44, "chariot": 18, "morale": 74.0, "training": 1.15},
	{"name": "乌桓游骑", "militia": 90, "archer": 48, "chariot": 38, "morale": 77.0, "training": 1.18},
	{"name": "敌国州军", "militia": 116, "archer": 56, "chariot": 24, "morale": 80.0, "training": 1.21},
	{"name": "鲜卑骑部", "militia": 94, "archer": 54, "chariot": 48, "morale": 83.0, "training": 1.24},
	{"name": "北伐前锋", "militia": 128, "archer": 64, "chariot": 34, "morale": 86.0, "training": 1.27},
	{"name": "三军会战阵", "militia": 146, "archer": 72, "chariot": 40, "morale": 89.0, "training": 1.30},
]
const LATE_ENEMY_NAMES := ["边郡游军", "乌桓余骑", "敌国转饷部曲"]

const EVENTS := [
	{"id": "drought", "title": "屯渠少水", "body": "典农官报称军屯支渠淤浅，若不调发工材，秋后屯租与前线军粮都将受损。", "options": ["发卒修渠", "开仓赈屯"], "seasons": ["summer", "autumn"]},
	{"id": "refugees", "title": "流民入坞", "body": "避乱百姓携老幼来到坞门，请求著籍耕屯并受城壁保护。", "options": ["编户授田", "给粮遣行"]},
	{"id": "merchant", "title": "军市马商", "body": "北地马商持过所入市，愿以魏五铢换军屯粟，也带来耐用农具。", "options": ["购置农具", "发粟收钱", "闭市谢客"]},
	{"id": "scouts", "title": "斥候见尘", "body": "望橹发现远道尘骑，疑是敌国细作正在窥测军仓与坞门。", "options": ["遣骑反侦", "闭坞断道"]},
	{"id": "harvest", "title": "屯租丰入", "body": "典农官核报屯田丰收，可尽数实军仓，也可赐粟慰劳军民。", "options": ["封仓备战", "赐粟劳众"], "seasons": ["spring", "autumn"]},
	{"id": "flood", "title": "津渠暴涨", "body": "河水漫入屯田，修堤可保军屯与漕道，否则只能弃低田护住军仓。", "options": ["发材筑堤", "弃田护仓"], "seasons": ["summer"]},
	{"id": "winter_relief", "title": "坞中寒赈", "body": "寒潮阻断军道，坞内流民缺粮。郡府可出屯粟赈济，亦可封仓备敌。", "options": ["计户给粟", "封仓待春"], "seasons": ["winter"]},
	{"id": "craftsmen", "title": "武库募匠", "body": "善造弩机与楼橹的工匠来投，中军武库请求给值留用。", "options": ["给钱安匠", "役作坞墙"], "seasons": ["spring", "summer"]},
	{"id": "rumors", "title": "军市讹言", "body": "军市流传敌国大军将至，未经斥候核实已使屯户惶恐。", "options": ["遣吏核报", "任其自息"]},
	{"id": "levy", "title": "都督催饷", "body": "都督府命青禾转输军粮钱货支援前线；拖延将使敌军更快逼近。", "options": ["具粮应调", "上表缓发"], "seasons": ["autumn", "winter"]},
]

const TERMS := {
	"population": "屯户", "residents": "军民", "army": "州军", "army_registry": "兵簿", "wounded": "伤卒",
	"civilian_food": "屯户口粮", "army_food": "州军军粮", "army_pay": "军费五铢", "wounded_food": "伤卒给粮", "wounded_care": "伤卒医钱",
	"tax": "户调", "farm_yield": "屯租入仓", "wood_yield": "营材入作", "stone_yield": "城砖入库",
	"ledger_title": "度支军计", "ledger_desc": "屯租、口粮、军费、伤卒与转饷逐日入计",
	"market_title": "州郡军市", "market_desc": "军市以魏五铢核价；仓容不足时整笔不成交",
	"military_title": "中军整兵", "military_desc": "兵簿、军粮、伤卒、转饷和敌国部曲均可核验",
	"enemy_intel": "斥候军报", "battle_forecast": "参军料敌", "roster": "兵簿与伤营", "defense_order": "中军将令",
	"patrol_name": "出坞游徼", "patrol_action": "遣骑", "recruit_action": "点兵", "recruit_verb": "点兵",
	"build_tab": "营坞", "trade_tab": "军市", "military_tab": "中军", "governance_tab": "州政",
	"build_action": "营造", "upgrade_action": "增筑", "governance_title": "州郡治事", "governance_desc": "坞城营造与三分经略分别成长，军屯和征战共同推动晋制",
	"era_progress": "三分经略", "day_ledger": "军计日簿", "victory_title": "坞城奏捷", "defeat_title": "敌军破坞", "provisions": "军粮", "pay": "军费",
}
const LOGISTICS := {
	"name": "军屯转饷", "unit": "载", "desc": "军仓、官作和军市支撑转饷；强弩器械与宿卫骑负载更高",
	"base_capacity": 64.0, "warehouse_capacity": 36.0, "woodcut_capacity": 13.0, "market_capacity": 8.0,
	"load": {"militia": 1.05, "archer": 1.6, "chariot": 3.0}, "patrol_cost": {"grain": 10, "coins": 95}, "patrol_minimum": 10,
	"ready": "军饷通达", "strained": "转饷迟缓", "critical": "粮道将断",
}
const ECONOMY := {"production": {"grain": 1.22, "wood": 1.20, "stone": 1.21, "coins": 1.23}, "grain_capacity_base": 1800.0, "grain_capacity_per_warehouse": 1100.0, "material_capacity_base": 520.0, "material_capacity_per_warehouse": 370.0, "coins_capacity_base": 8200.0, "coins_capacity_per_warehouse": 4000.0, "population_base": 120, "population_per_house": 74, "army_base": 44, "army_per_barracks": 28}
const TRADE_LABELS := {"sell_grain": "军屯粟出仓", "buy_grain": "军市籴粮", "sell_wood": "营材发卖", "buy_stone": "市买坞砖", "action": "军市"}
const POLICIES := {
	"irrigate": {"name": "修复屯渠", "effect": "三日军屯粟增产35%", "glyph": "屯", "notice": "屯渠修复：三日内军屯粟增产"},
	"tax_relief": {"name": "减免户调", "effect": "屯户与民心上升", "glyph": "调", "notice": "减免户调：屯户安定"},
	"reward_army": {"name": "犒劳部曲", "effect": "民心上升，伤卒提前归队", "glyph": "劳", "notice": "犒劳部曲：州军振奋，伤卒恢复加快"},
}
const NARRATIVE := {"transition": "汉室分崩，青禾归入曹魏州郡。典农军屯、坞堡户里、中军武库和军屯转饷成为生存根基，魏五铢与强弩精骑一同进入新的州郡战争。"}

static func initial_resources() -> Dictionary: return {"grain": 650.0, "wood": 235.0, "stone": 170.0, "coins": 3300.0}
static func initial_buildings() -> Dictionary: return SpringAutumn.initial_buildings()
static func initial_units() -> Dictionary: return {"militia": 40, "archer": 10, "chariot": 5}
static func empty_units() -> Dictionary: return {"militia": 0, "archer": 0, "chariot": 0}

static func definition() -> Dictionary:
	return {"id": ID, "display_name": DISPLAY_NAME, "next_id": NEXT_ID, "city_levels": CITY_LEVELS, "era_growth": ERA_GROWTH, "visual": VISUAL, "seasons": SEASONS, "resource_units": RESOURCE_UNITS, "buildings": BUILDINGS, "units": UNITS, "defense_orders": DEFENSE_ORDERS, "enemy_waves": ENEMY_WAVES, "late_enemy_names": LATE_ENEMY_NAMES, "events": EVENTS, "terms": TERMS, "logistics": LOGISTICS, "economy": ECONOMY, "trade_labels": TRADE_LABELS, "policies": POLICIES, "narrative": NARRATIVE, "initial_resources": initial_resources(), "initial_buildings": initial_buildings(), "initial_units": initial_units(), "empty_units": empty_units()}
