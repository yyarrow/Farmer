extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("Audio").shutdown()
	var state = root.get_node("State")
	_check(not ProjectSettings.get_setting("application/config/quit_on_go_back", true), "Android back is handled in game")
	state.reset_game()
	state.tutorial_seen = true
	var scene: PackedScene = load("res://main.tscn")
	var ui = scene.instantiate()
	root.add_child(ui)
	await process_frame
	_check(ui.theme != null and ui.theme.default_font != null, "bundled UI font is active")
	for glyph in "敌军稳定伤亡粮木石币":
		_check(ui.theme.default_font.has_char(glyph.unicode_at(0)), "bundled UI font covers %s" % glyph)
	var missing_glyphs := {}
	for file_path in _gd_files_recursive("res://src"):
		for glyph in FileAccess.get_file_as_string(file_path):
			var codepoint := glyph.unicode_at(0)
			if codepoint >= 128 and not ui.theme.default_font.has_char(codepoint):
				missing_glyphs[glyph] = true
	_check(missing_glyphs.is_empty(), "bundled UI font covers every source glyph: %s" % str(missing_glyphs.keys()))
	await process_frame
	_check(ui.content_box != null, "main content built")
	_check(ui.content_scroll.scroll_deadzone == 10, "content scroll separates taps from intentional drags")
	_check(_all_controls_pass_scroll_input(ui.content_box), "content cards pass touch drags to their ScrollContainer")
	_check(ui.time_buttons.size() == 3 and ui.advance_day_button != null, "time controls built")
	_check(_has_label_containing(ui.content_box, "里聚 · 建筑用地 4 / 6"), "building page explains occupied and available city lots")
	_check(ui._format_save_time_with_bias(0.0, 480) == "1970-01-01  08:00", "save timestamps use the device time-zone offset")
	_check(_has_label_containing(ui.content_box, "本季产出 20.0 → 40.0石/日"), "building card exposes the actual current and next production")
	ui.current_tab = 1
	ui._render_tab()
	await process_frame
	_check(_has_label_containing(ui.content_box, "粮 360 / 2000石"), "ledger exposes current storage against capacity")
	ui.current_tab = 0
	ui._render_tab()
	await process_frame
	var advice: Dictionary = ui._opening_guidance()
	_check(str(advice.get("step", "")) == "recruit" and int(advice.get("tab", -1)) == 2, "opening advice starts with a concrete recruitment action")
	state.units.militia = 25
	advice = ui._opening_guidance()
	_check(str(advice.get("step", "")) == "defense" and int(advice.get("tab", -1)) == 0, "opening advice advances to a defensive building choice")
	state.buildings.wall = 1
	advice = ui._opening_guidance()
	_check(str(advice.get("step", "")) == "scout" and int(advice.get("tab", -1)) == 2, "opening advice advances to scouting")
	state.enemy_army.scouted = true
	advice = ui._opening_guidance()
	_check(str(advice.get("step", "")) in ["reinforce", "ready"] and str(advice.get("detail", "")).contains("胜算约"), "opening advice ends with the real battle forecast")
	state.attack_wave = 2
	_check(ui._opening_guidance().is_empty(), "opening advice disappears after the first victory")
	state.reset_game()
	state.tutorial_seen = true
	state.set_time_speed(1.0)
	for tab in range(4):
		ui.current_tab = tab
		ui._update_tab_buttons()
		ui._render_tab()
		await process_frame
		_check(ui.content_box.get_child_count() > 0, "tab %d renders" % tab)
		_check(_all_controls_pass_scroll_input(ui.content_box), "tab %d cards preserve touch scrolling" % tab)
	ui.current_tab = 3
	ui._render_tab()
	await process_frame
	_check(_has_label_containing(ui.content_box, "春秋时代积累"), "governance page separates era progress from city level")
	state.chapter = 2
	state.changed.emit()
	await process_frame
	_check(is_equal_approx(ui.city_world.scale.x, 1.08) and ui.city_pan_hint.visible, "larger city expands the map and enables horizontal inspection")
	var pan_before: float = ui._city_pan_x
	var drag := InputEventScreenDrag.new()
	drag.position = Vector2(200, 320)
	drag.relative = Vector2(-18, 0)
	ui._unhandled_input(drag)
	_check(ui._city_pan_x < pan_before, "horizontal drag moves the expanded city map")
	state.chapter = 3
	state.era_progress = state.get_era_progress_target()
	_check(state.advance_era(), "UI fixture advances into Warring States")
	await process_frame
	_check(str(ui.title_label.text).contains("战国") and is_equal_approx(ui.city_world.scale.x, 1.16), "era and preserved city scale refresh together")
	_check(str(ui.tab_buttons[0].text).contains("营城") and str(ui.tab_buttons[1].text).contains("互市"), "Warring States replaces primary tab vocabulary")
	_check(str(ui.city_background.texture.resource_path).contains("city_warring_states") and str(ui.city_visual_layer.world_state.era) == "warring_states", "era transition replaces the painted city and persistent visual state")
	ui.current_tab = 0
	ui._render_tab()
	await process_frame
	_check(_has_label_containing(ui.content_box, "武备营"), "building page uses Warring States catalog")
	ui.current_tab = 2
	ui._render_tab()
	await process_frame
	_check(_has_label_containing(ui.content_box, "甲士") and _has_label_containing(ui.content_box, "劲弩士") and _has_label_containing(ui.content_box, "轻骑"), "military page uses Warring States unit catalog")
	ui.current_tab = 3
	ui._render_tab()
	await process_frame
	_check(_has_label_containing(ui.content_box, "进入秦"), "Warring States governance exposes Qin as the next configured era")
	state.chapter = 5
	state.era_progress = state.get_era_progress_target()
	_check(state.advance_era(), "UI fixture advances into Qin")
	await process_frame
	ui.current_tab = 2
	ui._render_tab()
	await process_frame
	_check(str(ui.title_label.text).contains("秦") and _has_label_containing(ui.content_box, "县尉勒卒") and _has_label_containing(ui.content_box, "弩卒") and _has_label_containing(ui.content_box, "委输载粟"), "Qin UI replaces military, logistics, and title vocabulary")
	_check(str(ui.tab_buttons[0].text).contains("县工") and str(ui.tab_buttons[2].text).contains("县尉"), "Qin replaces primary tab vocabulary")
	_check(str(ui.city_background.texture.resource_path).contains("city_qin"), "Qin UI replaces the painted city")
	state.chapter = 5
	state.era_progress = state.get_era_progress_target()
	_check(state.advance_era(), "UI fixture advances into Han")
	await process_frame
	ui.current_tab = 2
	ui._render_tab()
	await process_frame
	_check(str(ui.title_label.text).contains("汉") and _has_label_containing(ui.content_box, "都尉治兵") and _has_label_containing(ui.content_box, "蹶张士") and _has_label_containing(ui.content_box, "传舍转输"), "Han UI replaces military, logistics, and title vocabulary")
	_check(str(ui.tab_buttons[1].text).contains("平准") and str(ui.tab_buttons[3].text).contains("郡政"), "Han replaces primary tab vocabulary")
	_check(str(ui.city_background.texture.resource_path).contains("city_han"), "Han UI replaces the painted city")
	state.chapter = 5
	state.era_progress = state.get_era_progress_target()
	_check(state.advance_era(), "UI fixture advances into Three Kingdoms")
	await process_frame
	ui.current_tab = 2
	ui._render_tab()
	await process_frame
	_check(str(ui.title_label.text).contains("三国") and _has_label_containing(ui.content_box, "中军整兵") and _has_label_containing(ui.content_box, "强弩士") and _has_label_containing(ui.content_box, "军屯转饷"), "Three Kingdoms UI replaces military, logistics, and title vocabulary")
	_check(str(ui.tab_buttons[0].text).contains("营坞") and str(ui.city_background.texture.resource_path).contains("city_three_kingdoms"), "Three Kingdoms replaces navigation and painted city")
	state.chapter = 5
	state.era_progress = state.get_era_progress_target()
	_check(state.advance_era(), "UI fixture advances into Jin")
	await process_frame
	ui.current_tab = 2
	ui._render_tab()
	await process_frame
	_check(str(ui.title_label.text).contains("晋") and _has_label_containing(ui.content_box, "都督治军") and _has_label_containing(ui.content_box, "具装骑") and _has_label_containing(ui.content_box, "州郡转输"), "Jin UI replaces military, logistics, and title vocabulary")
	_check(str(ui.tab_buttons[1].text).contains("津市") and str(ui.city_background.texture.resource_path).contains("city_jin"), "Jin replaces navigation and painted city")
	state.chapter = 5
	state.era_progress = state.get_era_progress_target()
	_check(state.advance_era(), "UI fixture advances into Northern and Southern Dynasties")
	await process_frame
	ui.current_tab = 2
	ui._render_tab()
	await process_frame
	_check(str(ui.title_label.text).contains("南北朝") and _has_label_containing(ui.content_box, "军府治戍") and _has_label_containing(ui.content_box, "甲骑具装") and _has_label_containing(ui.content_box, "镇戍转饷"), "Northern and Southern Dynasties UI replaces military, logistics, and title vocabulary")
	_check(str(ui.tab_buttons[1].text).contains("关市") and str(ui.city_background.texture.resource_path).contains("city_northern_southern"), "Northern and Southern Dynasties replaces navigation and painted city")
	state.chapter = 5
	state.era_progress = state.get_era_progress_target()
	_check(state.advance_era(), "UI fixture advances into Sui")
	await process_frame
	ui.current_tab = 2
	ui._render_tab()
	await process_frame
	_check(str(ui.title_label.text).contains("隋") and _has_label_containing(ui.content_box, "鹰扬治军") and _has_label_containing(ui.content_box, "骁骑") and _has_label_containing(ui.content_box, "漕河转输"), "Sui UI replaces military, logistics, and title vocabulary")
	_check(str(ui.tab_buttons[1].text).contains("运河市") and str(ui.city_background.texture.resource_path).contains("city_sui"), "Sui replaces navigation and painted city")
	state.chapter = 5
	state.era_progress = state.get_era_progress_target()
	_check(state.advance_era(), "UI fixture advances into Tang")
	await process_frame
	ui.current_tab = 2
	ui._render_tab()
	await process_frame
	_check(str(ui.title_label.text).contains("唐") and _has_label_containing(ui.content_box, "折冲治军") and _has_label_containing(ui.content_box, "轻骑") and _has_label_containing(ui.content_box, "馆驿漕运"), "Tang UI replaces military, logistics, and title vocabulary")
	_check(str(ui.tab_buttons[1].text).contains("坊市") and str(ui.city_background.texture.resource_path).contains("city_tang"), "Tang replaces navigation and painted city")
	state.chapter = 5
	state.era_progress = state.get_era_progress_target()
	_check(state.advance_era(), "UI fixture advances into Five Dynasties")
	await process_frame
	ui.current_tab = 2
	ui._render_tab()
	await process_frame
	_check(str(ui.title_label.text).contains("五代") and _has_label_containing(ui.content_box, "节度治军") and _has_label_containing(ui.content_box, "牙军骑") and _has_label_containing(ui.content_box, "藩镇转饷"), "Five Dynasties UI replaces military, logistics, and title vocabulary")
	_check(str(ui.tab_buttons[1].text).contains("州市") and str(ui.city_background.texture.resource_path).contains("city_five_dynasties"), "Five Dynasties replaces navigation and painted city")
	state.chapter = 5
	state.era_progress = state.get_era_progress_target()
	_check(state.advance_era(), "UI fixture advances into Song")
	await process_frame
	ui.current_tab = 2
	ui._render_tab()
	await process_frame
	_check(str(ui.title_label.text).contains("宋") and _has_label_containing(ui.content_box, "经略治军") and _has_label_containing(ui.content_box, "神臂弓手") and _has_label_containing(ui.content_box, "纲运转般"), "Song UI replaces military, logistics, and title vocabulary")
	_check(str(ui.tab_buttons[1].text).contains("榷市") and str(ui.city_background.texture.resource_path).contains("city_song"), "Song replaces navigation and painted city")
	state.chapter = 5
	state.era_progress = state.get_era_progress_target()
	_check(state.advance_era(), "UI fixture advances into Yuan")
	await process_frame
	ui.current_tab = 2
	ui._render_tab()
	await process_frame
	_check(str(ui.title_label.text).contains("元") and _has_label_containing(ui.content_box, "万户治军") and _has_label_containing(ui.content_box, "蒙古骑军") and _has_label_containing(ui.content_box, "站赤漕运"), "Yuan UI replaces military, logistics, and title vocabulary")
	_check(str(ui.tab_buttons[1].text).contains("马市") and str(ui.city_background.texture.resource_path).contains("city_yuan"), "Yuan replaces navigation and painted city")
	state.chapter = 5
	state.era_progress = state.get_era_progress_target()
	_check(state.advance_era(), "UI fixture advances into Ming")
	await process_frame
	ui.current_tab = 2
	ui._render_tab()
	await process_frame
	_check(str(ui.title_label.text).contains("明") and _has_label_containing(ui.content_box, "卫所治军") and _has_label_containing(ui.content_box, "神机铳手") and _has_label_containing(ui.content_box, "漕运军需"), "Ming UI replaces military, logistics, and title vocabulary")
	_check(str(ui.tab_buttons[1].text).contains("会馆") and str(ui.city_background.texture.resource_path).contains("city_ming"), "Ming replaces navigation and painted city")
	state.chapter = 5
	state.era_progress = state.get_era_progress_target()
	_check(state.advance_era(), "UI fixture advances into Qing")
	await process_frame
	ui.current_tab = 2
	ui._render_tab()
	await process_frame
	_check(str(ui.title_label.text).contains("清") and _has_label_containing(ui.content_box, "提督治军") and _has_label_containing(ui.content_box, "八旗马甲") and _has_label_containing(ui.content_box, "驿站粮台"), "Qing UI replaces military, logistics, and title vocabulary")
	_check(str(ui.tab_buttons[1].text).contains("商埠") and str(ui.city_background.texture.resource_path).contains("city_qing"), "Qing replaces navigation and painted city")
	ui.current_tab = 3
	ui._render_tab()
	await process_frame
	_check(_has_label_containing(ui.content_box, "清新制已启用") and _has_label_containing(ui.content_box, "清新制已定"), "terminal era is shown as complete instead of an inert zero bar")
	state.reset_game()
	state.tutorial_seen = true
	state.set_time_speed(1.0)
	await process_frame
	ui.content_scroll.scroll_vertical = 10000
	await process_frame
	ui.tab_buttons[0].pressed.emit()
	await process_frame
	_check(ui.content_scroll.scroll_vertical == 0, "opening another tab starts at its first action")
	ui.current_tab = 2
	state.enemy_army.scouted = false
	ui._render_tab()
	await process_frame
	_check(_has_label_containing(ui.content_box, "军情不足") and not _has_label_containing(ui.content_box, "胜算约"), "unscouted military view does not leak exact forecast")
	for order_name in ["持重", "坚壁", "雁行", "锋矢"]:
		_check(_has_button_containing(ui.content_box, order_name), "military view exposes order " + order_name)
	state.enemy_army.scouted = true
	_check(state.set_defense_order("fortify"), "defense order can be changed from the military flow")
	ui._render_tab()
	await process_frame
	_check(_has_label_containing(ui.content_box, "阵令「坚壁」") and _has_label_containing(ui.content_box, "胜算约") and _has_label_containing(ui.content_box, "预计伤亡"), "scouting unlocks an order-specific battle forecast")
	var breakdown: String = ui._battle_breakdown({
		"player_before": {"militia": 10, "archer": 5, "chariot": 0},
		"player_survivors": {"militia": 7, "archer": 4, "chariot": 0},
		"player_losses_by_type": {"militia": 3, "archer": 1, "chariot": 0},
		"killed": {"militia": 1, "archer": 0, "chariot": 0},
		"wounded": {"militia": 2, "archer": 1, "chariot": 0},
		"enemy_before": {"militia": 12, "archer": 4, "chariot": 0},
		"enemy_survivors": {"militia": 8, "archer": 3, "chariot": 0},
		"enemy_losses_by_type": {"militia": 4, "archer": 1, "chariot": 0},
	})
	_check(breakdown.contains("乡勇 1亡 2伤 7余") and breakdown.contains("戈卒 4损 8余"), "battle report exposes per-type dead, wounded, losses and survivors")
	state.enemy_army.scouted = false
	state.resources.grain = 12.0
	_check(ui._event_option_caption("drought", 1, "赈济").contains("粮-12石 民心-4"), "event button exposes stock-limited disaster outcome")
	state.population = state.get_population_cap() - state.get_army_count() - state.get_wounded_count() - 5
	state.morale = 97.0
	ui.current_tab = 3
	ui._render_tab()
	await process_frame
	_check(_has_label_containing(ui.content_box, "民口+5 · 民心+3"), "policy card exposes the actual capped civil gains")
	state.population = state.get_population_cap() - state.get_army_count() - state.get_wounded_count()
	state.morale = 100.0
	ui._render_tab()
	await process_frame
	_check(_has_label_containing(ui.content_box, "民口与民心均已满"), "policy card exposes its blocked day state")
	state.population -= 5
	state.morale = 97.0
	state.visual_event.emit("day", {"ledger": state.get_daily_ledger(), "recovered": 0})
	await process_frame
	_check(_has_label_containing(ui.content_box, "民口+5 · 民心+3"), "day settlement refreshes the open policy page")
	state.population = 110
	state.morale = 70.0
	ui._show_settings()
	await process_frame
	await process_frame
	_check(ui.modal_layer != null and is_instance_valid(ui.modal_layer), "settings modal opens")
	_check(ui.modal_layer.get_child_count() >= 2, "settings modal content")
	var settings_toggles: Array[Node] = ui.modal_layer.find_children("*", "CheckButton", true, false)
	_check(settings_toggles.size() == 3, "settings exposes mute, haptics and diagnostics toggles")
	for toggle in settings_toggles:
		_check(toggle.get_theme_color("font_pressed_color").is_equal_approx(ui.INK), "%s pressed text stays readable" % toggle.text)
	_check(state.time_speed == 1.0 and state.get_effective_time_speed() == 0.0, "settings temporarily pauses time")
	_check(_has_button(ui.modal_layer, "开源软件许可与鸣谢"), "settings exposes open-source licenses")
	ui._show_licenses()
	await process_frame
	var notices: Array[Node] = ui.modal_layer.find_children("LicenseNotice", "RichTextLabel", true, false)
	_check(notices.size() == 1, "license screen renders one scrollable notice")
	if notices.size() == 1:
		var notice_text := str(notices[0].text)
		_check(notice_text.contains("Godot Engine") and notice_text.contains("Permission is hereby granted"), "Godot MIT license is user-accessible")
		_check(notice_text.contains("Qinghe Sans SC") and notice_text.contains("SIL OPEN FONT LICENSE"), "font OFL license is user-accessible")
		_check(notice_text.contains("引擎第三方组件与版权") and notice_text.contains("Apache-2.0"), "engine third-party notices are user-accessible")
		_check(not notice_text.contains("Â©"), "embedded third-party notices are normalized for display")
		var missing_notice_glyphs := {}
		for glyph in notice_text:
			if glyph.unicode_at(0) >= 128 and not ui.theme.default_font.has_char(glyph.unicode_at(0)):
				missing_notice_glyphs[glyph] = true
		_check(missing_notice_glyphs.is_empty(), "bundled UI font covers every license glyph: %s" % str(missing_notice_glyphs.keys()))
	_check(state.get_effective_time_speed() == 0.0, "license screen keeps time paused")
	ui._handle_back_request()
	await process_frame
	_check(ui.modal_layer != null and _has_label(ui.modal_layer, "城邑设置"), "back from licenses returns to settings")
	_check(_has_button(ui.modal_layer, "重看上任说明"), "settings exposes the onboarding explanation after first launch")
	ui._show_tutorial(true)
	await process_frame
	_check(_has_label_containing(ui.modal_layer, "不操作就不会过日") and _has_button(ui.modal_layer, "返回设置"), "reopened onboarding explains paused time and can return to settings")
	ui._handle_back_request()
	await process_frame
	_check(ui.modal_layer != null and _has_label(ui.modal_layer, "城邑设置"), "back from reopened onboarding returns to settings")
	ui._close_settings()
	await process_frame
	_check(state.get_effective_time_speed() == 1.0, "closing settings restores selected speed")
	ui._show_settings()
	await process_frame
	ui._handle_back_request()
	await process_frame
	_check(ui.modal_layer == null, "back closes settings")
	_check(state.get_effective_time_speed() == 1.0, "back from settings restores selected speed")
	ui._show_settings()
	await process_frame
	ui._confirm_action("测试确认", "测试危险操作返回。", "确认", func(): pass)
	await process_frame
	ui._handle_back_request()
	await process_frame
	_check(ui.modal_layer != null and _has_label(ui.modal_layer, "城邑设置"), "back cancels nested confirmation to settings")
	ui._close_settings()
	await process_frame
	ui._show_modal("强制决策", "需要明确选择。", [{"text": "处理", "callback": func(): pass}], ui.GOLD)
	await process_frame
	var compulsory_modal = ui.modal_layer
	ui._handle_back_request()
	await process_frame
	_check(ui.modal_layer == compulsory_modal and is_instance_valid(compulsory_modal), "back cannot bypass compulsory decisions")
	ui._dismiss_modal()
	await process_frame
	ui._handle_back_request()
	await process_frame
	_check(ui.modal_layer != null and _has_label(ui.modal_layer, "暂离青禾？"), "back on main opens save-and-exit confirmation")
	ui._handle_back_request()
	await process_frame
	_check(ui.modal_layer == null, "back cancels exit confirmation")
	_check(state.get_effective_time_speed() == 1.0, "canceling exit restores selected speed")
	state.set_time_speed(0.0)
	for id in state.BUILDINGS:
		state.buildings[id] = 5
	state.changed.emit()
	state.visual_event.emit("chapter", {"chapter": 3})
	await process_frame
	await process_frame
	_check(state.get_prosperity() > 100, "city visuals accept max state")
	var visuals = ui.city_visual_layer
	_check(visuals.displayed_stages.farm == 3 and visuals.master_banners.farm.visible, "level five building has final art and master banner")
	var level_signatures := {}
	for level in 6:
		state.buildings.farm = level
		visuals._refresh_buildings()
		var signature := "%d/%.2f/%s/%s" % [visuals.displayed_stages.farm, visuals.building_views.farm.scale.x, visuals.veteran_banners.farm.visible, visuals.master_banners.farm.visible]
		level_signatures[signature] = true
	_check(level_signatures.size() == 6, "all six building levels have distinct persistent appearances")
	state.buildings.farm = 3
	state.changed.emit()
	await process_frame
	_check(visuals.displayed_stages.farm == 2 and visuals.veteran_banners.farm.visible and not visuals.master_banners.farm.visible, "level three has distinct veteran appearance")
	_check(absf(float(visuals.building_views.farm.scale.x) - 1.02) < 0.001, "each building level has a distinct scale")
	state.buffs = {"farm_until": state.current_day + 2, "all_until": state.current_day + 2}
	state.units = {"militia": 35, "archer": 10, "chariot": 5}
	state.defense_order = "sally"
	state.wounded = {"militia": 5, "archer": 0, "chariot": 0}
	state.enemy_army.scouted = true
	state.next_attack_day = state.current_day + 2
	visuals._refresh_buildings()
	_check(bool(visuals.world_state.irrigation) and bool(visuals.world_state.all_buff), "active production policies remain visible in the city")
	_check(int(visuals.world_state.soldier_markers) >= 3 and int(visuals.world_state.wounded_markers) == 1, "army and wounded state remain visible in the city")
	_check(str(visuals.world_state.defense_order) == "sally", "standing defense order remains visible in the city")
	_check(bool(visuals.world_state.enemy_warning), "scouted or nearby enemy remains visible at the wall")
	visuals.effects.clear()
	visuals.play_event("defense_order", {"order": "volley"})
	_check(_has_effect_text(visuals.effects, "军令·雁行"), "changing defense order has specific city feedback")
	visuals.effects.clear()
	visuals.play_event("policy", {"policy": "irrigate"})
	_check(_has_effect_kind(visuals.effects, "water"), "irrigation policy has specific water feedback")
	visuals.effects.clear()
	visuals.play_event("trade", {"trade": "sell_grain"})
	_check(_has_effect_velocity(visuals.effects, "caravan", -1), "selling sends caravans outward")
	visuals.effects.clear()
	visuals.play_event("trade", {"trade": "buy_grain"})
	_check(_has_effect_velocity(visuals.effects, "caravan", 1), "buying brings caravans inward")
	visuals.effects.clear()
	visuals.play_event("day", {"ledger": state.get_daily_ledger(), "recovered": 2})
	_check(_has_effect_text(visuals.effects, "2人归队"), "daily settlement reports recovered troops visually")
	visuals.effects.clear()
	visuals.play_event("event_choice", {"id": "merchant", "choice": 2})
	_check(not _has_effect_kind(visuals.effects, "caravan"), "declining a merchant does not show a false caravan journey")
	visuals.effects.clear()
	visuals.play_event("storage_full", {"resource": "grain"})
	_check(_has_effect_text(visuals.effects, "仓容不足"), "blocked full-storage trade has visible feedback")
	ui.queue_free()
	state.reset_game()
	await process_frame
	if failures.is_empty():
		print("UI_SMOKE_OK tabs=4 settings=ok city_visuals=ok")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)

