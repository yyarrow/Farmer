extends RefCounted

const SpringAutumn = preload("res://src/data/eras/spring_autumn.gd")

const ID := "han"
const DISPLAY_NAME := "汉"
const NEXT_ID := "three_kingdoms"

const CITY_LEVELS := [
	{"level": 1, "name": "里邑", "slots": 6, "advance_target": 270, "view_scale": 1.00},
	{"level": 2, "name": "县城", "slots": 9, "advance_target": 420, "view_scale": 1.10},
	{"level": 3, "name": "郡治", "slots": 12, "advance_target": 585, "view_scale": 1.20},
	{"level": 4, "name": "都尉府", "slots": 12, "advance_target": 765, "view_scale": 1.30},
	{"level": 5, "name": "边郡雄城", "slots": 12, "advance_target": 960, "view_scale": 1.40},
]

const ERA_GROWTH := {"target": 1950, "minimum_city_level": 5, "daily": 7, "building_base": 21, "city_level": 105, "battle_victory": 82, "patrol_victory": 16}
const VISUAL := {"tint": Color("#ffe9cf"), "background": "res://assets/art/terrain_only/city_han_terrain_only.png", "map_hint": "汉郡城坊与厩苑铺展，可左右拖动巡视武库、太仓和传舍", "identity": {"earth": Color(0.37, 0.24, 0.17, 0.66), "standard": Color("#a84b39"), "motif": "han_que"}}
const SEASONS := SpringAutumn.SEASONS

const RESOURCE_UNITS := {
	"grain": {"name": "廪粟", "short": "粟", "unit": "斛", "glyph": "廪"},
	"wood": {"name": "官材", "short": "材", "unit": "车", "glyph": "材"},
	"stone": {"name": "城砖", "short": "砖", "unit": "方", "glyph": "砖"},
	"coins": {"name": "五铢钱", "short": "钱", "unit": "枚", "glyph": "铢"},
}

const BUILDINGS := {
	"farm": {"name": "代田沟洫", "glyph": "田", "desc": "推行代田与沟洫，增加田租和边郡军食", "max": 5, "base": {"wood": 56, "stone": 24, "coins": 380}},
	"woodcut": {"name": "山泽署", "glyph": "泽", "desc": "管理山林陂泽与官材，为传车、武库和城工供料", "max": 5, "base": {"grain": 40, "stone": 22, "coins": 460}},
	"quarry": {"name": "陶窑砖场", "glyph": "窑", "desc": "烧造汉砖瓦当，营缮郡城、仓廪与亭障", "max": 5, "base": {"grain": 54, "wood": 44, "coins": 560}},
	"house": {"name": "编户里坊", "glyph": "里", "desc": "整顿里坊与户籍，扩充编户齐民和算赋基础", "max": 5, "base": {"wood": 74, "stone": 40, "coins": 530}},
	"market": {"name": "市肆", "glyph": "肆", "desc": "汇集郡国商旅，以五铢钱平准粮材价格", "max": 5, "base": {"wood": 82, "stone": 44, "coins": 680}},
	"warehouse": {"name": "太仓", "glyph": "太", "desc": "高廪窖藏田租与官物，并衔接传舍转输", "max": 5, "base": {"wood": 72, "stone": 58, "coins": 480}},
	"barracks": {"name": "武库营", "glyph": "武", "desc": "武库检修兵车器，训练材官、蹶张士和骑士", "max": 5, "base": {"grain": 100, "wood": 96, "stone": 54, "coins": 980}},
	"wall": {"name": "郡塞亭障", "glyph": "障", "desc": "营缮郡塞、亭障与望楼，保护转输和守军", "max": 5, "base": {"grain": 58, "wood": 105, "stone": 138, "coins": 1080}},
}

const UNITS := {
	"militia": {"name": "材官", "enemy_name": "步兵", "glyph": "材", "count_unit": "人", "batch_label": "伍", "batch": 5, "need": 0, "power": 1.45, "ranged": 0.0, "melee": 1.45, "exposure": 0.78, "cost": {"grain": 17, "coins": 320}, "grain_daily": 0.16, "coins_daily": 0.90},
	"archer": {"name": "蹶张士", "enemy_name": "强弩手", "glyph": "张", "count_unit": "人", "batch_label": "伍", "batch": 5, "need": 2, "power": 2.10, "ranged": 2.68, "melee": 0.78, "exposure": 0.47, "cost": {"grain": 24, "wood": 16, "coins": 690}, "grain_daily": 0.19, "coins_daily": 1.55},
	"chariot": {"name": "边郡骑士", "enemy_name": "胡骑", "glyph": "骑", "count_unit": "骑", "batch_label": "队", "batch": 5, "need": 3, "power": 3.02, "ranged": 0.0, "melee": 3.02, "exposure": 0.35, "cost": {"grain": 38, "wood": 15, "stone": 5, "coins": 1340}, "grain_daily": 0.39, "coins_daily": 3.75},
}

