extends RefCounted

const SpringAutumn = preload("res://src/data/eras/spring_autumn.gd")

const ID := "yuan"
const DISPLAY_NAME := "元"
const NEXT_ID := "ming"

const CITY_LEVELS := [
	{"level": 1, "name": "屯聚", "slots": 6, "advance_target": 570, "view_scale": 1.00},
	{"level": 2, "name": "县治", "slots": 7, "advance_target": 870, "view_scale": 1.13},
	{"level": 3, "name": "路城", "slots": 8, "advance_target": 1185, "view_scale": 1.25},
	{"level": 4, "name": "行省治所", "slots": 9, "advance_target": 1515, "view_scale": 1.35},
	{"level": 5, "name": "漕运重镇", "slots": 10, "advance_target": 1860, "view_scale": 1.45},
]

const ERA_GROWTH := {"target": 2950, "minimum_city_level": 5, "daily": 15, "building_base": 37, "city_level": 200, "battle_victory": 146, "patrol_victory": 32}
const BATTLE_PACING := {"attack_interval_bonus": 1, "post_defeat_bonus": 3}
const VISUAL := {"tint": Color("#d9e4df"), "background": "res://assets/art/city_yuan.png", "map_hint": "元代路城沟通草原与漕河，可左右拖动巡视屯田、站赤马院、官仓、诸色户坊和万户府", "identity": {"earth": Color(0.35, 0.39, 0.38, 0.74), "standard": Color("#327174"), "motif": "steppe_station"}}
const SEASONS := SpringAutumn.SEASONS

const RESOURCE_UNITS := {
	"grain": {"name": "屯粮", "short": "粮", "unit": "石", "glyph": "屯"},
	"wood": {"name": "官山木", "short": "木", "unit": "车", "glyph": "官"},
	"stone": {"name": "城砖", "short": "砖", "unit": "方", "glyph": "城"},
	"coins": {"name": "至元钞", "short": "钞", "unit": "贯", "glyph": "钞"},
}

const BUILDINGS := {
	"farm": {"name": "军民屯田", "glyph": "屯", "desc": "军屯与民屯共修沟渠，将北粮和漕米汇入行省仓场", "max": 5, "base": {"wood": 126, "stone": 54, "coins": 1320}},
	"woodcut": {"name": "官山材场", "glyph": "官", "desc": "采办官山木料，供应站车、马院、城门和漕船修造", "max": 5, "base": {"grain": 94, "stone": 52, "coins": 1520}},
	"quarry": {"name": "砖瓦局", "glyph": "局", "desc": "烧造城砖瓦件，修筑路城、仓廒、桥梁与炮械台座", "max": 5, "base": {"grain": 120, "wood": 98, "coins": 1780}},
	"house": {"name": "诸色户坊", "glyph": "户", "desc": "安置民户、军户、匠户和站户，依各自差役编籍成坊", "max": 5, "base": {"wood": 172, "stone": 98, "coins": 1720}},
	"market": {"name": "马市商坊", "glyph": "马", "desc": "马匹、皮货、丝绢与至元钞在路城汇集，各地商旅按例互市", "max": 5, "base": {"wood": 186, "stone": 106, "coins": 2100}},
	"warehouse": {"name": "行省漕仓", "glyph": "漕", "desc": "接纳海运与河漕粮石，再由站车分拨路府、军营和沿边城寨", "max": 5, "base": {"wood": 168, "stone": 134, "coins": 1600}},
	"barracks": {"name": "万户府", "glyph": "万", "desc": "统领汉军步卒、弩军与蒙古骑军，核验军户、马匹和器械", "max": 5, "base": {"grain": 234, "wood": 222, "stone": 130, "coins": 3200}},
	"wall": {"name": "路城堡寨", "glyph": "路", "desc": "加固路城、壕堑、敌台与外围寨堡，护住漕仓和站赤干道", "max": 5, "base": {"grain": 136, "wood": 240, "stone": 316, "coins": 3440}},
}

const UNITS := {
	"militia": {"name": "汉军步卒", "enemy_name": "步军", "glyph": "汉", "count_unit": "人", "batch_label": "队", "batch": 5, "need": 0, "power": 2.76, "ranged": 0.0, "melee": 2.76, "exposure": 0.61, "cost": {"grain": 42, "coins": 1320}, "grain_daily": 0.32, "coins_daily": 2.76},
	"archer": {"name": "弩军", "enemy_name": "弓弩军", "glyph": "弩", "count_unit": "人", "batch_label": "队", "batch": 5, "need": 2, "power": 4.00, "ranged": 5.02, "melee": 1.54, "exposure": 0.32, "cost": {"grain": 56, "wood": 38, "coins": 2340}, "grain_daily": 0.39, "coins_daily": 4.48},
	"chariot": {"name": "蒙古骑军", "enemy_name": "草原骑军", "glyph": "骑", "count_unit": "骑", "batch_label": "队", "batch": 5, "need": 3, "power": 5.82, "ranged": 1.28, "melee": 5.24, "exposure": 0.19, "cost": {"grain": 90, "wood": 37, "stone": 13, "coins": 4420}, "grain_daily": 0.84, "coins_daily": 10.90},
}

