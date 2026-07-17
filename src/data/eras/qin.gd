extends RefCounted

const SpringAutumn = preload("res://src/data/eras/spring_autumn.gd")

const ID := "qin"
const DISPLAY_NAME := "秦"
const NEXT_ID := "han"

const CITY_LEVELS := [
	{"level": 1, "name": "亭聚", "slots": 6, "advance_target": 230, "view_scale": 1.00},
	{"level": 2, "name": "乡邑", "slots": 9, "advance_target": 360, "view_scale": 1.09},
	{"level": 3, "name": "县治", "slots": 12, "advance_target": 505, "view_scale": 1.18},
	{"level": 4, "name": "郡县", "slots": 12, "advance_target": 665, "view_scale": 1.27},
	{"level": 5, "name": "关塞重城", "slots": 12, "advance_target": 840, "view_scale": 1.36},
]

const ERA_GROWTH := {"target": 1700, "minimum_city_level": 5, "daily": 6, "building_base": 19, "city_level": 92, "battle_victory": 74, "patrol_victory": 14}
const VISUAL := {"tint": Color("#f0dfce"), "background": "res://assets/art/city_qin_skeleton.png", "map_hint": "秦制县城纵深更广，可左右拖动巡视县廷与传舍", "identity": {"earth": Color(0.20, 0.17, 0.15, 0.72), "standard": Color("#26211f"), "motif": "qin_road"}}
const SEASONS := SpringAutumn.SEASONS

const RESOURCE_UNITS := {
	"grain": {"name": "仓粟", "short": "粟", "unit": "斛", "glyph": "粟"},
	"wood": {"name": "工材", "short": "材", "unit": "车", "glyph": "材"},
	"stone": {"name": "城材", "short": "城", "unit": "方", "glyph": "石"},
	"coins": {"name": "半两钱", "short": "钱", "unit": "枚", "glyph": "半"},
}

const BUILDINGS := {
	"farm": {"name": "授田阡陌", "glyph": "田", "desc": "按户授田、整齐阡陌，向县仓稳定输粟", "max": 5, "base": {"wood": 48, "stone": 20, "coins": 300}},
	"woodcut": {"name": "工室材场", "glyph": "工", "desc": "由县工室核发材木，供应城工、兵械与传车", "max": 5, "base": {"grain": 34, "stone": 18, "coins": 370}},
	"quarry": {"name": "城旦作场", "glyph": "作", "desc": "组织城材与夯筑工役，维持关塞县城", "max": 5, "base": {"grain": 46, "wood": 38, "coins": 460}},
	"house": {"name": "编户闾里", "glyph": "户", "desc": "什伍连坐、编列黔首，扩充户籍与赋入", "max": 5, "base": {"wood": 64, "stone": 32, "coins": 430}},
	"market": {"name": "市亭", "glyph": "市", "desc": "由市啬夫平量校价，通行统一半两钱", "max": 5, "base": {"wood": 70, "stone": 36, "coins": 560}},
	"warehouse": {"name": "县仓少内", "glyph": "仓", "desc": "县仓收粟，少内掌钱与公物，并统筹委输", "max": 5, "base": {"wood": 62, "stone": 48, "coins": 380}},
	"barracks": {"name": "县尉营", "glyph": "尉", "desc": "县尉整饬锐士、弩卒和骑士，核验军籍兵械", "max": 5, "base": {"grain": 86, "wood": 82, "stone": 44, "coins": 780}},
	"wall": {"name": "关塞垣", "glyph": "塞", "desc": "增筑夯土垣、门阙与亭燧，压低守卒战损", "max": 5, "base": {"grain": 48, "wood": 90, "stone": 118, "coins": 860}},
}

const UNITS := {
	"militia": {"name": "锐士", "enemy_name": "步卒", "glyph": "锐", "count_unit": "人", "batch_label": "伍", "batch": 5, "need": 0, "power": 1.32, "ranged": 0.0, "melee": 1.32, "exposure": 0.82, "cost": {"grain": 14, "coins": 240}, "grain_daily": 0.14, "coins_daily": 0.72},
	"archer": {"name": "弩卒", "enemy_name": "弩兵", "glyph": "弩", "count_unit": "人", "batch_label": "伍", "batch": 5, "need": 2, "power": 1.92, "ranged": 2.46, "melee": 0.70, "exposure": 0.50, "cost": {"grain": 20, "wood": 14, "coins": 560}, "grain_daily": 0.17, "coins_daily": 1.28},
	"chariot": {"name": "骑士", "enemy_name": "骑卒", "glyph": "骑", "count_unit": "骑", "batch_label": "队", "batch": 5, "need": 3, "power": 2.72, "ranged": 0.0, "melee": 2.72, "exposure": 0.39, "cost": {"grain": 32, "wood": 13, "stone": 5, "coins": 1080}, "grain_daily": 0.34, "coins_daily": 3.05},
}

