class_name HitSpark
extends Node2D
## The flash of a hit: a bright core, an expanding ring, rays biased along the knockback
## direction and, on heavy hits, speed lines streaking behind the victim. Additive; frees itself.

const LIFETIME := 0.3
const RAYS := 9

var color: Color = Color.WHITE
var direction: Vector2 = Vector2.RIGHT
## 0..1, how big the hit feels.
var power: float = 0.3
## Overall size multiplier: the effects level times the character profile's spark scale.
var amount: float = 1.0
var _age: float = 0.0


func _init() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	z_index = 20


## How big a hit feels from its damage and launch speed, 0..1.
static func power_for(damage: float, launch_speed: float) -> float:
	return clampf(damage / 25.0 * 0.6 + launch_speed / 900.0 * 0.4, 0.15, 1.0)


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
	var ease_out := 1.0 - pow(1.0 - t, 3.0)
	var size := (10.0 + 22.0 * power) * amount
	draw_circle(Vector2.ZERO, size * 0.3 * fade, Color(1.0, 1.0, 1.0, 0.5 * fade))
	draw_arc(Vector2.ZERO, size * ease_out + 2.0, 0.0, TAU, 28, Color(color.r, color.g, color.b, fade), 2.0 * fade + 0.5)
	var base := direction.angle()
	for i in RAYS:
		var spread := (float(i) / float(RAYS - 1) - 0.5) * 2.4
		var a := base + spread
		var length := size * (0.6 + 0.8 * cos(spread * 0.9)) * (0.4 + ease_out)
		draw_line(Vector2.from_angle(a) * size * 0.3 * ease_out, Vector2.from_angle(a) * length, Color(color.r, color.g, color.b, fade), 1.5 * fade + 0.4)
	if power > 0.55:
		var normal := direction.orthogonal()
		for i in 5:
			var offset := (float(i) - 2.0) * 4.0
			var start := -direction * (size * 0.8) + normal * offset
			var length := (20.0 + 30.0 * power) * ease_out
			draw_line(start, start - direction * length, Color(1.0, 1.0, 1.0, 0.7 * fade), 1.0)
