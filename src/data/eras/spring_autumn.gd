extends RefCounted

const ID := "spring_autumn"
const DISPLAY_NAME := "春秋"
const NEXT_ID := "warring_states"

const CITY_LEVELS := [
	{"level": 1, "name": "里聚", "slots": 6, "advance_target": 140, "view_scale": 1.00},
	{"level": 2, "name": "邑城", "slots": 7, "advance_target": 235, "view_scale": 1.08},
	{"level": 3, "name": "大邑", "slots": 8, "advance_target": 340, "view_scale": 1.16},
]

const ERA_GROWTH := {
	"target": 1000,
	"minimum_city_level": 3,
	"daily": 4,
	"building_base": 14,
	"city_level": 65,
	"battle_victory": 58,
	"patrol_victory": 10,
}

const VISUAL := {"tint": Color("#ffffff"), "background": "res://assets/art/city_spring.png", "map_hint": "左右拖动巡视城郭"}

const SEASONS := [
	{"id": "spring", "name": "春", "grain": 1.00, "wood": 1.00, "stone": 0.90, "coins": 1.00, "food": 1.00},
	{"id": "summer", "name": "夏", "grain": 1.00, "wood": 1.15, "stone": 1.00, "coins": 1.05, "food": 1.00},
	{"id": "autumn", "name": "秋", "grain": 1.25, "wood": 1.00, "stone": 1.10, "coins": 1.15, "food": 1.00},
	{"id": "winter", "name": "冬", "grain": 0.85, "wood": 0.85, "stone": 1.15, "coins": 0.95, "food": 1.05},
]

const RESOURCE_UNITS := {
	"grain": {"name": "粮秣", "short": "粮", "unit": "石", "glyph": "粟"},
	"wood": {"name": "木料", "short": "木", "unit": "车", "glyph": "木"},
	"stone": {"name": "石料", "short": "石", "unit": "方", "glyph": "石"},
	"coins": {"name": "财货", "short": "钱", "unit": "枚", "glyph": "币"},
}

const BUILDINGS := {
	"farm": {"name": "农田", "glyph": "田", "desc": "灌溉阡陌，增加每日粮秣收获", "max": 5, "base": {"wood": 34, "stone": 12, "coins": 180}},
	"woodcut": {"name": "林场", "glyph": "木", "desc": "轮伐山林，增加每日木料产出", "max": 5, "base": {"grain": 22, "stone": 10, "coins": 220}},
	"quarry": {"name": "石场", "glyph": "石", "desc": "开采石料，用于城防与扩建", "max": 5, "base": {"grain": 30, "wood": 24, "coins": 280}},
	"house": {"name": "民居", "glyph": "舍", "desc": "提高容纳人口与每日赋税", "max": 5, "base": {"wood": 42, "stone": 18, "coins": 250}},
	"market": {"name": "市集", "glyph": "市", "desc": "增加财货收入，改善交易价格", "max": 5, "base": {"wood": 48, "stone": 22, "coins": 350}},
	"warehouse": {"name": "仓廪", "glyph": "仓", "desc": "提高各类物资储量并减少战败损失", "max": 5, "base": {"wood": 40, "stone": 30, "coins": 200}},
	"barracks": {"name": "兵营", "glyph": "兵", "desc": "提高军籍容量、训练与兵种解锁", "max": 5, "base": {"grain": 55, "wood": 55, "stone": 26, "coins": 450}},
	"wall": {"name": "城垣", "glyph": "城", "desc": "限制敌军接战并降低守军伤亡", "max": 5, "base": {"grain": 30, "wood": 60, "stone": 75, "coins": 500}},
}

const UNITS := {
	"militia": {"name": "乡勇", "enemy_name": "戈卒", "glyph": "勇", "batch": 5, "need": 0, "power": 1.0, "ranged": 0.0, "melee": 1.0, "exposure": 1.0, "cost": {"grain": 8, "coins": 120}, "grain_daily": 0.10, "coins_daily": 0.40},
	"archer": {"name": "弓手", "enemy_name": "弓手", "glyph": "弓", "batch": 5, "need": 2, "power": 1.45, "ranged": 1.8, "melee": 0.55, "exposure": 0.62, "cost": {"grain": 12, "wood": 8, "coins": 320}, "grain_daily": 0.12, "coins_daily": 0.80},
	"chariot": {"name": "车士", "enemy_name": "车士", "glyph": "车", "batch": 5, "need": 3, "power": 2.20, "ranged": 0.0, "melee": 2.2, "exposure": 0.48, "cost": {"grain": 20, "wood": 12, "stone": 4, "coins": 650}, "grain_daily": 0.24, "coins_daily": 2.00},
}

