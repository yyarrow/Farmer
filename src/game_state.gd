extends Node

signal changed
signal notice(message: String)
signal event_started(event: Dictionary)
signal battle_finished(result: Dictionary)
signal visual_event(kind: String, payload: Dictionary)
signal save_slots_changed
signal time_state_changed

const LEGACY_SAVE_PATH := "user://qinghe_save.json"
const SAVE_DIR := "user://saves"
const AUTO_SAVE_PATH := "user://saves/autosave.json"
const SLOT_COUNT := 3
const FORMAT_VERSION := 3
const DAY_SECONDS := 24.0
const MAX_OFFLINE_SECONDS := 7200.0
const OFFLINE_DAY_SECONDS := 300.0
const MAX_ENEMY_TIER := 8
const FINAL_ENEMY_WAVE := 13
const DAYS_PER_SEASON := 12
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
	"militia": {"name": "乡勇", "glyph": "勇", "batch": 5, "need": 0, "power": 1.0, "ranged": 0.0, "melee": 1.0, "exposure": 1.0, "cost": {"grain": 8, "coins": 120}, "grain_daily": 0.10, "coins_daily": 0.40},
	"archer": {"name": "弓手", "glyph": "弓", "batch": 5, "need": 2, "power": 1.45, "ranged": 1.8, "melee": 0.55, "exposure": 0.62, "cost": {"grain": 12, "wood": 8, "coins": 320}, "grain_daily": 0.12, "coins_daily": 0.80},
	"chariot": {"name": "车士", "glyph": "车", "batch": 5, "need": 3, "power": 2.20, "ranged": 0.0, "melee": 2.2, "exposure": 0.48, "cost": {"grain": 20, "wood": 12, "stone": 4, "coins": 650}, "grain_daily": 0.24, "coins_daily": 2.00},
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

var resources := {"grain": 360.0, "wood": 125.0, "stone": 82.0, "coins": 1500.0}
var buildings := {"farm": 1, "woodcut": 1, "quarry": 0, "house": 1, "market": 0, "warehouse": 1, "barracks": 0, "wall": 0}
var units := {"militia": 20, "archer": 0, "chariot": 0}
var wounded := {"militia": 0, "archer": 0, "chariot": 0}
var recovery_queue: Array = []
var population := 110
var morale := 70.0
var current_day := 1
var chapter := 1
var day_progress := 0.0
var next_attack_day := 7
var attack_wave := 1
var enemy_army: Dictionary = {}
var defense_order := "steady"
var last_patrol_day := 0
var patrol_delay_wave := 0
var tutorial_seen := false
var current_event: Dictionary = {}
var last_event_id := ""
var buffs := {"farm_until": 0, "all_until": 0}
var offline_report := ""
var last_day_report := ""
var time_speed := 0.0
var modal_paused := false
var persistence_enabled := true
var rng := RandomNumberGenerator.new()
var _change_accum := 0.0
var _save_accum := 0.0

func _ready() -> void:
	rng.randomize()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	_migrate_legacy_save()
	load_game()
	if enemy_army.is_empty():
		enemy_army = _make_enemy_army(attack_wave)
	set_process(true)
	Telemetry.track("game_state_ready", {"day": current_day, "chapter": chapter, "format": FORMAT_VERSION})

func _process(delta: float) -> void:
	var simulation_delta := delta * get_effective_time_speed()
	if simulation_delta > 0.0:
		_tick_economy(simulation_delta)
	_change_accum += delta
	_save_accum += delta
	if _change_accum >= 0.35:
		_change_accum = 0.0
		changed.emit()
	if _save_accum >= 10.0:
		_save_accum = 0.0
		save_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()

func _tick_economy(delta: float) -> void:
	var remaining_seconds := maxf(0.0, delta)
	while remaining_seconds > 0.0001:
		var seconds_to_next_day := maxf(0.0, (1.0 - day_progress) * DAY_SECONDS)
		var step := minf(remaining_seconds, seconds_to_next_day)
		var completed_ledger := get_daily_ledger()
		_produce_resources(step)
		day_progress += step / DAY_SECONDS
		remaining_seconds -= step
		if day_progress < 0.999999:
			break
		day_progress = 0.0
		var siege_due := current_day + 1 >= next_attack_day
		_advance_day(completed_ledger)
		# A long frame must never skip a decision that intentionally stops time.
		if siege_due or not current_event.is_empty():
			break

func _produce_resources(delta: float) -> void:
	var rates := get_rates()
	for key in resources:
		resources[key] = clampf(resources[key] + float(rates.get(key, 0.0)) * delta, 0.0, get_capacity(key))

func get_daily_ledger() -> Dictionary:
	var season := get_season_data()
	var all_bonus := 1.22 if current_day <= int(buffs.get("all_until", 0)) else 1.0
	var farm_bonus := 1.35 if current_day <= int(buffs.get("farm_until", 0)) else 1.0
	var market_bonus := 1.0 + float(buildings.market) * 0.08
	var grain_income: float = 20.0 * buildings.farm * farm_bonus * all_bonus * float(season.grain)
	var wood_income: float = 9.0 * buildings.woodcut * all_bonus * float(season.wood)
	var stone_income: float = 6.0 * buildings.quarry * all_bonus * float(season.stone)
	var tax_income: float = (35.0 * buildings.house + 55.0 * buildings.market + population * 0.25) * market_bonus * all_bonus * float(season.coins)
	var civilian_food := population / 15.0 * float(season.food)
	var army_food := 0.0
	var army_pay := 0.0
	for id in UNITS:
		army_food += int(units[id]) * float(UNITS[id].grain_daily)
		army_pay += int(units[id]) * float(UNITS[id].coins_daily)
	var wounded_count := get_wounded_count()
	var wounded_food := wounded_count * 0.08
	var wounded_care := wounded_count * 0.30
	return {
		"grain": {"income": grain_income, "expense": civilian_food + army_food + wounded_food, "net": grain_income - civilian_food - army_food - wounded_food, "details": [["%s季农收 ×%.2f" % [season.name, season.grain], grain_income], ["百姓口粮 ×%.2f" % season.food, -civilian_food], ["军籍粮秣", -army_food], ["伤员养护", -wounded_food]]},
		"wood": {"income": wood_income, "expense": 0.0, "net": wood_income, "details": [["%s季轮伐 ×%.2f" % [season.name, season.wood], wood_income]]},
		"stone": {"income": stone_income, "expense": 0.0, "net": stone_income, "details": [["%s季开采 ×%.2f" % [season.name, season.stone], stone_income]]},
		"coins": {"income": tax_income, "expense": army_pay + wounded_care, "net": tax_income - army_pay - wounded_care, "details": [["%s季赋税 ×%.2f" % [season.name, season.coins], tax_income], ["军饷", -army_pay], ["伤员医药", -wounded_care]]},
	}

func get_calendar() -> Dictionary:
	var absolute_day := maxi(0, current_day - 1)
	var season_index := int(absolute_day / DAYS_PER_SEASON) % SEASONS.size()
	return {
		"year": int(absolute_day / (DAYS_PER_SEASON * SEASONS.size())) + 1,
		"season_index": season_index,
		"season": SEASONS[season_index].id,
		"season_name": SEASONS[season_index].name,
		"day": absolute_day % DAYS_PER_SEASON + 1,
	}

func get_season_data() -> Dictionary:
	return SEASONS[int(get_calendar().season_index)]

func get_rates() -> Dictionary:
	var ledger := get_daily_ledger()
	return {
		"grain": float(ledger.grain.net) / DAY_SECONDS,
		"wood": float(ledger.wood.net) / DAY_SECONDS,
		"stone": float(ledger.stone.net) / DAY_SECONDS,
		"coins": float(ledger.coins.net) / DAY_SECONDS,
	}

func get_effective_time_speed() -> float:
	return 0.0 if modal_paused else time_speed

func set_time_speed(value: float, reason := "player") -> void:
	var normalized := 0.0
	if value >= 1.5:
		normalized = 2.0
	elif value >= 0.5:
		normalized = 1.0
	if is_equal_approx(time_speed, normalized):
		return
	time_speed = normalized
	changed.emit()
	time_state_changed.emit()
	Telemetry.track("time_speed_changed", {"speed": time_speed, "reason": reason, "day": current_day})

