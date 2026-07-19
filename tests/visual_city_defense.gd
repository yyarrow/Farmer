extends SceneTree

const DefenseVisuals = preload("res://src/city_defense_visuals.gd")

var viewport: SubViewport

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("Audio").shutdown()
	viewport = SubViewport.new()
	viewport.size = Vector2i(1080, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)

	var background := ColorRect.new()
	background.color = Color("#e7d8ad")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(background)

	var title := Label.new()
	title.text = "城防独立边界 · 0—5级"
	title.position = Vector2(34, 22)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#26362d"))
	viewport.add_child(title)

	for level in 6:
		var panel := Node2D.new()
		panel.position = Vector2(18 + (level % 3) * 350, 70 + (level / 3) * 310)
		panel.scale = Vector2(0.61, 0.61)
		viewport.add_child(panel)
		var defense := DefenseVisuals.new()
		defense.configure(level, "warring_states", {}, 12)
		panel.add_child(defense)
		var label := Label.new()
		label.text = "%d级 · %s" % [level, ["未建", "木栅", "土垒", "城垣", "重门", "完备"][level]]
		label.position = Vector2(80, 242)
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_color", Color("#26362d"))
		panel.add_child(label)

	await process_frame
	await process_frame
	var image := viewport.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://.qa")
	var error := image.save_png("res://.qa/city_defense_levels.png")
	print("CITY_DEFENSE_VISUAL_OK path=res://.qa/city_defense_levels.png error=%d" % error)
	quit(0 if error == OK else 1)
