extends RefCounted

const MAX_ACTIONS_PER_DAY := 4

var state: Node
var policy := "balanced"
var action_counts := {}
var invariant_errors: Array[String] = []
var patrols_by_wave := {}
var policy_used_day := {}

func _init(game_state: Node, policy_id: String) -> void:
	state = game_state
	policy = policy_id

func act_day() -> void:
	if not state.current_event.is_empty():
		_resolve_event()
	var actions := 0
	while actions < MAX_ACTIONS_PER_DAY:
		var acted := false
		match policy:
			"agrarian": acted = _act_agrarian()
			"militarist": acted = _act_militarist()
			"greedy": acted = _act_greedy()
			_: acted = _act_balanced()
		if not acted:
			break
		actions += 1

func finish_forced_choices() -> void:
	if not state.current_event.is_empty():
		_resolve_event()

func _act_balanced() -> bool:
	if float(state.morale) < 48.0 and _try_policy("reward_army"):
		return true
	if _try_advance_chapter():
		return true
	var wave := int(state.attack_wave)
	var wall_target := mini(5, 1 + floori((wave - 1) / 2.0))
	var barracks_target := mini(5, 1 + floori(wave / 2.0))
	var army_target := mini(state.get_army_capacity(), 25 + (wave - 1) * 7)
	var shortfall: bool = state.days_until_attack() <= 3 and _forecast_win_rate() < 0.68
	if shortfall:
		wall_target = mini(5, wall_target + 1)
		barracks_target = mini(5, barracks_target + 1)
	if _try_upgrade("wall", wall_target):
		return true
	if _try_upgrade("barracks", barracks_target):
		return true
	if (state.get_army_count() < army_target or shortfall) and _try_recruit_best(state.get_army_capacity() if shortfall else army_target):
		return true
	if state.days_until_attack() <= 2 and not bool(state.enemy_army.get("scouted", false)) and _try_patrol(1):
		return true
	var day := int(state.current_day)
	var economy_targets := {
		"farm": mini(5, 1 + floori(day / 12.0)),
		"quarry": mini(5, 1 + floori(day / 16.0)),
		"woodcut": mini(5, 1 + floori(day / 15.0)),
		"market": mini(5, floori(day / 14.0)),
		"house": mini(5, 1 + floori(day / 20.0)),
		"warehouse": mini(5, 1 + floori(day / 24.0)),
	}
	for id in ["farm", "quarry", "woodcut", "market", "house", "warehouse"]:
		if _try_upgrade(id, int(economy_targets[id])):
			return true
	return _try_liquidity_trade(240.0, 220.0)

func _act_agrarian() -> bool:
	if float(state.morale) < 42.0 and _try_policy("reward_army"):
		return true
	if _try_advance_chapter():
		return true
	var day := int(state.current_day)
	var economy_targets := {
		"farm": mini(5, 2 + floori(day / 12.0)),
		"quarry": mini(5, 1 + floori(day / 14.0)),
		"woodcut": mini(5, 2 + floori(day / 15.0)),
		"market": mini(5, 1 + floori(day / 18.0)),
		"house": mini(5, 1 + floori(day / 18.0)),
		"warehouse": mini(5, 1 + floori(day / 22.0)),
	}
	if state.days_until_attack() > 3:
		for id in ["farm", "quarry", "woodcut", "market", "house", "warehouse"]:
			if _try_upgrade(id, int(economy_targets[id])):
				return true
	var wave := int(state.attack_wave)
	var wall_target := mini(4, 1 + floori((wave - 1) / 2.0))
	var barracks_target := mini(4, 1 + floori((wave - 1) / 2.0))
	var army_target := mini(state.get_army_capacity(), 25 + (wave - 1) * 5)
	var shortfall: bool = state.days_until_attack() <= 3 and _forecast_win_rate() < 0.58
	if shortfall:
		wall_target = mini(5, wall_target + 1)
		barracks_target = mini(5, barracks_target + 1)
	if _try_upgrade("wall", wall_target):
		return true
	if _try_upgrade("barracks", barracks_target):
		return true
	if (state.get_army_count() < army_target or shortfall) and _try_recruit_best(state.get_army_capacity() if shortfall else army_target):
		return true
	for id in ["farm", "quarry", "woodcut", "market", "house", "warehouse"]:
		if _try_upgrade(id, int(economy_targets[id])):
			return true
	if state.days_until_attack() <= 1 and not bool(state.enemy_army.get("scouted", false)) and _try_patrol(1):
		return true
	return _try_liquidity_trade(300.0, 260.0)

