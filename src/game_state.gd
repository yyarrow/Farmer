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
const DAY_SECONDS := 24.0
const MAX_OFFLINE_SECONDS := 7200.0

const BUILDINGS := {
	"farm": {"name": "农田", "glyph": "田", "desc": "灌溉阡陌，持续产出粮食", "max": 5, "base": {"wood": 34, "stone": 12, "coins": 18}},
	"woodcut": {"name": "林场", "glyph": "木", "desc": "轮伐山林，持续产出木材", "max": 5, "base": {"grain": 22, "stone": 10, "coins": 22}},
	"quarry": {"name": "石场", "glyph": "石", "desc": "开采石料，用于城防与扩建", "max": 5, "base": {"grain": 30, "wood": 24, "coins": 28}},
	"house": {"name": "民居", "glyph": "舍", "desc": "提高人口上限与赋税收入", "max": 5, "base": {"wood": 42, "stone": 18, "coins": 25}},
	"market": {"name": "市集", "glyph": "市", "desc": "增加铜钱产出，改善交易价格", "max": 5, "base": {"wood": 48, "stone": 22, "coins": 35}},
	"warehouse": {"name": "仓廪", "glyph": "仓", "desc": "提高资源储量，减少灾害损失", "max": 5, "base": {"wood": 40, "stone": 30, "coins": 20}},
	"barracks": {"name": "兵营", "glyph": "兵", "desc": "训练更强兵种，提高军队士气", "max": 5, "base": {"grain": 55, "wood": 55, "stone": 26, "coins": 45}},
	"wall": {"name": "城垣", "glyph": "城", "desc": "直接增强守城战力，保护百姓", "max": 5, "base": {"grain": 30, "wood": 60, "stone": 75, "coins": 50}},
}

const UNITS := {
	"militia": {"name": "乡勇", "glyph": "勇", "power": 3, "need": 0, "cost": {"grain": 34, "coins": 18}, "upkeep": 0.026},
	"archer": {"name": "弓手", "glyph": "弓", "power": 7, "need": 2, "cost": {"grain": 48, "wood": 28, "coins": 42}, "upkeep": 0.052},
	"chariot": {"name": "战车", "glyph": "车", "power": 16, "need": 3, "cost": {"grain": 78, "wood": 32, "stone": 18, "coins": 95}, "upkeep": 0.11},
}

const EVENTS := [
	{"id": "drought", "title": "旱意初显", "body": "东渠水位骤降，田间已有龟裂。若不处置，今岁收成恐受影响。", "options": ["疏浚旧渠", "开仓稳民"]},
	{"id": "refugees", "title": "流民叩关", "body": "邻邑战乱，一队流民携农具来到城下，请求在此安家。", "options": ["接纳入籍", "赈粮送行"]},
	{"id": "merchant", "title": "齐商来访", "body": "远来的商队带着铁制农具，愿以高价换取本地粮草。", "options": ["购置农具", "出售粮草"]},
	{"id": "scouts", "title": "烽燧疑云", "body": "斥候发现陌生骑手窥探城防，边境气氛骤然紧张。", "options": ["派斥候反侦", "封关戒严"]},
	{"id": "harvest", "title": "嘉禾同穗", "body": "田中生出双穗嘉禾，百姓认为是丰年的吉兆。", "options": ["入仓备荒", "设宴庆贺"]},
]

var resources := {"grain": 180.0, "wood": 125.0, "stone": 82.0, "coins": 150.0}
var buildings := {"farm": 1, "woodcut": 1, "quarry": 0, "house": 1, "market": 0, "warehouse": 1, "barracks": 0, "wall": 0}
var units := {"militia": 4, "archer": 0, "chariot": 0}
var population := 22
var morale := 70.0
var threat := 24.0
var current_day := 1
var chapter := 1
var day_progress := 0.0
var next_attack_day := 7
var tutorial_seen := false
var current_event: Dictionary = {}
var buffs := {"farm_until": 0, "all_until": 0}
var offline_report := ""
var time_speed := 0.0
var modal_paused := false
var rng := RandomNumberGenerator.new()
var _change_accum := 0.0
var _save_accum := 0.0

