extends RefCounted

const SpringAutumn = preload("res://src/data/eras/spring_autumn.gd")

const ID := "five_dynasties"
const DISPLAY_NAME := "五代"
const NEXT_ID := "song"

const CITY_LEVELS := [
	{"level": 1, "name": "军镇聚", "slots": 6, "advance_target": 510, "view_scale": 1.00},
	{"level": 2, "name": "防御州", "slots": 9, "advance_target": 780, "view_scale": 1.13},
	{"level": 3, "name": "节镇州城", "slots": 12, "advance_target": 1065, "view_scale": 1.25},
	{"level": 4, "name": "留后府", "slots": 12, "advance_target": 1365, "view_scale": 1.35},
	{"level": 5, "name": "藩镇雄城", "slots": 12, "advance_target": 1680, "view_scale": 1.45},
]

const ERA_GROWTH := {"target": 3450, "minimum_city_level": 5, "daily": 13, "building_base": 33, "city_level": 176, "battle_victory": 130, "patrol_victory": 28}
const VISUAL := {"tint": Color("#e8dfd3"), "background": "res://assets/art/terrain_only/city_five_dynasties_terrain_only.png", "map_hint": "五代藩镇层层设防，可左右拖动巡视牙城、转运仓、州市和修筑不断的外郭", "identity": {"earth": Color(0.34, 0.31, 0.28, 0.72), "standard": Color("#6d4035"), "motif": "commandery"}}
const SEASONS := SpringAutumn.SEASONS

const RESOURCE_UNITS := {
	"grain": {"name": "军粮", "short": "粮", "unit": "斛", "glyph": "军"},
	"wood": {"name": "营城材", "short": "材", "unit": "车", "glyph": "营"},
	"stone": {"name": "牙城砖", "short": "砖", "unit": "方", "glyph": "牙"},
	"coins": {"name": "诸道通宝", "short": "钱", "unit": "文", "glyph": "宝"},
}

const BUILDINGS := {
	"farm": {"name": "营田庄", "glyph": "营", "desc": "招集军户流民耕作营田，向转运仓稳定输送军粮", "max": 5, "base": {"wood": 116, "stone": 50, "coins": 1160}},
	"woodcut": {"name": "修城材场", "glyph": "修", "desc": "采办营城材与马料，供应城栅、楼橹、车械和军府", "max": 5, "base": {"grain": 86, "stone": 48, "coins": 1340}},
	"quarry": {"name": "砖瓦军作", "glyph": "作", "desc": "昼夜烧造牙城砖瓦，修补反复受战的城垣官署", "max": 5, "base": {"grain": 110, "wood": 90, "coins": 1580}},
	"house": {"name": "军户坊", "glyph": "户", "desc": "编置军户、流民与匠户，以坊栅保护藩镇人力", "max": 5, "base": {"wood": 158, "stone": 90, "coins": 1520}},
	"market": {"name": "藩镇州市", "glyph": "市", "desc": "旧开元钱与诸道通宝并行，军民商旅在州城互易", "max": 5, "base": {"wood": 172, "stone": 98, "coins": 1860}},
	"warehouse": {"name": "转运仓", "glyph": "运", "desc": "收纳营田军粮、诸道钱帛与甲械，供应牙军和州兵", "max": 5, "base": {"wood": 156, "stone": 122, "coins": 1410}},
	"barracks": {"name": "节度军府", "glyph": "度", "desc": "统摄镇兵、强弩手与牙军骑，掌握军令、兵籍和赏赐", "max": 5, "base": {"grain": 216, "wood": 204, "stone": 118, "coins": 2820}},
	"wall": {"name": "牙城堡垒", "glyph": "堡", "desc": "加固牙城、外郭、敌楼与鹿角，守住军仓和节度使府", "max": 5, "base": {"grain": 124, "wood": 222, "stone": 288, "coins": 3020}},
}

const UNITS := {
	"militia": {"name": "镇兵", "enemy_name": "州兵", "glyph": "镇", "count_unit": "人", "batch_label": "伍", "batch": 5, "need": 0, "power": 2.40, "ranged": 0.0, "melee": 2.40, "exposure": 0.63, "cost": {"grain": 38, "coins": 1160}, "grain_daily": 0.29, "coins_daily": 2.42},
	"archer": {"name": "强弩手", "enemy_name": "弩军", "glyph": "弩", "count_unit": "人", "batch_label": "伍", "batch": 5, "need": 2, "power": 3.46, "ranged": 4.34, "melee": 1.34, "exposure": 0.34, "cost": {"grain": 51, "wood": 34, "coins": 2070}, "grain_daily": 0.35, "coins_daily": 3.92},
	"chariot": {"name": "牙军骑", "enemy_name": "亲骑", "glyph": "牙", "count_unit": "骑", "batch_label": "队", "batch": 5, "need": 3, "power": 5.04, "ranged": 0.0, "melee": 5.04, "exposure": 0.20, "cost": {"grain": 82, "wood": 33, "stone": 11, "coins": 3910}, "grain_daily": 0.75, "coins_daily": 9.45},
}