func set_modal_paused(value: bool) -> void:
	if modal_paused == value:
		return
	modal_paused = value
	time_state_changed.emit()

func advance_one_day() -> bool:
	if time_speed > 0.0 or modal_paused or not current_event.is_empty():
		notice.emit("请先暂停时间并处理当前事务")
		return false
	var remaining_seconds := maxf(0.0, (1.0 - day_progress) * DAY_SECONDS)
	var completed_ledger := get_daily_ledger()
	_produce_resources(remaining_seconds)
	day_progress = 0.0
	Telemetry.track("day_advanced_manually", {"from_day": current_day})
	_advance_day(completed_ledger)
	return true

func get_capacity(resource_id: String) -> float:
	var warehouse_level := float(buildings.warehouse)
	match resource_id:
		"grain": return 1200.0 + warehouse_level * 800.0
		"wood", "stone": return 350.0 + warehouse_level * 250.0
		"coins": return 5000.0 + warehouse_level * 2500.0
	return 1000.0

func get_population_cap() -> int:
	return 90 + buildings.house * 60

func get_households() -> int:
	return ceili(float(population + get_army_count() + get_wounded_count()) / 5.0)

func get_total_residents() -> int:
	return population + get_army_count() + get_wounded_count()

func get_army_capacity() -> int:
	return 25 + buildings.barracks * 20

func get_army_count() -> int:
	return int(units.militia) + int(units.archer) + int(units.chariot)

func get_wounded_count() -> int:
	return int(wounded.militia) + int(wounded.archer) + int(wounded.chariot)

func get_training() -> float:
	return 1.0 + buildings.barracks * 0.06

func _morale_factor(value: float) -> float:
	return clampf(0.65 + value / 200.0, 0.70, 1.15)

func _force_power(force: Dictionary, force_morale: float, training: float) -> int:
	var raw := 0.0
	for id in UNITS:
		raw += int(force.get(id, 0)) * float(UNITS[id].power)
	return roundi(raw * _morale_factor(force_morale) * training)

func get_army_power() -> int:
	return _force_power(units, morale, get_training())

func get_defense() -> int:
	return get_army_power()

func get_defense_order_data() -> Dictionary:
	return DEFENSE_ORDERS.get(defense_order, DEFENSE_ORDERS.steady)

func set_defense_order(id: String) -> bool:
	if not DEFENSE_ORDERS.has(id) or id == defense_order:
		return false
	var previous := defense_order
	defense_order = id
	changed.emit()
	notice.emit("守城阵令改为「%s」" % DEFENSE_ORDERS[id].name)
	visual_event.emit("defense_order", {"order": id, "previous": previous})
	Audio.play_sfx("command")
	Telemetry.track("defense_order_changed", {"from": previous, "to": id, "day": current_day, "wave": attack_wave, "army": units.duplicate()})
	save_game()
	return true

func get_enemy_power() -> int:
	if enemy_army.is_empty():
		return 0
	return _force_power(enemy_army, float(enemy_army.morale), float(enemy_army.training))

func get_next_enemy_power() -> int:
	return get_enemy_power()

func days_until_attack() -> int:
	return maxi(0, next_attack_day - current_day)

func get_prosperity() -> int:
	var building_score := 0
	for id in buildings:
		building_score += int(buildings[id]) * 10
	return building_score + roundi(population / 5.0) + get_army_count() + chapter * 10

func get_chapter_target() -> int:
	return 150 + (chapter - 1) * 95

func building_cost(id: String) -> Dictionary:
	var level := int(buildings[id])
	var scale := pow(1.55, level)
	var out := {}
	for key in BUILDINGS[id].base:
		out[key] = ceili(float(BUILDINGS[id].base[key]) * scale)
	return out

func can_afford(cost: Dictionary) -> bool:
	for key in cost:
		if resources.get(key, 0.0) + 0.001 < float(cost[key]):
			return false
	return true

func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		notice.emit("物资不足，请查看每日账本安排生产")
		Telemetry.track("resource_shortage", {"cost": cost, "resources": resources.duplicate()})
		visual_event.emit("shortage", {"cost": cost})
		return false
	for key in cost:
		resources[key] -= float(cost[key])
	return true

func upgrade_building(id: String) -> bool:
	if not BUILDINGS.has(id):
		return false
	var level := int(buildings[id])
	if level >= int(BUILDINGS[id].max):
		notice.emit("此建筑已臻完善")
		return false
	var cost := building_cost(id)
	if not spend(cost):
		return false
	buildings[id] = level + 1
	if id == "house":
		population = mini(get_population_cap() - get_army_count() - get_wounded_count(), population + 5)
	if id == "barracks":
		morale = minf(100.0, morale + 4.0)
	changed.emit()
	var event_kind := "build" if level == 0 else "upgrade"
	notice.emit(("建成 " if level == 0 else "升级 ") + BUILDINGS[id].name)
	visual_event.emit(event_kind, {"building": id, "level": buildings[id]})
	Audio.play_sfx(event_kind)
	Telemetry.track("building_%s" % event_kind, {"building": id, "from": level, "to": buildings[id], "cost": cost})
	save_game()
	return true

func recruit(id: String) -> bool:
	if not UNITS.has(id):
		return false
	var data: Dictionary = UNITS[id]
	if buildings.barracks < int(data.need):
		notice.emit("兵营需要达到 %d 级" % int(data.need))
		return false
	var batch := int(data.batch)
	if get_army_count() + get_wounded_count() + batch > get_army_capacity():
		notice.emit("军籍已满，请升级兵营")
		return false
	if population - batch < 40:
		notice.emit("民间丁口不足，无法继续征募")
		return false
	if not spend(data.cost):
		return false
	population -= batch
	units[id] += batch
	morale = maxf(35.0, morale - 0.5)
	changed.emit()
	notice.emit("征募一伍%s：%d人转入军籍" % [data.name, batch])
	visual_event.emit("recruit", {"unit": id, "count": units[id], "batch": batch})
	Audio.play_sfx("recruit")
	Telemetry.track("unit_recruited", {"unit": id, "batch": batch, "count": units[id], "army_power": get_army_power(), "daily_upkeep": get_daily_ledger()})
	save_game()
	return true

func get_trade_quote(kind: String) -> Dictionary:
	match kind:
		"sell_grain": return {"cost": {"grain": 55}, "gain": {"coins": 340 + buildings.market * 30}}
		"buy_grain": return {"cost": {"coins": maxi(340, 460 - buildings.market * 20)}, "gain": {"grain": 55}}
		"sell_wood": return {"cost": {"wood": 40}, "gain": {"coins": 300 + buildings.market * 20}}
		"buy_stone": return {"cost": {"coins": maxi(380, 500 - buildings.market * 20)}, "gain": {"stone": 35}}
	return {}

func trade(kind: String) -> bool:
	var quote := get_trade_quote(kind)
	if quote.is_empty():
		return false
	for resource in quote.gain:
		var amount := float(quote.gain[resource])
		if float(resources.get(resource, 0.0)) + amount > get_capacity(resource) + 0.001:
			notice.emit("仓容不足：需留出%d%s%s空间，本次不扣款" % [roundi(amount), RESOURCE_UNITS[resource].unit, RESOURCE_UNITS[resource].short])
			visual_event.emit("storage_full", {"resource": resource, "amount": amount})
			Telemetry.track("trade_blocked_capacity", {"kind": kind, "resource": resource, "amount": amount, "stored": resources.get(resource, 0.0), "capacity": get_capacity(resource)})
			return false
	if not spend(quote.cost):
		return false
	for resource in quote.gain:
		resources[resource] += float(quote.gain[resource])
	changed.emit()
	notice.emit("市易完成")
	visual_event.emit("trade", {"trade": kind})
	Audio.play_sfx("trade")
	Telemetry.track("trade_completed", {"kind": kind, "quote": quote, "resources": resources.duplicate()})
	save_game()
	return true

func get_policy_cost(id: String) -> Dictionary:
	match id:
		"irrigate": return {"wood": 35, "stone": 24, "coins": 280}
		"tax_relief": return {"coins": 650, "grain": 35}
		"reward_army": return {"grain": 60, "coins": 450}
	return {}

