extends SceneTree

const HeadlessPlayer = preload("res://tests/headless_player.gd")
const DEFAULT_POLICIES := ["balanced", "agrarian", "militarist", "greedy"]
const POLICY_NAMES := {
	"balanced": "均衡经营",
	"agrarian": "重农发展",
	"militarist": "重军备战",
	"greedy": "贪发展不设防",
}

var state: Node
var current_battles: Array[Dictionary] = []
var invariant_failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	state = root.get_node("State")
	var audio = root.get_node("Audio")
	var config := _parse_config()
	state.persistence_enabled = false
	audio.settings.diagnostics_enabled = false
	if audio.music_player:
		audio.music_player.stop()
	audio.sfx_players.clear()
	state.battle_finished.connect(_on_battle_finished)
	var started_ms := Time.get_ticks_msec()
	var policy_reports := {}
	for policy in config.policies:
		policy_reports[policy] = _run_policy(policy, int(config.runs), int(config.days), int(config.seed))
	var mechanic_probes := {
		"patrol_spam": _run_patrol_spam_probe(int(config.runs), int(config.days), int(config.seed) + 9000001),
	}
	var warnings := _analyze_balance(policy_reports, mechanic_probes, int(config.days))
	var report := {
		"report_version": 1,
		"generated_at": Time.get_datetime_string_from_system(false, true),
		"game_version": ProjectSettings.get_setting("application/config/version", "unknown"),
		"config": config,
		"elapsed_seconds": snappedf((Time.get_ticks_msec() - started_ms) / 1000.0, 0.01),
		"stable_definition": "终局民心>=35、军籍>=10、粮储覆盖>=3日且结尾连续败绩<2；历史最大连败另行记录",
		"policies": policy_reports,
		"mechanic_probes": mechanic_probes,
		"warnings": warnings,
		"invariant_failures": invariant_failures,
	}
	var paths := _write_reports(str(config.report), report)
	_print_summary(report, paths)
	if not invariant_failures.is_empty() or (bool(config.strict) and not warnings.is_empty()):
		quit(1)
	else:
		quit(0)

