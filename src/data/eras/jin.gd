extends RefCounted

const SpringAutumn = preload("res://src/data/eras/spring_autumn.gd")

const ID := "jin"
const DISPLAY_NAME := "晋"
const NEXT_ID := "northern_southern"

const CITY_LEVELS := [
	{"level": 1, "name": "侨置里", "slots": 6, "advance_target": 350, "view_scale": 1.00},
	{"level": 2, "name": "坞壁县", "slots": 9, "advance_target": 540, "view_scale": 1.11},
	{"level": 3, "name": "州郡治", "slots": 12, "advance_target": 745, "view_scale": 1.21},
	{"level": 4, "name": "都督府", "slots": 12, "advance_target": 965, "view_scale": 1.31},
	{"level": 5, "name": "江防雄镇", "slots": 12, "advance_target": 1200, "view_scale": 1.41},
]

const ERA_GROWTH := {"target": 2450, "minimum_city_level": 5, "daily": 9, "building_base": 25, "city_level": 128, "battle_victory": 98, "patrol_victory": 20}
const VISUAL := {"tint": Color("#eee5dc"), "background": "res://assets/art/city_jin_skeleton.png", "map_hint": "晋代州城临河铺展，可左右拖动巡视坞壁、津市与都督军府", "identity": {"earth": Color(0.38, 0.30, 0.25, 0.66), "standard": Color("#95594c"), "motif": "river_gate"}}
const SEASONS := SpringAutumn.SEASONS

const RESOURCE_UNITS := {
	"grain": {"name": "租粟", "short": "粟", "unit": "斛", "glyph": "租"},
	"wood": {"name": "官材", "short": "材", "unit": "车", "glyph": "材"},
	"stone": {"name": "坞砖", "short": "砖", "unit": "方", "glyph": "坞"},
	"coins": {"name": "晋五铢", "short": "钱", "unit": "枚", "glyph": "晋"},
}

const BUILDINGS := {
	"farm": {"name": "占田庄亩", "glyph": "田", "desc": "整顿占田、佃客与水田，向州仓缴纳租粟", "max": 5, "base": {"wood": 72, "stone": 32, "coins": 560}},
	"woodcut": {"name": "山泽材场", "glyph": "泽", "desc": "采办竹木与官材，供应舟楫、坞壁和军械", "max": 5, "base": {"grain": 54, "stone": 30, "coins": 670}},
	"quarry": {"name": "坞砖窑", "glyph": "窑", "desc": "烧制城砖瓦件，营缮州治、坞堡与江防设施", "max": 5, "base": {"grain": 70, "wood": 58, "coins": 810}},
	"house": {"name": "侨户里坊", "glyph": "侨", "desc": "登记南渡流民与土著编户，扩充州郡户籍", "max": 5, "base": {"wood": 98, "stone": 56, "coins": 780}},
	"market": {"name": "津市", "glyph": "津", "desc": "依托渡口汇集舟商、钱帛与山泽物产", "max": 5, "base": {"wood": 108, "stone": 60, "coins": 980}},
	"warehouse": {"name": "州仓", "glyph": "州", "desc": "收纳租粟、户调与江防军资，维系州郡转输", "max": 5, "base": {"wood": 96, "stone": 78, "coins": 710}},
	"barracks": {"name": "都督军府", "glyph": "督", "desc": "统摄州郡兵、强弩手和具装骑，检校武库军簿", "max": 5, "base": {"grain": 134, "wood": 128, "stone": 74, "coins": 1460}},
	"wall": {"name": "坞壁江防", "glyph": "壁", "desc": "修筑坞壁、门楼、江堤与望戍，安置军民流户", "max": 5, "base": {"grain": 78, "wood": 140, "stone": 182, "coins": 1580}},
}

const UNITS := {
	"militia": {"name": "州郡兵", "enemy_name": "步兵", "glyph": "州", "count_unit": "人", "batch_label": "伍", "batch": 5, "need": 0, "power": 1.72, "ranged": 0.0, "melee": 1.72, "exposure": 0.73, "cost": {"grain": 23, "coins": 520}, "grain_daily": 0.20, "coins_daily": 1.24},
	"archer": {"name": "强弩手", "enemy_name": "弩手", "glyph": "弩", "count_unit": "人", "batch_label": "伍", "batch": 5, "need": 2, "power": 2.50, "ranged": 3.18, "melee": 0.94, "exposure": 0.43, "cost": {"grain": 32, "wood": 22, "coins": 1030}, "grain_daily": 0.24, "coins_daily": 2.18},
	"chariot": {"name": "具装骑", "enemy_name": "甲骑", "glyph": "装", "count_unit": "骑", "batch_label": "队", "batch": 5, "need": 3, "power": 3.62, "ranged": 0.0, "melee": 3.62, "exposure": 0.29, "cost": {"grain": 50, "wood": 21, "stone": 7, "coins": 2010}, "grain_daily": 0.49, "coins_daily": 5.30},
}