func get_policy_preview(id: String) -> Dictionary:
	match id:
		"irrigate":
			return {"active_days": maxi(0, current_day + 3 - int(buffs.farm_until))}
		"tax_relief":
			var civilian_room := maxi(0, get_population_cap() - get_army_count() - get_wounded_count() - population)
			return {"population_gain": mini(15, civilian_room), "morale_gain": minf(12.0, 100.0 - morale)}
		"reward_army":
			var expedited_wounded := 0
			for entry in recovery_queue:
				if int(entry.return_day) > current_day + 1:
					expedited_wounded += int(entry.count)
			return {"morale_gain": minf(18.0, 100.0 - morale), "expedited_wounded": expedited_wounded}
	return {}

func get_policy_block_reason(id: String) -> String:
	if get_policy_cost(id).is_empty():
		return "未知政令"
	var preview := get_policy_preview(id)
	if id == "irrigate" and int(preview.active_days) <= 0:
		return "水利增产已达三日"
	if id == "tax_relief":
		if int(preview.population_gain) <= 0 and float(preview.morale_gain) <= 0.001:
			return "民口与民心均已满"
	if id == "reward_army":
		if float(preview.morale_gain) <= 0.001 and int(preview.expedited_wounded) <= 0:
			return "士气已满且伤员无法再提早归队"
	return ""

func enact_policy(id: String) -> bool:
	var block_reason := get_policy_block_reason(id)
	if not block_reason.is_empty():
		notice.emit(block_reason + "，本次不扣物资")
		Telemetry.track("policy_blocked", {"policy": id, "reason": block_reason, "day": current_day})
		return false
	var cost := get_policy_cost(id)
	if not spend(cost):
		return false
	match id:
		"irrigate":
			buffs.farm_until = current_day + 3
			notice.emit("水利修成：三日内粮秣增产")
		"tax_relief":
			population = mini(get_population_cap() - get_army_count() - get_wounded_count(), population + 15)
			morale = minf(100.0, morale + 12.0)
			notice.emit("轻徭薄赋：民心与民口上升")
		"reward_army":
			morale = minf(100.0, morale + 18.0)
			for entry in recovery_queue:
				entry.return_day = maxi(current_day + 1, int(entry.return_day) - 1)
			notice.emit("犒赏三军：士气大振，伤员恢复加快")
	changed.emit()
	visual_event.emit("policy", {"policy": id})
	Audio.play_sfx("event")
	Telemetry.track("policy_enacted", {"policy": id, "day": current_day, "cost": cost})
	save_game()
	return true

func patrol() -> bool:
	if last_patrol_day == current_day:
		notice.emit("今日已派出巡骑")
		return false
	if get_army_count() < 10:
		notice.emit("至少需要十名可战士卒才能出城巡剿")
		return false
	if not spend({"grain": 6, "coins": 40}):
		return false
	last_patrol_day = current_day
	var scout_power := maxf(1.0, get_enemy_power() * 0.55)
	var chance := clampf(0.24 + get_army_power() / (get_army_power() + scout_power) * 0.68, 0.25, 0.88)
	var won := rng.randf() <= chance
	enemy_army.scouted = true
	var player_losses := 0
	var enemy_losses := 0
	var player_loss_detail := {}
	var enemy_losses_by_type := {"militia": 0, "archer": 0, "chariot": 0}
	var delayed := false
	var field_victory := false
	if won:
		enemy_losses = rng.randi_range(2, 5)
		var lost := _deal_losses(enemy_army, enemy_losses, rng)
		enemy_losses = _sum_force(lost)
		enemy_losses_by_type = lost
		if patrol_delay_wave != attack_wave:
			next_attack_day += 1
			patrol_delay_wave = attack_wave
			delayed = true
		morale = minf(100.0, morale + 3.0)
		if _sum_force(enemy_army) <= 0:
			field_victory = true
			attack_wave += 1
			next_attack_day = current_day + _next_attack_interval(true)
			enemy_army = _make_enemy_army(attack_wave)
			notice.emit("巡剿大捷：歼敌%d人（%s），下一支敌军已在集结" % [enemy_losses, _loss_summary(lost, true)])
		else:
			notice.emit("巡剿得胜：敌军折损%d人（%s）%s" % [enemy_losses, _loss_summary(lost, true), "，行军延误一日" if delayed else ""])
		visual_event.emit("patrol_win", {"enemy_losses": enemy_losses, "enemy_losses_by_type": lost, "delayed": delayed, "field_victory": field_victory})
		Audio.play_sfx("battle_win")
	else:
		player_losses = rng.randi_range(1, 3)
		player_loss_detail = _apply_field_losses(player_losses, 0.20)
		morale = maxf(20.0, morale - 5.0)
		notice.emit("巡剿失利：%s，但已探明敌军编成" % _casualty_summary(player_loss_detail.killed, player_loss_detail.wounded))
		visual_event.emit("patrol_loss", {"player_losses": player_losses, "killed": player_loss_detail.killed, "wounded": player_loss_detail.wounded})
		Audio.play_sfx("battle_loss")
	changed.emit()
	Telemetry.track("patrol_resolved", {"won": won, "chance": chance, "player_losses": player_losses, "player_loss_detail": player_loss_detail, "enemy_losses": enemy_losses, "enemy_losses_by_type": enemy_losses_by_type, "delayed": delayed, "field_victory": field_victory, "enemy": enemy_army.duplicate(true)})
	save_game()
	return true

func _advance_day(completed_ledger: Dictionary = {}) -> void:
	current_day += 1
	var recovered := _recover_wounded()
	var ledger := completed_ledger if not completed_ledger.is_empty() else get_daily_ledger()
	last_day_report = "第%d日账：粮 %+.1f石  木 %+.1f车  石 %+.1f方  财 %+.0f枚" % [current_day, ledger.grain.net, ledger.wood.net, ledger.stone.net, ledger.coins.net]
	var civil_food := maxf(1.0, population / 15.0)
	if resources.grain > civil_food * 5.0 and get_total_residents() < get_population_cap() and morale >= 55.0:
		population += 1
	elif resources.grain < civil_food * 0.5:
		var lost_people := maxi(1, roundi(population * 0.02))
		population = maxi(40, population - lost_people)
		morale = maxf(10.0, morale - 7.0)
		notice.emit("粮秣告急：%d名百姓离邑" % lost_people)
	morale = clampf(morale + (0.6 if float(ledger.grain.net) >= 0.0 else -1.2), 10.0, 100.0)
	if current_day >= next_attack_day:
		_resolve_siege()
	elif current_event.is_empty() and current_day % 3 == 0:
		_start_random_event()
	changed.emit()
	visual_event.emit("day", {"ledger": ledger, "recovered": recovered})
	Telemetry.track("day_settled", {"day": current_day, "ledger": ledger, "population": population, "army": units.duplicate(), "wounded": wounded.duplicate()})
	save_game()

func _recover_wounded() -> int:
	var remaining: Array = []
	var recovered := 0
	for entry in recovery_queue:
		if int(entry.return_day) <= current_day:
			var id: String = entry.unit
			var count := int(entry.count)
			wounded[id] = maxi(0, int(wounded[id]) - count)
			units[id] += count
			recovered += count
		else:
			remaining.append(entry)
	recovery_queue = remaining
	if recovered > 0:
		notice.emit("伤营有%d人康复归队" % recovered)
	return recovered

func _start_random_event() -> void:
	set_time_speed(0.0, "random_event")
	var season_id := str(get_calendar().season)
	var available := _events_for_current_season()
	var candidates := available.filter(func(event: Dictionary): return str(event.id) != last_event_id)
	if candidates.is_empty():
		candidates = available
	current_event = candidates[rng.randi_range(0, candidates.size() - 1)].duplicate(true)
	last_event_id = str(current_event.id)
	Audio.play_sfx("event")
	visual_event.emit("event", {"id": current_event.id})
	Telemetry.track("random_event_started", {"id": current_event.id, "day": current_day, "season": season_id})
	event_started.emit(current_event)

func _events_for_current_season() -> Array:
	var season_id := str(get_calendar().season)
	var available: Array = []
	for event in EVENTS:
		if not event.has("seasons") or season_id in event.seasons:
			available.append(event)
	return available

