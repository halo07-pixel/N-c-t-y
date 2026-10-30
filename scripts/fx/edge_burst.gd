class_name EdgeBurst
extends Node2D
## The flash where a fighter is knocked out of the screen: a ring and rays that
## expand and fade, drawn with additive blending. Frees itself when done.

const LIFETIME := 0.55
const RAYS := 12
const MAX_RADIUS := 64.0

var color: Color = Color(1.0, 0.9, 0.6)
var accent: Color = Color(1.0, 1.0, 1.0)
## The effects level's multiplier (0.5 / 1 / 1.5).
var amount: float = 1.0
var _age: float = 0.0


func _init() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	z_index = 20


## Progress 0..1 of the burst, used for the size and fade.
static func progress(age: float) -> float:
	return clampf(age / LIFETIME, 0.0, 1.0)


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := progress(_age)
	var fade := 1.0 - t
	var radius := MAX_RADIUS * amount * (1.0 - pow(1.0 - t, 3.0))
	draw_circle(Vector2.ZERO, radius * 0.35, Color(1.0, 1.0, 1.0, 0.6 * fade))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(color.r, color.g, color.b, fade), 3.0 * fade + 0.5)
	for ray in RAYS:
		var angle := TAU * float(ray) / float(RAYS)
		var from := Vector2.from_angle(angle) * radius * 0.5
		var to := Vector2.from_angle(angle) * radius * 1.3
		draw_line(from, to, Color(accent.r, accent.g, accent.b, fade) if ray % 2 == 0 else Color(1.0, 1.0, 1.0, fade), 2.0 * fade + 0.5)
	# A second, wider ring a beat later, in the character's accent.
	var late := clampf((t - 0.25) / 0.75, 0.0, 1.0)
	draw_arc(Vector2.ZERO, radius * (0.6 + 0.9 * late), 0.0, TAU, 40, Color(accent.r, accent.g, accent.b, (1.0 - late) * 0.7), 2.0 * (1.0 - late) + 0.4)
