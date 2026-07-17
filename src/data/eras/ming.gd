extends RefCounted

const SpringAutumn = preload("res://src/data/eras/spring_autumn.gd")

const ID := "ming"
const DISPLAY_NAME := "明"
const NEXT_ID := "qing"

const CITY_LEVELS := [
	{"level": 1, "name": "里甲村", "slots": 6, "advance_target": 600, "view_scale": 1.00},
	{"level": 2, "name": "县城", "slots": 9, "advance_target": 915, "view_scale": 1.13},
	{"level": 3, "name": "府城", "slots": 12, "advance_target": 1245, "view_scale": 1.25},
	{"level": 4, "name": "卫城", "slots": 12, "advance_target": 1590, "view_scale": 1.35},
	{"level": 5, "name": "九边重镇", "slots": 12, "advance_target": 1950, "view_scale": 1.45},
]

const ERA_GROWTH := {"target": 3050, "minimum_city_level": 5, "daily": 16, "building_base": 39, "city_level": 212, "battle_victory": 154, "patrol_victory": 34}
const BATTLE_PACING := {"attack_interval_bonus": 2, "post_defeat_bonus": 3}
const VISUAL := {"tint": Color("#dce2e8"), "background": "res://assets/art/city_ming_skeleton.png", "map_hint": "明代卫城以砖垣和漕渠相护，可左右拖动巡视军屯、里甲街巷、漕仓、卫所与神机敌台", "identity": {"earth": Color(0.34, 0.36, 0.40, 0.76), "standard": Color("#8c3435"), "motif": "brick_bastion"}}
const SEASONS := SpringAutumn.SEASONS

const RESOURCE_UNITS := {
	"grain": {"name": "漕粮", "short": "粮", "unit": "石", "glyph": "漕"},
	"wood": {"name": "营造木", "short": "木", "unit": "车", "glyph": "木"},
	"stone": {"name": "城砖", "short": "砖", "unit": "方", "glyph": "砖"},
	"coins": {"name": "库银", "short": "银", "unit": "两", "glyph": "银"},
}

const BUILDINGS := {
	"farm": {"name": "卫所军屯", "glyph": "屯", "desc": "卫军分屯耕守，水利和屯仓共同稳定边镇漕粮", "max": 5, "base": {"wood": 132, "stone": 56, "coins": 1400}},
	"woodcut": {"name": "营造材厂", "glyph": "厂", "desc": "采办营造木，供应漕船、城楼、火器车架与军民屋舍", "max": 5, "base": {"grain": 98, "stone": 54, "coins": 1610}},
	"quarry": {"name": "城砖窑厂", "glyph": "窑", "desc": "烧造定式城砖，修筑府卫砖城、敌台、仓廒和水关", "max": 5, "base": {"grain": 126, "wood": 102, "coins": 1880}},
	"house": {"name": "里甲街巷", "glyph": "甲", "desc": "按里甲编户协理粮差，安置民户、军户与轮班匠役", "max": 5, "base": {"wood": 180, "stone": 102, "coins": 1820}},
	"market": {"name": "城坊会馆", "glyph": "会", "desc": "商帮会馆联络粮船与边市，宝钞旧额之外更以库银核价", "max": 5, "base": {"wood": 194, "stone": 110, "coins": 2220}},
	"warehouse": {"name": "漕粮仓场", "glyph": "仓", "desc": "收纳南粮、屯粮和军械，再按卫所与边镇需求拨运", "max": 5, "base": {"wood": 176, "stone": 140, "coins": 1700}},
	"barracks": {"name": "卫所军署", "glyph": "卫", "desc": "清查军户屯田，统练卫所军、神机铳手与边军铁骑", "max": 5, "base": {"grain": 244, "wood": 232, "stone": 136, "coins": 3400}},
	"wall": {"name": "砖城敌台", "glyph": "台", "desc": "增筑包砖城垣、瓮城、敌台和炮位，守护仓场与九边驿路", "max": 5, "base": {"grain": 142, "wood": 250, "stone": 330, "coins": 3660}},
}

const UNITS := {
	"militia": {"name": "卫所军", "enemy_name": "营兵", "glyph": "卫", "count_unit": "人", "batch_label": "队", "batch": 5, "need": 0, "power": 2.94, "ranged": 0.0, "melee": 2.94, "exposure": 0.60, "cost": {"grain": 44, "coins": 1400}, "grain_daily": 0.34, "coins_daily": 2.96},
	"archer": {"name": "神机铳手", "enemy_name": "火器军", "glyph": "铳", "count_unit": "人", "batch_label": "队", "batch": 5, "need": 2, "power": 4.30, "ranged": 5.40, "melee": 1.64, "exposure": 0.31, "cost": {"grain": 59, "wood": 40, "coins": 2480}, "grain_daily": 0.42, "coins_daily": 4.82},
	"chariot": {"name": "边军铁骑", "enemy_name": "塞外骑兵", "glyph": "边", "count_unit": "骑", "batch_label": "队", "batch": 5, "need": 3, "power": 6.22, "ranged": 0.86, "melee": 5.84, "exposure": 0.19, "cost": {"grain": 94, "wood": 39, "stone": 14, "coins": 4700}, "grain_daily": 0.89, "coins_daily": 11.75},
}

