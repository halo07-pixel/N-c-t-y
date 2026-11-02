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
	# Same night as the stage: smooth sky, stars, moon with a glow, far hills, dark ground.
	var top := StagePalette.SKY_TOP
	var mid := StagePalette.SKY_MID
	var low := StagePalette.SKY_HORIZON.darkened(0.25)
	_sky_band(0.0, 150.0, top, mid)
	_sky_band(150.0, SCREEN.y, mid, low)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 70:
		var at := Vector2(rng.randf_range(0.0, SCREEN.x), rng.randf_range(0.0, 150.0))
		draw_circle(at, rng.randf_range(0.4, 0.9), Color(1.0, 0.97, 0.92, rng.randf_range(0.3, 0.9)))
	var moon := Vector2(370.0, 80.0)
	for ring in 10:
		draw_circle(moon, 30.0 + ring * 5.0, Color(StagePalette.MOON_GLOW, 0.02))
	draw_circle(moon, 30.0, StagePalette.MOON)
	draw_circle(moon + Vector2(-9.0, -6.0), 6.0, Color(0.85, 0.82, 0.7, 0.45))
	draw_circle(moon + Vector2(10.0, 8.0), 4.0, Color(0.85, 0.82, 0.7, 0.35))
	var hills := PackedVector2Array([Vector2(0.0, SCREEN.y)])
	for step in 25:
		var x := step * SCREEN.x / 24.0
		hills.append(Vector2(x, 205.0 - 14.0 * sin(x * 0.03 + 1.0) - 7.0 * sin(x * 0.08)))
	hills.append(Vector2(SCREEN.x, SCREEN.y))
	draw_colored_polygon(hills, StagePalette.FAR.darkened(0.2))
	draw_rect(Rect2(0.0, 238.0, SCREEN.x, 32.0), Color(StagePalette.NEAR, 0.85))


func _sky_band(from_y: float, to_y: float, from: Color, to: Color) -> void:
	draw_polygon(
		PackedVector2Array([Vector2(0.0, from_y), Vector2(SCREEN.x, from_y), Vector2(SCREEN.x, to_y), Vector2(0.0, to_y)]),
		PackedColorArray([from, from, to, to])
	)


## Outlined text centered on `position.x`; `position.y` is the baseline.
func draw_centered(text: String, position: Vector2, font_size: int, color: Color) -> void:
	var font := UiFont.get_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	draw_left(text, Vector2(position.x - width * 0.5, position.y), font_size, color)


## Outlined text starting at `position` (left end of the baseline).
func draw_left(text: String, position: Vector2, font_size: int, color: Color) -> void:
	var font := UiFont.get_font()
	draw_string_outline(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 3, OUTLINE)
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
