extends SceneTree

const UiFont = preload("res://src/ui_font.gd")
const SIZE := Vector2i(1024, 500)
const INK := Color("#26372e")
const PAPER := Color("#f5e6bd")
const CINNABAR := Color("#a84b3d")
const GOLD := Color("#d2a653")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("generate_store_assets requires a rendered display driver")
		quit(1)
		return
	root.get_node("Audio").shutdown()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://store/screenshots"))
	var icon_svg := FileAccess.get_file_as_string("res://assets/icon.svg")
	# Play applies its own corner treatment, so the listing icon keeps a full-bleed background.
	icon_svg = icon_svg.replace("rx=\"108\"", "rx=\"0\"")
	var icon := Image.new()
	if icon_svg.is_empty() or icon.load_svg_from_string(icon_svg) != OK or icon.is_empty():
		push_error("cannot load store icon source")
		quit(1)
		return
	if icon.get_size() != Vector2i(512, 512):
		icon.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	icon.convert(Image.FORMAT_RGBA8)
	if icon.save_png("res://store/icon-512.png") != OK:
		push_error("cannot save 512x512 store icon")
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas := Control.new()
	canvas.size = SIZE
	canvas.theme = UiFont.make_theme()
	viewport.add_child(canvas)
	_build_feature_graphic(canvas)
	await process_frame
	await process_frame
	await create_timer(0.5).timeout
	var feature := viewport.get_texture().get_image()
	feature.convert(Image.FORMAT_RGB8)
	if feature.is_empty() or feature.get_size() != SIZE or feature.save_png("res://store/feature-graphic.png") != OK:
		push_error("cannot render 1024x500 feature graphic")
		quit(1)
		return
	for item in [
		["res://.qa/visual_spring_max.png", "res://store/screenshots/01-spring-city.png"],
		["res://.qa/visual_autumn_max.png", "res://store/screenshots/02-autumn-city.png"],
		["res://.qa/visual_winter_max.png", "res://store/screenshots/03-winter-city.png"],
	]:
		var screenshot := Image.load_from_file(item[0])
		if screenshot.is_empty():
			push_error("missing source screenshot: " + item[0])
			quit(1)
			return
		screenshot.resize(1080, 1920, Image.INTERPOLATE_LANCZOS)
		screenshot.convert(Image.FORMAT_RGB8)
		if screenshot.save_png(item[1]) != OK:
			push_error("cannot save store screenshot: " + item[1])
			quit(1)
			return
	print("STORE_ASSETS_OK icon=512x512 feature=1024x500 screenshots=3x1080x1920")
	quit(0)

func _build_feature_graphic(canvas: Control) -> void:
	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = load("res://assets/art/city_spring.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	canvas.add_child(background)

	var warmth := ColorRect.new()
	warmth.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	warmth.color = Color(0.76, 0.50, 0.20, 0.13)
	canvas.add_child(warmth)

	var shade_texture := GradientTexture2D.new()
	shade_texture.width = SIZE.x
	shade_texture.height = SIZE.y
	shade_texture.fill_from = Vector2(0.0, 0.5)
	shade_texture.fill_to = Vector2(1.0, 0.5)
	var shade_gradient := Gradient.new()
	shade_gradient.offsets = PackedFloat32Array([0.0, 0.48, 0.78, 1.0])
	shade_gradient.colors = PackedColorArray([
		Color(0.035, 0.075, 0.052, 0.98),
		Color(0.055, 0.11, 0.075, 0.82),
		Color(0.055, 0.11, 0.075, 0.20),
		Color(0.055, 0.11, 0.075, 0.02),
	])
	shade_texture.gradient = shade_gradient
	var shade := TextureRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.texture = shade_texture
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	canvas.add_child(shade)

	var seal := Label.new()
	seal.position = Vector2(62, 67)
	seal.size = Vector2(86, 86)
	seal.text = "禾"
	seal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seal.add_theme_font_size_override("font_size", 48)
	seal.add_theme_color_override("font_color", Color("#fff1ce"))
	seal.add_theme_stylebox_override("normal", _style(CINNABAR, 20))
	canvas.add_child(seal)

	_add_label(canvas, "青禾邑", Vector2(58, 177), Vector2(480, 100), 82, PAPER, true)
	var divider := ColorRect.new()
	divider.position = Vector2(64, 287)
	divider.size = Vector2(370, 3)
	divider.color = GOLD
	canvas.add_child(divider)
	_add_label(canvas, "四时耕战 · 一邑春秋", Vector2(64, 307), Vector2(470, 48), 30, Color("#efd7a0"), false)
	_add_label(canvas, "经营百业　营造城邑　调度军民", Vector2(66, 374), Vector2(480, 38), 20, Color("#eee1be"), false)

	var badge := Label.new()
	badge.position = Vector2(836, 370)
	badge.size = Vector2(120, 64)
	badge.text = "离线单机"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 20)
	badge.add_theme_color_override("font_color", INK)
	badge.add_theme_stylebox_override("normal", _style(Color(0.96, 0.88, 0.66, 0.92), 24, 2, CINNABAR))
	canvas.add_child(badge)

func _add_label(parent: Control, text_value: String, position: Vector2, size: Vector2, font_size: int, color: Color, bold: bool) -> void:
	var label := Label.new()
	label.position = position
	label.size = size
	label.text = text_value
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if bold:
		label.add_theme_constant_override("outline_size", 1)
		label.add_theme_color_override("font_outline_color", Color(0.03, 0.06, 0.04, 0.35))
	parent.add_child(label)

func _style(fill: Color, radius: int, border_width := 0, border_color := Color.TRANSPARENT) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.border_width_left = border_width
	box.border_width_top = border_width
	box.border_width_right = border_width
	box.border_width_bottom = border_width
	box.border_color = border_color
	return box
