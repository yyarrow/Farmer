extends SceneTree

const RUNS := 2000

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("Audio").shutdown()
	var state = root.get_node("State")
	state.reset_game()
	var cases := [
		{"name": "初始守军", "force": {"militia": 20, "archer": 0, "chariot": 0}, "wall": 0, "barracks": 0, "morale": 70.0, "min_win": 0.28, "max_win": 0.42},
		{"name": "基础备战", "force": {"militia": 25, "archer": 0, "chariot": 0}, "wall": 1, "barracks": 1, "morale": 74.0, "min_win": 0.58, "max_win": 0.76},
		{"name": "充分备战", "force": {"militia": 25, "archer": 5, "chariot": 0}, "wall": 1, "barracks": 2, "morale": 78.0, "min_win": 0.84, "max_win": 0.96},
	]
	var sim_rng := RandomNumberGenerator.new()
	sim_rng.seed = 3042026
	var failures: Array[String] = []
	for case_data in cases:
		state.buildings.wall = case_data.wall
		state.buildings.barracks = case_data.barracks
		var wins := 0
		var total_losses := 0
		for _i in RUNS:
			var result: Dictionary = state._simulate_battle(case_data.force, case_data.morale, state._make_enemy_army(1), sim_rng)
			wins += 1 if bool(result.won) else 0
			total_losses += int(result.player_losses)
		var win_rate := float(wins) / RUNS
		var average_losses := float(total_losses) / RUNS
		print("BALANCE_CASE %s win=%.1f%% avg_losses=%.2f" % [case_data.name, win_rate * 100.0, average_losses])
		if win_rate < float(case_data.min_win) or win_rate > float(case_data.max_win):
			failures.append("%s win rate %.3f outside target" % [case_data.name, win_rate])
		if average_losses <= 0.0:
			failures.append("%s has no casualties" % case_data.name)
	if failures.is_empty():
		print("BALANCE_SIM_OK runs=%d targets=3" % RUNS)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
