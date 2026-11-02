class_name ParryFx
extends Node2D
## A bright ring and the word PARRY where a hit was parried.

const LIFETIME := 0.45
var _age: float = 0.0


func _init() -> void:
	z_index = 20


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _age / LIFETIME
	var fade := 1.0 - t
	var radius := 8.0 + 24.0 * t
	# A bright flash at the start, then an expanding ring and sparks flying outwards.
	if t < 0.25:
		draw_circle(Vector2.ZERO, 10.0 * (1.0 - t * 2.0), Color(1.0, 1.0, 1.0, 0.8))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(1.0, 0.92, 0.55, 0.9 * fade), 2.5)
	draw_arc(Vector2.ZERO, radius * 0.6, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.7 * fade), 1.0)
	for i in 8:
		var angle := TAU * float(i) / 8.0 + 0.2
		var inner := Vector2.from_angle(angle) * (radius * 0.7)
		var outer := Vector2.from_angle(angle) * (radius * 1.25 + 6.0)
		draw_line(inner, outer, Color(1.0, 0.95, 0.7, 0.85 * fade), 1.5)
	var font := UiFont.get_font()
	var origin := Vector2(-20.0, -26.0 - 10.0 * t)
	draw_string_outline(font, origin, "PARRY", HORIZONTAL_ALIGNMENT_CENTER, 40.0, 11, 3, Color(0.1, 0.05, 0.15, fade))
	draw_string(font, origin, "PARRY", HORIZONTAL_ALIGNMENT_CENTER, 40.0, 11, Color(1.0, 0.95, 0.6, fade))