func _event_choice_cost(id: String, choice: int) -> Dictionary:
	match id:
		"drought":
			if choice == 0: return {"wood": 28, "stone": 18}
		"refugees":
			if choice == 0: return {"grain": 58}
		"merchant":
			if choice == 0: return {"coins": 720}
			if choice == 1: return {"grain": 75}
		"scouts":
			if choice == 0: return {"coins": 320}
		"flood":
			if choice == 0: return {"wood": 30, "stone": 18}
		"winter_relief":
			if choice == 0: return {"grain": 42}
		"craftsmen":
			if choice == 0: return {"coins": 480, "wood": 16}
		"rumors":
			if choice == 0: return {"coins": 200}
		"levy":
			if choice == 0: return {"grain": 45, "coins": 220}
	return {}

func get_event_choice_block_reason(choice: int) -> String:
	if current_event.is_empty() or choice < 0 or choice >= int(current_event.get("options", []).size()):
		return "选项无效"
	var id := str(current_event.get("id", ""))
	var cost := _event_choice_cost(id, choice)
	if not cost.is_empty() and not can_afford(cost):
		return "物资不足"
	if id == "refugees" and choice == 0:
		var civilian_room := get_population_cap() - get_army_count() - get_wounded_count() - population
		if civilian_room < 20:
			return "需20人民口空位"
	if id == "merchant" and choice == 1 and resources.coins + 620.0 > get_capacity("coins") + 0.001:
		return "需620枚财货空位"
	return ""

func is_event_choice_available(choice: int) -> bool:
	return get_event_choice_block_reason(choice).is_empty()

func resolve_event(choice: int) -> bool:
	if current_event.is_empty() or choice < 0 or choice >= int(current_event.get("options", []).size()):
		return false
	var block_reason := get_event_choice_block_reason(choice)
	if not block_reason.is_empty():
		notice.emit(block_reason + "，无法执行这项处置")
		Telemetry.track("event_choice_unavailable", {"id": current_event.get("id", ""), "choice": choice, "reason": block_reason, "resources": resources.duplicate()})
		return false
	var id: String = current_event.id
	var cost := _event_choice_cost(id, choice)
	if not cost.is_empty() and not spend(cost):
		return false
	match id:
		"drought":
			if choice == 0:
				buffs.farm_until = current_day + 3
				notice.emit("旧渠复通，农田转危为安")
			else:
				var relief := mini(45, floori(resources.grain))
				resources.grain -= relief
				if relief == 45:
					morale = minf(100.0, morale + 4.0)
					notice.emit("开仓赈济，百姓得以安心")
				else:
					morale = maxf(10.0, morale - 4.0)
					notice.emit("粮储不足，仅赈出%d石，乡里仍有不安" % relief)
		"refugees":
			if choice == 0:
				population += 20
				morale = minf(100.0, morale + 6.0)
				notice.emit("新民入籍，田野更添生气")
			else:
				var relief := mini(28, floori(resources.grain))
				resources.grain -= relief
				morale = minf(100.0, morale + 2.0) if relief == 28 else maxf(10.0, morale - 3.0)
				notice.emit("备粮送行，流民转赴他邑" if relief == 28 else "粮少难赈，流民失望离去")
		"merchant":
			if choice == 0:
				buffs.all_until = current_day + 3
				notice.emit("新农具使全邑生产加快")
			elif choice == 1:
				resources.coins += 620.0
				notice.emit("商队购粮75石，财货入库620枚")
			else:
				notice.emit("商队另赴他邑，青禾物资未有变动")
		"scouts":
			if choice == 0:
				enemy_army.scouted = true
				var losses := _deal_losses(enemy_army, 3, rng)
				notice.emit("反侦得手：探明敌军并使其折损%d人" % _sum_force(losses))
			else:
				next_attack_day += 1
				morale = maxf(10.0, morale - 3.0)
				notice.emit("封关戒严：敌军行军延误一日")
		"harvest":
			if choice == 0:
				resources.grain = minf(get_capacity("grain"), resources.grain + 105.0)
				notice.emit("嘉禾入仓，粮储充盈")
			else:
				resources.grain = minf(get_capacity("grain"), resources.grain + 42.0)
				morale = minf(100.0, morale + 15.0)
				notice.emit("与民同乐，举邑欢腾")
		"flood":
			if choice == 0:
				buffs.farm_until = maxi(int(buffs.farm_until), current_day + 3)
				morale = minf(100.0, morale + 2.0)
				notice.emit("堤渠相济，三日内农田增产")
			else:
				var lost_grain := mini(60, floori(resources.grain))
				resources.grain -= lost_grain
				morale = maxf(10.0, morale - 4.0)
				notice.emit("低田受淹，损失粮%d石，民心受挫" % lost_grain)
		"winter_relief":
			if choice == 0:
				morale = minf(100.0, morale + 10.0)
				notice.emit("粥棚炊烟不绝，民心得安")
			else:
				morale = maxf(10.0, morale - 5.0)
				notice.emit("仓门紧闭，乡里颇有怨言")
		"craftsmen":
			if choice == 0:
				buffs.all_until = maxi(int(buffs.all_until), current_day + 3)
				notice.emit("百工安居，三日内全邑增产")
			else:
				resources.stone = minf(get_capacity("stone"), resources.stone + 28.0)
				morale = maxf(10.0, morale - 3.0)
				notice.emit("城工告成，却留下役使怨言")
		"rumors":
			if choice == 0:
				enemy_army.scouted = true
				morale = minf(100.0, morale + 5.0)
				notice.emit("吏卒查明军情，流言渐息")
			else:
				morale = maxf(10.0, morale - 6.0)
				notice.emit("流言蔓延，民心浮动")
		"levy":
			if choice == 0:
				morale = minf(100.0, morale + 3.0)
				notice.emit("使者受礼而去，边境暂安")
			else:
				next_attack_day = maxi(current_day + 1, next_attack_day - 1)
				morale = maxf(10.0, morale - 4.0)
				notice.emit("邻侯震怒，敌军行程提前一日")
	current_event = {}
	changed.emit()
	visual_event.emit("event_choice", {"id": id, "choice": choice})
	Telemetry.track("random_event_resolved", {"id": id, "choice": choice, "resources": resources.duplicate()})
	save_game()
	return true

func _make_enemy_army(wave: int) -> Dictionary:
	var tier := _enemy_tier_for_wave(wave)
	var index := mini(tier - 1, ENEMY_WAVES.size() - 1)
	var army: Dictionary = ENEMY_WAVES[index].duplicate(true)
	if tier > ENEMY_WAVES.size():
		var extra := tier - ENEMY_WAVES.size()
		army.militia += extra * 8
		army.archer += extra * 4
		army.chariot += extra * 5 if extra % 2 == 0 else 0
		army.morale = minf(88.0, float(army.morale) + extra * 2.0)
		army.training = minf(1.30, float(army.training) + extra * 0.03)
	if wave > FINAL_ENEMY_WAVE:
		var late_names := ["列国游军", "边军会师", "诸侯征粮师"]
		army.name = late_names[(wave - FINAL_ENEMY_WAVE - 1) % late_names.size()]
		match wave % 3:
			0:
				army.militia += 8
				army.archer -= 4
				army.chariot -= 1
			1:
				army.militia -= 8
				army.archer += 4
				army.chariot += 1
	army.tier = tier
	army.wave = wave
	army.scouted = false
	return army

func _enemy_tier_for_wave(wave: int) -> int:
	if wave <= 3:
		return clampi(wave, 1, MAX_ENEMY_TIER)
	return mini(MAX_ENEMY_TIER, 3 + int((wave - 3) / 2))

func _next_attack_interval(won: bool) -> int:
	var interval := maxi(5, 8 - chapter)
	if attack_wave > FINAL_ENEMY_WAVE:
		interval += 2
	if not won:
		interval += 2
	return interval

func get_enemy_display() -> Dictionary:
	var total := _sum_force(enemy_army)
	if bool(enemy_army.get("scouted", false)):
		return {"name": enemy_army.name, "known": true, "total": total, "range": "%d人" % total, "composition": "戈卒%d  弓手%d  车士%d" % [enemy_army.militia, enemy_army.archer, enemy_army.chariot]}
	var low := maxi(1, floori(total * 0.78))
	var high := ceili(total * 1.22)
	return {"name": enemy_army.name, "known": false, "total": total, "range": "%d～%d人" % [low, high], "composition": "编成未明，巡剿可探查"}