func _ready() -> void:
	rng.randomize()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	_migrate_legacy_save()
	load_game()
	set_process(true)
	Telemetry.track("game_state_ready", {"day": current_day, "chapter": chapter})

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
		resources[key] = clampf(resources[key] + rates.get(key, 0.0) * delta, 0.0, get_capacity(key))

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

func get_rates() -> Dictionary:
	var all_bonus := 1.22 if current_day <= int(buffs.get("all_until", 0)) else 1.0
	var farm_bonus := 1.35 if current_day <= int(buffs.get("farm_until", 0)) else 1.0
	var market_bonus := 1.0 + float(buildings.market) * 0.08
	var army_upkeep := 0.0
	for id in UNITS:
		army_upkeep += float(units[id]) * float(UNITS[id].upkeep)
	return {
		"grain": (0.62 * buildings.farm * farm_bonus * all_bonus) - population * 0.004 - army_upkeep,
		"wood": 0.36 * buildings.woodcut * all_bonus,
		"stone": 0.24 * buildings.quarry * all_bonus,
		"coins": (0.16 * buildings.house + 0.29 * buildings.market + population * 0.006) * market_bonus * all_bonus - army_upkeep * 0.34,
	}

func get_capacity(_resource_id: String) -> float:
	return 520.0 + float(buildings.warehouse) * 360.0

func get_population_cap() -> int:
	return 18 + buildings.house * 16

func get_army_count() -> int:
	return units.militia + units.archer + units.chariot

func get_army_power() -> int:
	var power := 0
	for id in UNITS:
		power += int(units[id]) * int(UNITS[id].power)
	return roundi(power * (0.75 + morale / 200.0))

func get_defense() -> int:
	return get_army_power() + buildings.wall * 15 + buildings.barracks * 4

func get_next_enemy_power() -> int:
	return roundi(16.0 + current_day * 2.8 + chapter * 11.0 + threat * 0.12)

func days_until_attack() -> int:
	return maxi(0, next_attack_day - current_day)

func get_prosperity() -> int:
	var building_score := 0
	for id in buildings:
		building_score += int(buildings[id]) * 10
	return building_score + population + get_army_count() * 2 + chapter * 8

func get_chapter_target() -> int:
	return 125 + (chapter - 1) * 85

func building_cost(id: String) -> Dictionary:
	var level := int(buildings[id])
	var scale := pow(1.58, level)
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
		notice.emit("资源不足，先经营一会儿吧")
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
		population = mini(get_population_cap(), population + 3)
	if id == "barracks":
		morale = minf(100.0, morale + 5.0)
	changed.emit()
	notice.emit(("建成 " if level == 0 else "升级 ") + BUILDINGS[id].name)
	var event_kind := "build" if level == 0 else "upgrade"
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
	if get_army_count() >= population:
		notice.emit("人口不足，无法继续征募")
		return false
	if not spend(data.cost):
		return false
	units[id] += 1
	morale = maxf(35.0, morale - 0.7)
	changed.emit()
	notice.emit("一队%s加入守军" % data.name)
	visual_event.emit("recruit", {"unit": id, "count": units[id]})
	Audio.play_sfx("recruit")
	Telemetry.track("unit_recruited", {"unit": id, "count": units[id], "army_power": get_army_power()})
	save_game()
	return true

func trade(kind: String) -> bool:
	var ok := false
	match kind:
		"sell_grain":
			ok = spend({"grain": 55})
			if ok: resources.coins += 34 + buildings.market * 3
		"buy_grain":
			ok = spend({"coins": maxi(34, 46 - buildings.market * 2)})
			if ok: resources.grain += 55
		"sell_wood":
			ok = spend({"wood": 40})
			if ok: resources.coins += 30 + buildings.market * 2
		"buy_stone":
			ok = spend({"coins": maxi(38, 50 - buildings.market * 2)})
			if ok: resources.stone += 35
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
			if not spend({"wood": 35, "stone": 24, "coins": 28}): return false
			buffs.farm_until = current_day + 3
			notice.emit("水利修成：三日内粮食增产")
		"tax_relief":
			if not spend({"coins": 65, "grain": 35}): return false
			population = mini(get_population_cap(), population + 7)
			morale = minf(100.0, morale + 12.0)
			notice.emit("轻徭薄赋：民心与人口上升")
		"reward_army":
			if not spend({"grain": 60, "coins": 45}): return false
			morale = minf(100.0, morale + 18.0)
			threat = maxf(0.0, threat - 8.0)
			notice.emit("犒赏三军：士气大振")
		_:
			return false
	changed.emit()
	visual_event.emit("policy", {"policy": id})
	Audio.play_sfx("event")
	Telemetry.track("policy_enacted", {"policy": id, "day": current_day})
	save_game()
	return true

