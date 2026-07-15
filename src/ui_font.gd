class_name QingheFont
extends RefCounted

const FONT_FILE: FontFile = preload("res://assets/fonts/QingheSansSC-Medium.ttf")

static func medium() -> Font:
	return FONT_FILE

static func make_theme() -> Theme:
	var ui_theme := Theme.new()
	ui_theme.default_font = medium()
	return ui_theme