func _parse_config() -> Dictionary:
	var config := {
		"runs": 1000,
		"days": 60,
		"seed": 20260715,
		"policies": DEFAULT_POLICIES.duplicate(),
		"report": "res://.qa/headless_balance_report.json",
		"strict": false,
	}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--runs="):
			config.runs = maxi(1, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--days="):
			config.days = maxi(7, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--seed="):
			config.seed = int(arg.get_slice("=", 1))
		elif arg.begins_with("--policy="):
			var requested := arg.get_slice("=", 1)
			if requested in DEFAULT_POLICIES:
				config.policies = [requested]
		elif arg.begins_with("--report="):
			config.report = arg.get_slice("=", 1)
		elif arg == "--strict":
			config.strict = true
	return config

func _run_policy(policy: String, runs: int, target_day: int, base_seed: int) -> Dictionary:
	var results: Array[Dictionary] = []
	for run_index in runs:
		var seed := base_seed + DEFAULT_POLICIES.find(policy) * 1000003 + run_index * 97
		results.append(_run_once(policy, seed, target_day))
	return _aggregate(policy, results, target_day)

func _run_once(policy: String, seed: int, target_day: int) -> Dictionary:
	state.reset_game()
	state.rng.seed = seed
	state.tutorial_seen = true
	current_battles.clear()
	var player = HeadlessPlayer.new(state, policy)
	var negative_grain_days := 0
	var negative_coin_days := 0
	var critical_days := 0
	var min_grain := float(state.resources.grain)
	var min_coins := float(state.resources.coins)
	var run_errors: Array[String] = []
	while int(state.current_day) < target_day:
		player.act_day()
		_collect_invariants(policy, seed, run_errors)
		var ledger: Dictionary = state.get_daily_ledger()
		negative_grain_days += 1 if float(ledger.grain.net) < 0.0 else 0
		negative_coin_days += 1 if float(ledger.coins.net) < 0.0 else 0
		critical_days += 1 if float(state.morale) <= 25.0 or state.get_army_count() < 5 else 0
		min_grain = minf(min_grain, float(state.resources.grain))
		min_coins = minf(min_coins, float(state.resources.coins))
		if not state.advance_one_day():
			_append_unique(run_errors, "advance_one_day rejected on day %d" % int(state.current_day))
			break
		player.finish_forced_choices()
		_collect_invariants(policy, seed, run_errors)
		if int(state.current_day) % 15 == 0:
			_check_snapshot_roundtrip(run_errors)
	var battle_wins := 0
	var casualties := 0
	var killed := 0
	var wounded_total := 0
	var enemy_losses := 0
	var current_defeat_streak := 0
	var max_defeat_streak := 0
	for battle in current_battles:
		if bool(battle.won):
			battle_wins += 1
			current_defeat_streak = 0
		else:
			current_defeat_streak += 1
			max_defeat_streak = maxi(max_defeat_streak, current_defeat_streak)
		casualties += int(battle.player_losses)
		killed += int(battle.killed_total)
		wounded_total += int(battle.wounded_total)
		enemy_losses += int(battle.enemy_losses)
	var final_ledger: Dictionary = state.get_daily_ledger()
	var grain_cover_days: float = float(state.resources.grain) / maxf(0.01, float(final_ledger.grain.expense))
	var stable: bool = float(state.morale) >= 35.0 and state.get_army_count() >= 10 and grain_cover_days >= 3.0 and current_defeat_streak < 2
	for error in player.invariant_errors:
		_append_unique(run_errors, error)
	for error in run_errors:
		_append_unique(invariant_failures, "%s seed=%d: %s" % [policy, seed, error], 100)
	return {
		"seed": seed,
		"battles": current_battles.size(),
		"battle_wins": battle_wins,
		"first_battle_won": bool(current_battles[0].won) if not current_battles.is_empty() else false,
		"first_battle_day": int(current_battles[0].day) if not current_battles.is_empty() else 0,
		"max_defeat_streak": max_defeat_streak,
		"ending_defeat_streak": current_defeat_streak,
		"casualties": casualties,
		"killed": killed,
		"wounded": wounded_total,
		"enemy_losses": enemy_losses,
		"negative_grain_days": negative_grain_days,
		"negative_coin_days": negative_coin_days,
		"critical_days": critical_days,
		"min_grain": min_grain,
		"min_coins": min_coins,
		"stable": stable,
		"grain_cover_days": grain_cover_days,
		"final": {
			"day": int(state.current_day),
			"chapter": int(state.chapter),
			"wave": int(state.attack_wave),
			"population": int(state.population),
			"army": state.get_army_count(),
			"wounded": state.get_wounded_count(),
			"morale": float(state.morale),
			"prosperity": state.get_prosperity(),
			"grain": float(state.resources.grain),
			"wood": float(state.resources.wood),
			"stone": float(state.resources.stone),
			"coins": float(state.resources.coins),
			"buildings": state.buildings.duplicate(true),
		},
		"actions": player.action_counts.duplicate(true),
		"invariant_errors": run_errors,
	}

func _on_battle_finished(result: Dictionary) -> void:
	var recorded: Dictionary = result.duplicate(true)
	recorded.day = int(state.current_day)
	current_battles.append(recorded)

func _run_patrol_spam_probe(runs: int, target_day: int, base_seed: int) -> Dictionary:
	var no_siege_runs := 0
	var zero_enemy_runs := 0
	var total_patrols := 0
	var total_battles := 0
	var total_final_coins := 0.0
	var first_battle_days: Array = []
	for run_index in runs:
		state.reset_game()
		state.rng.seed = base_seed + run_index * 131
		state.tutorial_seen = true
		current_battles.clear()
		var patrols := 0
		var reached_zero := false
		while int(state.current_day) < target_day:
			if not state.current_event.is_empty():
				state.resolve_event(1)
			if state.get_army_count() >= 10 and float(state.resources.grain) >= 6.0 and float(state.resources.coins) >= 40.0:
				if state.patrol():
					patrols += 1
			if state._sum_force(state.enemy_army) <= 0:
				reached_zero = true
			if not state.advance_one_day():
				break
		total_patrols += patrols
		total_battles += current_battles.size()
		total_final_coins += float(state.resources.coins)
		if current_battles.is_empty():
			no_siege_runs += 1
		else:
			first_battle_days.append(int(current_battles[0].day))
		if reached_zero:
			zero_enemy_runs += 1
	return {
		"name": "每日巡剿滥用探针",
		"runs": runs,
		"no_siege_rate": snappedf(float(no_siege_runs) / maxf(1.0, runs), 0.0001),
		"zero_enemy_rate": snappedf(float(zero_enemy_runs) / maxf(1.0, runs), 0.0001),
		"average_patrols": snappedf(float(total_patrols) / maxf(1.0, runs), 0.01),
		"average_battles": snappedf(float(total_battles) / maxf(1.0, runs), 0.01),
		"average_first_battle_day": snappedf(_average(first_battle_days), 0.01),
		"average_final_coins": snappedf(total_final_coins / maxf(1.0, runs), 0.01),
	}

func _collect_invariants(policy: String, seed: int, errors: Array[String]) -> void:
	for id in state.resources:
		var value := float(state.resources[id])
		if not is_finite(value) or value < -0.001:
			_append_unique(errors, "invalid resource %s=%s" % [id, value])
		if value > state.get_capacity(id) + 0.01:
			_append_unique(errors, "resource %s exceeds capacity" % id)
	for id in state.UNITS:
		if int(state.units[id]) < 0 or int(state.wounded[id]) < 0:
			_append_unique(errors, "negative personnel in %s" % id)
	if int(state.population) < 0:
		_append_unique(errors, "negative population")
	if state.get_total_residents() > state.get_population_cap():
		_append_unique(errors, "residents exceed housing cap")
	if state.get_army_count() + state.get_wounded_count() > state.get_army_capacity():
		_append_unique(errors, "army exceeds capacity")
	if float(state.morale) < 9.999 or float(state.morale) > 100.001:
		_append_unique(errors, "morale outside bounds")
	for id in state.BUILDINGS:
		if int(state.buildings[id]) < 0 or int(state.buildings[id]) > int(state.BUILDINGS[id].max):
			_append_unique(errors, "building %s outside bounds" % id)
	var queued := {"militia": 0, "archer": 0, "chariot": 0}
	for entry in state.recovery_queue:
		var unit := str(entry.get("unit", ""))
		if not queued.has(unit) or int(entry.get("count", 0)) <= 0:
			_append_unique(errors, "invalid recovery queue entry")
		else:
			queued[unit] += int(entry.count)
	for id in state.UNITS:
		if int(queued[id]) != int(state.wounded[id]):
			_append_unique(errors, "wounded queue mismatch for %s" % id)
	for id in state.UNITS:
		if int(state.enemy_army.get(id, 0)) < 0:
			_append_unique(errors, "negative enemy personnel in %s" % id)
	if errors.size() > 20:
		_append_unique(invariant_failures, "%s seed=%d produced too many invariant errors" % [policy, seed], 100)

func _check_snapshot_roundtrip(errors: Array[String]) -> void:
	var before: Dictionary = state.get_snapshot()
	state._apply_snapshot(before, false)
	var after: Dictionary = state.get_snapshot()
	for key in ["resources", "buildings", "units", "wounded", "recovery_queue", "population", "morale", "current_day", "chapter", "day_progress", "next_attack_day", "attack_wave", "enemy_army", "last_patrol_day", "patrol_delay_wave", "buffs"]:
		if before.get(key) != after.get(key):
			_append_unique(errors, "snapshot roundtrip changed %s on day %d" % [key, int(state.current_day)])

func _aggregate(policy: String, results: Array[Dictionary], target_day: int) -> Dictionary:
	var runs := results.size()
	var total_battles := 0
	var total_wins := 0
	var first_battles := 0
	var first_wins := 0
	var no_defeat_runs := 0
	var stable_runs := 0
	var healthy_morale_runs := 0
	var adequate_army_runs := 0
	var food_secure_runs := 0
	var recovered_streak_runs := 0
	var totals := {
		"battles": 0.0, "defeats": 0.0, "casualties": 0.0, "killed": 0.0, "wounded": 0.0,
		"negative_grain_days": 0.0, "negative_coin_days": 0.0, "critical_days": 0.0,
		"max_defeat_streak": 0.0, "ending_defeat_streak": 0.0, "grain_cover_days": 0.0,
		"final_army": 0.0, "final_population": 0.0, "final_morale": 0.0, "final_prosperity": 0.0,
		"final_grain": 0.0, "final_coins": 0.0, "final_chapter": 0.0, "final_wave": 0.0,
	}
	var distributions := {"army": [], "morale": [], "grain": [], "coins": [], "prosperity": [], "casualties": []}
	var action_totals := {}
	var first_battle_days: Array = []
	for result in results:
		total_battles += int(result.battles)
		total_wins += int(result.battle_wins)
		if int(result.battles) > 0:
			first_battles += 1
			first_wins += 1 if bool(result.first_battle_won) else 0
			first_battle_days.append(int(result.first_battle_day))
		var defeats := int(result.battles) - int(result.battle_wins)
		no_defeat_runs += 1 if defeats == 0 and int(result.battles) > 0 else 0
		stable_runs += 1 if bool(result.stable) else 0
		healthy_morale_runs += 1 if float(result.final.morale) >= 35.0 else 0
		adequate_army_runs += 1 if int(result.final.army) >= 10 else 0
		food_secure_runs += 1 if float(result.grain_cover_days) >= 3.0 else 0
		recovered_streak_runs += 1 if int(result.ending_defeat_streak) < 2 else 0
		totals.battles += int(result.battles)
		totals.defeats += defeats
		totals.casualties += int(result.casualties)
		totals.killed += int(result.killed)
		totals.wounded += int(result.wounded)
		totals.negative_grain_days += int(result.negative_grain_days)
		totals.negative_coin_days += int(result.negative_coin_days)
		totals.critical_days += int(result.critical_days)
		totals.max_defeat_streak += int(result.max_defeat_streak)
		totals.ending_defeat_streak += int(result.ending_defeat_streak)
		totals.grain_cover_days += float(result.grain_cover_days)
		totals.final_army += int(result.final.army)
		totals.final_population += int(result.final.population)
		totals.final_morale += float(result.final.morale)
		totals.final_prosperity += int(result.final.prosperity)
		totals.final_grain += float(result.final.grain)
		totals.final_coins += float(result.final.coins)
		totals.final_chapter += int(result.final.chapter)
		totals.final_wave += int(result.final.wave)
		distributions.army.append(float(result.final.army))
		distributions.morale.append(float(result.final.morale))
		distributions.grain.append(float(result.final.grain))
		distributions.coins.append(float(result.final.coins))
		distributions.prosperity.append(float(result.final.prosperity))
		distributions.casualties.append(float(result.casualties))
		for action in result.actions:
			action_totals[action] = int(action_totals.get(action, 0)) + int(result.actions[action])
	var averages := {}
	for key in totals:
		averages[key] = snappedf(float(totals[key]) / maxf(1.0, runs), 0.01)
	var percentiles := {}
	for key in distributions:
		percentiles[key] = {
			"p10": snappedf(_percentile(distributions[key], 0.10), 0.01),
			"p50": snappedf(_percentile(distributions[key], 0.50), 0.01),
			"p90": snappedf(_percentile(distributions[key], 0.90), 0.01),
		}
	var actions_per_run := {}
	for action in action_totals:
		actions_per_run[action] = snappedf(float(action_totals[action]) / maxf(1.0, runs), 0.01)
	return {
		"name": POLICY_NAMES[policy],
		"runs": runs,
		"target_day": target_day,
		"total_battles": total_battles,
		"runs_without_battle": runs - first_battles,
		"siege_win_rate": snappedf(float(total_wins) / maxf(1.0, total_battles), 0.0001),
		"first_siege_win_rate": snappedf(float(first_wins) / maxf(1.0, first_battles), 0.0001),
		"no_defeat_run_rate": snappedf(float(no_defeat_runs) / maxf(1.0, runs), 0.0001),
		"stable_run_rate": snappedf(float(stable_runs) / maxf(1.0, runs), 0.0001),
		"readiness_rates": {
			"morale": snappedf(float(healthy_morale_runs) / maxf(1.0, runs), 0.0001),
			"army": snappedf(float(adequate_army_runs) / maxf(1.0, runs), 0.0001),
			"food": snappedf(float(food_secure_runs) / maxf(1.0, runs), 0.0001),
			"ending_streak": snappedf(float(recovered_streak_runs) / maxf(1.0, runs), 0.0001),
		},
		"average_first_battle_day": snappedf(_average(first_battle_days), 0.01),
		"averages": averages,
		"percentiles": percentiles,
		"actions_per_run": actions_per_run,
		"sample_runs": results.slice(0, mini(5, results.size())),
	}

func _analyze_balance(reports: Dictionary, probes: Dictionary, target_day: int) -> Array[String]:
	var warnings: Array[String] = []
	if reports.has("balanced"):
		var balanced: Dictionary = reports.balanced
		if float(balanced.first_siege_win_rate) < 0.55 or float(balanced.first_siege_win_rate) > 0.95:
			warnings.append("均衡策略首战胜率 %.1f%%，超出目标 55%%～95%%" % (float(balanced.first_siege_win_rate) * 100.0))
		if float(balanced.stable_run_rate) < 0.55:
			warnings.append("均衡策略第%d日稳定率仅 %.1f%%" % [target_day, float(balanced.stable_run_rate) * 100.0])
	if reports.has("militarist") and reports.has("balanced"):
		var first_battle_worse: bool = float(reports.militarist.first_siege_win_rate) + 0.02 < float(reports.balanced.first_siege_win_rate)
		var sustained_return_worse: bool = float(reports.militarist.stable_run_rate) + 0.05 < float(reports.balanced.stable_run_rate) and float(reports.militarist.siege_win_rate) + 0.02 < float(reports.balanced.siege_win_rate)
		if first_battle_worse or sustained_return_worse:
			warnings.append("重军策略的首战或长期稳定性明显低于均衡策略，额外军备投入回报不足")
		if float(reports.militarist.averages.negative_grain_days) > target_day * 0.20 or float(reports.militarist.averages.negative_coin_days) > target_day * 0.20:
			warnings.append("重军策略长期净产出为负，军备维持成本可能过重")
	if reports.has("greedy") and reports.has("balanced"):
		if float(reports.greedy.stable_run_rate) >= float(reports.balanced.stable_run_rate):
			warnings.append("不设防策略稳定率不低于均衡策略，防务回报不足")
	for policy in reports:
		var data: Dictionary = reports[policy]
		if int(data.runs_without_battle) > ceili(int(data.runs) * 0.02):
			warnings.append("%s有%d局在%d日内未发生攻城，需检查巡剿延迟是否可被滥用" % [data.name, data.runs_without_battle, target_day])
		if float(data.averages.negative_grain_days) > target_day * 0.40:
			warnings.append("%s平均有%.1f日粮食净产出为负" % [data.name, float(data.averages.negative_grain_days)])
	var patrol_probe: Dictionary = probes.patrol_spam
	if float(patrol_probe.no_siege_rate) > 0.05:
		warnings.append("每日巡剿可使 %.1f%% 的对局在第%d日前完全不触发攻城" % [float(patrol_probe.no_siege_rate) * 100.0, target_day])
	if float(patrol_probe.zero_enemy_rate) > 0.05:
		warnings.append("巡剿可在 %.1f%% 的对局中把来敌打空，需防止对空军重复延迟和领奖" % (float(patrol_probe.zero_enemy_rate) * 100.0))
	return warnings

func _write_reports(report_path: String, report: Dictionary) -> Dictionary:
	var directory := report_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var json_file := FileAccess.open(report_path, FileAccess.WRITE)
	if json_file:
		json_file.store_string(JSON.stringify(report, "  "))
	var markdown_path := report_path.trim_suffix(".json") + ".md"
	var markdown_file := FileAccess.open(markdown_path, FileAccess.WRITE)
	if markdown_file:
		markdown_file.store_string(_to_markdown(report))
	return {
		"json": ProjectSettings.globalize_path(report_path),
		"markdown": ProjectSettings.globalize_path(markdown_path),
	}

func _to_markdown(report: Dictionary) -> String:
	var config: Dictionary = report.config
	var lines := PackedStringArray([
		"# 青禾邑无界面自动试玩报告",
		"",
		"- 每种策略：%d 局" % int(config.runs),
		"- 模拟终点：第 %d 日" % int(config.days),
		"- 基础随机种子：%d" % int(config.seed),
		"- 稳定口径：%s" % str(report.stable_definition),
		"- 耗时：%.2f 秒" % float(report.elapsed_seconds),
		"",
		"| 策略 | 首战胜率 | 全部守城胜率 | 无败绩局 | 第%d日稳定率 | 平均守城 | 平均伤亡 | 终局军籍 | 终局民心 |" % int(config.days),
		"| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
	])
	for policy in config.policies:
		var data: Dictionary = report.policies[policy]
		lines.append("| %s | %.1f%% | %.1f%% | %.1f%% | %.1f%% | %.2f | %.2f人 | %.1f人 | %.1f |" % [
			data.name,
			float(data.first_siege_win_rate) * 100.0,
			float(data.siege_win_rate) * 100.0,
			float(data.no_defeat_run_rate) * 100.0,
			float(data.stable_run_rate) * 100.0,
			float(data.averages.battles),
			float(data.averages.casualties),
			float(data.averages.final_army),
			float(data.averages.final_morale),
		])
	lines.append("")
	lines.append("## 机制滥用探针")
	lines.append("")
	var patrol_probe: Dictionary = report.mechanic_probes.patrol_spam
	lines.append("- 每日巡剿：无攻城 %.1f%%，打空敌军 %.1f%%，平均巡剿 %.2f 次，平均攻城 %.2f 次。" % [
		float(patrol_probe.no_siege_rate) * 100.0,
		float(patrol_probe.zero_enemy_rate) * 100.0,
		float(patrol_probe.average_patrols),
		float(patrol_probe.average_battles),
	])
	lines.append("")
	lines.append("## 自动诊断")
	lines.append("")
	if report.warnings.is_empty():
		lines.append("- 未触发预设平衡警告。")
	else:
		for warning in report.warnings:
			lines.append("- %s" % warning)
	lines.append("")
	lines.append("## 状态一致性")
	lines.append("")
	if report.invariant_failures.is_empty():
		lines.append("- 资源、人口、军籍、伤员队列和存档往返断言全部通过。")
	else:
		for failure in report.invariant_failures:
			lines.append("- %s" % failure)
	return "\n".join(lines) + "\n"

func _print_summary(report: Dictionary, paths: Dictionary) -> void:
	for policy in report.config.policies:
		var data: Dictionary = report.policies[policy]
		print("HEADLESS_CASE %s runs=%d first=%.1f%% all=%.1f%% stable=%.1f%% battles=%.2f casualties=%.2f" % [
			data.name,
			int(data.runs),
			float(data.first_siege_win_rate) * 100.0,
			float(data.siege_win_rate) * 100.0,
			float(data.stable_run_rate) * 100.0,
			float(data.averages.battles),
			float(data.averages.casualties),
		])
	for warning in report.warnings:
		print("BALANCE_WARNING %s" % warning)
	var patrol_probe: Dictionary = report.mechanic_probes.patrol_spam
	print("HEADLESS_PROBE patrol_spam no_siege=%.1f%% zero_enemy=%.1f%% patrols=%.2f battles=%.2f" % [
		float(patrol_probe.no_siege_rate) * 100.0,
		float(patrol_probe.zero_enemy_rate) * 100.0,
		float(patrol_probe.average_patrols),
		float(patrol_probe.average_battles),
	])
	print("HEADLESS_PLAYTEST_OK invariant_failures=%d elapsed=%.2fs" % [report.invariant_failures.size(), float(report.elapsed_seconds)])
	print("HEADLESS_REPORT_JSON %s" % paths.json)
	print("HEADLESS_REPORT_MD %s" % paths.markdown)

func _percentile(values: Array, ratio: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return float(sorted[clampi(roundi((sorted.size() - 1) * ratio), 0, sorted.size() - 1)])

func _average(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += float(value)
	return total / values.size()

func _append_unique(target: Array[String], value: String, limit := 20) -> void:
	if target.size() < limit and value not in target:
		target.append(value)