func get_battle_forecast(iterations := 120) -> Dictionary:
	var wins := 0
	var losses: Array[int] = []
	var forecast_rng := RandomNumberGenerator.new()
	forecast_rng.seed = int(current_day * 10007 + attack_wave * 7919 + get_army_count() * 97 + buildings.wall * 31)
	for _i in iterations:
		var result := _simulate_battle(units, morale, enemy_army, forecast_rng)
		if bool(result.won):
			wins += 1
		losses.append(int(result.player_losses))
	losses.sort()
	var low_index := clampi(floori(losses.size() * 0.15), 0, losses.size() - 1)
	var high_index := clampi(floori(losses.size() * 0.85), 0, losses.size() - 1)
	return {"win_rate": float(wins) / maxf(1.0, iterations), "loss_low": losses[low_index], "loss_high": losses[high_index]}

func _simulate_battle(player_force: Dictionary, player_morale: float, enemy_force: Dictionary, sim_rng: RandomNumberGenerator) -> Dictionary:
	var player := {"militia": int(player_force.get("militia", 0)), "archer": int(player_force.get("archer", 0)), "chariot": int(player_force.get("chariot", 0))}
	var enemy := {"militia": int(enemy_force.get("militia", 0)), "archer": int(enemy_force.get("archer", 0)), "chariot": int(enemy_force.get("chariot", 0))}
	var player_before := player.duplicate()
	var enemy_before := enemy.duplicate()
	var player_initial := _sum_force(player)
	var enemy_initial := _sum_force(enemy)
	var player_losses_by_type := {"militia": 0, "archer": 0, "chariot": 0}
	var enemy_losses_by_type := {"militia": 0, "archer": 0, "chariot": 0}
	var player_current_morale := player_morale
	var enemy_current_morale := float(enemy_force.get("morale", 50.0))
	var player_training := get_training()
	var enemy_training := float(enemy_force.get("training", 1.0))
	var wall_cover := maxf(0.52, 1.0 - buildings.wall * 0.09)
	var order := get_defense_order_data()
	var incoming_multiplier := float(order.incoming)
	var ranged_multiplier := float(order.ranged)
	var melee_multiplier := float(order.melee)
	var round_log: Array = []
	for round_index in 3:
		if _sum_force(player) <= 0 or _sum_force(enemy) <= 0 or player_current_morale < 24.0 or enemy_current_morale < 24.0:
			break
		var player_ranged := int(player.archer) * float(UNITS.archer.ranged) * 0.055 * _morale_factor(player_current_morale) * player_training * ranged_multiplier * sim_rng.randf_range(0.90, 1.10)
		var enemy_ranged := int(enemy.archer) * float(UNITS.archer.ranged) * 0.055 * _morale_factor(enemy_current_morale) * enemy_training * wall_cover * incoming_multiplier * sim_rng.randf_range(0.90, 1.10)
		var player_melee_strength: float = player.militia * 1.0 + player.archer * 0.35 + player.chariot * 2.2
		var enemy_melee_strength: float = enemy.militia * 1.0 + enemy.archer * 0.35 + enemy.chariot * 2.2
		var player_clash: float = player_melee_strength * 0.047 * _morale_factor(player_current_morale) * player_training * melee_multiplier * sim_rng.randf_range(0.90, 1.10)
		var enemy_clash: float = enemy_melee_strength * 0.047 * _morale_factor(enemy_current_morale) * enemy_training * wall_cover * incoming_multiplier * sim_rng.randf_range(0.90, 1.10)
		var player_round_losses := mini(_sum_force(player), _stochastic_round(enemy_ranged + enemy_clash, sim_rng))
		var enemy_round_losses := mini(_sum_force(enemy), _stochastic_round(player_ranged + player_clash, sim_rng))
		var lost_player := _deal_losses(player, player_round_losses, sim_rng)
		var lost_enemy := _deal_losses(enemy, enemy_round_losses, sim_rng)
		_merge_force_counts(player_losses_by_type, lost_player)
		_merge_force_counts(enemy_losses_by_type, lost_enemy)
		player_current_morale -= player_round_losses * 2.3 + maxf(0.0, _sum_force(enemy) - _sum_force(player)) * 0.06
		enemy_current_morale -= enemy_round_losses * 2.3 + maxf(0.0, _sum_force(player) - _sum_force(enemy)) * 0.06 + buildings.wall * 1.2
		round_log.append({"round": round_index + 1, "player_losses": player_round_losses, "enemy_losses": enemy_round_losses, "player_morale": roundi(player_current_morale), "enemy_morale": roundi(enemy_current_morale)})
	var player_score := float(_force_power(player, player_current_morale, player_training))
	var enemy_score := float(_force_power(enemy, enemy_current_morale, enemy_training))
	var win_chance := pow(maxf(0.1, player_score), 3.0) / (pow(maxf(0.1, player_score), 3.0) + pow(maxf(0.1, enemy_score), 3.0))
	var won := sim_rng.randf() <= win_chance
	if _sum_force(enemy) <= 0 or enemy_current_morale < 24.0:
		won = true
	elif _sum_force(player) <= 0 or player_current_morale < 24.0:
		won = false
	if won and _sum_force(enemy) > 0:
		var retreat_losses := _stochastic_round(_sum_force(enemy) * sim_rng.randf_range(0.08, 0.14), sim_rng)
		_merge_force_counts(enemy_losses_by_type, _deal_losses(enemy, retreat_losses, sim_rng))
	elif not won and _sum_force(player) > 0:
		var retreat_losses := _stochastic_round(_sum_force(player) * sim_rng.randf_range(0.08, 0.14), sim_rng)
		_merge_force_counts(player_losses_by_type, _deal_losses(player, retreat_losses, sim_rng))
	var killed := {"militia": 0, "archer": 0, "chariot": 0}
	var injured := {"militia": 0, "archer": 0, "chariot": 0}
	for id in UNITS:
		var total_lost := int(player_losses_by_type[id])
		var dead := _stochastic_round(total_lost * 0.30, sim_rng)
		killed[id] = dead
		injured[id] = total_lost - dead
	return {
		"won": won,
		"defense_order": defense_order,
		"defense_order_name": order.name,
		"player_before": player_before,
		"enemy_before": enemy_before,
		"player_survivors": player,
		"enemy_survivors": enemy,
		"player_power": _force_power(player_before, player_morale, player_training),
		"enemy_power": _force_power(enemy_before, float(enemy_force.get("morale", 50.0)), enemy_training),
		"player_losses": _sum_force(player_losses_by_type),
		"enemy_losses": _sum_force(enemy_losses_by_type),
		"player_losses_by_type": player_losses_by_type,
		"enemy_losses_by_type": enemy_losses_by_type,
		"killed": killed,
		"wounded": injured,
		"killed_total": _sum_force(killed),
		"wounded_total": _sum_force(injured),
		"player_morale_after": maxf(10.0, player_current_morale),
		"enemy_morale_after": maxf(0.0, enemy_current_morale),
		"resolution_win_chance": win_chance,
		"rounds": round_log,
	}

func _resolve_siege() -> void:
	set_time_speed(0.0, "siege")
	var resolved_wave := attack_wave
	var enemy_before := enemy_army.duplicate(true)
	var result := _simulate_battle(units, morale, enemy_army, rng)
	units = result.player_survivors.duplicate(true)
	morale = float(result.player_morale_after)
	_add_wounded(result.wounded)
	var loss_text := "阵亡%d人，负伤%d人；敌军折损%d人。" % [result.killed_total, result.wounded_total, result.enemy_losses]
	if bool(result.won):
		var spoils := 180.0 + attack_wave * 40.0
		resources.coins = minf(get_capacity("coins"), resources.coins + spoils)
		morale = minf(100.0, morale + 7.0)
		loss_text += " 守军得胜，缴获财货%d枚。" % roundi(spoils)
		if resolved_wave == FINAL_ENEMY_WAVE:
			loss_text += " 列国主力受挫，此后边患转为间歇游军。"
	else:
		var protection := 1.0 - minf(0.66, buildings.warehouse * 0.10 + buildings.wall * 0.06)
		var lost_grain := minf(resources.grain, (45.0 + attack_wave * 8.0) * protection)
		var lost_coins := minf(resources.coins, (280.0 + attack_wave * 55.0) * protection)
		resources.grain -= lost_grain
		resources.coins -= lost_coins
		morale = maxf(10.0, morale - 12.0)
		loss_text += " 城外仓舍受损，损失粮%d石、财%d枚。" % [roundi(lost_grain), roundi(lost_coins)]
	result.loss_text = loss_text
	result.enemy_name = enemy_before.name
	result.enemy_total = _sum_force(enemy_before)
	if bool(result.won):
		attack_wave += 1
	next_attack_day = current_day + _next_attack_interval(bool(result.won))
	patrol_delay_wave = 0
	enemy_army = _make_enemy_army(attack_wave)
	visual_event.emit("siege_win" if result.won else "siege_loss", result)
	Audio.play_sfx("battle_win" if result.won else "battle_loss")
	Telemetry.track("siege_resolved", result.merged({"day": current_day, "chapter": chapter, "wave": resolved_wave}))
	battle_finished.emit(result)

