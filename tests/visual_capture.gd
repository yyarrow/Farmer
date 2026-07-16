extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("visual_capture requires a rendered display driver")
		quit(1)
		return
	root.get_node("Audio").shutdown()
	var state = root.get_node("State")
	root.get_node("Telemetry").previous_unclean_exit = false
	state.reset_game()
	state.tutorial_seen = true
	for id in state.BUILDINGS:
		state.buildings[id] = 5
	var scene: PackedScene = load("res://main.tscn")
	var ui = scene.instantiate()
	root.add_child(ui)
	await process_frame
	await process_frame
	for capture in [[1, "spring"], [25, "autumn"], [37, "winter"]]:
		state.current_day = int(capture[0])
		state.next_attack_day = state.current_day + 6
		state.changed.emit()
		await create_timer(0.9).timeout
		var image := root.get_viewport().get_texture().get_image()
		if image.is_empty() or image.get_width() != 540 or image.get_height() != 960:
			failures.append("invalid %s frame" % capture[1])
			continue
		var path := "res://.qa/visual_%s_max.png" % capture[1]
		if image.save_png(path) != OK:
			failures.append("cannot save %s" % path)
	ui.current_tab = 2
	ui._update_tab_buttons()
	state.enemy_army.scouted = false
	ui._render_tab()
	await create_timer(0.3).timeout
	var unknown_intel_image := root.get_viewport().get_texture().get_image()
	if unknown_intel_image.is_empty() or unknown_intel_image.get_width() != 540 or unknown_intel_image.get_height() != 960:
		failures.append("invalid unknown intelligence frame")
	elif unknown_intel_image.save_png("res://.qa/visual_military_unknown.png") != OK:
		failures.append("cannot save unknown intelligence frame")
	state.enemy_army.scouted = true
	state.defense_order = "volley"
	ui._render_tab()
	await create_timer(0.3).timeout
	var scouted_intel_image := root.get_viewport().get_texture().get_image()
	if scouted_intel_image.is_empty() or scouted_intel_image.get_width() != 540 or scouted_intel_image.get_height() != 960:
		failures.append("invalid scouted intelligence frame")
	elif scouted_intel_image.save_png("res://.qa/visual_military_scouted.png") != OK:
		failures.append("cannot save scouted intelligence frame")
	state.defense_order = "sally"
	ui._render_tab()
	await create_timer(0.3).timeout
	var sally_order_image := root.get_viewport().get_texture().get_image()
	if sally_order_image.is_empty() or sally_order_image.get_width() != 540 or sally_order_image.get_height() != 960:
		failures.append("invalid sally order frame")
	elif sally_order_image.save_png("res://.qa/visual_military_order_sally.png") != OK:
		failures.append("cannot save sally order frame")
	ui.current_tab = 3
	ui._update_tab_buttons()
	state.current_day = 5
	state.next_attack_day = state.current_day + 6
	state.buffs.farm_until = 5
	state.population = state.get_population_cap() - state.get_army_count() - state.get_wounded_count() - 5
	state.morale = 97.0
	state.recovery_queue = [{"unit": "militia", "count": 7, "return_day": 8}]
	ui._render_tab()
	await create_timer(0.3).timeout
	var active_policy_top_image := root.get_viewport().get_texture().get_image()
	if active_policy_top_image.is_empty() or active_policy_top_image.get_width() != 540 or active_policy_top_image.get_height() != 960:
		failures.append("invalid active policy top frame")
	elif active_policy_top_image.save_png("res://.qa/visual_policy_active_top.png") != OK:
		failures.append("cannot save active policy top frame")
	ui.content_scroll.scroll_vertical = 10000
	await process_frame
	ui.content_scroll.scroll_vertical = maxi(0, ui.content_scroll.scroll_vertical - 18)
	await create_timer(0.3).timeout
	var active_policy_bottom_image := root.get_viewport().get_texture().get_image()
	if active_policy_bottom_image.is_empty() or active_policy_bottom_image.get_width() != 540 or active_policy_bottom_image.get_height() != 960:
		failures.append("invalid active policy bottom frame")
	elif active_policy_bottom_image.save_png("res://.qa/visual_policy_active_bottom.png") != OK:
		failures.append("cannot save active policy bottom frame")
	state.buffs.farm_until = state.current_day + 3
	state.population = state.get_population_cap() - state.get_army_count() - state.get_wounded_count()
	state.morale = 100.0
	state.recovery_queue = []
	ui._render_tab()
	ui.content_scroll.scroll_vertical = 0
	await create_timer(0.3).timeout
	var blocked_policy_top_image := root.get_viewport().get_texture().get_image()
	if blocked_policy_top_image.is_empty() or blocked_policy_top_image.get_width() != 540 or blocked_policy_top_image.get_height() != 960:
		failures.append("invalid blocked policy top frame")
	elif blocked_policy_top_image.save_png("res://.qa/visual_policy_blocked_top.png") != OK:
		failures.append("cannot save blocked policy top frame")
	ui.content_scroll.scroll_vertical = 10000
	await process_frame
	ui.content_scroll.scroll_vertical = maxi(0, ui.content_scroll.scroll_vertical - 18)
	await create_timer(0.3).timeout
	var blocked_policy_bottom_image := root.get_viewport().get_texture().get_image()
	if blocked_policy_bottom_image.is_empty() or blocked_policy_bottom_image.get_width() != 540 or blocked_policy_bottom_image.get_height() != 960:
		failures.append("invalid blocked policy bottom frame")
	elif blocked_policy_bottom_image.save_png("res://.qa/visual_policy_blocked_bottom.png") != OK:
		failures.append("cannot save blocked policy bottom frame")
	ui.current_tab = 0
	ui._update_tab_buttons()
	ui._render_tab()
	state.current_day = 5
	state.next_attack_day = 7
	state.enemy_army.scouted = true
	state.buffs = {"farm_until": 8, "all_until": 8}
	state.units = {"militia": 45, "archer": 15, "chariot": 5}
	state.defense_order = "fortify"
	state.wounded = {"militia": 5, "archer": 5, "chariot": 0}
	state.changed.emit()
	ui.city_visual_layer.play_event("policy", {"policy": "irrigate"})
	await create_timer(0.45).timeout
	var feedback_image := root.get_viewport().get_texture().get_image()
	if feedback_image.is_empty() or feedback_image.get_width() != 540 or feedback_image.get_height() != 960:
		failures.append("invalid world feedback frame")
	elif feedback_image.save_png("res://.qa/visual_world_feedback.png") != OK:
		failures.append("cannot save world feedback frame")
	ui._show_licenses()
	await create_timer(0.5).timeout
	var licenses_image := root.get_viewport().get_texture().get_image()
	if licenses_image.is_empty() or licenses_image.get_width() != 540 or licenses_image.get_height() != 960:
		failures.append("invalid licenses frame")
	elif licenses_image.save_png("res://.qa/visual_licenses.png") != OK:
		failures.append("cannot save licenses frame")
	ui._dismiss_modal()
	ui._handle_back_request()
	await create_timer(0.5).timeout
	var modal_image := root.get_viewport().get_texture().get_image()
	if modal_image.is_empty() or modal_image.get_width() != 540 or modal_image.get_height() != 960:
		failures.append("invalid exit confirmation frame")
	elif modal_image.save_png("res://.qa/visual_exit_confirm.png") != OK:
		failures.append("cannot save exit confirmation frame")
	ui._dismiss_modal()
	state.current_event = state.EVENTS[7].duplicate(true)
	ui._on_event_started(state.current_event)
	await create_timer(0.5).timeout
	var event_image := root.get_viewport().get_texture().get_image()
	if event_image.is_empty() or event_image.get_width() != 540 or event_image.get_height() != 960:
		failures.append("invalid long event frame")
	elif event_image.save_png("res://.qa/visual_event_longest.png") != OK:
		failures.append("cannot save long event frame")
	ui._dismiss_modal()
	ui._on_battle_finished({
		"won": false,
		"enemy_name": "列国主力",
		"enemy_total": 128,
		"defense_order_name": "锋矢",
		"player_power": 172,
		"enemy_power": 184,
		"loss_text": "阵亡12人，负伤27人；敌军折损34人。城外仓舍受损，损失粮126石、财935枚。",
		"player_before": {"militia": 52, "archer": 18, "chariot": 10},
		"player_survivors": {"militia": 26, "archer": 7, "chariot": 8},
		"player_losses_by_type": {"militia": 26, "archer": 11, "chariot": 2},
		"killed": {"militia": 8, "archer": 3, "chariot": 1},
		"wounded": {"militia": 18, "archer": 8, "chariot": 1},
		"enemy_before": {"militia": 72, "archer": 36, "chariot": 20},
		"enemy_survivors": {"militia": 51, "archer": 25, "chariot": 18},
		"enemy_losses_by_type": {"militia": 21, "archer": 11, "chariot": 2},
		"rounds": [
			{"round": 1, "player_losses": 9, "enemy_losses": 11},
			{"round": 2, "player_losses": 13, "enemy_losses": 14},
			{"round": 3, "player_losses": 17, "enemy_losses": 9},
		],
	})
	await create_timer(0.5).timeout
	var battle_image := root.get_viewport().get_texture().get_image()
	if battle_image.is_empty() or battle_image.get_width() != 540 or battle_image.get_height() != 960:
		failures.append("invalid battle report frame")
	elif battle_image.save_png("res://.qa/visual_battle_report.png") != OK:
		failures.append("cannot save battle report frame")
	ui.queue_free()
	state.reset_game()
	await process_frame
	if failures.is_empty():
		print("VISUAL_CAPTURE_OK seasons=3 intelligence=2 orders=2 policies=4 feedback=1 modals=4 size=540x960")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