const DEFENSE_ORDERS := {
	"steady": {"name": "牙城持阵", "glyph": "牙", "desc": "镇兵强弩与牙军依城列阵，攻守无额外修正", "incoming": 1.00, "ranged": 1.00, "melee": 1.00},
	"fortify": {"name": "堡垒闭守", "glyph": "堡", "desc": "敌方杀伤-27%，我方远射-6%、近战-28%", "incoming": 0.73, "ranged": 0.94, "melee": 0.72},
	"volley": {"name": "强弩压城", "glyph": "弩", "desc": "强弩远射+56%，近战-21%，敌方杀伤+9%", "incoming": 1.09, "ranged": 1.56, "melee": 0.79},
	"sally": {"name": "牙骑突营", "glyph": "牙", "desc": "近战杀伤+46%，远射-22%，敌方杀伤+27%", "incoming": 1.27, "ranged": 0.78, "melee": 1.46},
}

const ENEMY_WAVES := [
	{"name": "溃镇乱兵", "militia": 144, "archer": 64, "chariot": 30, "morale": 74.0, "training": 1.15},
	{"name": "河朔牙骑", "militia": 116, "archer": 66, "chariot": 76, "morale": 77.0, "training": 1.18},
	{"name": "邻镇州军", "militia": 158, "archer": 76, "chariot": 46, "morale": 80.0, "training": 1.21},
	{"name": "沙陀骑军", "militia": 122, "archer": 74, "chariot": 90, "morale": 83.0, "training": 1.24},
	{"name": "争衡禁军", "militia": 176, "archer": 88, "chariot": 60, "morale": 86.0, "training": 1.27},
	{"name": "诸道会战军", "militia": 202, "archer": 100, "chariot": 68, "morale": 89.0, "training": 1.30},
]
const LATE_ENEMY_NAMES := ["邻镇游军", "沙陀余骑", "诸道转饷军"]

const EVENTS := [
	{"id": "drought", "title": "营田渠涸", "body": "军户营田的支渠干涸，若不调修城材疏浚，转运仓军粮将难以为继。", "options": ["发军修渠", "开仓赈户"], "seasons": ["summer", "autumn"]},
	{"id": "refugees", "title": "流民投镇", "body": "邻州战乱后的军民来到外郭，请求编入军户坊并受牙城保护。", "options": ["编户授田", "给粮遣行"]},
	{"id": "merchant", "title": "州市钱商", "body": "钱商携旧开元钱和诸道新铸通宝入市，愿以铜钱换取军粮。", "options": ["购置农具", "发粮收钱", "闭市谢客"]},
	{"id": "scouts", "title": "敌楼传烽", "body": "外郭敌楼发现邻镇斥骑窥测军仓与城门，军府尚未辨明旗号。", "options": ["遣牙骑反侦", "闭郭断道"]},
	{"id": "harvest", "title": "营田粮熟", "body": "营田庄军粮丰收，可尽数封入转运仓，也可赐粮稳住军户和牙军。", "options": ["封仓备战", "赐粮安众"], "seasons": ["spring", "autumn"]},
	{"id": "flood", "title": "壕渠暴涨", "body": "暴雨漫过牙城壕渠，修堤可保营田与转运道，否则只能弃低田护仓。", "options": ["发材固堤", "弃田护仓"], "seasons": ["summer"]},
	{"id": "winter_relief", "title": "军户寒赈", "body": "风雪截断邻道，外郭军户与流民缺粮。留后可开仓，也可紧闭牙城。", "options": ["按户给粮", "封仓待春"], "seasons": ["winter"]},
	{"id": "craftsmen", "title": "军作募匠", "body": "善造强弩、马具和城砖的工匠投镇，节度军府请求给值留用。", "options": ["给钱安匠", "役修牙城"], "seasons": ["spring", "summer"]},
	{"id": "rumors", "title": "牙城兵谣", "body": "州市传言邻镇将领已倒戈，未经军报核实便使军户与商人惊惧。", "options": ["军吏验报", "任其自息"]},
	{"id": "levy", "title": "节帅催饷", "body": "节帅急征军粮通宝犒赏牙军；拖延会使邻镇抢先截断转运道。", "options": ["转运应调", "申牒缓发"], "seasons": ["autumn", "winter"]},
]