const DEFENSE_ORDERS := {
	"steady": {"name": "什伍阵", "glyph": "伍", "desc": "什伍相保，按律持阵，攻守无额外修正", "incoming": 1.00, "ranged": 1.00, "melee": 1.00},
	"fortify": {"name": "坚塞", "glyph": "塞", "desc": "敌方杀伤-20%，我方远射-10%、近战-20%", "incoming": 0.80, "ranged": 0.90, "melee": 0.80},
	"volley": {"name": "弩机齐发", "glyph": "机", "desc": "弩卒远射+40%，近战-15%，敌方杀伤+6%", "incoming": 1.06, "ranged": 1.40, "melee": 0.85},
	"sally": {"name": "锐士出关", "glyph": "锐", "desc": "近战杀伤+27%，远射-15%，敌方杀伤+20%", "incoming": 1.20, "ranged": 0.85, "melee": 1.27},
}

const ENEMY_WAVES := [
	{"name": "亡人聚众", "militia": 95, "archer": 40, "chariot": 15, "morale": 74.0, "training": 1.16},
	{"name": "旧国游兵", "militia": 105, "archer": 44, "chariot": 15, "morale": 77.0, "training": 1.18},
	{"name": "逃戍合军", "militia": 114, "archer": 48, "chariot": 20, "morale": 80.0, "training": 1.21},
	{"name": "北地胡骑", "militia": 102, "archer": 50, "chariot": 30, "morale": 83.0, "training": 1.23},
	{"name": "关东反秦军", "militia": 124, "archer": 56, "chariot": 25, "morale": 86.0, "training": 1.26},
	{"name": "楚地义军前锋", "militia": 138, "archer": 62, "chariot": 30, "morale": 88.0, "training": 1.29},
]
const LATE_ENEMY_NAMES := ["关东游军", "戍卒会师", "楚军转粮队"]

const EVENTS := [
	{"id": "drought", "title": "县渠壅塞", "body": "田啬夫报称支渠淤塞，黔首所授之田已有干裂。县廷须在发粟与征工之间作出裁断。", "options": ["发工疏渠", "启仓赈粟"], "seasons": ["summer", "autumn"]},
	{"id": "refugees", "title": "黔首徙入", "body": "新并郡县的数户黔首携农具抵达亭门，请求编入青禾户籍。", "options": ["验籍授田", "给粟遣行"]},
	{"id": "merchant", "title": "关东贾人", "body": "持验传的贾人运来铁农具，愿以半两钱购换县中仓粟。", "options": ["购置铁器", "发粟易钱", "按律谢绝"]},
	{"id": "scouts", "title": "亭燧警讯", "body": "亭长发现陌生骑从窥测道路，疑有旧国游兵逼近。", "options": ["遣候反侦", "闭关稽查"]},
	{"id": "harvest", "title": "仓律课最", "body": "今岁田租入仓整齐，仓啬夫请示是尽数封廪，还是出粟与民同劳。", "options": ["封检入仓", "赐粟劳民"], "seasons": ["spring", "autumn"]},
	{"id": "flood", "title": "河渠决口", "body": "暴雨冲开渠堤，若即刻发材城筑可保授田，否则只能弃低田护县仓。", "options": ["发材塞决", "弃田护仓"], "seasons": ["summer"]},
	{"id": "winter_relief", "title": "寒令赈恤", "body": "大寒断道，里典呈报贫户无薪。县廷可依仓律给粟，也可闭仓待春。", "options": ["计口给粟", "封仓待春"], "seasons": ["winter"]},
	{"id": "craftsmen", "title": "工室缺匠", "body": "新徙来的百工精于弩机和木作，工室请求留用以补城工。", "options": ["给值留工", "发作城垣"], "seasons": ["spring", "summer"]},
	{"id": "rumors", "title": "里中妖言", "body": "市亭流传关东已反，真假未明却使黔首惶惶。", "options": ["县吏核验", "听其自止"]},
	{"id": "levy", "title": "郡守发戍", "body": "郡府传书，令青禾备粟钱支持北地戍卒；拒命将使关塞压力骤增。", "options": ["具粟应书", "申诉缓发"], "seasons": ["autumn", "winter"]},
]

