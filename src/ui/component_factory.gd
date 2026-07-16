extends RefCounted

const INK := Color("#29382f")
const INK_SOFT := Color("#5f6555")
const PAPER := Color("#f4e8c8")
const PAPER_DARK := Color("#dfca96")
const JADE := Color("#55745d")
const JADE_LIGHT := Color("#779274")
const CINNABAR := Color("#a54a3d")
const GOLD := Color("#c99945")
const SHADOW := Color(0.10, 0.12, 0.09, 0.42)

static func style(fill: Color, radius := 12, border_width := 0, border_color := Color.TRANSPARENT, padding := 0) -> StyleBoxFlat:
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
	box.content_margin_left = padding
	box.content_margin_top = padding
	box.content_margin_right = padding
	box.content_margin_bottom = padding
	return box

static func card(height: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = height
	panel.add_theme_stylebox_override("panel", style(Color(1.0, 0.975, 0.89, 0.80), 14, 1, Color(0.42, 0.36, 0.24, 0.16), 10))
	return panel

static func glyph_badge(glyph: String, color: Color) -> Label:
	var badge := Label.new()
	badge.text = glyph
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.custom_minimum_size = Vector2(50, 50)
	badge.add_theme_font_size_override("font_size", 20)
	badge.add_theme_color_override("font_color", Color.WHITE)
	badge.add_theme_stylebox_override("normal", style(color, 14))
	return badge

static func action_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(76, 42)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", style(JADE, 11, 0, Color.TRANSPARENT, 5))
	button.add_theme_stylebox_override("hover", style(JADE_LIGHT, 11, 0, Color.TRANSPARENT, 5))
	button.add_theme_stylebox_override("pressed", style(CINNABAR, 11, 0, Color.TRANSPARENT, 5))
	button.add_theme_stylebox_override("disabled", style(Color(0.42, 0.41, 0.35, 0.35), 11, 0, Color.TRANSPARENT, 5))
	return button

static func info_banner(title: String, detail: String, accent: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 68 if "\n" in detail else 60
	panel.add_theme_stylebox_override("panel", style(Color(accent, 0.13), 13, 1, Color(accent, 0.22), 9))
	var stack := VBoxContainer.new()
	panel.add_child(stack)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 13)
	heading.add_theme_color_override("font_color", accent.darkened(0.25))
	stack.add_child(heading)
	var desc := Label.new()
	desc.text = detail
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", INK)
	stack.add_child(desc)
	return panel

static func progress_card(title: String, value: int, target: int, detail_text: String) -> PanelContainer:
	var panel := card(90)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	panel.add_child(stack)
	var heading := HBoxContainer.new()
	stack.add_child(heading)
	var label := Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", INK)
	heading.add_child(label)
	var number := Label.new()
	number.text = "%d / %d" % [value, target]
	number.add_theme_font_size_override("font_size", 13)
	number.add_theme_color_override("font_color", CINNABAR)
	heading.add_child(number)
	var progress := ProgressBar.new()
	progress.max_value = target
	progress.value = value
	progress.show_percentage = false
	progress.custom_minimum_size.y = 8
	progress.add_theme_stylebox_override("background", style(Color(0.31, 0.32, 0.23, 0.13), 4))
	progress.add_theme_stylebox_override("fill", style(JADE, 4))
	stack.add_child(progress)
	var detail := Label.new()
	detail.text = detail_text
	detail.add_theme_font_size_override("font_size", 10)
	detail.add_theme_color_override("font_color", INK_SOFT)
	stack.add_child(detail)
	return panel

static func danger_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 44
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", CINNABAR)
	button.add_theme_stylebox_override("normal", style(Color(CINNABAR, 0.08), 11, 1, Color(CINNABAR, 0.28), 6))
	button.add_theme_stylebox_override("pressed", style(Color(CINNABAR, 0.20), 11, 1, CINNABAR, 6))
	return button
