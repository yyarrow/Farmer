extends RefCounted

const SpringAutumn = preload("res://src/data/eras/spring_autumn.gd")

const ID := "song"
const DISPLAY_NAME := "宋"
const NEXT_ID := "yuan"

const CITY_LEVELS := [
	{"level": 1, "name": "草市镇", "slots": 6, "advance_target": 540, "view_scale": 1.00},
	{"level": 2, "name": "县城", "slots": 9, "advance_target": 825, "view_scale": 1.13},
	{"level": 3, "name": "州军城", "slots": 12, "advance_target": 1125, "view_scale": 1.25},
	{"level": 4, "name": "路府", "slots": 12, "advance_target": 1440, "view_scale": 1.35},
	{"level": 5, "name": "江淮重镇", "slots": 12, "advance_target": 1770, "view_scale": 1.45},
]

const ERA_GROWTH := {"target": 2850, "minimum_city_level": 5, "daily": 14, "building_base": 35, "city_level": 188, "battle_victory": 138, "patrol_victory": 30}
const BATTLE_PACING := {"attack_interval_bonus": 1, "post_defeat_bonus": 3}
const VISUAL := {"tint": Color("#dce8df"), "background": "res://assets/art/city_song_terrain.png", "map_hint": "宋代州城沿河开市，可左右拖动巡视圩田、厢坊、转般仓、军寨和城外草市", "identity": {"earth": Color(0.34, 0.40, 0.36, 0.72), "standard": Color("#4f6f68"), "motif": "river_market"}}
const SEASONS := SpringAutumn.SEASONS

const RESOURCE_UNITS := {
	"grain": {"name": "上供米", "short": "米", "unit": "石", "glyph": "漕"},
	"wood": {"name": "山场材", "short": "材", "unit": "车", "glyph": "山"},
	"stone": {"name": "城砖", "short": "砖", "unit": "方", "glyph": "砖"},
	"coins": {"name": "年号钱", "short": "钱", "unit": "文", "glyph": "贯"},
}

const BUILDINGS := {
	"farm": {"name": "圩田水网", "glyph": "圩", "desc": "修筑圩岸陂塘，引水灌田，将上供米汇入沿河仓廪", "max": 5, "base": {"wood": 120, "stone": 52, "coins": 1240}},
	"woodcut": {"name": "山场作坊", "glyph": "山", "desc": "由山场采办木竹，供应舟车、民居、军械与河岸修缮", "max": 5, "base": {"grain": 90, "stone": 50, "coins": 1430}},
	"quarry": {"name": "砖瓦窑务", "glyph": "窑", "desc": "烧造城砖瓦件，维护州城、仓场、桥闸和军寨", "max": 5, "base": {"grain": 114, "wood": 94, "coins": 1680}},
	"house": {"name": "厢坊街巷", "glyph": "厢", "desc": "街巷突破旧坊墙延展，以厢巡和户籍安置商民工匠", "max": 5, "base": {"wood": 164, "stone": 94, "coins": 1620}},
	"market": {"name": "草市榷场", "glyph": "榷", "desc": "城内行铺、城外草市与边地榷场相接，年号钱随货流通", "max": 5, "base": {"wood": 178, "stone": 102, "coins": 1980}},
	"warehouse": {"name": "转般仓", "glyph": "般", "desc": "水陆纲运在此卸纳转般，分储上供米、军粮与官物", "max": 5, "base": {"wood": 162, "stone": 128, "coins": 1500}},
	"barracks": {"name": "将兵军寨", "glyph": "将", "desc": "以将兵法统练乡兵、神臂弓手与马军，核验军额和衣粮", "max": 5, "base": {"grain": 224, "wood": 212, "stone": 124, "coins": 3000}},
	"wall": {"name": "城寨关防", "glyph": "寨", "desc": "联结州城、堡寨、壕堑和烽堠，护住河运仓场与居民街巷", "max": 5, "base": {"grain": 130, "wood": 230, "stone": 302, "coins": 3220}},
}

const UNITS := {
	"militia": {"name": "乡兵", "enemy_name": "州县兵", "glyph": "乡", "count_unit": "人", "batch_label": "队", "batch": 5, "need": 0, "power": 2.58, "ranged": 0.0, "melee": 2.58, "exposure": 0.62, "cost": {"grain": 40, "coins": 1240}, "grain_daily": 0.30, "coins_daily": 2.58},
	"archer": {"name": "神臂弓手", "enemy_name": "强弩军", "glyph": "臂", "count_unit": "人", "batch_label": "队", "batch": 5, "need": 2, "power": 3.72, "ranged": 4.66, "melee": 1.44, "exposure": 0.33, "cost": {"grain": 53, "wood": 36, "coins": 2200}, "grain_daily": 0.37, "coins_daily": 4.18},
	"chariot": {"name": "马军", "enemy_name": "蕃骑", "glyph": "马", "count_unit": "骑", "batch_label": "队", "batch": 5, "need": 3, "power": 5.42, "ranged": 0.0, "melee": 5.42, "exposure": 0.20, "cost": {"grain": 86, "wood": 35, "stone": 12, "coins": 4160}, "grain_daily": 0.79, "coins_daily": 10.10},
}