func _add_wounded(injured: Dictionary) -> void:
	for id in UNITS:
		var count := int(injured.get(id, 0))
		if count <= 0:
			continue
		wounded[id] += count
		recovery_queue.append({"unit": id, "count": count, "return_day": current_day + rng.randi_range(2, 4)})

func _apply_field_losses(count: int, killed_ratio: float) -> Dictionary:
	var force := units.duplicate(true)
	var lost := _deal_losses(force, count, rng)
	units = force
	var killed := {"militia": 0, "archer": 0, "chariot": 0}
	var injured := {"militia": 0, "archer": 0, "chariot": 0}
	for id in UNITS:
		var dead := _stochastic_round(int(lost[id]) * killed_ratio, rng)
		killed[id] = dead
		injured[id] = int(lost[id]) - dead
	_add_wounded(injured)
	return {"lost": lost, "killed": killed, "wounded": injured}

func _loss_summary(losses: Dictionary, enemy := false) -> String:
	var names := {"militia": "戈卒", "archer": "弓手", "chariot": "车士"} if enemy else {"militia": "乡勇", "archer": "弓手", "chariot": "车士"}
	var parts: Array[String] = []
	for id in UNITS:
		var count := int(losses.get(id, 0))
		if count > 0:
			parts.append("%s%d" % [names[id], count])
	return "、".join(parts) if not parts.is_empty() else "无"

func _casualty_summary(killed: Dictionary, injured: Dictionary) -> String:
	var parts: Array[String] = []
	for id in UNITS:
		var dead := int(killed.get(id, 0))
		var wounded_count := int(injured.get(id, 0))
		if dead + wounded_count > 0:
			parts.append("%s亡%d伤%d" % [UNITS[id].name, dead, wounded_count])
	return "、".join(parts) if not parts.is_empty() else "无人伤亡"

func _deal_losses(force: Dictionary, requested: int, sim_rng: RandomNumberGenerator) -> Dictionary:
	var lost := {"militia": 0, "archer": 0, "chariot": 0}
	for _i in mini(requested, _sum_force(force)):
		var total_weight := 0.0
		for id in UNITS:
			total_weight += int(force.get(id, 0)) * float(UNITS[id].exposure)
		if total_weight <= 0.0:
			break
		var roll := sim_rng.randf() * total_weight
		for id in UNITS:
			roll -= int(force.get(id, 0)) * float(UNITS[id].exposure)
			if roll <= 0.0 and int(force.get(id, 0)) > 0:
				force[id] = int(force[id]) - 1
				lost[id] += 1
				break
	return lost

func _stochastic_round(value: float, sim_rng: RandomNumberGenerator) -> int:
	var whole := floori(maxf(0.0, value))
	return whole + (1 if sim_rng.randf() < value - whole else 0)

func _sum_force(force: Dictionary) -> int:
	return int(force.get("militia", 0)) + int(force.get("archer", 0)) + int(force.get("chariot", 0))

func _merge_force_counts(target: Dictionary, addition: Dictionary) -> void:
	for id in UNITS:
		target[id] = int(target.get(id, 0)) + int(addition.get(id, 0))

func advance_chapter() -> bool:
	if get_prosperity() < get_chapter_target():
		notice.emit("繁荣度尚不足以扩建城邑")
		return false
	if chapter >= 3:
		notice.emit("青禾已成一方强邑")
		return false
	chapter += 1
	set_time_speed(0.0, "chapter_advanced")
	resources.coins = minf(get_capacity("coins"), resources.coins + 1200.0)
	resources.grain = minf(get_capacity("grain"), resources.grain + 150.0)
	population = mini(get_population_cap() - get_army_count() - get_wounded_count(), population + 10)
	next_attack_day = mini(next_attack_day, current_day + 4)
	patrol_delay_wave = 0
	enemy_army = _make_enemy_army(attack_wave)
	notice.emit("城邑晋升：邻国开始派出更完整的军队")
	changed.emit()
	visual_event.emit("chapter", {"chapter": chapter})
	Audio.play_sfx("upgrade")
	Telemetry.track("chapter_advanced", {"chapter": chapter, "prosperity": get_prosperity()})
	save_game()
	return true

func mark_tutorial_seen() -> void:
	tutorial_seen = true
	Telemetry.track("tutorial_completed", {"day": current_day})
	save_game()

func save_game() -> void:
	if not persistence_enabled:
		return
	if _write_save(AUTO_SAVE_PATH, get_snapshot()):
		Telemetry.track("autosave", {"day": current_day, "chapter": chapter})

func load_game() -> void:
	if not FileAccess.file_exists(AUTO_SAVE_PATH):
		return
	var data := _read_save(AUTO_SAVE_PATH)
	if data.is_empty():
		Telemetry.track_error("autosave_invalid", "自动存档无法解析")
		return
	_apply_snapshot(data, true)
	Telemetry.track("autosave_loaded", {"day": current_day, "chapter": chapter})

func get_snapshot() -> Dictionary:
	return {
		"format_version": FORMAT_VERSION,
		"resources": resources.duplicate(true),
		"buildings": buildings.duplicate(true),
		"units": units.duplicate(true),
		"wounded": wounded.duplicate(true),
		"recovery_queue": recovery_queue.duplicate(true),
		"population": population,
		"morale": morale,
		"current_day": current_day,
		"chapter": chapter,
		"day_progress": day_progress,
		"next_attack_day": next_attack_day,
		"attack_wave": attack_wave,
		"enemy_army": enemy_army.duplicate(true),
		"defense_order": defense_order,
		"last_patrol_day": last_patrol_day,
		"patrol_delay_wave": patrol_delay_wave,
		"tutorial_seen": tutorial_seen,
		"current_event": current_event.duplicate(true),
		"last_event_id": last_event_id,
		"buffs": buffs.duplicate(true),
		"prosperity": get_prosperity(),
		"saved_at": Time.get_unix_time_from_system(),
	}

func _upgrade_snapshot(data: Dictionary) -> Dictionary:
	var upgraded := data.duplicate(true)
	if int(upgraded.get("format_version", 1)) < FORMAT_VERSION:
		var old_resources: Dictionary = upgraded.get("resources", {}).duplicate(true)
		old_resources.grain = float(old_resources.get("grain", 180.0)) * 2.0
		old_resources.coins = float(old_resources.get("coins", 150.0)) * 10.0
		upgraded.resources = old_resources
		var old_units: Dictionary = upgraded.get("units", {}).duplicate(true)
		for id in UNITS:
			old_units[id] = int(old_units.get(id, 0)) * 5
		upgraded.units = old_units
		upgraded.population = int(upgraded.get("population", 22)) * 5
		upgraded.wounded = {"militia": 0, "archer": 0, "chariot": 0}
		upgraded.recovery_queue = []
		upgraded.attack_wave = maxi(1, int(upgraded.get("chapter", 1)))
		upgraded.enemy_army = _make_enemy_army(int(upgraded.attack_wave))
		upgraded.last_patrol_day = 0
		upgraded.patrol_delay_wave = 0
		upgraded.format_version = FORMAT_VERSION
		Telemetry.track("save_format_migrated", {"from": data.get("format_version", 1), "to": FORMAT_VERSION})
	return upgraded

