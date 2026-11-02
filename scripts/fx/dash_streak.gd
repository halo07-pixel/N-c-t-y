class_name DashStreak
extends Node2D
## The streak left by a dash: thin lines from where it began to where it ended, fading fast.

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
	var direction := (to_point - from_point)
	if direction.length() < 1.0:
		return
	# A tapered wedge from the start to the fighter, plus thin speed lines on top of it.
	var normal := direction.normalized().orthogonal()
	var half := 9.0 * fade
	var wedge := PackedVector2Array([
		from_point + Vector2(0.0, -16.0), to_point + Vector2(0.0, -16.0) + normal * half,
		to_point + Vector2(0.0, -16.0) - normal * half,
	])
	draw_colored_polygon(wedge, Color(color.r, color.g, color.b, 0.28 * fade))
	for i in 5:
		var offset := Vector2(0.0, -6.0 - float(i) * 5.0)
		draw_line(from_point + offset, to_point + offset, Color(color.r, color.g, color.b, 0.6 * fade), 1.0 * fade + 0.3)
