extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state := root.get_node("State")
	state.reset_game()
	_check(state.get_population_cap() == 34, "initial population cap")
	_check(state.get_defense() > 0, "initial defense")
	_check(state.get_rates().grain > 0.0, "initial grain production")

	state.resources = {"grain": 5000.0, "wood": 5000.0, "stone": 5000.0, "coins": 5000.0}
	_check(state.upgrade_building("market"), "build market")
	_check(state.buildings.market == 1, "market level updated")
	_check(state.trade("sell_grain"), "market trade")

	for _i in 3:
		state.upgrade_building("barracks")
	_check(state.buildings.barracks == 3, "barracks progression")
	_check(state.recruit("archer"), "archer unlock")
	_check(state.recruit("chariot"), "chariot unlock")
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