func patrol() -> bool:
	if get_army_count() < 3:
		notice.emit("至少需要三队士卒才能出城巡剿")
		return false
	if not spend({"grain": 38, "coins": 18}):
		return false
	var roll := get_army_power() * rng.randf_range(0.82, 1.2)
	var enemy := 18.0 + current_day * 1.7
	if roll >= enemy:
		threat = maxf(0.0, threat - 26.0)
		resources.coins = minf(get_capacity("coins"), resources.coins + 35.0)
		morale = minf(100.0, morale + 5.0)
		notice.emit("巡剿得胜，缴获铜钱并降低威胁")
		visual_event.emit("patrol_win", {"power": get_army_power(), "enemy": enemy})
		Audio.play_sfx("battle_win")
	else:
		_apply_casualties(0.10)
		morale = maxf(20.0, morale - 8.0)
		notice.emit("巡剿失利，部分士卒负伤")
		visual_event.emit("patrol_loss", {"power": get_army_power(), "enemy": enemy})
		Audio.play_sfx("battle_loss")
	changed.emit()
	Telemetry.track("patrol_resolved", {"won": roll >= enemy, "roll": roll, "enemy": enemy})
	save_game()
	return true

func _advance_day() -> void:
	current_day += 1
	if resources.grain > population * 1.2 and population < get_population_cap():
		population += 1
	elif resources.grain < 8.0:
		population = maxi(6, population - 1)
		morale = maxf(10.0, morale - 5.0)
	threat = minf(100.0, threat + 6.0 + current_day * 0.22)
	morale = clampf(morale + (0.8 if resources.grain > 50 else -1.5), 10.0, 100.0)
	if current_day >= next_attack_day:
		_resolve_siege()
	elif current_event.is_empty() and current_day % 3 == 0:
		_start_random_event()
	changed.emit()
	save_game()

func _start_random_event() -> void:
	set_time_speed(0.0, "random_event")
	current_event = EVENTS[rng.randi_range(0, EVENTS.size() - 1)].duplicate(true)
	Audio.play_sfx("event")
	visual_event.emit("event", {"id": current_event.id})
	Telemetry.track("random_event_started", {"id": current_event.id, "day": current_day})
	event_started.emit(current_event)

func resolve_event(choice: int) -> void:
	if current_event.is_empty():
		return
	var id: String = current_event.id
	match id:
		"drought":
			if choice == 0 and spend({"wood": 28, "stone": 18}):
				buffs.farm_until = current_day + 3
				notice.emit("旧渠复通，农田转危为安")
			else:
				resources.grain = maxf(0.0, resources.grain - 45.0)
				morale = minf(100.0, morale + 4.0)
				notice.emit("开仓赈济，百姓得以安心")
		"refugees":
			if choice == 0 and spend({"grain": 58}):
				population = mini(get_population_cap(), population + 8)
				morale = minf(100.0, morale + 6.0)
				notice.emit("新民入籍，田野更添生气")
			else:
				resources.grain = maxf(0.0, resources.grain - 28.0)
				morale = minf(100.0, morale + 2.0)
		"merchant":
			if choice == 0 and spend({"coins": 72}):
				buffs.all_until = current_day + 3
				notice.emit("新农具使全邑生产加快")
			else:
				resources.grain = maxf(0.0, resources.grain - 75.0)
				resources.coins += 62.0
				notice.emit("商队满载而归，铜钱入库")
		"scouts":
			if choice == 0 and spend({"coins": 32}):
				threat = maxf(0.0, threat - 18.0)
				notice.emit("斥候带回敌军动向")
			else:
				threat = maxf(0.0, threat - 8.0)
				morale = maxf(10.0, morale - 4.0)
		"harvest":
			if choice == 0:
				resources.grain = minf(get_capacity("grain"), resources.grain + 105.0)
				notice.emit("嘉禾入仓，粮储充盈")
			else:
				resources.grain += 42.0
				morale = minf(100.0, morale + 15.0)
				notice.emit("与民同乐，举邑欢腾")
	current_event = {}
	changed.emit()
	visual_event.emit("event_choice", {"id": id, "choice": choice})
	Telemetry.track("random_event_resolved", {"id": id, "choice": choice, "resources": resources.duplicate()})
	save_game()

