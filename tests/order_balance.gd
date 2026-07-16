extends SceneTree

const RUNS := 3000

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("Audio").shutdown()
	var state = root.get_node("State")
	state.persistence_enabled = false
	state.reset_game()
	var militia := {"militia": 30, "archer": 0, "chariot": 0}
	var archers := {"militia": 25, "archer": 15, "chariot": 0}
	var chariots := {"militia": 25, "archer": 5, "chariot": 15}
	var enemy: Dictionary = state._make_enemy_army(2)
	var results := {}
	for scenario in [
		{"id": "militia", "force": militia, "wall": 1, "barracks": 2},
		{"id": "archers", "force": archers, "wall": 1, "barracks": 3},
		{"id": "chariots", "force": chariots, "wall": 1, "barracks": 3},
	]:
		results[scenario.id] = {}
		state.buildings.wall = int(scenario.wall)
		state.buildings.barracks = int(scenario.barracks)
		for order_id in state.DEFENSE_ORDERS:
			state.defense_order = str(order_id)
			var metrics := _simulate(state, scenario.force, enemy, int(hash(str(scenario.id))) & 0x7fffffff)
			results[scenario.id][order_id] = metrics
			print("ORDER_CASE %s/%s win=%.1f%% own=%.2f enemy=%.2f" % [scenario.id, order_id, metrics.win_rate * 100.0, metrics.player_losses, metrics.enemy_losses])

	var militia_steady: Dictionary = results.militia.steady
	var militia_fortify: Dictionary = results.militia.fortify
	_check(float(militia_fortify.player_losses) <= float(militia_steady.player_losses) * 0.90, "坚壁 must materially reduce casualties")
	_check(float(militia_fortify.enemy_losses) < float(militia_steady.enemy_losses), "坚壁 must trade away enemy losses")

	var archer_steady: Dictionary = results.archers.steady
	var archer_volley: Dictionary = results.archers.volley
	var militia_volley: Dictionary = results.militia.volley
	_check(float(archer_volley.enemy_losses) >= float(archer_steady.enemy_losses) * 1.06, "雁行 must reward a real archer contingent")
	_check(float(militia_volley.enemy_losses) < float(militia_steady.enemy_losses), "雁行 must not help an army without archers")

	var chariot_steady: Dictionary = results.chariots.steady
	var chariot_sally: Dictionary = results.chariots.sally
	_check(float(chariot_sally.enemy_losses) >= float(chariot_steady.enemy_losses) * 1.06, "锋矢 must reward a melee-heavy army")
	_check(float(chariot_sally.player_losses) >= float(chariot_steady.player_losses) * 1.06, "锋矢 must carry a visible casualty risk")

	if failures.is_empty():
		print("ORDER_BALANCE_OK runs=%d scenarios=3 orders=4 tradeoffs=6" % RUNS)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _simulate(state: Node, force: Dictionary, enemy: Dictionary, seed: int) -> Dictionary:
	var sim_rng := RandomNumberGenerator.new()
	sim_rng.seed = seed
	var wins := 0
	var player_losses := 0
	var enemy_losses := 0
	for _i in RUNS:
		var result: Dictionary = state._simulate_battle(force, 76.0, enemy, sim_rng)
		wins += 1 if bool(result.won) else 0
		player_losses += int(result.player_losses)
		enemy_losses += int(result.enemy_losses)
	return {
		"win_rate": float(wins) / RUNS,
		"player_losses": float(player_losses) / RUNS,
		"enemy_losses": float(enemy_losses) / RUNS,
	}

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