const DEFENSE_ORDERS := {
	"steady": {"name": "车营合守", "glyph": "营", "desc": "卫军、铳手与铁骑依车营砖城合守，攻守无额外修正", "incoming": 1.00, "ranged": 1.00, "melee": 1.00},
	"fortify": {"name": "敌台固守", "glyph": "台", "desc": "敌方杀伤-30%，我方远射-4%、近战-31%", "incoming": 0.70, "ranged": 0.96, "melee": 0.69},
	"volley": {"name": "神机迭发", "glyph": "铳", "desc": "神机铳手远射+62%，近战-24%，敌方杀伤+10%", "incoming": 1.10, "ranged": 1.62, "melee": 0.76},
	"sally": {"name": "铁骑出塞", "glyph": "骑", "desc": "近战杀伤+51%，远射-25%，敌方杀伤+30%", "incoming": 1.30, "ranged": 0.75, "melee": 1.51},
}

const ENEMY_WAVES := [
	{"name": "山场盗众", "militia": 192, "archer": 88, "chariot": 44, "morale": 77.0, "training": 1.21},
	{"name": "塞外游骑", "militia": 150, "archer": 90, "chariot": 106, "morale": 80.0, "training": 1.24},
	{"name": "叛卫营兵", "militia": 206, "archer": 102, "chariot": 68, "morale": 83.0, "training": 1.27},
	{"name": "边墙大队", "militia": 158, "archer": 100, "chariot": 122, "morale": 86.0, "training": 1.30},
	{"name": "围城火器军", "militia": 226, "archer": 116, "chariot": 82, "morale": 89.0, "training": 1.33},
	{"name": "诸营会战军", "militia": 260, "archer": 132, "chariot": 94, "morale": 92.0, "training": 1.36},
]
const LATE_ENEMY_NAMES := ["塞外游骑", "叛卫营兵", "截漕围城军"]

const EVENTS := [
	{"id": "drought", "title": "军屯渠涸", "body": "卫所军屯水渠见底，若不发营造木修水车，边镇漕粮将明显减收。", "options": ["军民修渠", "开仓济屯"], "seasons": ["summer", "autumn"]},
	{"id": "refugees", "title": "灾户投里", "body": "邻府受灾民户来到城外，请求编入里甲街巷并承种荒废屯田。", "options": ["编甲授田", "给粮遣返"]},
	{"id": "merchant", "title": "商帮到馆", "body": "南北商帮携布匹、铜钱与库银抵达会馆，愿承运漕粮和营造木。", "options": ["购器修船", "发粮收银", "停市稽验"]},
	{"id": "scouts", "title": "墩台举烟", "body": "边墙墩台发现塞外骑兵窥探水关，卫所尚未摸清其后队与火器。", "options": ["遣骑哨探", "闭关撤民"]},
	{"id": "harvest", "title": "屯田报熟", "body": "军屯丰收，可装船并入漕粮仓场，也可留粮补足军户月粮。", "options": ["征收入仓", "留粮养军"], "seasons": ["spring", "autumn"]},
	{"id": "flood", "title": "漕堤决口", "body": "洪水冲向仓场和砖窑，军民合修可保漕渠，否则只能舍外屯护卫城。", "options": ["筑堤堵口", "弃屯护城"], "seasons": ["summer"]},
	{"id": "winter_relief", "title": "里甲冬赈", "body": "雪后粮价上涨，贫户与老弱军户缺粮。府城可开仓，也可封存边饷。", "options": ["按里赈粮", "封仓备边"], "seasons": ["winter"]},
	{"id": "craftsmen", "title": "军器匠到卫", "body": "会造鸟铳、铜炮、火药和漕船的匠役来投，神机营请拨银留用。", "options": ["给银置局", "役修敌台"], "seasons": ["spring", "summer"]},
	{"id": "rumors", "title": "边报纷传", "body": "会馆流传敌军已经越墙，尚未经墩台与驿递互证，商户开始闭门囤粮。", "options": ["验报安坊", "任其自息"]},
	{"id": "levy", "title": "兵部催饷", "body": "兵部行文催发漕粮、火器与库银支援邻镇，拖延可能让边墙出现缺口。", "options": ["照数解运", "具奏缓发"], "seasons": ["autumn", "winter"]},
]