const DEFENSE_ORDERS := {
	"steady": {"name": "诸军合守", "glyph": "合", "desc": "步卒弩军与骑军依路城合守，攻守无额外修正", "incoming": 1.00, "ranged": 1.00, "melee": 1.00},
	"fortify": {"name": "堡寨扼道", "glyph": "寨", "desc": "敌方杀伤-29%，我方远射-5%、近战-30%", "incoming": 0.71, "ranged": 0.95, "melee": 0.70},
	"volley": {"name": "弩炮齐发", "glyph": "炮", "desc": "弩军远射+60%，近战-23%，敌方杀伤+10%", "incoming": 1.10, "ranged": 1.60, "melee": 0.77},
	"sally": {"name": "骑军迂击", "glyph": "骑", "desc": "近战杀伤+49%，远射-24%，敌方杀伤+29%", "incoming": 1.29, "ranged": 0.76, "melee": 1.49},
}

const ENEMY_WAVES := [
	{"name": "逃户盗群", "militia": 176, "archer": 80, "chariot": 40, "morale": 76.0, "training": 1.19},
	{"name": "草原游骑", "militia": 140, "archer": 82, "chariot": 96, "morale": 79.0, "training": 1.22},
	{"name": "邻路叛军", "militia": 190, "archer": 94, "chariot": 60, "morale": 82.0, "training": 1.25},
	{"name": "争位诸王军", "militia": 146, "archer": 92, "chariot": 112, "morale": 85.0, "training": 1.28},
	{"name": "断漕行军", "militia": 210, "archer": 108, "chariot": 76, "morale": 88.0, "training": 1.31},
	{"name": "行省会战军", "militia": 242, "archer": 124, "chariot": 88, "morale": 91.0, "training": 1.34},
]
const LATE_ENEMY_NAMES := ["草原游骑", "邻省叛军", "截断站赤军"]

const EVENTS := [
	{"id": "drought", "title": "屯渠见底", "body": "军民屯田的灌渠干涸，若不发官山木修闸，漕仓将少收一季屯粮。", "options": ["役户修渠", "发仓济屯"], "seasons": ["summer", "autumn"]},
	{"id": "refugees", "title": "逃户来归", "body": "邻路灾荒后的各色人户停在城外，请求编入诸色户坊并领种屯田。", "options": ["验籍授田", "给粮遣行"]},
	{"id": "merchant", "title": "西商入马市", "body": "远方商队携马匹、皮货和至元钞到市，愿换屯粮、木材与旅舍供给。", "options": ["购马修械", "出粮收钞", "闭市验钞"]},
	{"id": "scouts", "title": "站赤飞报", "body": "急递报告游骑越过北道，万户府尚未查明其旗号和后续马群。", "options": ["遣骑探路", "撤驿闭关"]},
	{"id": "harvest", "title": "军民屯熟", "body": "军屯与民屯同时收获，可海河联运入行省漕仓，也可留粮安置站户。", "options": ["起运入仓", "留粮安户"], "seasons": ["spring", "autumn"]},
	{"id": "flood", "title": "漕河漫仓", "body": "漕河骤涨逼近仓廒，调砖木护堤可保粮运，否则只能舍外屯护主仓。", "options": ["筑堤护漕", "弃屯护仓"], "seasons": ["summer"]},
	{"id": "winter_relief", "title": "站户冬困", "body": "大雪阻断驿道，站户马匹和贫户都缺屯粮。行省可赈济，也可封仓待解冻。", "options": ["按站给粮", "封仓待春"], "seasons": ["winter"]},
	{"id": "craftsmen", "title": "匠户造炮", "body": "善铸铜火炮、造弩和修站车的匠户来投，砖瓦局与万户府请求留用。", "options": ["给钞置局", "役修堡寨"], "seasons": ["spring", "summer"]},
	{"id": "rumors", "title": "钞法流言", "body": "马市盛传旧钞即将禁用，商旅争换粮货，消息尚未经行省文书证实。", "options": ["验文平市", "任其自息"]},
	{"id": "levy", "title": "行省调粮", "body": "行省檄调漕粮与至元钞支援北路，延误会使站赤和军马同时断供。", "options": ["发仓应调", "申文缓发"], "seasons": ["autumn", "winter"]},
]