const DEFENSE_ORDERS := {
	"steady": {"name": "部曲持营", "glyph": "部", "desc": "部曲分屯，材官持营，攻守无额外修正", "incoming": 1.00, "ranged": 1.00, "melee": 1.00},
	"fortify": {"name": "亭障固守", "glyph": "障", "desc": "敌方杀伤-21%，我方远射-9%、近战-21%", "incoming": 0.79, "ranged": 0.91, "melee": 0.79},
	"volley": {"name": "蹶张列弩", "glyph": "张", "desc": "蹶张远射+43%，近战-15%，敌方杀伤+6%", "incoming": 1.06, "ranged": 1.43, "melee": 0.85},
	"sally": {"name": "骑士驰突", "glyph": "驰", "desc": "近战杀伤+30%，远射-16%，敌方杀伤+21%", "incoming": 1.21, "ranged": 0.84, "melee": 1.30},
}

const ENEMY_WAVES := [
	{"name": "山泽群盗", "militia": 90, "archer": 38, "chariot": 15, "morale": 72.0, "training": 1.14},
	{"name": "豪强部曲", "militia": 100, "archer": 44, "chariot": 15, "morale": 76.0, "training": 1.17},
	{"name": "匈奴游骑", "militia": 82, "archer": 48, "chariot": 35, "morale": 79.0, "training": 1.20},
	{"name": "羌骑前锋", "militia": 94, "archer": 52, "chariot": 35, "morale": 82.0, "training": 1.23},
	{"name": "西域叛军", "militia": 114, "archer": 58, "chariot": 30, "morale": 85.0, "training": 1.26},
	{"name": "边郡合围军", "militia": 128, "archer": 64, "chariot": 35, "morale": 88.0, "training": 1.29},
]
const LATE_ENEMY_NAMES := ["塞外游骑", "羌胡合军", "豪强转粮部曲"]

const EVENTS := [
	{"id": "drought", "title": "沟洫失水", "body": "田官报称代田沟洫水势不足，若不及时发材修治，田租入廪将受影响。", "options": ["调徒修洫", "开廪赈户"], "seasons": ["summer", "autumn"]},
	{"id": "refugees", "title": "流民归里", "body": "邻郡灾民携带户籍残牍来到城下，请求编入青禾里坊。", "options": ["占田著籍", "给粟还乡"]},
	{"id": "merchant", "title": "西域胡商", "body": "持传胡商带来良种与铁器，愿用五铢钱换取本地廪粟。", "options": ["购种置器", "发粟收钱", "闭市不易"]},
	{"id": "scouts", "title": "候望见骑", "body": "塞外尘起，候官疑有游骑窥伺亭障与转输道路。", "options": ["遣骑候望", "闭障断道"]},
	{"id": "harvest", "title": "田租丰入", "body": "秋租入廪多于常岁，郡吏请示充实太仓，或出粟宴饮安民。", "options": ["实廪备边", "赐粟同乐"], "seasons": ["spring", "autumn"]},
	{"id": "flood", "title": "河防告急", "body": "河水漫过陂渠，急修堤防可反引水肥田，否则只能舍弃低田保太仓。", "options": ["发材筑堤", "弃田护廪"], "seasons": ["summer"]},
	{"id": "winter_relief", "title": "郡国赈贷", "body": "大雪闭塞传舍，贫户缺粟。县廷可依户赈贷，亦可封廪自守。", "options": ["计户赈贷", "封廪候春"], "seasons": ["winter"]},
	{"id": "craftsmen", "title": "武库募工", "body": "善制弩机、瓦当的工匠经过青禾，武库与陶窑都请求留用。", "options": ["给钱安工", "役作城砖"], "seasons": ["spring", "summer"]},
	{"id": "rumors", "title": "市肆边谣", "body": "市中盛传匈奴已越塞，未经候官核实便引起里坊惊惧。", "options": ["遣吏验报", "任其自息"]},
	{"id": "levy", "title": "都尉征调", "body": "都尉府要求青禾出粟钱支援边军；若拒绝，下一股游骑或将提前抵达。", "options": ["输粟佐边", "上书缓调"], "seasons": ["autumn", "winter"]},
]

