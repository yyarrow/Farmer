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

const ENEMY_WAVES := [
	{"name": "山泽盗", "militia": 20, "archer": 5, "chariot": 0, "morale": 50.0, "training": 0.92},
	{"name": "流寇合众", "militia": 30, "archer": 10, "chariot": 0, "morale": 56.0, "training": 0.96},
	{"name": "邻邑征粮队", "militia": 36, "archer": 14, "chariot": 5, "morale": 60.0, "training": 1.00},
	{"name": "列国偏师", "militia": 44, "archer": 18, "chariot": 5, "morale": 64.0, "training": 1.04},
	{"name": "边军锐卒", "militia": 52, "archer": 22, "chariot": 10, "morale": 68.0, "training": 1.08},
	{"name": "诸侯联军前锋", "militia": 62, "archer": 28, "chariot": 10, "morale": 72.0, "training": 1.12},
]

const EVENTS := [
	{"id": "drought", "title": "旱意初显", "body": "东渠水位骤降，田间已有龟裂。若不处置，今岁收成恐受影响。", "options": ["疏浚旧渠", "开仓稳民"]},
	{"id": "refugees", "title": "流民叩关", "body": "邻邑战乱，一队流民携农具来到城下，请求在此安家。", "options": ["接纳入籍", "赈粮送行"]},
	{"id": "merchant", "title": "齐商来访", "body": "远来的商队带着铁制农具，愿以高价换取本地粮草。", "options": ["购置农具", "出售粮草"]},
	{"id": "scouts", "title": "烽燧疑云", "body": "斥候发现陌生骑手窥探城防，边境气氛骤然紧张。", "options": ["派斥候反侦", "封关戒严"]},
	{"id": "harvest", "title": "嘉禾同穗", "body": "田中生出双穗嘉禾，百姓认为是丰年的吉兆。", "options": ["入仓备荒", "设宴庆贺"]},
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
var last_patrol_day := 0
var patrol_delay_wave := 0
var tutorial_seen := false
var current_event: Dictionary = {}
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
	_produce_resources(delta)
	day_progress += delta / DAY_SECONDS
	if day_progress >= 1.0:
		day_progress -= 1.0
		_advance_day()

func _produce_resources(delta: float) -> void:
	var rates := get_rates()
	for key in resources:
		resources[key] = clampf(resources[key] + float(rates.get(key, 0.0)) * delta, 0.0, get_capacity(key))

func get_daily_ledger() -> Dictionary:
	var all_bonus := 1.22 if current_day <= int(buffs.get("all_until", 0)) else 1.0
	var farm_bonus := 1.35 if current_day <= int(buffs.get("farm_until", 0)) else 1.0
	var market_bonus := 1.0 + float(buildings.market) * 0.08
	var grain_income: float = 20.0 * buildings.farm * farm_bonus * all_bonus
	var wood_income: float = 9.0 * buildings.woodcut * all_bonus
	var stone_income: float = 6.0 * buildings.quarry * all_bonus
	var tax_income: float = (35.0 * buildings.house + 55.0 * buildings.market + population * 0.25) * market_bonus * all_bonus
	var civilian_food := population / 15.0
	var army_food := 0.0
	var army_pay := 0.0
	for id in UNITS:
		army_food += int(units[id]) * float(UNITS[id].grain_daily)
		army_pay += int(units[id]) * float(UNITS[id].coins_daily)
	var wounded_count := get_wounded_count()
	var wounded_food := wounded_count * 0.08
	var wounded_care := wounded_count * 0.30
	return {
		"grain": {"income": grain_income, "expense": civilian_food + army_food + wounded_food, "net": grain_income - civilian_food - army_food - wounded_food, "details": [["农田收获", grain_income], ["百姓口粮", -civilian_food], ["军籍粮秣", -army_food], ["伤员养护", -wounded_food]]},
		"wood": {"income": wood_income, "expense": 0.0, "net": wood_income, "details": [["林场轮伐", wood_income]]},
		"stone": {"income": stone_income, "expense": 0.0, "net": stone_income, "details": [["石场开采", stone_income]]},
		"coins": {"income": tax_income, "expense": army_pay + wounded_care, "net": tax_income - army_pay - wounded_care, "details": [["民居与市税", tax_income], ["军饷", -army_pay], ["伤员医药", -wounded_care]]},
	}

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
	_produce_resources(remaining_seconds)
	day_progress = 0.0
	Telemetry.track("day_advanced_manually", {"from_day": current_day})
	_advance_day()
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

func trade(kind: String) -> bool:
	var ok := false
	match kind:
		"sell_grain":
			ok = spend({"grain": 55})
			if ok: resources.coins = minf(get_capacity("coins"), resources.coins + 340 + buildings.market * 30)
		"buy_grain":
			ok = spend({"coins": maxi(340, 460 - buildings.market * 20)})
			if ok: resources.grain = minf(get_capacity("grain"), resources.grain + 55)
		"sell_wood":
			ok = spend({"wood": 40})
			if ok: resources.coins = minf(get_capacity("coins"), resources.coins + 300 + buildings.market * 20)
		"buy_stone":
			ok = spend({"coins": maxi(380, 500 - buildings.market * 20)})
			if ok: resources.stone = minf(get_capacity("stone"), resources.stone + 35)
	if ok:
		changed.emit()
		notice.emit("市易完成")
		visual_event.emit("trade", {"trade": kind})
		Audio.play_sfx("trade")
		Telemetry.track("trade_completed", {"kind": kind, "resources": resources.duplicate()})
		save_game()
	return ok

func enact_policy(id: String) -> bool:
	match id:
		"irrigate":
			if not spend({"wood": 35, "stone": 24, "coins": 280}): return false
			buffs.farm_until = current_day + 3
			notice.emit("水利修成：三日内粮秣增产")
		"tax_relief":
			if not spend({"coins": 650, "grain": 35}): return false
			population = mini(get_population_cap() - get_army_count() - get_wounded_count(), population + 15)
			morale = minf(100.0, morale + 12.0)
			notice.emit("轻徭薄赋：民心与民口上升")
		"reward_army":
			if not spend({"grain": 60, "coins": 450}): return false
			morale = minf(100.0, morale + 18.0)
			for entry in recovery_queue:
				entry.return_day = maxi(current_day + 1, int(entry.return_day) - 1)
			notice.emit("犒赏三军：士气大振，伤员恢复加快")
		_:
			return false
	changed.emit()
	visual_event.emit("policy", {"policy": id})
	Audio.play_sfx("event")
	Telemetry.track("policy_enacted", {"policy": id, "day": current_day})
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
	var delayed := false
	var field_victory := false
	if won:
		enemy_losses = rng.randi_range(2, 5)
		var lost := _deal_losses(enemy_army, enemy_losses, rng)
		enemy_losses = _sum_force(lost)
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
			notice.emit("巡剿大捷：歼敌%d人，下一支敌军已在集结" % enemy_losses)
		else:
			notice.emit("巡剿得胜：敌军折损%d人%s" % [enemy_losses, "，行军延误一日" if delayed else ""])
		visual_event.emit("patrol_win", {"enemy_losses": enemy_losses, "delayed": delayed, "field_victory": field_victory})
		Audio.play_sfx("battle_win")
	else:
		player_losses = rng.randi_range(1, 3)
		_apply_field_losses(player_losses, 0.20)
		morale = maxf(20.0, morale - 5.0)
		notice.emit("巡剿失利：%d人伤亡，但已探明敌军编成" % player_losses)
		visual_event.emit("patrol_loss", {"player_losses": player_losses})
		Audio.play_sfx("battle_loss")
	changed.emit()
	Telemetry.track("patrol_resolved", {"won": won, "chance": chance, "player_losses": player_losses, "enemy_losses": enemy_losses, "delayed": delayed, "field_victory": field_victory, "enemy": enemy_army.duplicate(true)})
	save_game()
	return true

func _advance_day() -> void:
	current_day += 1
	_recover_wounded()
	var ledger := get_daily_ledger()
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
	Telemetry.track("day_settled", {"day": current_day, "ledger": ledger, "population": population, "army": units.duplicate(), "wounded": wounded.duplicate()})
	save_game()

func _recover_wounded() -> void:
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

func _start_random_event() -> void:
	set_time_speed(0.0, "random_event")
	current_event = EVENTS[rng.randi_range(0, EVENTS.size() - 1)].duplicate(true)
	Audio.play_sfx("event")
	visual_event.emit("event", {"id": current_event.id})
	Telemetry.track("random_event_started", {"id": current_event.id, "day": current_day})
	event_started.emit(current_event)

func is_event_choice_available(choice: int) -> bool:
	if current_event.is_empty() or choice < 0 or choice >= int(current_event.get("options", []).size()):
		return false
	if choice != 0:
		return true
	match str(current_event.get("id", "")):
		"drought": return can_afford({"wood": 28, "stone": 18})
		"refugees": return can_afford({"grain": 58})
		"merchant": return can_afford({"coins": 720})
		"scouts": return can_afford({"coins": 320})
	return true

func resolve_event(choice: int) -> bool:
	if current_event.is_empty() or choice < 0 or choice >= int(current_event.get("options", []).size()):
		return false
	if not is_event_choice_available(choice):
		notice.emit("物资不足，无法执行这项处置")
		Telemetry.track("event_choice_unavailable", {"id": current_event.get("id", ""), "choice": choice, "resources": resources.duplicate()})
		return false
	var id: String = current_event.id
	match id:
		"drought":
			if choice == 0:
				if not spend({"wood": 28, "stone": 18}): return false
				buffs.farm_until = current_day + 3
				notice.emit("旧渠复通，农田转危为安")
			else:
				resources.grain = maxf(0.0, resources.grain - 45.0)
				morale = minf(100.0, morale + 4.0)
				notice.emit("开仓赈济，百姓得以安心")
		"refugees":
			if choice == 0:
				if not spend({"grain": 58}): return false
				population = mini(get_population_cap() - get_army_count() - get_wounded_count(), population + 20)
				morale = minf(100.0, morale + 6.0)
				notice.emit("新民入籍，田野更添生气")
			else:
				resources.grain = maxf(0.0, resources.grain - 28.0)
				morale = minf(100.0, morale + 2.0)
		"merchant":
			if choice == 0:
				if not spend({"coins": 720}): return false
				buffs.all_until = current_day + 3
				notice.emit("新农具使全邑生产加快")
			else:
				var sold_grain := minf(75.0, resources.grain)
				var proceeds := 620.0 * sold_grain / 75.0
				resources.grain -= sold_grain
				resources.coins = minf(get_capacity("coins"), resources.coins + proceeds)
				notice.emit("商队购粮%d石，财货入库%d枚" % [roundi(sold_grain), roundi(proceeds)])
		"scouts":
			if choice == 0:
				if not spend({"coins": 320}): return false
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
	current_event = {}
	changed.emit()
	visual_event.emit("event_choice", {"id": id, "choice": choice})
	Telemetry.track("random_event_resolved", {"id": id, "choice": choice, "resources": resources.duplicate()})
	save_game()
	return true

func _make_enemy_army(wave: int) -> Dictionary:
	var tier := mini(wave, MAX_ENEMY_TIER)
	var index := mini(tier - 1, ENEMY_WAVES.size() - 1)
	var army: Dictionary = ENEMY_WAVES[index].duplicate(true)
	if tier > ENEMY_WAVES.size():
		var extra := tier - ENEMY_WAVES.size()
		army.militia += extra * 8
		army.archer += extra * 4
		army.chariot += extra * 5 if extra % 2 == 0 else 0
		army.morale = minf(88.0, float(army.morale) + extra * 2.0)
		army.training = minf(1.30, float(army.training) + extra * 0.03)
	if wave > MAX_ENEMY_TIER:
		var late_names := ["列国游军", "边军会师", "诸侯征粮师"]
		army.name = late_names[(wave - MAX_ENEMY_TIER - 1) % late_names.size()]
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

func _next_attack_interval(won: bool) -> int:
	var interval := maxi(5, 8 - chapter)
	if attack_wave > MAX_ENEMY_TIER:
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
	var round_log: Array = []
	for round_index in 3:
		if _sum_force(player) <= 0 or _sum_force(enemy) <= 0 or player_current_morale < 24.0 or enemy_current_morale < 24.0:
			break
		var player_ranged := int(player.archer) * float(UNITS.archer.ranged) * 0.055 * _morale_factor(player_current_morale) * player_training * sim_rng.randf_range(0.90, 1.10)
		var enemy_ranged := int(enemy.archer) * float(UNITS.archer.ranged) * 0.055 * _morale_factor(enemy_current_morale) * enemy_training * wall_cover * sim_rng.randf_range(0.90, 1.10)
		var player_melee_strength: float = player.militia * 1.0 + player.archer * 0.35 + player.chariot * 2.2
		var enemy_melee_strength: float = enemy.militia * 1.0 + enemy.archer * 0.35 + enemy.chariot * 2.2
		var player_clash: float = player_melee_strength * 0.047 * _morale_factor(player_current_morale) * player_training * sim_rng.randf_range(0.90, 1.10)
		var enemy_clash: float = enemy_melee_strength * 0.047 * _morale_factor(enemy_current_morale) * enemy_training * wall_cover * sim_rng.randf_range(0.90, 1.10)
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
		"player_before": player_before,
		"enemy_before": enemy_before,
		"player_survivors": player,
		"enemy_survivors": enemy,
		"player_power": _force_power(player_before, player_morale, player_training),
		"enemy_power": _force_power(enemy_before, float(enemy_force.get("morale", 50.0)), enemy_training),
		"player_losses": _sum_force(player_losses_by_type),
		"enemy_losses": _sum_force(enemy_losses_by_type),
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
		if resolved_wave == MAX_ENEMY_TIER:
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

func _apply_field_losses(count: int, killed_ratio: float) -> void:
	var force := units.duplicate(true)
	var lost := _deal_losses(force, count, rng)
	units = force
	var injured := {"militia": 0, "archer": 0, "chariot": 0}
	for id in UNITS:
		var dead := _stochastic_round(int(lost[id]) * killed_ratio, rng)
		injured[id] = int(lost[id]) - dead
	_add_wounded(injured)

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
		"last_patrol_day": last_patrol_day,
		"patrol_delay_wave": patrol_delay_wave,
		"tutorial_seen": tutorial_seen,
		"current_event": current_event.duplicate(true),
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
	var snapshot := _upgrade_snapshot(data)
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
	last_patrol_day = int(snapshot.get("last_patrol_day", 0))
	patrol_delay_wave = int(snapshot.get("patrol_delay_wave", 0))
	tutorial_seen = bool(snapshot.get("tutorial_seen", tutorial_seen))
	time_speed = 0.0
	buffs = {"farm_until": 0, "all_until": 0}
	buffs.merge(snapshot.get("buffs", {}), true)
	current_event = snapshot.get("current_event", {}).duplicate(true)
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
		var gain: float = maxf(0.0, float(ledger[key].net)) * rewarded_days * 0.45
		resources[key] = minf(get_capacity(key), resources[key] + gain)
		if gain >= 1.0:
			gains.append("%s +%d%s" % [_resource_name(key), roundi(gain), _resource_unit(key)])
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
	return ok

func load_slot(slot: int) -> bool:
	var data := _read_save(_slot_path(slot))
	if data.is_empty():
		notice.emit("该档位尚无存档")
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
			return false
	if not found:
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

func _read_save_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	return json.data if json.data is Dictionary and not json.data.is_empty() else {}

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
		Telemetry.track_error("save_parse_failed", "存档与备份均无法解析", {"path": path})
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
	last_patrol_day = 0
	patrol_delay_wave = 0
	current_event = {}
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
