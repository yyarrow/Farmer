extends SceneTree

var failures: Array[String] = []
var battle_results: Array[Dictionary] = []
var day_visual_events := 0
var last_day_visual := {}
var notices: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state = root.get_node("State")
	var audio = root.get_node("Audio")
	var telemetry = root.get_node("Telemetry")
	audio.sfx_streams.clear()
	state.battle_finished.connect(func(result: Dictionary): battle_results.append(result))
	state.notice.connect(func(message: String): notices.append(message))
	state.visual_event.connect(func(kind: String, payload: Dictionary):
		if kind == "day":
			day_visual_events += 1
			last_day_visual = payload.duplicate(true)
	)
	state.reset_game()
	state.tutorial_seen = true
	_fill_resources(state)

	# Every building reaches every level and remains within its declared maximum.
	for id in state.BUILDINGS:
		while int(state.buildings[id]) < int(state.BUILDINGS[id].max):
			_fill_resources(state)
			_check(state.upgrade_building(id), "upgrade %s" % id)
		_check(int(state.buildings[id]) == 5, "%s reaches level 5" % id)

	# All economy actions, unit unlocks and policies execute.
	_fill_resources(state)
	for trade in ["sell_grain", "buy_grain", "sell_wood", "buy_stone"]:
		for resource in state.resources:
			state.resources[resource] = state.get_capacity(resource) * 0.40
		_check(state.trade(trade), "trade %s" % trade)
	var grain_quote: Dictionary = state.get_trade_quote("buy_grain")
	_check(int(grain_quote.cost.coins) == maxi(340, 460 - state.buildings.market * 20) and int(grain_quote.gain.grain) == 55, "market UI and settlement share one quote")
	state.resources.coins = 2000.0
	state.resources.grain = state.get_capacity("grain") - 10.0
	var coins_before_blocked_trade: float = state.resources.coins
	_check(not state.trade("buy_grain") and state.resources.coins == coins_before_blocked_trade and state.resources.grain == state.get_capacity("grain") - 10.0, "full grain storage rejects purchase without charging")
	state.resources.grain = 500.0
	state.resources.coins = state.get_capacity("coins") - 10.0
	var grain_before_blocked_sale: float = state.resources.grain
	_check(not state.trade("sell_grain") and state.resources.grain == grain_before_blocked_sale and state.resources.coins == state.get_capacity("coins") - 10.0, "full treasury rejects sale without taking goods")
	for unit in state.UNITS:
		_fill_resources(state)
		_check(state.recruit(unit), "recruit %s" % unit)
	for policy in ["irrigate", "tax_relief", "reward_army"]:
		_fill_resources(state)
		if policy == "reward_army":
			state.morale = 70.0
		_check(state.enact_policy(policy), "policy %s" % policy)
	_check(int(state.get_policy_cost("irrigate").wood) == 35 and int(state.get_policy_cost("reward_army").coins) == 450, "policy UI and settlement share one cost")
	state.population = state.get_population_cap() - state.get_army_count() - state.get_wounded_count() - 5
	state.morale = 97.0
	var relief_preview: Dictionary = state.get_policy_preview("tax_relief")
	_check(int(relief_preview.population_gain) == 5 and is_equal_approx(float(relief_preview.morale_gain), 3.0), "policy preview reports exact capped gains")
	var wood_before_blocked_policy: float = state.resources.wood
	_check(state.get_policy_block_reason("irrigate") == "水利增产已达三日", "active irrigation explains why it cannot be repurchased")
	_check(not state.enact_policy("irrigate") and state.resources.wood == wood_before_blocked_policy, "duplicate irrigation is rejected without charging")
	_fill_resources(state)
	state.population = state.get_population_cap() - state.get_army_count() - state.get_wounded_count()
	state.morale = 100.0
	var coins_before_blocked_relief: float = state.resources.coins
	_check(not state.enact_policy("tax_relief") and state.resources.coins == coins_before_blocked_relief, "maxed civil relief is rejected without charging")
	state.recovery_queue = []
	var grain_before_blocked_reward: float = state.resources.grain
	_check(not state.enact_policy("reward_army") and state.resources.grain == grain_before_blocked_reward, "effectless army reward is rejected without charging")

	# Each random event branch resolves without leaving a modal event behind.
	var event_branch_count := 0
	for event_data in state.EVENTS:
		for choice in event_data.options.size():
			_fill_event_resources(state)
			state.current_event = event_data.duplicate(true)
			_check(state.resolve_event(choice), "event %s choice %d resolves" % [event_data.id, choice])
			_check(state.current_event.is_empty(), "event %s choice %d" % [event_data.id, choice])
			event_branch_count += 1

	# Seasonal random selection never repeats the immediately previous event,
	# and the repeat guard survives save/load.
	state.reset_game()
	state.current_day = 37
	state.next_attack_day = 43
	var previous_event := ""
	for event_index in 30:
		state._start_random_event()
		var selected_event := str(state.current_event.id)
		_check(previous_event.is_empty() or selected_event != previous_event, "random events do not repeat consecutively")
		if event_index == 0:
			var repeat_snapshot: Dictionary = state.get_snapshot()
			state.last_event_id = ""
			state._apply_snapshot(repeat_snapshot, false)
			_check(state.last_event_id == selected_event, "last random event persists")
		var available_choice := 0
		while not state.is_event_choice_available(available_choice):
			available_choice += 1
		_check(state.resolve_event(available_choice), "selected event resolves")
		previous_event = selected_event

	# Unaffordable event investments stay pending instead of silently executing another option.
	state.current_event = state.EVENTS[2].duplicate(true)
	state.resources.grain = 0.0
	state.resources.coins = 0.0
	_check(not state.is_event_choice_available(0), "unaffordable merchant investment is disabled")
	_check(not state.resolve_event(0) and not state.current_event.is_empty(), "unaffordable event choice remains pending")
	_check(not state.is_event_choice_available(1) and not state.resolve_event(1), "merchant cannot buy nonexistent grain")
	_check(state.resources.coins == 0.0 and state.resolve_event(2), "declining merchant grants no free proceeds")
	state.current_event = state.EVENTS[0].duplicate(true)
	state.resources.grain = 44.0
	var morale_before_short_relief: float = state.morale
	_check(state.get_event_choice_block_reason(1).is_empty(), "disaster keeps a fallback choice when resources are scarce")
	_check(state.resolve_event(1) and state.resources.grain == 0.0 and state.morale == morale_before_short_relief - 4.0, "underfunded drought relief uses actual grain and grants no free morale")
	state.current_event = state.EVENTS[1].duplicate(true)
	state.resources.grain = 100.0
	state.population = state.get_population_cap() - state.get_army_count() - state.get_wounded_count() - 10
	_check(state.get_event_choice_block_reason(0) == "需20人民口空位", "refugees require the full advertised population space")
	_check(not state.resolve_event(0) and state.resources.grain == 100.0, "full housing rejects refugees without taking grain")
	state.current_event = state.EVENTS[2].duplicate(true)
	state.resources.grain = 100.0
	state.resources.coins = state.get_capacity("coins") - 500.0
	_check(state.get_event_choice_block_reason(1) == "需620枚财货空位", "merchant sale requires full treasury space")
	_check(not state.resolve_event(1) and state.resources.grain == 100.0, "full treasury rejects event sale without taking grain")
	state.resources = {"grain": 0.0, "wood": 0.0, "stone": 0.0, "coins": 0.0}
	state.population = state.get_population_cap() - state.get_army_count() - state.get_wounded_count()
	for event_data in state.EVENTS:
		state.current_event = event_data.duplicate(true)
		var fallback_count := 0
		for choice in event_data.options.size():
			if state.is_event_choice_available(choice):
				fallback_count += 1
		_check(fallback_count > 0, "resource-empty event always has a fallback: " + str(event_data.id))

	# Deterministic strong and weak siege cases.
	state.reset_game()
	battle_results.clear()
	state.units = {"militia": 100, "archer": 100, "chariot": 100}
	state.morale = 100.0
	state._resolve_siege()
	_check(not battle_results.is_empty() and bool(battle_results[-1].won), "high defense wins siege")
	_check(int(battle_results[-1].player_losses) == int(battle_results[-1].killed_total) + int(battle_results[-1].wounded_total), "battle losses reconcile")
	state.units.militia = 0
	state.wounded.militia = 5
	state.recovery_queue = [{"unit": "militia", "count": 5, "return_day": state.current_day}]
	_check(state._recover_wounded() == 5 and state.units.militia == 5 and state.wounded.militia == 0, "wounded recovery reports and restores exact people")
	_check(int(battle_results[-1].enemy_losses) > 0, "battle inflicts real enemy casualties")
	battle_results.clear()
	state.units = {"militia": 0, "archer": 0, "chariot": 0}
	state.buildings.wall = 0
	state.buildings.barracks = 0
	state.current_day = 40
	state._resolve_siege()
	_check(not battle_results.is_empty() and not bool(battle_results[-1].won), "zero defense loses siege")
	_check(state.attack_wave == 2 and state.next_attack_day == 49, "defeat retries the current tier with two recovery days")

	# Enemy intelligence is a persisted roster, not a hidden difficulty score.
	state.reset_game()
	_check(state._sum_force(state.enemy_army) == 25, "first enemy roster has real manpower")
	_check(not bool(state.get_enemy_display().known), "enemy starts unscouted")
	state.enemy_army.scouted = true
	var enemy_snapshot: Dictionary = state.get_snapshot()
	state.enemy_army = {}
	state._apply_snapshot(enemy_snapshot, false)
	_check(bool(state.get_enemy_display().known) and state.get_enemy_display().composition.contains("戈卒"), "enemy intelligence persists")

	# Patrol can delay each enemy roster only once, and destroying it advances the wave.
	state.reset_game()
	_fill_resources(state)
	state.units = {"militia": 100, "archer": 0, "chariot": 0}
	state.enemy_army = state._make_enemy_army(1)
	_seed_successful_patrol(state)
	_check(state.patrol(), "first patrol resolves")
	var once_delayed_until: int = state.next_attack_day
	state.current_day += 1
	_seed_successful_patrol(state)
	_check(state.patrol(), "second patrol resolves")
	_check(state.next_attack_day == once_delayed_until, "same enemy roster is delayed at most once")
	state.enemy_army = state._make_enemy_army(1)
	state.enemy_army.militia = 1
	state.enemy_army.archer = 0
	state.enemy_army.chariot = 0
	state.last_patrol_day = 0
	state.current_day += 1
	_seed_successful_patrol(state)
	_check(state.patrol() and state.attack_wave == 2 and state._sum_force(state.enemy_army) > 0, "field victory replaces a destroyed enemy roster")

	# Late war remains challenging but bounded after the final enemy tier.
	_check(int(state._make_enemy_army(4).tier) == 3 and int(state._make_enemy_army(5).tier) == 4, "mid-campaign enemy tiers hold for recovery")
	var tier_eight: Dictionary = state._make_enemy_army(state.FINAL_ENEMY_WAVE)
	var tier_thirty: Dictionary = state._make_enemy_army(30)
	var tier_eight_power: int = state._force_power(tier_eight, tier_eight.morale, tier_eight.training)
	var tier_thirty_power: int = state._force_power(tier_thirty, tier_thirty.morale, tier_thirty.training)
	_check(abs(tier_thirty_power - tier_eight_power) <= 8, "late enemy power stops growing beyond player capacity")
	state.reset_game()
	state.current_day = 80
	state.chapter = 3
	state.attack_wave = state.FINAL_ENEMY_WAVE
	state.enemy_army = state._make_enemy_army(state.attack_wave)
	state.units = {"militia": 100, "archer": 100, "chariot": 100}
	state.morale = 100.0
	state._resolve_siege()
	_check(state.attack_wave == state.FINAL_ENEMY_WAVE + 1 and state.next_attack_day == 87, "late war victory enters slower border-raid cadence")

	# Save slot CRUD and metadata.
	state.reset_game()
	state.current_day = 42
	state.next_attack_day = 47
	state.chapter = 2
	for resource in state.resources:
		state.resources[resource] = state.get_capacity(resource) * 0.40
	_check(state.manual_save(1), "manual save")
	state.current_day = 3
	_check(state.load_slot(1), "manual load")
	_check(state.current_day == 42, "manual save restores day")
	var slots: Array = state.list_save_slots()
	_check(bool(slots[0].exists) and int(slots[0].chapter) == 2, "slot metadata")
	_check(state.delete_slot(1), "manual delete")
	_check(not bool(state.list_save_slots()[0].exists), "slot deleted")

	# A truncated primary save falls back to the previous atomic backup.
	state.delete_slot(2)
	state.current_day = 51
	state.next_attack_day = 56
	_check(state.manual_save(2), "backup fixture first save")
	state.current_day = 52
	_check(state.manual_save(2), "backup fixture second save")
	var corrupt := FileAccess.open(state._slot_path(2), FileAccess.WRITE)
	corrupt.store_string("{truncated")
	corrupt = null
	state.current_day = 1
	_check(state.load_slot(2) and state.current_day == 51, "corrupt primary recovers previous save")
	_check(state.delete_slot(2), "recovered slot delete removes backup")

	# Parseable JSON with damaged field types is invalid and also falls back.
	state.delete_slot(3)
	state.current_day = 61
	state.next_attack_day = 66
	_check(state.manual_save(3), "schema backup fixture first save")
	state.current_day = 62
	_check(state.manual_save(3), "schema backup fixture second save")
	var malformed := FileAccess.open(state._slot_path(3), FileAccess.WRITE)
	malformed.store_string('{"format_version":3,"resources":"broken"}')
	malformed = null
	state.current_day = 1
	_check(state.load_slot(3) and state.current_day == 61, "schema-invalid primary recovers previous save")
	var safe_day: int = state.current_day
	state._apply_snapshot({"format_version": 3, "recovery_queue": [{"unit": "unknown", "count": 1, "return_day": 2}]}, false)
	_check(state.current_day == safe_day, "direct invalid snapshot leaves live state untouched")
	var inconsistent_snapshot: Dictionary = state.get_snapshot()
	inconsistent_snapshot.population = state.get_population_cap() + 1
	var inconsistent := FileAccess.open(state._slot_path(3), FileAccess.WRITE)
	inconsistent.store_string(JSON.stringify(inconsistent_snapshot))
	inconsistent = null
	state.current_day = 1
	_check(state.load_slot(3) and state.current_day == 61, "cross-field invalid primary recovers previous save")
	var spoofed_event_snapshot: Dictionary = state.get_snapshot()
	spoofed_event_snapshot.current_event = state.EVENTS[0].duplicate(true)
	spoofed_event_snapshot.current_event.options = ["免费领取物资"]
	safe_day = state.current_day
	state._apply_snapshot(spoofed_event_snapshot, false)
	_check(state.current_day == safe_day and state.current_event.is_empty(), "spoofed event options are rejected")
	var empty_enemy_snapshot: Dictionary = state.get_snapshot()
	empty_enemy_snapshot.enemy_army.militia = 0
	empty_enemy_snapshot.enemy_army.archer = 0
	empty_enemy_snapshot.enemy_army.chariot = 0
	state._apply_snapshot(empty_enemy_snapshot, false)
	_check(state.current_day == safe_day and state._sum_force(state.enemy_army) > 0, "zero-strength saved enemy is rejected")
	var old_copy_snapshot: Dictionary = state.get_snapshot()
	old_copy_snapshot.current_event = state.EVENTS[0].duplicate(true)
	old_copy_snapshot.current_event.title = "旧版事件标题"
	old_copy_snapshot.current_event.body = "旧版事件说明"
	state._apply_snapshot(old_copy_snapshot, false)
	_check(state.current_event.title == state.EVENTS[0].title and state.current_event.body == state.EVENTS[0].body, "old event copy is normalized without losing the save")
	state.resolve_event(1)
	_check(state.delete_slot(3), "schema-recovered slot delete removes backup")
	state.delete_slot(1)
	var unrecoverable := FileAccess.open(state._slot_path(1), FileAccess.WRITE)
	unrecoverable.store_string("{broken")
	unrecoverable = null
	notices.clear()
	_check(not state.load_slot(1) and not notices.is_empty() and notices[-1] == "该档位存档损坏且无可用备份", "unrecoverable slot is not mislabeled as empty")
	_check(state.delete_slot(1), "unrecoverable slot can still be deleted")

	# Settings persist and diagnostics export contains a snapshot.
	audio.set_volume("music", 0.37)
	audio.load_settings()
	_check(absf(float(audio.settings.music) - 0.37) < 0.001, "music volume persists")
	var music_stream: AudioStreamWAV = audio.music_player.stream
	_check(music_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "music loops forward")
	_check(music_stream.loop_begin == int(audio.MUSIC_LOOP_INTRO_SECONDS * music_stream.mix_rate), "music loops after crossfade intro")
	audio.set_music_season("spring", true)
	var old_music_index: int = audio._active_music_index
	audio.set_music_season("summer")
	var new_music_index: int = audio._active_music_index
	_check(audio.music_players[old_music_index].playing and audio.music_players[new_music_index].playing, "seasonal music crossfade overlaps both tracks")
	audio._set_season_crossfade(0.5, old_music_index, new_music_index)
	_check(absf(float(audio._music_gains[old_music_index]) - sqrt(0.5)) < 0.001, "seasonal music uses equal-power crossfade")
	audio._duck_music()
	_check(audio._duck_gain < 0.5, "battle duck is independent during seasonal crossfade")
	audio._season_tween.set_speed_scale(30.0)
	audio._duck_tween.set_speed_scale(30.0)
	await create_timer(0.15).timeout
	_check(not audio.music_players[old_music_index].playing and audio.music_players[old_music_index].stream == null, "crossfade releases previous seasonal track")
	_check(audio.music_player.playing and absf(audio._duck_gain - 1.0) < 0.001, "seasonal track and battle duck finish cleanly")
	for season in ["autumn", "winter", "spring"]:
		audio.set_music_season(season, true)
		_check(audio.current_music_id == season and audio.music_player.playing, "seasonal music selects " + season)
		music_stream = audio.music_player.stream
		_check(music_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "seasonal music keeps loop mode " + season)
	audio.set_music_season("unknown")
	_check(audio.current_music_id == "spring", "unknown music season is ignored")
	audio.set_volume("music", 0.42)
	var corrupt_settings := FileAccess.open(audio.SETTINGS_PATH, FileAccess.WRITE)
	corrupt_settings.store_string("{truncated")
	corrupt_settings = null
	audio.settings.music = 0.99
	audio.load_settings()
	_check(absf(float(audio.settings.music) - 0.37) < 0.001, "corrupt audio settings recover previous values")
	audio.set_haptics_enabled(false)
	audio.load_settings()
	_check(not bool(audio.settings.haptics), "haptics preference persists")
	if FileAccess.file_exists(telemetry.EVENT_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(telemetry.EVENT_PATH))
	telemetry.track("fresh_install_probe", {})
	_check(FileAccess.file_exists(telemetry.EVENT_PATH), "first diagnostic event creates its file")
	var report_path: String = telemetry.build_report(state.get_snapshot(), state.list_save_slots())
	_check(FileAccess.file_exists(report_path), "diagnostic report exported")
	_check(FileAccess.get_file_as_string(report_path).contains("game_snapshot"), "diagnostic report content")

	# Offline progress only grants capped production: it never advances days or triggers danger.
	state.reset_game()
	state.current_day = 5
	state.next_attack_day = 7
	state.resources = {"grain": 20.0, "wood": 20.0, "stone": 20.0, "coins": 20.0}
	var offline_data: Dictionary = state.get_snapshot()
	offline_data.saved_at = Time.get_unix_time_from_system() - 120.0
	state._apply_snapshot(offline_data, true)
	_check(state.current_day == 5 and state.next_attack_day == 7, "offline progress does not advance danger")
	_check(state.current_event.is_empty() and state.resources.grain > 20.0, "offline progress grants safe production")
	state.reset_game()
	state.resources.grain = state.get_capacity("grain") - 3.0
	state.resources.wood = state.get_capacity("wood")
	state.resources.stone = state.get_capacity("stone")
	state.resources.coins = state.get_capacity("coins")
	var near_capacity_snapshot: Dictionary = state.get_snapshot()
	near_capacity_snapshot.saved_at = Time.get_unix_time_from_system() - state.MAX_OFFLINE_SECONDS
	state._apply_snapshot(near_capacity_snapshot, true)
	_check(state.offline_report.contains("粮 +3石") and not state.offline_report.contains("木 +"), "offline report shows only actual stored gains")
	state.current_event = state.EVENTS[0].duplicate(true)
	var event_snapshot: Dictionary = state.get_snapshot()
	state.current_event = {}
	state._apply_snapshot(event_snapshot, false)
	_check(not state.current_event.is_empty(), "pending event persists in save")
	state.resolve_event(1)

	# Version 2 saves migrate units to people and currency to visible historical units.
	var legacy_snapshot := {"format_version": 2, "resources": {"grain": 180.0, "wood": 125.0, "stone": 82.0, "coins": 150.0}, "buildings": {"farm": 1, "woodcut": 1, "house": 1, "warehouse": 1}, "units": {"militia": 4, "archer": 1, "chariot": 0}, "population": 22, "current_day": 2, "chapter": 1}
	state._apply_snapshot(legacy_snapshot, false)
	_check(state.resources.grain == 360.0 and state.resources.coins == 1500.0, "legacy resources migrate")
	_check(state.population == 110 and state.units.militia == 20 and state.units.archer == 5, "legacy population and units migrate")

	# Art sheets are RGBA and contain transparent pixels.
	for id in state.BUILDINGS:
		var texture: Texture2D = load("res://assets/art/buildings/%s_stages.png" % id)
		var image := texture.get_image()
		_check(not image.is_empty(), "art sheet loads %s" % id)
		_check(image.detect_alpha() != Image.ALPHA_NONE, "art sheet alpha %s" % id)
		_check(texture.get_width() <= 768 and texture.get_width() >= 512, "art sheet keeps display detail without excess memory %s" % id)

	# Long economy soak: 20,000 ticks, manually resolving events as they arise.
	state.reset_game()
	state.tutorial_seen = true
	day_visual_events = 0
	last_day_visual = {}
	for i in 20000:
		state._tick_economy(0.1)
		if not state.current_event.is_empty():
			state.resolve_event(i % 2)
		for key in state.resources:
			_check(is_finite(float(state.resources[key])), "finite %s at tick %d" % [key, i])
			_check(float(state.resources[key]) >= 0.0, "nonnegative %s at tick %d" % [key, i])
	_check(day_visual_events > 0 and last_day_visual.has("ledger") and last_day_visual.has("recovered"), "daily settlement emits complete visual feedback")

	state.reset_game()
	audio.set_volume("music", 0.62)
	audio.set_haptics_enabled(true)
	music_stream = null
	for player in audio.music_players:
		player.stop()
		player.stream = null
	await create_timer(0.1).timeout
	audio.shutdown()
	await create_timer(0.1).timeout
	if failures.is_empty():
		print("FULL_FLOW_OK ticks=20000 buildings=8 event_types=%d event_branches=%d saves=3 diagnostics=ok" % [state.EVENTS.size(), event_branch_count])
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _fill_resources(state) -> void:
	state.resources = {"grain": 100000.0, "wood": 100000.0, "stone": 100000.0, "coins": 100000.0}
	var civilian_cap: int = maxi(40, state.get_population_cap() - state.get_army_count() - state.get_wounded_count())
	state.population = clampi(maxi(state.population, 200), 40, civilian_cap)

func _fill_event_resources(state) -> void:
	for resource in state.resources:
		state.resources[resource] = state.get_capacity(resource) * 0.40
	var civilian_cap: int = maxi(40, state.get_population_cap() - state.get_army_count() - state.get_wounded_count())
	state.population = clampi(state.population, 40, maxi(40, civilian_cap - 40))

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)

func _seed_successful_patrol(state) -> void:
	for candidate in range(1, 1000):
		state.rng.seed = candidate
		if state.rng.randf() < 0.80:
			state.rng.seed = candidate
			return