func _apply_snapshot(data: Dictionary, apply_offline: bool) -> void:
	if not _is_valid_save_data(data):
		Telemetry.track_error("save_snapshot_rejected", "存档结构或数值范围无效")
		return
	var snapshot := _upgrade_snapshot(data)
	if not _is_valid_save_data(snapshot):
		Telemetry.track_error("save_migration_rejected", "迁移后的存档状态不一致")
		return
	resources = {"grain": 360.0, "wood": 125.0, "stone": 82.0, "coins": 1500.0}
	resources.merge(snapshot.get("resources", {}), true)
	buildings = {"farm": 1, "woodcut": 1, "quarry": 0, "house": 1, "market": 0, "warehouse": 1, "barracks": 0, "wall": 0}
	buildings.merge(snapshot.get("buildings", {}), true)
	units = {"militia": 20, "archer": 0, "chariot": 0}
	units.merge(snapshot.get("units", {}), true)
	wounded = {"militia": 0, "archer": 0, "chariot": 0}
	wounded.merge(snapshot.get("wounded", {}), true)
	recovery_queue = snapshot.get("recovery_queue", []).duplicate(true)
	population = int(snapshot.get("population", 110))
	morale = float(snapshot.get("morale", 70.0))
	current_day = int(snapshot.get("current_day", 1))
	chapter = int(snapshot.get("chapter", 1))
	day_progress = float(snapshot.get("day_progress", 0.0))
	next_attack_day = int(snapshot.get("next_attack_day", 7))
	attack_wave = int(snapshot.get("attack_wave", 1))
	enemy_army = snapshot.get("enemy_army", _make_enemy_army(attack_wave)).duplicate(true)
	defense_order = str(snapshot.get("defense_order", "steady"))
	last_patrol_day = int(snapshot.get("last_patrol_day", 0))
	patrol_delay_wave = int(snapshot.get("patrol_delay_wave", 0))
	tutorial_seen = bool(snapshot.get("tutorial_seen", tutorial_seen))
	time_speed = 0.0
	buffs = {"farm_until": 0, "all_until": 0}
	buffs.merge(snapshot.get("buffs", {}), true)
	var saved_event: Dictionary = snapshot.get("current_event", {})
	current_event = _event_definition(str(saved_event.get("id", ""))).duplicate(true) if not saved_event.is_empty() else {}
	last_event_id = str(snapshot.get("last_event_id", ""))
	offline_report = ""
	last_day_report = ""
	if apply_offline:
		_apply_offline_progress(snapshot)

func _apply_offline_progress(data: Dictionary) -> void:
	var elapsed := clampf(Time.get_unix_time_from_system() - float(data.get("saved_at", Time.get_unix_time_from_system())), 0.0, MAX_OFFLINE_SECONDS)
	if elapsed < 30.0:
		return
	var rewarded_days := minf(24.0, elapsed / OFFLINE_DAY_SECONDS)
	var ledger := get_daily_ledger()
	var gains := []
	for key in resources:
		var potential_gain: float = maxf(0.0, float(ledger[key].net)) * rewarded_days * 0.45
		var before: float = resources[key]
		resources[key] = minf(get_capacity(key), before + potential_gain)
		var actual_gain: float = resources[key] - before
		if actual_gain >= 1.0:
			gains.append("%s +%d%s" % [_resource_name(key), roundi(actual_gain), _resource_unit(key)])
	if not gains.is_empty():
		offline_report = "离城期间只结算安全生产：" + "  ".join(gains)
		Telemetry.track("offline_rewards", {"elapsed": roundi(elapsed), "rewarded_days": rewarded_days, "gains": gains})

func manual_save(slot: int) -> bool:
	if slot < 1 or slot > SLOT_COUNT:
		return false
	var data := get_snapshot()
	data.slot = slot
	var ok := _write_save(_slot_path(slot), data)
	if ok:
		notice.emit("进度已保存到档位 %d" % slot)
		Audio.play_sfx("ui_tap")
		Telemetry.track("manual_save", {"slot": slot, "day": current_day, "chapter": chapter})
		save_slots_changed.emit()
	else:
		notice.emit("档位 %d 保存失败，诊断记录已保留" % slot)
	return ok

func load_slot(slot: int) -> bool:
	var path := _slot_path(slot)
	var had_save_file := FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")
	var data := _read_save(path)
	if data.is_empty():
		notice.emit("该档位存档损坏且无可用备份" if had_save_file else "该档位尚无存档")
		return false
	_apply_snapshot(data, true)
	changed.emit()
	save_game()
	notice.emit("已载入档位 %d" % slot)
	visual_event.emit("load", {"slot": slot})
	Telemetry.track("manual_load", {"slot": slot, "day": current_day, "chapter": chapter})
	return true

func delete_slot(slot: int) -> bool:
	var path := _slot_path(slot)
	var found := false
	for candidate in [path, path + ".bak", path + ".tmp"]:
		if not FileAccess.file_exists(candidate):
			continue
		found = true
		var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
		if error != OK:
			Telemetry.track_error("save_delete_failed", error_string(error), {"slot": slot, "path": candidate})
			notice.emit("档位 %d 删除失败，诊断记录已保留" % slot)
			return false
	if not found:
		notice.emit("该档位尚无存档")
		return false
	Telemetry.track("manual_save_deleted", {"slot": slot})
	save_slots_changed.emit()
	return true

func list_save_slots() -> Array:
	var slots: Array = []
	for slot in range(1, SLOT_COUNT + 1):
		var path := _slot_path(slot)
		var data := _read_save(path)
		if data.is_empty():
			slots.append({"slot": slot, "exists": false})
		else:
			slots.append({"slot": slot, "exists": true, "day": int(data.get("current_day", 1)), "chapter": int(data.get("chapter", 1)), "prosperity": int(data.get("prosperity", 0)), "saved_at": float(data.get("saved_at", 0.0))})
	return slots

func _slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot]

func _write_save(path: String, data: Dictionary) -> bool:
	var temp_path := path + ".tmp"
	var backup_path := path + ".bak"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if not file:
		Telemetry.track_error("save_open_failed", "无法写入存档临时文件", {"path": temp_path, "error": FileAccess.get_open_error()})
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	file = null
	if not _read_save_file(temp_path).is_empty():
		var had_primary := FileAccess.file_exists(path)
		if had_primary:
			if FileAccess.file_exists(backup_path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path))
			var backup_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(backup_path))
			if backup_error != OK:
				DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
				Telemetry.track_error("save_backup_failed", error_string(backup_error), {"path": path})
				return false
		var commit_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(path))
		if commit_error == OK:
			return true
		if had_primary and FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(ProjectSettings.globalize_path(backup_path), ProjectSettings.globalize_path(path))
		Telemetry.track_error("save_commit_failed", error_string(commit_error), {"path": path})
		return false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
	Telemetry.track_error("save_verify_failed", "存档临时文件校验失败", {"path": path})
	return false

func _valid_number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum

func _valid_numeric_map(value: Variant, allowed_keys: Array, minimum: float, maximum: float) -> bool:
	if value is not Dictionary:
		return false
	for key in value:
		if key not in allowed_keys or not _valid_number(value[key], minimum, maximum):
			return false
	return true

func _event_definition(id: String) -> Dictionary:
	for event in EVENTS:
		if str(event.id) == id:
			return event
	return {}