func _act_militarist() -> bool:
	if (float(state.morale) < 58.0 or state.get_wounded_count() >= 8) and _try_policy("reward_army"):
		return true
	if _try_advance_chapter():
		return true
	var wave := int(state.attack_wave)
	var wall_target := mini(5, wave + 1)
	var barracks_target := mini(5, wave + 1)
	var core_wall_target := mini(5, wave)
	var core_barracks_target := mini(5, wave)
	var army_target := mini(state.get_army_capacity(), 35 + (wave - 1) * 10)
	var shortfall: bool = state.days_until_attack() <= 3 and _forecast_win_rate() < 0.78
	if _try_upgrade("wall", core_wall_target):
		return true
	if _try_upgrade("barracks", core_barracks_target):
		return true
	if (state.get_army_count() < army_target or shortfall) and _try_recruit_best(state.get_army_capacity() if shortfall else army_target):
		return true
	if _try_upgrade("wall", wall_target):
		return true
	if _try_upgrade("barracks", barracks_target):
		return true
	if state.days_until_attack() <= 3 and _try_patrol(1):
		return true
	var ledger: Dictionary = state.get_daily_ledger()
	if float(ledger.grain.net) < 5.0 and _try_upgrade("farm", 5):
		return true
	if float(ledger.coins.net) < 20.0:
		if _try_upgrade("market", 5):
			return true
		if _try_upgrade("house", 5):
			return true
	var support_target := mini(5, 1 + floori(int(state.current_day) / 18.0))
	for id in ["market", "house", "quarry", "woodcut", "farm", "warehouse"]:
		if _try_upgrade(id, support_target):
			return true
	return _try_liquidity_trade(180.0, 150.0)

func _act_greedy() -> bool:
	if _try_advance_chapter():
		return true
	var day := int(state.current_day)
	var economy_targets := {
		"farm": mini(5, 2 + floori(day / 10.0)),
		"quarry": mini(5, 1 + floori(day / 12.0)),
		"woodcut": mini(5, 2 + floori(day / 12.0)),
		"market": mini(5, 1 + floori(day / 12.0)),
		"house": mini(5, 2 + floori(day / 15.0)),
		"warehouse": mini(5, 1 + floori(day / 18.0)),
	}
	for id in ["farm", "market", "woodcut", "quarry", "house", "warehouse"]:
		if _try_upgrade(id, int(economy_targets[id])):
			return true
	return _try_liquidity_trade(360.0, 320.0)

func _try_advance_chapter() -> bool:
	if int(state.chapter) >= 3 or state.get_prosperity() < state.get_chapter_target():
		return false
	if state.advance_chapter():
		_record("advance_chapter")
		return true
	return false

func _try_policy(id: String) -> bool:
	if int(policy_used_day.get(id, 0)) == int(state.current_day):
		return false
	var cost: Dictionary = state.get_policy_cost(id)
	if cost.is_empty() or not state.get_policy_block_reason(id).is_empty() or not state.can_afford(cost):
		return false
	if state.enact_policy(id):
		policy_used_day[id] = int(state.current_day)
		_record("policy_%s" % id)
		return true
	return false

func _forecast_win_rate() -> float:
	return float(state.get_battle_forecast(12).win_rate)

func _try_upgrade(id: String, target: int) -> bool:
	if int(state.buildings[id]) >= target or int(state.buildings[id]) >= int(state.BUILDINGS[id].max):
		return false
	var cost: Dictionary = state.building_cost(id)
	if cost.has("stone") and float(state.resources.stone) < float(cost.stone):
		var price := maxi(380, 500 - int(state.buildings.market) * 20)
		if float(state.resources.coins) >= price and float(state.resources.stone) + 1.0 < state.get_capacity("stone"):
			if state.trade("buy_stone"):
				_record("trade_buy_stone")
				return true
	if not state.can_afford(cost):
		return false
	if state.upgrade_building(id):
		_record("build_%s" % id)
		return true
	return false