const TERMS := {
	"population": "军户", "residents": "藩镇军民", "army": "镇军", "army_registry": "军簿", "wounded": "伤卒",
	"civilian_food": "军户口粮", "army_food": "镇军军粮", "army_pay": "赏军通宝", "wounded_food": "伤卒给粮", "wounded_care": "伤卒医钱",
	"tax": "户调", "farm_yield": "营田入仓", "wood_yield": "营材入场", "stone_yield": "牙砖入作",
	"ledger_title": "藩镇度支", "ledger_desc": "户调、军粮、赏钱、伤卒与转饷逐日核算",
	"market_title": "藩镇州市", "market_desc": "旧钱与诸道通宝并行；仓容不足时整笔不成交",
	"military_title": "节度治军", "military_desc": "军簿、军粮、伤卒、转饷与邻镇军报均可核验",
	"enemy_intel": "敌楼军报", "battle_forecast": "牙将料敌", "roster": "军簿与伤营", "defense_order": "节度军令",
	"patrol_name": "牙骑巡道", "patrol_action": "遣骑", "recruit_action": "募兵", "recruit_verb": "募兵",
	"build_tab": "营镇", "trade_tab": "州市", "military_tab": "军府", "governance_tab": "节镇",
	"build_action": "营筑", "upgrade_action": "加固", "governance_title": "节镇治事", "governance_desc": "牙城营筑与诸道经略分别成长，营田、转运和战功积蓄再统一之势",
	"era_progress": "诸道经略", "day_ledger": "度支日计", "victory_title": "牙城奏捷", "defeat_title": "敌军破郭", "provisions": "军粮", "pay": "赏钱",
}
const LOGISTICS := {
	"name": "藩镇转饷", "unit": "车载", "desc": "转运仓、修城材场与州市维系军饷；牙军骑马料和强弩器械负载最高",
	"base_capacity": 94.0, "warehouse_capacity": 51.0, "woodcut_capacity": 18.0, "market_capacity": 18.0,
	"load": {"militia": 1.2, "archer": 1.85, "chariot": 4.2}, "patrol_cost": {"grain": 15, "coins": 205}, "patrol_minimum": 10,
	"ready": "转运通达", "strained": "转饷壅滞", "critical": "军粮将绝",
}
const ECONOMY := {"production": {"grain": 1.42, "wood": 1.40, "stone": 1.41, "coins": 1.44}, "grain_capacity_base": 2950.0, "grain_capacity_per_warehouse": 1600.0, "material_capacity_base": 900.0, "material_capacity_per_warehouse": 575.0, "coins_capacity_base": 15800.0, "coins_capacity_per_warehouse": 6800.0, "population_base": 170, "population_per_house": 94, "army_base": 64, "army_per_barracks": 38}
const TRADE_LABELS := {"sell_grain": "军粮出仓", "buy_grain": "州市籴粮", "sell_wood": "营城材发卖", "buy_stone": "车运牙城砖", "action": "互易"}
const POLICIES := {
	"irrigate": {"name": "修治营田渠", "effect": "三日军粮增产35%", "glyph": "营", "notice": "营田渠修治：三日内军粮增产"},
	"tax_relief": {"name": "宽减户调", "effect": "军户与民心上升", "glyph": "宽", "notice": "宽减户调：藩镇军户安定"},
	"reward_army": {"name": "犒赏牙军", "effect": "民心上升，伤卒提前归队", "glyph": "赏", "notice": "犒赏牙军：镇军振奋，伤卒恢复加快"},
}
const NARRATIVE := {"transition": "唐室倾覆，诸道军镇争衡。青禾加固牙城外郭，以营田庄和转运仓维持镇军；旧开元钱与诸道通宝并行，强弩手和牙军骑守护一条随时可能被截断的转饷路。"}

static func initial_resources() -> Dictionary: return {"grain": 1200.0, "wood": 445.0, "stone": 340.0, "coins": 7800.0}
static func initial_buildings() -> Dictionary: return SpringAutumn.initial_buildings()
static func initial_units() -> Dictionary: return {"militia": 65, "archer": 10, "chariot": 5}
static func empty_units() -> Dictionary: return {"militia": 0, "archer": 0, "chariot": 0}

static func definition() -> Dictionary:
	return {"id": ID, "display_name": DISPLAY_NAME, "next_id": NEXT_ID, "city_levels": CITY_LEVELS, "era_growth": ERA_GROWTH, "visual": VISUAL, "seasons": SEASONS, "resource_units": RESOURCE_UNITS, "buildings": BUILDINGS, "units": UNITS, "defense_orders": DEFENSE_ORDERS, "enemy_waves": ENEMY_WAVES, "late_enemy_names": LATE_ENEMY_NAMES, "events": EVENTS, "terms": TERMS, "logistics": LOGISTICS, "economy": ECONOMY, "trade_labels": TRADE_LABELS, "policies": POLICIES, "narrative": NARRATIVE, "initial_resources": initial_resources(), "initial_buildings": initial_buildings(), "initial_units": initial_units(), "empty_units": empty_units()}