func _resolve_siege() -> void:
	set_time_speed(0.0, "siege")
	var enemy := get_next_enemy_power()
	var defense := get_defense()
	var rolled := roundi(defense * rng.randf_range(0.86, 1.15))
	var won := rolled >= enemy
	var result := {"won": won, "enemy": enemy, "defense": defense, "loss_text": ""}
	if won:
		_apply_casualties(0.05)
		resources.coins = minf(get_capacity("coins"), resources.coins + 45.0 + chapter * 12.0)
		morale = minf(100.0, morale + 9.0)
		result.loss_text = "守军击退来敌，并缴获一批军资。"
	else:
		_apply_casualties(0.18)
		var protection := 1.0 - minf(0.58, buildings.warehouse * 0.10 + buildings.wall * 0.05)
		var lost_grain := minf(resources.grain, (55.0 + current_day * 2.0) * protection)
		var lost_coins := minf(resources.coins, (32.0 + current_day) * protection)
		resources.grain -= lost_grain
		resources.coins -= lost_coins
		morale = maxf(10.0, morale - 14.0)
		result.loss_text = "城外仓舍受损，损失粮食 %d、铜钱 %d。" % [roundi(lost_grain), roundi(lost_coins)]
	threat = 18.0
	next_attack_day = current_day + maxi(4, 7 - chapter)
	visual_event.emit("siege_win" if won else "siege_loss", result)
	Audio.play_sfx("battle_win" if won else "battle_loss")
	Telemetry.track("siege_resolved", result.merged({"day": current_day, "chapter": chapter}))
	battle_finished.emit(result)

func _apply_casualties(ratio: float) -> void:
	for id in ["chariot", "archer", "militia"]:
		var count := int(units[id])
		if count > 0 and rng.randf() < ratio * count:
			units[id] = maxi(0, count - 1)

func advance_chapter() -> bool:
	if get_prosperity() < get_chapter_target():
		notice.emit("繁荣度尚不足以扩建城邑")
		return false
	if chapter >= 3:
		notice.emit("青禾已成一方强邑")
		return false
	chapter += 1
	set_time_speed(0.0, "chapter_advanced")
	resources.coins = minf(get_capacity("coins"), resources.coins + 120.0)
	resources.grain = minf(get_capacity("grain"), resources.grain + 150.0)
	population = mini(get_population_cap(), population + 5)
	threat += 15.0
	next_attack_day = mini(next_attack_day, current_day + 4)
	notice.emit("城邑晋升！新的挑战正在逼近")
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
		"format_version": 2,
		"resources": resources.duplicate(true),
		"buildings": buildings.duplicate(true),
		"units": units.duplicate(true),
		"population": population,
		"morale": morale,
		"threat": threat,
		"current_day": current_day,
		"chapter": chapter,
		"day_progress": day_progress,
		"next_attack_day": next_attack_day,
		"tutorial_seen": tutorial_seen,
		"current_event": current_event.duplicate(true),
		"buffs": buffs.duplicate(true),
		"prosperity": get_prosperity(),
		"saved_at": Time.get_unix_time_from_system(),
	}