const DEFENSE_ORDERS := {
	"steady": {"name": "城寨守御", "glyph": "寨", "desc": "乡兵弓手与马军依城寨轮守，攻守无额外修正", "incoming": 1.00, "ranged": 1.00, "melee": 1.00},
	"fortify": {"name": "据险坚守", "glyph": "险", "desc": "敌方杀伤-28%，我方远射-5%、近战-29%", "incoming": 0.72, "ranged": 0.95, "melee": 0.71},
	"volley": {"name": "神臂迭射", "glyph": "臂", "desc": "神臂弓远射+58%，近战-22%，敌方杀伤+9%", "incoming": 1.09, "ranged": 1.58, "melee": 0.78},
	"sally": {"name": "马军踏营", "glyph": "马", "desc": "近战杀伤+47%，远射-23%，敌方杀伤+28%", "incoming": 1.28, "ranged": 0.77, "melee": 1.47},
}

const ENEMY_WAVES := [
	{"name": "山泽寇盗", "militia": 152, "archer": 68, "chariot": 32, "morale": 75.0, "training": 1.17},
	{"name": "边地蕃骑", "militia": 122, "archer": 70, "chariot": 82, "morale": 78.0, "training": 1.20},
	{"name": "邻路叛军", "militia": 166, "archer": 80, "chariot": 50, "morale": 81.0, "training": 1.23},
	{"name": "北地游骑", "militia": 128, "archer": 78, "chariot": 96, "morale": 84.0, "training": 1.26},
	{"name": "强邻南侵军", "militia": 184, "archer": 92, "chariot": 64, "morale": 87.0, "training": 1.29},
	{"name": "诸军会攻", "militia": 212, "archer": 106, "chariot": 72, "morale": 90.0, "training": 1.32},
]
const LATE_ENEMY_NAMES := ["沿淮游军", "北地铁骑", "断纲劫粮军"]

const EVENTS := [
	{"id": "drought", "title": "圩田水浅", "body": "久旱使圩田支港见底，若不调山场材修闸，上供米会在转般前减收。", "options": ["修闸引水", "开仓济农"], "seasons": ["summer", "autumn"]},
	{"id": "refugees", "title": "流民入厢", "body": "边地迁来的农户与手工业者停在草市，请求编入厢坊并分授圩田。", "options": ["编户授业", "给米遣行"]},
	{"id": "merchant", "title": "纲船到市", "body": "纲船带来纸墨、瓷器和年号钱，愿在榷场换取本地米粮与山场材。", "options": ["采办器具", "出米收钱", "停榷核验"]},
	{"id": "scouts", "title": "烽堠急递", "body": "河口烽堠发现游骑窥探仓场，将兵军寨尚未探清其后续兵力。", "options": ["遣马军哨探", "闭寨断津"]},
	{"id": "harvest", "title": "圩田秋成", "body": "新修圩田稻谷丰收，可编纲转般备边，也可留米平价济养厢坊。", "options": ["编纲入仓", "平粜安民"], "seasons": ["spring", "autumn"]},
	{"id": "flood", "title": "江涨圩危", "body": "连雨推高江水，砖木并用可护住圩岸和转般仓，否则须弃外圩保城。", "options": ["合力固圩", "弃圩护仓"], "seasons": ["summer"]},
	{"id": "winter_relief", "title": "厢坊寒赈", "body": "冬运受阻，贫户与退役伤兵缺米。州府可开常平之储，也可封仓待春。", "options": ["按户赈米", "封仓候运"], "seasons": ["winter"]},
	{"id": "craftsmen", "title": "百工投坊", "body": "会造神臂弓、河船和活字印具的工匠来投，窑务与军寨争相延揽。", "options": ["给钱置坊", "役修关寨"], "seasons": ["spring", "summer"]},
	{"id": "rumors", "title": "邸报未明", "body": "草市流传边寨已失的消息，尚未经递铺与军报互证，商旅开始囤米。", "options": ["验报安市", "任其自息"]},
	{"id": "levy", "title": "经略催纲", "body": "经略司催发一纲军粮和年号钱支援沿边城寨，迟缓可能使河路被截。", "options": ["转般应调", "具状缓发"], "seasons": ["autumn", "winter"]},
]