const TERMS := {
	"population": "编户", "residents": "吏民", "army": "郡兵", "army_registry": "兵籍", "wounded": "伤兵",
	"civilian_food": "编户口粮", "army_food": "郡兵军食", "army_pay": "军费五铢", "wounded_food": "伤兵给粟", "wounded_care": "医药钱",
	"tax": "租赋", "farm_yield": "田租入廪", "wood_yield": "官材入署", "stone_yield": "砖瓦入场",
	"ledger_title": "郡县上计", "ledger_desc": "田租、口粮、军食、军费与转输逐日入簿",
	"market_title": "市肆平准", "market_desc": "市掾以五铢钱平准交易；仓容不足时整笔不成交",
	"military_title": "都尉治兵", "military_desc": "兵籍、军食、伤兵、转输与塞外军报均可追溯",
	"enemy_intel": "候官军报", "battle_forecast": "都尉料敌", "roster": "兵籍与伤营", "defense_order": "都尉军令",
	"patrol_name": "出障候望", "patrol_action": "遣骑", "recruit_action": "募士", "recruit_verb": "募士",
	"build_tab": "营缮", "trade_tab": "平准", "military_tab": "都尉", "governance_tab": "郡政",
	"build_action": "营缮", "upgrade_action": "增修", "governance_title": "郡县治事", "governance_desc": "郡城营缮与汉制经略分别成长，农战边功共同推动下个时代",
	"era_progress": "汉制经略", "day_ledger": "上计日簿", "victory_title": "亭障奏捷", "defeat_title": "胡骑入塞", "provisions": "军食", "pay": "军费",
}
const LOGISTICS := {
	"name": "传舍转输", "unit": "载", "desc": "太仓、山泽署和市肆维系传舍转输；边郡骑士与强弩器械负载更高",
	"base_capacity": 58.0, "warehouse_capacity": 33.0, "woodcut_capacity": 12.0, "market_capacity": 7.0,
	"load": {"militia": 1.0, "archer": 1.5, "chariot": 2.8}, "patrol_cost": {"grain": 9, "coins": 80}, "patrol_minimum": 10,
	"ready": "传舍通达", "strained": "转输迟滞", "critical": "粮道将绝",
}
const ECONOMY := {"production": {"grain": 1.18, "wood": 1.16, "stone": 1.18, "coins": 1.20}, "grain_capacity_base": 1600.0, "grain_capacity_per_warehouse": 1000.0, "material_capacity_base": 460.0, "material_capacity_per_warehouse": 330.0, "coins_capacity_base": 7000.0, "coins_capacity_per_warehouse": 3500.0, "population_base": 110, "population_per_house": 70, "army_base": 40, "army_per_barracks": 26}
const TRADE_LABELS := {"sell_grain": "廪粟出市", "buy_grain": "籴粟实廪", "sell_wood": "官材发卖", "buy_stone": "市买城砖", "action": "平准"}
const POLICIES := {
	"irrigate": {"name": "推行代田", "effect": "三日廪粟增产35%", "glyph": "代", "notice": "代田沟洫修成：三日内廪粟增产"},
	"tax_relief": {"name": "轻田租算赋", "effect": "编户与民心上升", "glyph": "租", "notice": "田租算赋从轻：编户归心"},
	"reward_army": {"name": "赐酒劳军", "effect": "民心上升，伤兵提前归队", "glyph": "酒", "notice": "赐酒劳军：郡兵振奋，伤兵恢复加快"},
}
const NARRATIVE := {"transition": "汉承秦制而务在休养。青禾整顿编户里坊、代田沟洫、太仓武库和传舍转输，五铢钱与斛量进入郡县日常，骑兵也成为边防主力。"}

static func initial_resources() -> Dictionary: return {"grain": 560.0, "wood": 205.0, "stone": 145.0, "coins": 2700.0}
static func initial_buildings() -> Dictionary: return SpringAutumn.initial_buildings()
static func initial_units() -> Dictionary: return {"militia": 35, "archer": 10, "chariot": 5}
static func empty_units() -> Dictionary: return {"militia": 0, "archer": 0, "chariot": 0}

static func definition() -> Dictionary:
	return {"id": ID, "display_name": DISPLAY_NAME, "next_id": NEXT_ID, "city_levels": CITY_LEVELS, "era_growth": ERA_GROWTH, "visual": VISUAL, "seasons": SEASONS, "resource_units": RESOURCE_UNITS, "buildings": BUILDINGS, "units": UNITS, "defense_orders": DEFENSE_ORDERS, "enemy_waves": ENEMY_WAVES, "late_enemy_names": LATE_ENEMY_NAMES, "events": EVENTS, "terms": TERMS, "logistics": LOGISTICS, "economy": ECONOMY, "trade_labels": TRADE_LABELS, "policies": POLICIES, "narrative": NARRATIVE, "initial_resources": initial_resources(), "initial_buildings": initial_buildings(), "initial_units": initial_units(), "empty_units": empty_units()}
