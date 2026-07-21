extends RefCounted

const SpringAutumn = preload("res://src/data/eras/spring_autumn.gd")

const ID := "tang"
const DISPLAY_NAME := "唐"
const NEXT_ID := "five_dynasties"

const CITY_LEVELS := [
	{"level": 1, "name": "乡里", "slots": 6, "advance_target": 470, "view_scale": 1.00},
	{"level": 2, "name": "县城", "slots": 9, "advance_target": 720, "view_scale": 1.12},
	{"level": 3, "name": "州治", "slots": 12, "advance_target": 985, "view_scale": 1.24},
	{"level": 4, "name": "上州城", "slots": 12, "advance_target": 1265, "view_scale": 1.34},
	{"level": 5, "name": "都护雄城", "slots": 12, "advance_target": 1560, "view_scale": 1.44},
]

const ERA_GROWTH := {"target": 3200, "minimum_city_level": 5, "daily": 12, "building_base": 31, "city_level": 164, "battle_victory": 122, "patrol_victory": 26}
const VISUAL := {"tint": Color("#f0e5d6"), "background": "res://assets/art/terrain_only/city_tang_terrain_only.png", "map_hint": "唐代州城采用自由营造格局，可左右拖动巡视折冲府、漕仓、驿馆与胡商骆驼队", "identity": {"earth": Color(0.45, 0.33, 0.25, 0.66), "standard": Color("#a84635"), "motif": "tang_ward"}}
const SEASONS := SpringAutumn.SEASONS

const RESOURCE_UNITS := {
	"grain": {"name": "租庸粟", "short": "粟", "unit": "斛", "glyph": "租"},
	"wood": {"name": "营造木", "short": "木", "unit": "车", "glyph": "木"},
	"stone": {"name": "州城砖", "short": "砖", "unit": "方", "glyph": "城"},
	"coins": {"name": "开元通宝", "short": "钱", "unit": "文", "glyph": "开"},
}

const BUILDINGS := {
	"farm": {"name": "均田渠陌", "glyph": "均", "desc": "修治渠陌与官田，按籍收纳租庸粟供州仓军府", "max": 5, "base": {"wood": 104, "stone": 45, "coins": 980}},
	"woodcut": {"name": "山泽作场", "glyph": "泽", "desc": "采办营造木与牧草，供应车船、坊门和军械", "max": 5, "base": {"grain": 78, "stone": 43, "coins": 1140}},
	"quarry": {"name": "砖瓦窑场", "glyph": "窑", "desc": "烧制青砖瓦件，营缮州署、坊墙、寺观和城楼", "max": 5, "base": {"grain": 100, "wood": 82, "coins": 1350}},
	"house": {"name": "州城里坊", "glyph": "坊", "desc": "以坊墙、街衢和户籍安置百姓、商旅与军户", "max": 5, "base": {"wood": 142, "stone": 82, "coins": 1300}},
	"market": {"name": "东西市", "glyph": "市", "desc": "汇聚州县商贾与丝路胡商，以开元通宝计价互易", "max": 5, "base": {"wood": 154, "stone": 88, "coins": 1600}},
	"warehouse": {"name": "漕运州仓", "glyph": "仓", "desc": "登记租庸粟、贡物与军资，衔接漕渠、馆驿和边镇", "max": 5, "base": {"wood": 140, "stone": 110, "coins": 1200}},
	"barracks": {"name": "折冲府", "glyph": "冲", "desc": "校阅府兵、强弩手与轻骑，管理兵籍、甲械与番上", "max": 5, "base": {"grain": 194, "wood": 184, "stone": 106, "coins": 2420}},
	"wall": {"name": "州城关塞", "glyph": "塞", "desc": "修筑坊门、城楼、瓮城与烽候，拱卫漕仓和商旅", "max": 5, "base": {"grain": 112, "wood": 200, "stone": 260, "coins": 2600}},
}

const UNITS := {
	"militia": {"name": "府兵", "enemy_name": "步军", "glyph": "府", "count_unit": "人", "batch_label": "伍", "batch": 5, "need": 0, "power": 2.22, "ranged": 0.0, "melee": 2.22, "exposure": 0.65, "cost": {"grain": 34, "coins": 960}, "grain_daily": 0.26, "coins_daily": 2.05},
	"archer": {"name": "强弩手", "enemy_name": "弓弩兵", "glyph": "弩", "count_unit": "人", "batch_label": "伍", "batch": 5, "need": 2, "power": 3.20, "ranged": 4.04, "melee": 1.22, "exposure": 0.36, "cost": {"grain": 46, "wood": 31, "coins": 1760}, "grain_daily": 0.32, "coins_daily": 3.40},
	"chariot": {"name": "轻骑", "enemy_name": "蕃骑", "glyph": "骑", "count_unit": "骑", "batch_label": "队", "batch": 5, "need": 3, "power": 4.66, "ranged": 0.0, "melee": 4.66, "exposure": 0.21, "cost": {"grain": 74, "wood": 30, "stone": 10, "coins": 3360}, "grain_daily": 0.68, "coins_daily": 8.25},
}