const TERMS := {
	"population": "诸色户", "residents": "路城军民", "army": "万户军", "army_registry": "军户籍", "wounded": "伤卒",
	"civilian_food": "诸户口粮", "army_food": "军户粮", "army_pay": "军赏钞", "wounded_food": "伤卒给粮", "wounded_care": "伤卒医钞",
	"tax": "科差", "farm_yield": "屯粮入仓", "wood_yield": "官木入场", "stone_yield": "城砖入局",
	"ledger_title": "行省钱谷", "ledger_desc": "科差、屯粮、军赏、站赤与漕运逐日核算",
	"market_title": "马市商坊", "market_desc": "至元钞按贯计价；仓容不足时整笔不成交",
	"military_title": "万户治军", "military_desc": "军户籍、军马、伤卒、站赤负载与路城军报均可核验",
	"enemy_intel": "站赤军报", "battle_forecast": "万户料敌", "roster": "军户与伤营", "defense_order": "万户军令",
	"patrol_name": "骑军巡站", "patrol_action": "发骑", "recruit_action": "签军", "recruit_verb": "签军",
	"build_tab": "营造", "trade_tab": "马市", "military_tab": "万户", "governance_tab": "行省",
	"build_action": "兴作", "upgrade_action": "增筑", "governance_title": "行省经画", "governance_desc": "路城营造与行省积累分别成长，屯田、站赤、漕运和军功共同推动新制",
	"era_progress": "行省积累", "day_ledger": "钱谷日计", "victory_title": "路城告捷", "defeat_title": "敌军入城", "provisions": "军户粮", "pay": "军赏钞",
}
const LOGISTICS := {
	"name": "站赤漕运", "unit": "站载", "desc": "行省漕仓、官山材场与马市支撑站赤；蒙古骑军的马匹草料负载最高",
	"base_capacity": 106.0, "warehouse_capacity": 57.0, "woodcut_capacity": 20.0, "market_capacity": 22.0,
	"load": {"militia": 1.30, "archer": 2.00, "chariot": 4.55}, "patrol_cost": {"grain": 17, "coins": 235}, "patrol_minimum": 10,
	"ready": "站漕畅达", "strained": "驿运迟滞", "critical": "站粮将绝",
}
const ECONOMY := {"production": {"grain": 1.50, "wood": 1.48, "stone": 1.49, "coins": 1.54}, "grain_capacity_base": 3260.0, "grain_capacity_per_warehouse": 1760.0, "material_capacity_base": 1000.0, "material_capacity_per_warehouse": 645.0, "coins_capacity_base": 18200.0, "coins_capacity_per_warehouse": 7800.0, "population_base": 190, "population_per_house": 106, "army_base": 72, "army_per_barracks": 42}
const TRADE_LABELS := {"sell_grain": "屯粮出仓", "buy_grain": "马市籴粮", "sell_wood": "官山木发卖", "buy_stone": "站车运砖", "action": "市易"}
const POLICIES := {
	"irrigate": {"name": "浚治屯渠", "effect": "三日屯粮增产35%", "glyph": "屯", "notice": "屯渠浚治：三日内屯粮增产"},
	"tax_relief": {"name": "蠲免科差", "effect": "诸色户与民心上升", "glyph": "蠲", "notice": "蠲免科差：路城诸户安定"},
	"reward_army": {"name": "给赏诸军", "effect": "民心上升，伤卒提前归队", "glyph": "赏", "notice": "给赏诸军：万户军振奋，伤卒恢复加快"},
}
const NARRATIVE := {"transition": "宋代路府与纲运旧制改归行省统辖。青禾以军民屯田供给漕仓，用站赤驿路衔接北方草原与南方河运；至元钞进入钱谷账簿，万户府则统合汉军弩阵和机动骑军。"}

static func initial_resources() -> Dictionary: return {"grain": 1320.0, "wood": 485.0, "stone": 370.0, "coins": 9000.0}
static func initial_buildings() -> Dictionary: return SpringAutumn.initial_buildings()
static func initial_units() -> Dictionary: return {"militia": 72, "archer": 12, "chariot": 5}
static func empty_units() -> Dictionary: return {"militia": 0, "archer": 0, "chariot": 0}

static func definition() -> Dictionary:
	return {"id": ID, "display_name": DISPLAY_NAME, "next_id": NEXT_ID, "city_levels": CITY_LEVELS, "era_growth": ERA_GROWTH, "battle_pacing": BATTLE_PACING, "visual": VISUAL, "seasons": SEASONS, "resource_units": RESOURCE_UNITS, "buildings": BUILDINGS, "units": UNITS, "defense_orders": DEFENSE_ORDERS, "enemy_waves": ENEMY_WAVES, "late_enemy_names": LATE_ENEMY_NAMES, "events": EVENTS, "terms": TERMS, "logistics": LOGISTICS, "economy": ECONOMY, "trade_labels": TRADE_LABELS, "policies": POLICIES, "narrative": NARRATIVE, "initial_resources": initial_resources(), "initial_buildings": initial_buildings(), "initial_units": initial_units(), "empty_units": empty_units()}
