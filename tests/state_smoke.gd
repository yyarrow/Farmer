extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state := root.get_node("State")
	state.reset_game()
	_check(state.get_population_cap() == 150, "initial population cap")
	_check(state.get_defense() > 0, "initial defense")
	_check(state.get_rates().grain > 0.0, "initial grain production")
	var ledger: Dictionary = state.get_daily_ledger()
	_check(absf(float(ledger.grain.net) - 10.6667) < 0.01, "initial grain ledger")
	_check(absf(float(ledger.coins.expense) - 8.0) < 0.01, "military upkeep is explicit")
	state.wounded.militia = 5
	_check(not state.recruit("militia"), "wounded soldiers continue to occupy roster capacity")
	state.reset_game()
	var paused_grain: float = state.resources.grain
	state._process(10.0)
	_check(state.current_day == 1 and is_equal_approx(state.resources.grain, paused_grain), "new game starts paused")
	state.set_time_speed(2.0)
	state._process(12.1)
	_check(state.current_day == 2, "double speed advances time")
	state.set_time_speed(1.0)
	state.set_modal_paused(true)
	var modal_progress: float = state.day_progress
	state._process(5.0)
	_check(is_equal_approx(state.day_progress, modal_progress), "modal pauses simulation")
	state.set_modal_paused(false)
	state.set_time_speed(0.0)
	_check(state.advance_one_day() and state.current_day == 3, "manual day advance")
	_check(not state.current_event.is_empty() and state.time_speed == 0.0, "event forces pause")
	state.resolve_event(1)
	state.reset_game()

	state.resources = {"grain": 5000.0, "wood": 5000.0, "stone": 5000.0, "coins": 5000.0}
	_check(state.upgrade_building("market"), "build market")
	_check(state.buildings.market == 1, "market level updated")
	var grain_before_trade: float = state.resources.grain
	var coins_before_trade: float = state.resources.coins
	_check(state.trade("sell_grain"), "market trade")
	_check(is_equal_approx(state.resources.grain, grain_before_trade - 55.0), "trade spends exact grain")
	_check(is_equal_approx(state.resources.coins, coins_before_trade + 370.0), "market level improves exact sale price")

	for _i in 3:
		state.upgrade_building("barracks")
	_check(state.buildings.barracks == 3, "barracks progression")
	var civilians_before_recruit: int = state.population
	_check(state.recruit("archer"), "archer unlock")
	_check(state.recruit("chariot"), "chariot unlock")
	_check(state.population == civilians_before_recruit - 10, "recruitment transfers real people")
	_check(state.units.archer == 5 and state.units.chariot == 5, "recruitment uses five-person squads")
	_check(state.get_army_power() > 20, "army power calculation")

	state.current_event = state.EVENTS[4].duplicate(true)
	state.resources.grain = 500.0
	var grain_before: float = state.resources.grain
	state.resolve_event(0)
	_check(state.resources.grain > grain_before, "event resolution")

	state.reset_game()
	if failures.is_empty():
		print("STATE_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