const DEFENSE_ORDERS := {
	"steady": {"name": "折冲列阵", "glyph": "冲", "desc": "步弩轻骑依府列阵，攻守无额外修正", "incoming": 1.00, "ranged": 1.00, "melee": 1.00},
	"fortify": {"name": "坊城固守", "glyph": "坊", "desc": "敌方杀伤-26%，我方远射-6%、近战-27%", "incoming": 0.74, "ranged": 0.94, "melee": 0.73},
	"volley": {"name": "强弩迭射", "glyph": "迭", "desc": "弓弩远射+54%，近战-20%，敌方杀伤+9%", "incoming": 1.09, "ranged": 1.54, "melee": 0.80},
	"sally": {"name": "轻骑卷击", "glyph": "骑", "desc": "近战杀伤+43%，远射-21%，敌方杀伤+26%", "incoming": 1.26, "ranged": 0.79, "melee": 1.43},
}

const ENEMY_WAVES := [
	{"name": "山泽群盗", "militia": 136, "archer": 60, "chariot": 28, "morale": 74.0, "training": 1.15},
	{"name": "突厥蕃骑", "militia": 110, "archer": 62, "chariot": 68, "morale": 77.0, "training": 1.18},
	{"name": "叛镇州兵", "militia": 150, "archer": 72, "chariot": 42, "morale": 80.0, "training": 1.21},
	{"name": "草原骑军", "militia": 116, "archer": 70, "chariot": 82, "morale": 83.0, "training": 1.24},
	{"name": "边镇入寇军", "militia": 166, "archer": 84, "chariot": 54, "morale": 86.0, "training": 1.27},
	{"name": "藩镇会战军", "militia": 190, "archer": 94, "chariot": 62, "morale": 89.0, "training": 1.30},
]
const LATE_ENEMY_NAMES := ["边塞游军", "蕃骑余部", "藩镇转饷军"]

const EVENTS := [
	{"id": "drought", "title": "渠陌少水", "body": "州城均田渠陌久旱，若不发营造木疏浚，租庸粟与军粮都将减收。", "options": ["发役通渠", "开仓赈户"], "seasons": ["summer", "autumn"]},
	{"id": "refugees", "title": "流户入坊", "body": "边地流户与远来商旅抵达坊门，请求著籍授田并在州城定居。", "options": ["检籍授田", "给粟遣行"]},
	{"id": "merchant", "title": "西市胡商", "body": "胡商驼队带来良马和农具，愿以开元通宝换取漕运州仓余粟。", "options": ["购置器马", "发粟收钱", "闭市谢客"]},
	{"id": "scouts", "title": "烽候见尘", "body": "边塞烽候发现成队骑军窥探驿路与漕仓，折冲府尚未核明来路。", "options": ["遣骑候望", "闭塞断道"]},
	{"id": "harvest", "title": "租庸丰入", "body": "州仓租庸粟充足，可封仓备边，也可赐粟安抚府兵与里坊百姓。", "options": ["实仓备边", "赐粟安众"], "seasons": ["spring", "autumn"]},
	{"id": "flood", "title": "漕渠暴涨", "body": "夏雨冲坏州外渠堤，修复可保漕道与田亩，否则只能弃低田护仓。", "options": ["发材筑堤", "弃田护仓"], "seasons": ["summer"]},
	{"id": "winter_relief", "title": "坊中寒赈", "body": "大雪封闭馆驿，里坊流户与商旅缺粮。州府可按籍赈粟，也可封仓守边。", "options": ["按籍给粟", "封仓待春"], "seasons": ["winter"]},
	{"id": "craftsmen", "title": "百工作坊", "body": "善制弓弩、车马具与砖瓦的百工来到东市，州府请求给值留用。", "options": ["给钱安工", "役作州城"], "seasons": ["spring", "summer"]},
	{"id": "rumors", "title": "坊市讹言", "body": "西市流传边军即将入寇，未经烽驿核实已使商旅和百姓不安。", "options": ["遣吏验报", "任其自息"]},
	{"id": "levy", "title": "节度催饷", "body": "边镇催取租庸粟与开元钱支援行军；迟发会使敌军更早迫近州城。", "options": ["馆驿转饷", "申牒缓发"], "seasons": ["autumn", "winter"]},
]

