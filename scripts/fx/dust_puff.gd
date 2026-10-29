class_name DustPuff
extends Node2D
## A few soft puffs kicked up by a landing or a jump. Frees itself.

const LIFETIME := 0.4
const PUFFS := 5

var strength: float = 1.0
var _age: float = 0.0


func _init() -> void:
	z_index = -1


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := clampf(_age / LIFETIME, 0.0, 1.0)
	var fade := 1.0 - t
	for i in PUFFS:
		var side := -1.0 if i % 2 == 0 else 1.0
		var reach := (3.0 + float(i / 2) * 3.5) * strength
		var center := Vector2(side * reach * (0.3 + t), -1.5 - t * 4.0 * strength)
		draw_circle(center, (1.6 + 2.2 * strength) * (0.6 + t), Color(0.85, 0.82, 0.95, 0.45 * fade))
