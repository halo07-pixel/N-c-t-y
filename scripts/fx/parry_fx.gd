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
	var radius := 8.0 + 20.0 * t
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(1.0, 0.92, 0.55, 0.9 * fade), 2.0)
	draw_arc(Vector2.ZERO, radius * 0.6, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.7 * fade), 1.0)
	var font := UiFont.get_font()
	draw_string(font, Vector2(-16.0, -22.0 - 10.0 * t), "PARRY", HORIZONTAL_ALIGNMENT_CENTER, 32.0, 9, Color(1.0, 0.95, 0.6, fade))
