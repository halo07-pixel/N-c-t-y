class_name ShockwaveFx
extends Node2D
## A ring that expands from a heavy impact (and a thin second ring behind it), plus a flat flash
## of light on the ground line. Used for tier-2 hits, parries and guard breaks. Additive;
## frees itself. Purely visual.

const LIFETIME := 0.32
## Hits at or above this HitSpark power get a ring.
const MIN_POWER := 0.7

var color: Color = Color(1.0, 1.0, 1.0)
## 0..1, scales the ring's reach.
var power: float = 1.0
var amount: float = 1.0
var _age: float = 0.0


func _init() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	z_index = 17


static func wants_ring(hit_power: float) -> bool:
	return hit_power >= MIN_POWER


## Ring radius `t` (0..1) through its life: fast at first, then easing out.
static func radius_at(t: float, hit_power: float) -> float:
	var reach := 22.0 + 30.0 * clampf(hit_power, 0.0, 1.0)
	return reach * (1.0 - pow(1.0 - clampf(t, 0.0, 1.0), 3.0))


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _age / LIFETIME
	var fade := 1.0 - t
	var radius := radius_at(t, power)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(color.r, color.g, color.b, 0.85 * fade * amount), 2.5 * fade + 0.5)
	draw_arc(Vector2.ZERO, radius * 0.62, 0.0, TAU, 28, Color(1.0, 1.0, 1.0, 0.6 * fade * amount), 1.0)
	if t < 0.3:
		var flash := 1.0 - t / 0.3
		draw_circle(Vector2.ZERO, 7.0 * flash, Color(1.0, 1.0, 1.0, 0.7 * flash))