func _try_recruit_best(target: int) -> bool:
	if state.get_army_count() >= target or state.get_army_count() >= state.get_army_capacity():
		return false
	var candidates: Array[String] = []
	var army_count := maxi(1, state.get_army_count())
	if int(state.buildings.barracks) >= 3 and (policy == "militarist" or int(state.units.chariot) * 6 < army_count):
		candidates.append("chariot")
	if int(state.buildings.barracks) >= 2 and int(state.units.archer) * 3 < army_count:
		candidates.append("archer")
	candidates.append("militia")
	for id in candidates:
		var data: Dictionary = state.UNITS[id]
		if int(state.buildings.barracks) < int(data.need) or not state.can_afford(data.cost):
			continue
		var residents_before: int = state.get_total_residents()
		if state.recruit(id):
			if state.get_total_residents() != residents_before:
				invariant_errors.append("recruitment did not conserve residents on day %d" % int(state.current_day))
			_record("recruit_%s" % id)
			return true
	return false

func _try_patrol(limit_per_wave: int) -> bool:
	var wave := int(state.attack_wave)
	if int(patrols_by_wave.get(wave, 0)) >= limit_per_wave:
		return false
	if int(state.last_patrol_day) == int(state.current_day) or state.get_army_count() < 10:
		return false
	if float(state.resources.grain) < 6.0 or float(state.resources.coins) < 40.0:
		return false
	var enemy_before: int = state._sum_force(state.enemy_army)
	var wave_before := int(state.attack_wave)
	if state.patrol():
		patrols_by_wave[wave] = int(patrols_by_wave.get(wave, 0)) + 1
		_record("patrol")
		var won: bool = int(state.attack_wave) > wave_before or state._sum_force(state.enemy_army) < enemy_before
		_record("patrol_win" if won else "patrol_loss")
		return true
	return false

func _try_liquidity_trade(grain_reserve: float, wood_reserve: float) -> bool:
	if float(state.resources.coins) >= 220.0:
		return false
	if float(state.resources.grain) >= grain_reserve + 55.0 and state.trade("sell_grain"):
		_record("trade_sell_grain")
		return true
	if float(state.resources.wood) >= wood_reserve + 40.0 and state.trade("sell_wood"):
		_record("trade_sell_wood")
		return true
	return false

func _resolve_event() -> void:
	var id := str(state.current_event.get("id", ""))
	var choice := _event_choice(id)
	if not state.is_event_choice_available(choice):
		for candidate in state.current_event.options.size():
			if state.is_event_choice_available(candidate):
				choice = candidate
				break
	state.resolve_event(choice)
	_record("event_%s_%d" % [id, choice])

func _event_choice(id: String) -> int:
	match id:
		"drought":
			return 0 if state.can_afford({"wood": 28, "stone": 18}) else 1
		"refugees":
			if policy == "militarist":
				return 1
			return 0 if state.get_total_residents() + 20 <= state.get_population_cap() and float(state.resources.grain) >= 90.0 else 1
		"merchant":
			if policy in ["agrarian", "greedy"] and float(state.resources.coins) >= 900.0:
				return 0
			return 1 if float(state.resources.grain) >= 260.0 else 2
		"scouts":
			if policy in ["balanced", "militarist"] and float(state.resources.coins) >= 420.0:
				return 0
			return 1
		"harvest":
			return 1 if float(state.morale) < 62.0 else 0
		"flood":
			return 0 if state.can_afford({"wood": 30, "stone": 18}) else 1
		"winter_relief":
			return 0 if float(state.resources.grain) >= 96.0 else 1
		"craftsmen":
			return 0 if policy in ["agrarian", "greedy"] and state.can_afford({"coins": 480, "wood": 16}) else 1
		"rumors":
			return 0 if policy in ["balanced", "militarist"] and float(state.resources.coins) >= 320.0 else 1
		"levy":
			return 0 if state.can_afford({"grain": 45, "coins": 220}) else 1
	return 0

func _record(action: String) -> void:
	action_counts[action] = int(action_counts.get(action, 0)) + 1