const TERMS := {
	"population": "州县编户", "residents": "坊市军民", "army": "府军", "army_registry": "兵籍", "wounded": "伤兵",
	"civilian_food": "编户口粮", "army_food": "府军粮秣", "army_pay": "军费通宝", "wounded_food": "伤兵给粟", "wounded_care": "伤兵医钱",
	"tax": "租庸调", "farm_yield": "租庸入仓", "wood_yield": "营木入场", "stone_yield": "城砖入窑",
	"ledger_title": "州府度支", "ledger_desc": "租庸、口粮、军费、伤兵与馆驿转输逐日核算",
	"market_title": "东西市互易", "market_desc": "州县商贾与胡商以开元通宝互易；仓容不足时整笔不成交",
	"military_title": "折冲治军", "military_desc": "兵籍、粮秣、伤兵、馆驿与边塞军报均可核验",
	"enemy_intel": "烽驿军报", "battle_forecast": "行军料敌", "roster": "兵籍与伤营", "defense_order": "折冲军令",
	"patrol_name": "出塞候骑", "patrol_action": "遣骑", "recruit_action": "点兵", "recruit_verb": "点兵",
	"build_tab": "营州", "trade_tab": "坊市", "military_tab": "折冲", "governance_tab": "州政",
	"build_action": "营缮", "upgrade_action": "增修", "governance_title": "州府治事", "governance_desc": "州城营缮与大唐经略分别成长，租庸、商路和边功共同积累下一时代",
	"era_progress": "大唐经略", "day_ledger": "度支日簿", "victory_title": "州城奏捷", "defeat_title": "敌军破坊", "provisions": "粮秣", "pay": "军费",
}
const LOGISTICS := {
	"name": "馆驿漕运", "unit": "驮载", "desc": "漕运州仓、山泽作场与东西市支撑馆驿；轻骑马料和强弩器械占用更多驮载",
	"base_capacity": 88.0, "warehouse_capacity": 48.0, "woodcut_capacity": 17.0, "market_capacity": 16.0,
	"load": {"militia": 1.15, "archer": 1.8, "chariot": 4.0}, "patrol_cost": {"grain": 14, "coins": 175}, "patrol_minimum": 10,
	"ready": "馆驿通达", "strained": "转饷迟滞", "critical": "驿粮将绝",
}
const ECONOMY := {"production": {"grain": 1.38, "wood": 1.36, "stone": 1.37, "coins": 1.40}, "grain_capacity_base": 2700.0, "grain_capacity_per_warehouse": 1500.0, "material_capacity_base": 820.0, "material_capacity_per_warehouse": 530.0, "coins_capacity_base": 14000.0, "coins_capacity_per_warehouse": 6150.0, "population_base": 160, "population_per_house": 90, "army_base": 60, "army_per_barracks": 36}
const TRADE_LABELS := {"sell_grain": "租庸粟出仓", "buy_grain": "东西市籴粟", "sell_wood": "营造木发卖", "buy_stone": "漕运州砖", "action": "互易"}
const POLICIES := {
	"irrigate": {"name": "修治均田渠", "effect": "三日租庸粟增产35%", "glyph": "均", "notice": "均田渠修治：三日内租庸粟增产"},
	"tax_relief": {"name": "宽减租庸", "effect": "州县编户与民心上升", "glyph": "庸", "notice": "宽减租庸：里坊编户安定"},
	"reward_army": {"name": "赐宴府军", "effect": "民心上升，伤兵提前归队", "glyph": "宴", "notice": "赐宴府军：将士振奋，伤兵恢复加快"},
}
const NARRATIVE := {"transition": "唐承隋制而更新钱法。青禾扩建里坊、东西市与漕运州仓，折冲府按兵籍番上；开元通宝以文计钱，强弩与机动轻骑沿馆驿漕道往来于州城和边塞。"}

static func initial_resources() -> Dictionary: return {"grain": 1070.0, "wood": 395.0, "stone": 300.0, "coins": 6700.0}
static func initial_buildings() -> Dictionary: return SpringAutumn.initial_buildings()
static func initial_units() -> Dictionary: return {"militia": 60, "archer": 10, "chariot": 5}
static func empty_units() -> Dictionary: return {"militia": 0, "archer": 0, "chariot": 0}

static func definition() -> Dictionary:
	return {"id": ID, "display_name": DISPLAY_NAME, "next_id": NEXT_ID, "city_levels": CITY_LEVELS, "era_growth": ERA_GROWTH, "visual": VISUAL, "seasons": SEASONS, "resource_units": RESOURCE_UNITS, "buildings": BUILDINGS, "units": UNITS, "defense_orders": DEFENSE_ORDERS, "enemy_waves": ENEMY_WAVES, "late_enemy_names": LATE_ENEMY_NAMES, "events": EVENTS, "terms": TERMS, "logistics": LOGISTICS, "economy": ECONOMY, "trade_labels": TRADE_LABELS, "policies": POLICIES, "narrative": NARRATIVE, "initial_resources": initial_resources(), "initial_buildings": initial_buildings(), "initial_units": initial_units(), "empty_units": empty_units()}