func _gd_files_recursive(directory: String) -> Array[String]:
	var paths: Array[String] = []
	for file_name in DirAccess.get_files_at(directory):
		if file_name.ends_with(".gd"):
			paths.append(directory.path_join(file_name))
	for child_name in DirAccess.get_directories_at(directory):
		paths.append_array(_gd_files_recursive(directory.path_join(child_name)))
	return paths

func _has_label(parent: Node, text_value: String) -> bool:
	for node in parent.find_children("*", "Label", true, false):
		if node.text == text_value:
			return true
	return false

func _has_label_containing(parent: Node, text_value: String) -> bool:
	for node in parent.find_children("*", "Label", true, false):
		if str(node.text).contains(text_value):
			return true
	return false

func _has_button(parent: Node, text_value: String) -> bool:
	for node in parent.find_children("*", "Button", true, false):
		if str(node.text) == text_value:
			return true
	return false

func _has_button_containing(parent: Node, text_value: String) -> bool:
	for node in parent.find_children("*", "Button", true, false):
		if str(node.text).contains(text_value):
			return true
	return false

func _all_controls_pass_scroll_input(root_node: Node) -> bool:
	if root_node is Control and root_node.mouse_filter != Control.MOUSE_FILTER_PASS:
		return false
	for child in root_node.get_children():
		if not _all_controls_pass_scroll_input(child):
			return false
	return true

func _has_effect_kind(effects: Array[Dictionary], kind: String) -> bool:
	for effect in effects:
		if str(effect.get("kind", "")) == kind:
			return true
	return false

func _has_effect_velocity(effects: Array[Dictionary], kind: String, direction: int) -> bool:
	for effect in effects:
		if str(effect.get("kind", "")) == kind and signf(float(effect.vel.x)) == float(direction):
			return true
	return false

func _has_effect_text(effects: Array[Dictionary], text_value: String) -> bool:
	for effect in effects:
		if str(effect.get("text", "")) == text_value:
			return true
	return false