const TERMS := {
	"population": "黔首", "residents": "编户", "army": "县卒", "army_registry": "卒籍", "wounded": "伤卒",
	"civilian_food": "黔首口粮", "army_food": "戍卒军食", "army_pay": "军用半两", "wounded_food": "伤卒给粟", "wounded_care": "伤卒医钱",
	"tax": "赋入", "farm_yield": "田租入仓", "wood_yield": "工材入室", "stone_yield": "城材入作",
	"ledger_title": "县廷计簿", "ledger_desc": "田租、口粮、军食、军用与委输逐日核算",
	"market_title": "市亭平量", "market_desc": "市亭校正斛量与半两；仓容不足时整笔不成交",
	"military_title": "县尉勒卒", "military_desc": "卒籍、军食、伤卒、委输与来敌什伍均可核验",
	"enemy_intel": "亭燧军报", "battle_forecast": "县尉料敌", "roster": "卒籍与伤卒", "defense_order": "县尉军令",
	"patrol_name": "出亭巡徼", "patrol_action": "发卒", "recruit_action": "发籍", "recruit_verb": "发籍",
	"build_tab": "县工", "trade_tab": "市亭", "military_tab": "县尉", "governance_tab": "县廷",
	"build_action": "营作", "upgrade_action": "增筑", "governance_title": "县廷治事", "governance_desc": "县治营作与一统积累分别推进，田战之功共同促成汉制",
	"era_progress": "一统积累", "day_ledger": "县廷日计", "victory_title": "关塞告捷", "defeat_title": "敌入亭鄣", "provisions": "军食", "pay": "军用",
}
const LOGISTICS := {
	"name": "委输载粟", "unit": "载", "desc": "县仓、工室与市亭共同组织委输；弩机和骑队会显著增加载粟压力",
	"base_capacity": 52.0, "warehouse_capacity": 30.0, "woodcut_capacity": 11.0, "market_capacity": 5.0,
	"load": {"militia": 1.0, "archer": 1.45, "chariot": 2.6}, "patrol_cost": {"grain": 8, "coins": 65}, "patrol_minimum": 10,
	"ready": "委输有序", "strained": "载粟吃紧", "critical": "长挽不继",
}
const ECONOMY := {"production": {"grain": 1.10, "wood": 1.10, "stone": 1.12, "coins": 1.10}, "grain_capacity_base": 1400.0, "grain_capacity_per_warehouse": 900.0, "material_capacity_base": 400.0, "material_capacity_per_warehouse": 290.0, "coins_capacity_base": 6000.0, "coins_capacity_per_warehouse": 3000.0, "population_base": 100, "population_per_house": 65, "army_base": 35, "army_per_barracks": 24}
const TRADE_LABELS := {"sell_grain": "发粟易钱", "buy_grain": "籴粟入仓", "sell_wood": "工材出室", "buy_stone": "购入城材", "action": "市易"}
const POLICIES := {
	"irrigate": {"name": "修治田渠", "effect": "三日仓粟增产35%", "glyph": "渠", "notice": "田渠修治：三日内仓粟增产"},
	"tax_relief": {"name": "缓征口赋", "effect": "黔首与民心上升", "glyph": "缓", "notice": "缓征口赋：黔首安定，户籍渐实"},
	"reward_army": {"name": "赐爵劳军", "effect": "民心上升，伤卒提前归队", "glyph": "爵", "notice": "赐爵劳军：锐士振奋，伤卒恢复加快"},
}
const NARRATIVE := {"transition": "海内一统，郡县奉行书同文、车同轨与统一度量。青禾改设县廷、县仓、市亭和委输体系，以半两钱、斛量与秦军什伍治理新县。"}

static func initial_resources() -> Dictionary: return {"grain": 480.0, "wood": 175.0, "stone": 120.0, "coins": 2200.0}
static func initial_buildings() -> Dictionary: return SpringAutumn.initial_buildings()
static func initial_units() -> Dictionary: return {"militia": 30, "archer": 5, "chariot": 0}
static func empty_units() -> Dictionary: return {"militia": 0, "archer": 0, "chariot": 0}

static func definition() -> Dictionary:
	return {"id": ID, "display_name": DISPLAY_NAME, "next_id": NEXT_ID, "city_levels": CITY_LEVELS, "era_growth": ERA_GROWTH, "visual": VISUAL, "seasons": SEASONS, "resource_units": RESOURCE_UNITS, "buildings": BUILDINGS, "units": UNITS, "defense_orders": DEFENSE_ORDERS, "enemy_waves": ENEMY_WAVES, "late_enemy_names": LATE_ENEMY_NAMES, "events": EVENTS, "terms": TERMS, "logistics": LOGISTICS, "economy": ECONOMY, "trade_labels": TRADE_LABELS, "policies": POLICIES, "narrative": NARRATIVE, "initial_resources": initial_resources(), "initial_buildings": initial_buildings(), "initial_units": initial_units(), "empty_units": empty_units()}
