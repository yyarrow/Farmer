extends RefCounted

const Presentation = preload("res://src/ui/presentation_formatter.gd")

static func guidance(state: Node) -> Dictionary:
	if state.attack_wave > 1:
		return {}
	var days_left: int = state.days_until_attack()
	var militia_cost: Dictionary = state.UNITS.militia.cost
	if state.get_army_count() < 25:
		var roster_used: int = state.get_army_count() + state.get_wounded_count()
		if roster_used + int(state.UNITS.militia.batch) > state.get_army_capacity():
			return {"step": "recover", "title": "首战备忘 · 安置伤卒", "detail": "伤员仍占军籍，待其归队或升级兵营扩充军籍后再征募。来敌%d日后抵城。" % days_left, "tab": 2, "action": "查看伤营"}
		if not state.can_afford(militia_cost):
			return {"step": "funds", "title": "首战备忘 · 筹措粮饷", "detail": "征募一伍%s需%s；先从账簿确认日结，必要时市易筹措。" % [state.UNITS.militia.name, Presentation.cost(militia_cost, state.RESOURCE_UNITS)], "tab": 1, "action": "查看账簿"}
		var enemy: Dictionary = state.get_enemy_display()
		return {"step": "recruit", "title": "首战备忘 · 补足军籍", "detail": "%s约%s，现有守军%d人。先征募一伍%s，不会推进日期。" % [enemy.name, enemy.range, state.get_army_count(), state.UNITS.militia.name], "tab": 2, "action": "前往军务"}
	if state.buildings.wall == 0 and state.buildings.barracks == 0:
		var can_build_defense: bool = state.can_afford(state.building_cost("wall")) or state.can_afford(state.building_cost("barracks"))
		if not can_build_defense:
			return {"step": "funds", "title": "首战备忘 · 积蓄城资", "detail": "守军已经补足；接下来修城垣减伤或建兵营扩军。先从账簿安排缺少的物资。", "tab": 1, "action": "查看账簿"}
		return {"step": "defense", "title": "首战备忘 · 建立防务", "detail": "来敌%d日后抵城。城垣直接降低伤亡；兵营提高军籍上限与训练，可择一先建。" % days_left, "tab": 0, "action": "查看城建"}
	if not bool(state.enemy_army.get("scouted", false)):
		return {"step": "scout", "title": "首战备忘 · 探明来敌", "detail": "防务已有根基。巡剿会探明真实编成，并有机会削敌、拖延行军，但也可能产生伤员。", "tab": 2, "action": "前往军务"}
	var forecast: Dictionary = state.get_battle_forecast(60)
	var win_percent := roundi(float(forecast.win_rate) * 100.0)
	var forecast_text := "当前推演胜算约%d%%，预计伤亡%d～%d人。" % [win_percent, int(forecast.loss_low), int(forecast.loss_high)]
	if win_percent < 60:
		return {"step": "reinforce", "title": "首战备忘 · 风险仍高", "detail": forecast_text + "继续扩军、修墙或更换阵令，再决定是否推进日期。", "tab": 2, "action": "调整军务"}
	return {"step": "ready", "title": "首战备忘 · 可以应战", "detail": forecast_text + "确认账簿能承担军粮军饷后，再用顶部按钮推进日期。", "tab": 2, "action": "查看推演"}
