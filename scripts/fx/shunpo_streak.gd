class_name ShunpoStreak
extends Node2D
## The streak left by a Shunpo: thin lines from where it began to where it ended, fading fast.

const LIFETIME := 0.25

var from_point: Vector2 = Vector2.ZERO
var to_point: Vector2 = Vector2.ZERO
var color: Color = Color(0.8, 0.9, 1.0)
var _age: float = 0.0


func _init() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	z_index = 15


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var fade := 1.0 - _age / LIFETIME
	for i in 5:
		var y := -6.0 - float(i) * 5.0
		var offset := Vector2(0.0, y)
		draw_line(from_point + offset, to_point + offset, Color(color.r, color.g, color.b, 0.35 * fade), 0.8 * fade + 0.2)