func _is_consistent_current_save(data: Dictionary) -> bool:
	var saved_buildings := {"farm": 1, "woodcut": 1, "quarry": 0, "house": 1, "market": 0, "warehouse": 1, "barracks": 0, "wall": 0}
	saved_buildings.merge(data.get("buildings", {}), true)
	var warehouse_level := float(saved_buildings.warehouse)
	var capacities := {
		"grain": 1200.0 + warehouse_level * 800.0,
		"wood": 350.0 + warehouse_level * 250.0,
		"stone": 350.0 + warehouse_level * 250.0,
		"coins": 5000.0 + warehouse_level * 2500.0,
	}
	var saved_resources := {"grain": 360.0, "wood": 125.0, "stone": 82.0, "coins": 1500.0}
	saved_resources.merge(data.get("resources", {}), true)
	for id in saved_resources:
		if float(saved_resources[id]) > float(capacities[id]) + 0.001:
			return false

	var saved_units := {"militia": 20, "archer": 0, "chariot": 0}
	saved_units.merge(data.get("units", {}), true)
	var saved_wounded := {"militia": 0, "archer": 0, "chariot": 0}
	saved_wounded.merge(data.get("wounded", {}), true)
	var army_total := _sum_force(saved_units)
	var wounded_total := _sum_force(saved_wounded)
	var saved_population := int(data.get("population", 110))
	if saved_population < 40 or saved_population + army_total + wounded_total > 90 + int(saved_buildings.house) * 60:
		return false
	if army_total + wounded_total > 25 + int(saved_buildings.barracks) * 20:
		return false

	var queued_wounded := {"militia": 0, "archer": 0, "chariot": 0}
	var saved_day := int(data.get("current_day", 1))
	for entry in data.get("recovery_queue", []):
		if int(entry.return_day) <= saved_day:
			return false
		queued_wounded[entry.unit] += int(entry.count)
	for id in UNITS:
		if int(queued_wounded[id]) != int(saved_wounded[id]):
			return false
	if int(data.get("next_attack_day", 7)) <= saved_day:
		return false
	if int(data.get("last_patrol_day", 0)) > saved_day:
		return false
	if int(data.get("patrol_delay_wave", 0)) > int(data.get("attack_wave", 1)):
		return false
	var saved_enemy: Dictionary = data.get("enemy_army", {})
	if not saved_enemy.is_empty():
		if _sum_force(saved_enemy) <= 0:
			return false
		if int(saved_enemy.get("wave", data.get("attack_wave", 1))) != int(data.get("attack_wave", 1)):
			return false
		if not _valid_number(saved_enemy.get("tier", 1), 1.0, MAX_ENEMY_TIER):
			return false

	var saved_event: Dictionary = data.get("current_event", {})
	if not saved_event.is_empty():
		var canonical_event := _event_definition(str(saved_event.get("id", "")))
		if canonical_event.is_empty() or saved_event.get("options") != canonical_event.options:
			return false
	return true

func _is_valid_save_data(data: Dictionary) -> bool:
	if data.is_empty() or not _valid_number(data.get("format_version", 1), 1.0, FORMAT_VERSION):
		return false
	var format_version := int(data.get("format_version", 1))
	if data.has("resources") and not _valid_numeric_map(data.resources, RESOURCE_UNITS.keys(), 0.0, 1000000000.0):
		return false
	if data.has("buildings"):
		if data.buildings is not Dictionary:
			return false
		for id in data.buildings:
			if not BUILDINGS.has(id) or not _valid_number(data.buildings[id], 0.0, float(BUILDINGS[id].max)):
				return false
	for roster_key in ["units", "wounded"]:
		if data.has(roster_key) and not _valid_numeric_map(data[roster_key], UNITS.keys(), 0.0, 10000.0):
			return false
	var numeric_ranges := {
		"population": [0.0, 1000000.0],
		"morale": [0.0, 100.0],
		"current_day": [1.0, 10000000.0],
		"chapter": [1.0, 3.0],
		"day_progress": [0.0, 1.0],
		"next_attack_day": [1.0, 10000000.0],
		"attack_wave": [1.0, 10000000.0],
		"last_patrol_day": [0.0, 10000000.0],
		"patrol_delay_wave": [0.0, 10000000.0],
		"saved_at": [0.0, 100000000000.0],
	}
	for key in numeric_ranges:
		if data.has(key) and not _valid_number(data[key], numeric_ranges[key][0], numeric_ranges[key][1]):
			return false
	if data.has("tutorial_seen") and data.tutorial_seen is not bool:
		return false
	if data.has("defense_order") and str(data.defense_order) not in DEFENSE_ORDERS:
		return false
	if data.has("buffs") and not _valid_numeric_map(data.buffs, ["farm_until", "all_until"], 0.0, 10000000.0):
		return false
	if data.has("recovery_queue"):
		if data.recovery_queue is not Array or data.recovery_queue.size() > 1000:
			return false
		for entry in data.recovery_queue:
			if entry is not Dictionary or str(entry.get("unit", "")) not in UNITS:
				return false
			if not _valid_number(entry.get("count"), 1.0, 10000.0) or not _valid_number(entry.get("return_day"), 1.0, 10000000.0):
				return false
	if data.has("enemy_army"):
		if data.enemy_army is not Dictionary or (format_version >= FORMAT_VERSION and data.enemy_army.is_empty()):
			return false
		if not data.enemy_army.is_empty():
			if data.enemy_army.get("name") is not String or str(data.enemy_army.name).length() > 80:
				return false
			if not _valid_numeric_map(
				{
					"militia": data.enemy_army.get("militia"),
					"archer": data.enemy_army.get("archer"),
					"chariot": data.enemy_army.get("chariot"),
				},
				["militia", "archer", "chariot"], 0.0, 10000.0
			):
				return false
			if not _valid_number(data.enemy_army.get("morale"), 0.0, 100.0) or not _valid_number(data.enemy_army.get("training"), 0.1, 3.0):
				return false
			if data.enemy_army.get("scouted") is not bool:
				return false
	if data.has("current_event"):
		if data.current_event is not Dictionary:
			return false
		if not data.current_event.is_empty():
			if _event_definition(str(data.current_event.get("id", ""))).is_empty() or data.current_event.get("options") is not Array:
				return false
			if data.current_event.get("title") is not String or str(data.current_event.title).length() > 80:
				return false
			if data.current_event.get("body") is not String or str(data.current_event.body).length() > 500:
				return false
			for option in data.current_event.options:
				if option is not String or str(option).length() > 100:
					return false
	if data.has("last_event_id"):
		if data.last_event_id is not String:
			return false
		var valid_last_ids: Array[String] = [""]
		for event in EVENTS:
			valid_last_ids.append(str(event.id))
		if str(data.last_event_id) not in valid_last_ids:
			return false
	if format_version >= FORMAT_VERSION and not _is_consistent_current_save(data):
		return false
	return true

func _read_save_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	return json.data if json.data is Dictionary and _is_valid_save_data(json.data) else {}

func _read_save(path: String) -> Dictionary:
	var primary := _read_save_file(path)
	if not primary.is_empty():
		return primary
	var backup_path := path + ".bak"
	var backup := _read_save_file(backup_path)
	if not backup.is_empty():
		Telemetry.track("save_backup_recovered", {"path": path})
		return backup
	if FileAccess.file_exists(path):
		Telemetry.track_error("save_invalid", "存档与备份均无法解析或未通过结构校验", {"path": path})
	return {}

func _migrate_legacy_save() -> void:
	if FileAccess.file_exists(AUTO_SAVE_PATH) or not FileAccess.file_exists(LEGACY_SAVE_PATH):
		return
	var data := _read_save(LEGACY_SAVE_PATH)
	if not data.is_empty() and _write_save(AUTO_SAVE_PATH, data):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LEGACY_SAVE_PATH))
		Telemetry.track("legacy_save_migrated", {"format": data.get("format_version", 1)})

func reset_game() -> void:
	resources = {"grain": 360.0, "wood": 125.0, "stone": 82.0, "coins": 1500.0}
	buildings = {"farm": 1, "woodcut": 1, "quarry": 0, "house": 1, "market": 0, "warehouse": 1, "barracks": 0, "wall": 0}
	units = {"militia": 20, "archer": 0, "chariot": 0}
	wounded = {"militia": 0, "archer": 0, "chariot": 0}
	recovery_queue = []
	population = 110
	morale = 70.0
	current_day = 1
	chapter = 1
	day_progress = 0.0
	next_attack_day = 7
	attack_wave = 1
	enemy_army = _make_enemy_army(attack_wave)
	defense_order = "steady"
	last_patrol_day = 0
	patrol_delay_wave = 0
	current_event = {}
	last_event_id = ""
	buffs = {"farm_until": 0, "all_until": 0}
	offline_report = ""
	last_day_report = ""
	time_speed = 0.0
	modal_paused = false
	changed.emit()
	visual_event.emit("new_game", {})
	Telemetry.track("new_game", {"format": FORMAT_VERSION})
	save_game()

func _resource_name(id: String) -> String:
	return str(RESOURCE_UNITS.get(id, {}).get("short", id))

func _resource_unit(id: String) -> String:
	return str(RESOURCE_UNITS.get(id, {}).get("unit", ""))
