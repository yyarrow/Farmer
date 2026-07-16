extends RefCounted

const FONT_LICENSE_PATH := "res://assets/fonts/OFL.txt"
# Names in Godot's third-party copyright table use these Latin glyphs.
# Keeping them here also makes the deterministic UI font subset include them.
const LICENSE_NAME_GLYPHS := "éóáöøÅ©"

static func build_notice() -> String:
	var lines := PackedStringArray([
		"《青禾邑》开源软件许可与鸣谢",
		"版本 %s" % ProjectSettings.get_setting("application/config/version", "未知"),
		"",
		"本游戏使用 Godot Engine。以下许可与版权信息由当前引擎直接提供，以便随引擎升级保持准确。",
		"",
		"========== Godot Engine ==========",
		_clean_text(Engine.get_license_text()),
		"",
		"========== 引擎第三方组件与版权 ==========",
	])
	for component in Engine.get_copyright_info():
		lines.append("")
		lines.append(str(component.get("name", "未命名组件")))
		for part in component.get("parts", []):
			for holder in part.get("copyright", []):
				lines.append("Copyright %s" % str(holder))
			lines.append("License: %s" % str(part.get("license", "未标注")))

	lines.append("")
	lines.append("========== 引擎第三方许可全文 ==========")
	var license_info := Engine.get_license_info()
	var license_names := license_info.keys()
	license_names.sort()
	for license_name in license_names:
		lines.append("")
		lines.append("----- %s -----" % str(license_name))
		lines.append(_clean_text(license_info[license_name]))

	lines.append("")
	lines.append("========== Qinghe Sans SC 字体 ==========")
	lines.append("由 Noto Sans SC 制作子集并更名；Copyright 2014–2021 Adobe，保留字体名称 Source。")
	lines.append(FileAccess.get_file_as_string(FONT_LICENSE_PATH))
	return "\n".join(lines)

static func _clean_text(value: Variant) -> String:
	# Godot 4.7's embedded FreeType notice contains one UTF-8 copyright
	# symbol decoded as Latin-1. Normalize it before displaying the text.
	return str(value).replace("Â©", "©")