const DEFENSE_ORDERS := {
	"steady": {"name": "方阵持营", "glyph": "方", "desc": "州军分屯、方阵持营，攻守无额外修正", "incoming": 1.00, "ranged": 1.00, "melee": 1.00},
	"fortify": {"name": "坞壁闭守", "glyph": "壁", "desc": "敌方杀伤-23%，我方远射-8%、近战-24%", "incoming": 0.77, "ranged": 0.92, "melee": 0.76},
	"volley": {"name": "弩手迭射", "glyph": "迭", "desc": "强弩远射+48%，近战-17%，敌方杀伤+7%", "incoming": 1.07, "ranged": 1.48, "melee": 0.83},
	"sally": {"name": "具装驰击", "glyph": "装", "desc": "近战杀伤+35%，远射-18%，敌方杀伤+23%", "incoming": 1.23, "ranged": 0.82, "melee": 1.35},
}

const ENEMY_WAVES := [
	{"name": "流寇坞众", "militia": 112, "archer": 48, "chariot": 20, "morale": 74.0, "training": 1.15},
	{"name": "北地胡骑", "militia": 96, "archer": 50, "chariot": 44, "morale": 77.0, "training": 1.18},
	{"name": "叛镇部曲", "militia": 124, "archer": 60, "chariot": 28, "morale": 80.0, "training": 1.21},
	{"name": "北方具装骑", "militia": 100, "archer": 58, "chariot": 54, "morale": 83.0, "training": 1.24},
	{"name": "江上敌国军", "militia": 136, "archer": 68, "chariot": 38, "morale": 86.0, "training": 1.27},
	{"name": "南北合围军", "militia": 154, "archer": 76, "chariot": 44, "morale": 89.0, "training": 1.30},
]
const LATE_ENEMY_NAMES := ["江淮游军", "北地余骑", "坞主转饷部曲"]

const EVENTS := [
	{"id": "drought", "title": "庄亩失灌", "body": "占田庄亩的支渠久未疏浚，佃户请州府调材修水，否则租粟将减。", "options": ["发役修渠", "开仓赈户"], "seasons": ["summer", "autumn"]},
	{"id": "refugees", "title": "流民南渡", "body": "北方流民乘舟抵达津口，请求侨置入籍并在坞壁内安居。", "options": ["侨置著籍", "给粟遣行"]},
	{"id": "merchant", "title": "江上舟商", "body": "舟商载来竹木与农具，愿以晋五铢换取州仓租粟。", "options": ["购具留商", "发粟收钱", "闭津不易"]},
	{"id": "scouts", "title": "江防烽报", "body": "江北尘烟骤起，望戍疑有敌骑正在试探渡口和坞门。", "options": ["遣候过江", "闭津断渡"]},
	{"id": "harvest", "title": "户调租丰", "body": "州仓收到丰足租粟，官吏请示尽数封储，或出粟安抚侨旧军民。", "options": ["实仓备边", "赐粟安众"], "seasons": ["spring", "autumn"]},
	{"id": "flood", "title": "江堤决口", "body": "暴涨江水冲开堤段，修防可保庄亩与津道，否则只能弃低田护州仓。", "options": ["发材筑堤", "弃田护仓"], "seasons": ["summer"]},
	{"id": "winter_relief", "title": "侨户寒赈", "body": "大雪封渡，新置侨户缺粮。州府可依籍赈粟，也可闭仓守备。", "options": ["按籍给粟", "封仓待春"], "seasons": ["winter"]},
	{"id": "craftsmen", "title": "坞壁募工", "body": "流民中有善造弩机、砖瓦与舟楫的工匠，都督府请求留用。", "options": ["给钱安工", "役作坞壁"], "seasons": ["spring", "summer"]},
	{"id": "rumors", "title": "士庶讹言", "body": "津市传言北军即将渡江，侨旧户籍间的不安迅速蔓延。", "options": ["遣吏验报", "任其自息"]},
	{"id": "levy", "title": "都督征调", "body": "都督府催取租粟与五铢供江防军；缓调会使对岸敌军提前行动。", "options": ["转输应调", "上表缓征"], "seasons": ["autumn", "winter"]},
]