const TERMS := {
	"population": "里甲户", "residents": "府卫军民", "army": "卫军", "army_registry": "军户册", "wounded": "伤军",
	"civilian_food": "里甲口粮", "army_food": "卫军月粮", "army_pay": "军饷银", "wounded_food": "伤军给粮", "wounded_care": "伤军医银",
	"tax": "粮差", "farm_yield": "屯粮入仓", "wood_yield": "营木入厂", "stone_yield": "城砖入窑",
	"ledger_title": "府卫粮册", "ledger_desc": "粮差、屯粮、月粮、军饷与漕运逐日核算",
	"market_title": "城坊会馆", "market_desc": "库银按两核价；仓容不足时整笔不成交",
	"military_title": "卫所治军", "military_desc": "军户册、月粮、伤军、漕运军需与墩台边报均可核验",
	"enemy_intel": "墩台边报", "battle_forecast": "参将料敌", "roster": "军户与伤营", "defense_order": "守城军令",
	"patrol_name": "铁骑巡边", "patrol_action": "出哨", "recruit_action": "选补", "recruit_verb": "选补",
	"build_tab": "营造", "trade_tab": "会馆", "military_tab": "卫所", "governance_tab": "府治",
	"build_action": "兴建", "upgrade_action": "包砖", "governance_title": "府卫经略", "governance_desc": "卫城营造与府卫积累分别成长，军屯、漕运、商税和边功共同推动新制",
	"era_progress": "府卫积累", "day_ledger": "粮册日计", "victory_title": "边城奏捷", "defeat_title": "敌军破关", "provisions": "月粮", "pay": "饷银",
}
const LOGISTICS := {
	"name": "漕运军需", "unit": "漕载", "desc": "漕粮仓、营造材厂与会馆支撑水陆军需；火器弹药和铁骑草料负载最高",
	"base_capacity": 112.0, "warehouse_capacity": 60.0, "woodcut_capacity": 21.0, "market_capacity": 24.0,
	"load": {"militia": 1.35, "archer": 2.10, "chariot": 4.75}, "patrol_cost": {"grain": 18, "coins": 250}, "patrol_minimum": 10,
	"ready": "漕需齐备", "strained": "军运迟滞", "critical": "边饷将绝",
}
const ECONOMY := {"production": {"grain": 1.54, "wood": 1.52, "stone": 1.53, "coins": 1.58}, "grain_capacity_base": 3420.0, "grain_capacity_per_warehouse": 1840.0, "material_capacity_base": 1050.0, "material_capacity_per_warehouse": 680.0, "coins_capacity_base": 19400.0, "coins_capacity_per_warehouse": 8300.0, "population_base": 200, "population_per_house": 112, "army_base": 76, "army_per_barracks": 44}
const TRADE_LABELS := {"sell_grain": "漕粮出仓", "buy_grain": "会馆籴粮", "sell_wood": "营造木发卖", "buy_stone": "漕船运砖", "action": "贸易"}
const POLICIES := {
	"irrigate": {"name": "整治军屯", "effect": "三日漕粮增产35%", "glyph": "屯", "notice": "军屯整治：三日内漕粮增产"},
	"tax_relief": {"name": "蠲免粮差", "effect": "里甲户与民心上升", "glyph": "蠲", "notice": "蠲免粮差：府卫里甲安定"},
	"reward_army": {"name": "犒赏边军", "effect": "民心上升，伤军提前归队", "glyph": "犒", "notice": "犒赏边军：卫军振奋，伤军恢复加快"},
}
const NARRATIVE := {"transition": "行省旧制更替，府县、里甲与卫所重新编排青禾的田土和人户。漕粮仓场衔接南北河道，砖城敌台守住边口；卫所军、神机铳手和边军铁骑必须在军屯、库银与火器军需之间保持平衡。"}

static func initial_resources() -> Dictionary: return {"grain": 1380.0, "wood": 505.0, "stone": 385.0, "coins": 9600.0}
static func initial_buildings() -> Dictionary: return SpringAutumn.initial_buildings()
static func initial_units() -> Dictionary: return {"militia": 76, "archer": 13, "chariot": 6}
static func empty_units() -> Dictionary: return {"militia": 0, "archer": 0, "chariot": 0}

static func definition() -> Dictionary:
	return {"id": ID, "display_name": DISPLAY_NAME, "next_id": NEXT_ID, "city_levels": CITY_LEVELS, "era_growth": ERA_GROWTH, "battle_pacing": BATTLE_PACING, "visual": VISUAL, "seasons": SEASONS, "resource_units": RESOURCE_UNITS, "buildings": BUILDINGS, "units": UNITS, "defense_orders": DEFENSE_ORDERS, "enemy_waves": ENEMY_WAVES, "late_enemy_names": LATE_ENEMY_NAMES, "events": EVENTS, "terms": TERMS, "logistics": LOGISTICS, "economy": ECONOMY, "trade_labels": TRADE_LABELS, "policies": POLICIES, "narrative": NARRATIVE, "initial_resources": initial_resources(), "initial_buildings": initial_buildings(), "initial_units": initial_units(), "empty_units": empty_units()}
