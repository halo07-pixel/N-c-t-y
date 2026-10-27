class_name MenuScreen
extends Control
## Base of every menu: full-screen control with the shared night backdrop and
## outlined text helpers. Subclasses draw in _draw_content and react in
## handle_action; they leave the screen by emitting Events.screen_requested.

const SCREEN := Vector2(480.0, 270.0)
const BG_TOP := Color(0.09, 0.06, 0.17)
const BG_BOTTOM := Color(0.02, 0.02, 0.05)
const MOON := Color(0.85, 0.85, 0.95, 0.09)
const WHITE := Color(0.95, 0.95, 1.0)
const DIM := Color(0.5, 0.5, 0.62)
const WARM := Color(1.0, 0.8, 0.35)
const RED := Color(0.95, 0.3, 0.3)
const BLUE := Color(0.3, 0.55, 0.95)
const OUTLINE := Color(0.03, 0.02, 0.06)
const BACKDROP_BANDS := 18


func _ready() -> void:
	# Menus are laid out in 480x270 and scaled up to the 720x405 screen.
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = SCREEN
	scale = RenderScale.ui()
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	_draw_backdrop()
	_draw_content()


func _unhandled_input(event: InputEvent) -> void:
	var action := MenuNav.read(event)
	if action != &"":
		handle_action(action)
		get_viewport().set_input_as_handled()


## Override: react to up, down, left, right, confirm or back.
func handle_action(_action: StringName) -> void:
	pass


## Override: draw the screen on top of the backdrop.
func _draw_content() -> void:
	pass


func go_to(screen: StringName) -> void:
	Events.screen_requested.emit(screen)


func _draw_backdrop() -> void:
	var band_height := SCREEN.y / BACKDROP_BANDS
	for band in BACKDROP_BANDS:
		var color := BG_TOP.lerp(BG_BOTTOM, float(band) / (BACKDROP_BANDS - 1))
		draw_rect(Rect2(0.0, band * band_height, SCREEN.x, band_height + 1.0), color)
	draw_circle(Vector2(360.0, 96.0), 74.0, MOON)
	draw_arc(Vector2(360.0, 96.0), 82.0, 0.0, TAU, 64, MOON, 1.0)
	draw_rect(Rect2(0.0, 238.0, SCREEN.x, 32.0), Color(0.0, 0.0, 0.0, 0.45))


## Outlined text centered on `position.x`; `position.y` is the baseline.
func draw_centered(text: String, position: Vector2, font_size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	draw_left(text, Vector2(position.x - width * 0.5, position.y), font_size, color)


## Outlined text starting at `position` (left end of the baseline).
func draw_left(text: String, position: Vector2, font_size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	draw_string_outline(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 3, OUTLINE)
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