const TERMS := {
	"population": "侨旧编户", "residents": "州郡军民", "army": "州军", "army_registry": "军簿", "wounded": "伤兵",
	"civilian_food": "编户口粮", "army_food": "州军粮秣", "army_pay": "军费五铢", "wounded_food": "伤兵给粟", "wounded_care": "伤兵医钱",
	"tax": "户调", "farm_yield": "租粟入仓", "wood_yield": "官材入场", "stone_yield": "坞砖入窑",
	"ledger_title": "州郡度支", "ledger_desc": "租粟、户调、军粮、伤兵与江防转输逐日入簿",
	"market_title": "津市互易", "market_desc": "舟商以晋五铢互易；仓容不足时整笔不成交",
	"military_title": "都督治军", "military_desc": "军簿、粮秣、伤兵、转输与南北军报均可追溯",
	"enemy_intel": "江防军报", "battle_forecast": "参军料敌", "roster": "军簿与伤营", "defense_order": "都督军令",
	"patrol_name": "出坞巡江", "patrol_action": "遣候", "recruit_action": "点兵", "recruit_verb": "点兵",
	"build_tab": "营坞", "trade_tab": "津市", "military_tab": "都督", "governance_tab": "州政",
	"build_action": "营缮", "upgrade_action": "增修", "governance_title": "州郡治事", "governance_desc": "州城营缮与江左经略分别成长，安置流民和江防战功推动南北新制",
	"era_progress": "江左经略", "day_ledger": "度支日簿", "victory_title": "江防奏捷", "defeat_title": "敌骑入坞", "provisions": "粮秣", "pay": "军费",
}
const LOGISTICS := {
	"name": "州郡转输", "unit": "载", "desc": "州仓、山泽材场与津市支撑水陆转输；具装骑的马铠军粮负载尤高",
	"base_capacity": 70.0, "warehouse_capacity": 39.0, "woodcut_capacity": 14.0, "market_capacity": 10.0,
	"load": {"militia": 1.05, "archer": 1.65, "chariot": 3.3}, "patrol_cost": {"grain": 11, "coins": 110}, "patrol_minimum": 10,
	"ready": "水陆通达", "strained": "转输壅滞", "critical": "粮道不继",
}
const ECONOMY := {"production": {"grain": 1.26, "wood": 1.24, "stone": 1.25, "coins": 1.27}, "grain_capacity_base": 2000.0, "grain_capacity_per_warehouse": 1200.0, "material_capacity_base": 590.0, "material_capacity_per_warehouse": 410.0, "coins_capacity_base": 9500.0, "coins_capacity_per_warehouse": 4500.0, "population_base": 130, "population_per_house": 78, "army_base": 48, "army_per_barracks": 30}
const TRADE_LABELS := {"sell_grain": "租粟出仓", "buy_grain": "津市籴粮", "sell_wood": "官材发卖", "buy_stone": "舟运坞砖", "action": "互易"}
const POLICIES := {
	"irrigate": {"name": "修治庄渠", "effect": "三日租粟增产35%", "glyph": "渠", "notice": "庄渠修治：三日内租粟增产"},
	"tax_relief": {"name": "宽减户调", "effect": "侨旧编户与民心上升", "glyph": "宽", "notice": "宽减户调：侨旧编户安定"},
	"reward_army": {"name": "劳飨州军", "effect": "民心上升，伤兵提前归队", "glyph": "飨", "notice": "劳飨州军：将士振奋，伤兵恢复加快"},
}
const NARRATIVE := {"transition": "三分归晋，而一统旋即陷入乱离。青禾修筑坞壁、侨置流民、整顿州仓津市，以州郡转输维系江防；强弩与具装骑成为南北相争的新军锋。"}

static func initial_resources() -> Dictionary: return {"grain": 740.0, "wood": 270.0, "stone": 200.0, "coins": 4000.0}
static func initial_buildings() -> Dictionary: return SpringAutumn.initial_buildings()
static func initial_units() -> Dictionary: return {"militia": 45, "archer": 10, "chariot": 5}
static func empty_units() -> Dictionary: return {"militia": 0, "archer": 0, "chariot": 0}

static func definition() -> Dictionary:
	return {"id": ID, "display_name": DISPLAY_NAME, "next_id": NEXT_ID, "city_levels": CITY_LEVELS, "era_growth": ERA_GROWTH, "visual": VISUAL, "seasons": SEASONS, "resource_units": RESOURCE_UNITS, "buildings": BUILDINGS, "units": UNITS, "defense_orders": DEFENSE_ORDERS, "enemy_waves": ENEMY_WAVES, "late_enemy_names": LATE_ENEMY_NAMES, "events": EVENTS, "terms": TERMS, "logistics": LOGISTICS, "economy": ECONOMY, "trade_labels": TRADE_LABELS, "policies": POLICIES, "narrative": NARRATIVE, "initial_resources": initial_resources(), "initial_buildings": initial_buildings(), "initial_units": initial_units(), "empty_units": empty_units()}