# A standing order changes the next siege without inventing another power score.
# The same multipliers feed both the visible forecast and the real battle.
const DEFENSE_ORDERS := {
	"steady": {"name": "持重", "glyph": "衡", "desc": "按常法守城，杀伤与战损均无修正", "incoming": 1.00, "ranged": 1.00, "melee": 1.00},
	"fortify": {"name": "坚壁", "glyph": "守", "desc": "敌方杀伤-16%，我方远射-12%、近战-18%", "incoming": 0.84, "ranged": 0.88, "melee": 0.82},
	"volley": {"name": "雁行", "glyph": "弓", "desc": "弓手远射+32%，近战-12%，敌方杀伤+4%", "incoming": 1.04, "ranged": 1.32, "melee": 0.88},
	"sally": {"name": "锋矢", "glyph": "锋", "desc": "近战杀伤+20%，远射-12%，敌方杀伤+16%", "incoming": 1.16, "ranged": 0.88, "melee": 1.20},
}

const ENEMY_WAVES := [
	{"name": "山泽盗", "militia": 20, "archer": 5, "chariot": 0, "morale": 50.0, "training": 0.92},
	{"name": "流寇合众", "militia": 30, "archer": 10, "chariot": 0, "morale": 56.0, "training": 0.96},
	{"name": "邻邑征粮队", "militia": 36, "archer": 14, "chariot": 5, "morale": 60.0, "training": 1.00},
	{"name": "列国偏师", "militia": 44, "archer": 18, "chariot": 5, "morale": 64.0, "training": 1.04},
	{"name": "边军锐卒", "militia": 52, "archer": 22, "chariot": 10, "morale": 68.0, "training": 1.08},
	{"name": "诸侯联军前锋", "militia": 62, "archer": 28, "chariot": 10, "morale": 72.0, "training": 1.12},
]

const EVENTS := [
	{"id": "drought", "title": "旱意初显", "body": "东渠水位骤降，田间已有龟裂。若不处置，今岁收成恐受影响。", "options": ["疏浚旧渠", "开仓稳民"], "seasons": ["summer", "autumn"]},
	{"id": "refugees", "title": "流民叩关", "body": "邻邑战乱，一队流民携农具来到城下，请求在此安家。", "options": ["接纳入籍", "赈粮送行"]},
	{"id": "merchant", "title": "齐商来访", "body": "远来的商队带着铁制农具，愿以高价换取本地粮草。", "options": ["购置农具", "出售粮草", "婉拒交易"]},
	{"id": "scouts", "title": "烽燧疑云", "body": "斥候发现陌生骑手窥探城防，边境气氛骤然紧张。", "options": ["派斥候反侦", "封关戒严"]},
	{"id": "harvest", "title": "嘉禾同穗", "body": "田中生出双穗嘉禾，百姓认为是丰年的吉兆。", "options": ["入仓备荒", "设宴庆贺"], "seasons": ["spring", "autumn"]},
	{"id": "flood", "title": "河涨侵畴", "body": "连日骤雨，河水漫过低畦。若能及时分洪，来日或可借水肥田。", "options": ["筑堤分洪", "弃畦保仓"], "seasons": ["summer"]},
	{"id": "winter_relief", "title": "朔雪封途", "body": "大雪封住山路，贫户柴米渐绝。仓门外已有乡老冒雪等候。", "options": ["开仓设粥", "闭户自守"], "seasons": ["winter"]},
	{"id": "craftsmen", "title": "百工过邑", "body": "一队失去旧主的匠人路过青禾，精于木石器械，正在寻觅安身之所。", "options": ["厚礼延请", "征作城工"], "seasons": ["spring", "summer"]},
	{"id": "rumors", "title": "市井流言", "body": "市中忽传敌军已破邻邑，真假难辨，人心却先乱了起来。", "options": ["遣吏澄清", "听其自息"]},
	{"id": "levy", "title": "邻侯索粮", "body": "邻侯使者持节入邑，索要粮财助战；若拒绝，边境军情恐会骤紧。", "options": ["备礼周旋", "闭门拒命"], "seasons": ["autumn", "winter"]},
]

static func initial_resources() -> Dictionary:
	return {"grain": 360.0, "wood": 125.0, "stone": 82.0, "coins": 1500.0}

static func initial_buildings() -> Dictionary:
	return {"farm": 1, "woodcut": 1, "quarry": 0, "house": 1, "market": 0, "warehouse": 1, "barracks": 0, "wall": 0}

static func initial_units() -> Dictionary:
	return {"militia": 20, "archer": 0, "chariot": 0}

static func empty_units() -> Dictionary:
	return {"militia": 0, "archer": 0, "chariot": 0}

static func definition() -> Dictionary:
	return {
		"id": ID,
		"display_name": DISPLAY_NAME,
		"next_id": NEXT_ID,
		"city_levels": CITY_LEVELS,
		"era_growth": ERA_GROWTH,
		"visual": VISUAL,
		"seasons": SEASONS,
		"resource_units": RESOURCE_UNITS,
		"buildings": BUILDINGS,
		"units": UNITS,
		"defense_orders": DEFENSE_ORDERS,
		"enemy_waves": ENEMY_WAVES,
		"events": EVENTS,
		"initial_resources": initial_resources(),
		"initial_buildings": initial_buildings(),
		"initial_units": initial_units(),
		"empty_units": empty_units(),
	}