const TERMS := {
	"population": "编户", "residents": "厢坊军民", "army": "寨军", "army_registry": "军额", "wounded": "伤卒",
	"civilian_food": "编户口粮", "army_food": "寨军衣粮", "army_pay": "军俸钱", "wounded_food": "伤卒给米", "wounded_care": "伤卒医药",
	"tax": "两税", "farm_yield": "圩田入仓", "wood_yield": "山材入场", "stone_yield": "城砖入窑",
	"ledger_title": "转运计簿", "ledger_desc": "两税、上供、军粮、军俸与纲运逐日核算",
	"market_title": "草市榷场", "market_desc": "年号钱按文计价；仓容不足时整笔不成交",
	"military_title": "经略治军", "military_desc": "军额、衣粮、伤卒、纲运和沿边军报均可核验",
	"enemy_intel": "烽堠边报", "battle_forecast": "将司料敌", "roster": "军额与伤营", "defense_order": "守御方略",
	"patrol_name": "马军巡边", "patrol_action": "遣哨", "recruit_action": "招刺", "recruit_verb": "招刺",
	"build_tab": "营缮", "trade_tab": "榷市", "military_tab": "经略", "governance_tab": "路府",
	"build_action": "营造", "upgrade_action": "增修", "governance_title": "路府经画", "governance_desc": "州城营缮与路府积累分别成长，农商、纲运与边功共同推动新制",
	"era_progress": "路府积累", "day_ledger": "转运日计", "victory_title": "城寨告捷", "defeat_title": "敌骑入厢", "provisions": "衣粮", "pay": "军俸",
}
const LOGISTICS := {
	"name": "纲运转般", "unit": "纲", "desc": "转般仓、山场和榷场衔接水陆纲运；马军草料与神臂弓械负载最高",
	"base_capacity": 100.0, "warehouse_capacity": 54.0, "woodcut_capacity": 19.0, "market_capacity": 20.0,
	"load": {"militia": 1.25, "archer": 1.92, "chariot": 4.35}, "patrol_cost": {"grain": 16, "coins": 220}, "patrol_minimum": 10,
	"ready": "纲运通济", "strained": "转般迟滞", "critical": "军纲将绝",
}
const ECONOMY := {"production": {"grain": 1.46, "wood": 1.44, "stone": 1.45, "coins": 1.50}, "grain_capacity_base": 3100.0, "grain_capacity_per_warehouse": 1680.0, "material_capacity_base": 950.0, "material_capacity_per_warehouse": 610.0, "coins_capacity_base": 17000.0, "coins_capacity_per_warehouse": 7300.0, "population_base": 180, "population_per_house": 100, "army_base": 68, "army_per_barracks": 40}
const TRADE_LABELS := {"sell_grain": "上供米出仓", "buy_grain": "榷市籴米", "sell_wood": "山场材发卖", "buy_stone": "纲船运砖", "action": "榷易"}
const POLICIES := {
	"irrigate": {"name": "修筑圩闸", "effect": "三日上供米增产35%", "glyph": "圩", "notice": "圩闸修成：三日内上供米增产"},
	"tax_relief": {"name": "倚阁两税", "effect": "编户与民心上升", "glyph": "阁", "notice": "倚阁两税：厢坊编户安定"},
	"reward_army": {"name": "给赐寨军", "effect": "民心上升，伤卒提前归队", "glyph": "赐", "notice": "给赐寨军：守兵振奋，伤卒恢复加快"},
}
const NARRATIVE := {"transition": "藩镇纷争渐定，州县财赋与文书重新归于朝廷。青禾沿江修圩开市，以转般仓衔接水陆纲运；厢坊和草市日益繁盛，将兵军寨却仍要用神臂弓与马军守住漫长边线。"}

static func initial_resources() -> Dictionary: return {"grain": 1260.0, "wood": 465.0, "stone": 355.0, "coins": 8400.0}
static func initial_buildings() -> Dictionary: return SpringAutumn.initial_buildings()
static func initial_units() -> Dictionary: return {"militia": 68, "archer": 11, "chariot": 5}
static func empty_units() -> Dictionary: return {"militia": 0, "archer": 0, "chariot": 0}

static func definition() -> Dictionary:
	return {"id": ID, "display_name": DISPLAY_NAME, "next_id": NEXT_ID, "city_levels": CITY_LEVELS, "era_growth": ERA_GROWTH, "battle_pacing": BATTLE_PACING, "visual": VISUAL, "seasons": SEASONS, "resource_units": RESOURCE_UNITS, "buildings": BUILDINGS, "units": UNITS, "defense_orders": DEFENSE_ORDERS, "enemy_waves": ENEMY_WAVES, "late_enemy_names": LATE_ENEMY_NAMES, "events": EVENTS, "terms": TERMS, "logistics": LOGISTICS, "economy": ECONOMY, "trade_labels": TRADE_LABELS, "policies": POLICIES, "narrative": NARRATIVE, "initial_resources": initial_resources(), "initial_buildings": initial_buildings(), "initial_units": initial_units(), "empty_units": empty_units()}
