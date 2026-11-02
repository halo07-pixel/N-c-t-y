class_name UiFont
extends RefCounted
## The one font every menu, HUD and effect draws text with.
## To change the look of all text, replace assets/fonts/ui_font.ttf (keep the license next to it).

const PATH := "res://assets/fonts/ui_font.ttf"

static var _font: Font


static func get_font() -> Font:
	if _font == null:
		_font = load(PATH) as Font if ResourceLoader.exists(PATH) else ThemeDB.fallback_font
	return _font