func _apply_snapshot(data: Dictionary, apply_offline: bool) -> void:
	resources = {"grain": 180.0, "wood": 125.0, "stone": 82.0, "coins": 150.0}
	resources.merge(data.get("resources", {}), true)
	buildings = {"farm": 1, "woodcut": 1, "quarry": 0, "house": 1, "market": 0, "warehouse": 1, "barracks": 0, "wall": 0}
	buildings.merge(data.get("buildings", {}), true)
	units = {"militia": 4, "archer": 0, "chariot": 0}
	units.merge(data.get("units", {}), true)
	population = int(data.get("population", 22))
	morale = float(data.get("morale", 70.0))
	threat = float(data.get("threat", 24.0))
	current_day = int(data.get("current_day", 1))
	chapter = int(data.get("chapter", 1))
	day_progress = float(data.get("day_progress", 0.0))
	next_attack_day = int(data.get("next_attack_day", 7))
	tutorial_seen = bool(data.get("tutorial_seen", tutorial_seen))
	time_speed = 0.0
	buffs = {"farm_until": 0, "all_until": 0}
	buffs.merge(data.get("buffs", {}), true)
	current_event = data.get("current_event", {}).duplicate(true)
	offline_report = ""
	if apply_offline:
		_apply_offline_progress(data)

func _apply_offline_progress(data: Dictionary) -> void:
	var elapsed := clampf(Time.get_unix_time_from_system() - float(data.get("saved_at", Time.get_unix_time_from_system())), 0.0, MAX_OFFLINE_SECONDS)
	if elapsed >= 30.0:
		var rates := get_rates()
		var gains := []
		for key in resources:
			var gain: float = maxf(0.0, float(rates.get(key, 0.0))) * elapsed * 0.45
			resources[key] = minf(get_capacity(key), resources[key] + gain)
			if gain >= 1.0:
				gains.append("%s +%d" % [_resource_name(key), roundi(gain)])
		if not gains.is_empty():
			offline_report = "离城期间：" + "  ".join(gains)
			Telemetry.track("offline_rewards", {"elapsed": roundi(elapsed), "gains": gains})

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
	if not FileAccess.file_exists(path):
		return false
	var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if error == OK:
		Telemetry.track("manual_save_deleted", {"slot": slot})
		save_slots_changed.emit()
		return true
	Telemetry.track_error("save_delete_failed", error_string(error), {"slot": slot})
	return false

func list_save_slots() -> Array:
	var slots: Array = []
	for slot in range(1, SLOT_COUNT + 1):
		var path := _slot_path(slot)
		var data := _read_save(path)
		if data.is_empty():
			slots.append({"slot": slot, "exists": false})
		else:
			slots.append({
				"slot": slot,
				"exists": true,
				"day": int(data.get("current_day", 1)),
				"chapter": int(data.get("chapter", 1)),
				"prosperity": int(data.get("prosperity", 0)),
				"saved_at": float(data.get("saved_at", 0.0)),
			})
	return slots

func _slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot]

func _write_save(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		Telemetry.track_error("save_open_failed", "无法写入存档", {"path": path, "error": FileAccess.get_open_error()})
		return false
	file.store_string(JSON.stringify(data))
	return true

func _read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func _migrate_legacy_save() -> void:
	if FileAccess.file_exists(AUTO_SAVE_PATH) or not FileAccess.file_exists(LEGACY_SAVE_PATH):
		return
	var data := _read_save(LEGACY_SAVE_PATH)
	if not data.is_empty() and _write_save(AUTO_SAVE_PATH, data):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LEGACY_SAVE_PATH))
		Telemetry.track("legacy_save_migrated", {"format": data.get("format_version", 1)})

func reset_game() -> void:
	resources = {"grain": 180.0, "wood": 125.0, "stone": 82.0, "coins": 150.0}
	buildings = {"farm": 1, "woodcut": 1, "quarry": 0, "house": 1, "market": 0, "warehouse": 1, "barracks": 0, "wall": 0}
	units = {"militia": 4, "archer": 0, "chariot": 0}
	population = 22
	morale = 70.0
	threat = 24.0
	current_day = 1
	chapter = 1
	day_progress = 0.0
	next_attack_day = 7
	current_event = {}
	buffs = {"farm_until": 0, "all_until": 0}
	offline_report = ""
	time_speed = 0.0
	modal_paused = false
	changed.emit()
	visual_event.emit("new_game", {})
	Telemetry.track("new_game", {})
	save_game()

func _resource_name(id: String) -> String:
	return {"grain": "粮", "wood": "木", "stone": "石", "coins": "钱"}.get(id, id)
