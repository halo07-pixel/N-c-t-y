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
## How the burst is drawn (an FxProfile impact style): slash, shards, petals or ink.
var style: StringName = &"slash"
var accent: Color = Color(1.0, 1.0, 1.0)
var _age: float = 0.0


func _init() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	z_index = 20


## How big a hit feels from its damage and launch speed, 0..1.
static func power_for(damage: float, launch_speed: float) -> float:
	return clampf(damage / 25.0 * 0.6 + launch_speed / 900.0 * 0.4, 0.15, 1.0)


## 0 light, 1 solid, 2 heavy: what extra layers a hit gets.
static func tier_for(hit_power: float) -> int:
	if hit_power < 0.4:
		return 0
	return 1 if hit_power < 0.7 else 2


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
	_draw_style(t, size)
	if power > 0.55:
		var normal := direction.orthogonal()
		for i in 5:
			var offset := (float(i) - 2.0) * 4.0
			var start := -direction * (size * 0.8) + normal * offset
			var length := (20.0 + 30.0 * power) * ease_out
			draw_line(start, start - direction * length, Color(1.0, 1.0, 1.0, 0.7 * fade), 1.0)


## The character-specific layer on top of the common flash.
func _draw_style(t: float, size: float) -> void:
	var fade := 1.0 - t
	var ease_out := 1.0 - pow(1.0 - t, 3.0)
	var tier := tier_for(power)
	var base := direction.angle()
	match style:
		&"slash":
			# Two crossing cuts through the point of impact; heavy hits get a longer second.
			var reach := size * (1.1 + 0.5 * float(tier)) * ease_out
			var cut := Vector2.from_angle(base + 0.9)
			draw_line(-cut * reach, cut * reach, Color(accent.r, accent.g, accent.b, fade), 2.4 * fade + 0.4)
			if tier >= 1:
				var cut2 := Vector2.from_angle(base - 0.9)
				draw_line(-cut2 * reach * 0.8, cut2 * reach * 0.8, Color(color.r, color.g, color.b, fade), 1.6 * fade + 0.3)
		&"shards":
			for i in 6 + tier * 3:
				var a := base + (float(i) / float(5 + tier * 3) - 0.5) * 3.0
				var tip := Vector2.from_angle(a) * size * (0.7 + 0.9 * ease_out)
				var tail := Vector2.from_angle(a) * size * 0.3 * ease_out
				var side := Vector2.from_angle(a + PI * 0.5) * 1.6 * fade
				draw_colored_polygon(PackedVector2Array([tail + side, tip, tail - side]), Color(accent.r, accent.g, accent.b, fade))
		&"petals":
			for i in 5 + tier * 2:
				var a := base + (float(i) / float(4 + tier * 2) - 0.5) * 3.4 + t * 1.2
				var center := Vector2.from_angle(a) * size * (0.4 + 0.9 * ease_out)
				var petal := PackedVector2Array()
				for step in 8:
					var p := float(step) * TAU / 8.0
					petal.append(center + Vector2(cos(p) * 4.0, sin(p) * 1.8).rotated(a + t * 4.0))
				draw_colored_polygon(petal, Color(color.r, color.g, color.b, fade))
		&"ink":
			# First the dark pulls in (lines converging), then it bursts out.
			if t < 0.3:
				var pull := t / 0.3
				for i in 8:
					var a := TAU * float(i) / 8.0
					var from := Vector2.from_angle(a) * size * (1.6 - 1.2 * pull)
					draw_line(from, from * 0.6, Color(color.r, color.g, color.b, 0.9), 1.6)
			else:
				var burst := (t - 0.3) / 0.7
				draw_arc(Vector2.ZERO, size * (0.4 + 1.3 * burst), 0.0, TAU, 28, Color(accent.r, accent.g, accent.b, 1.0 - burst), 2.4 * (1.0 - burst) + 0.4)
	if tier >= 2:
		draw_arc(Vector2.ZERO, size * 1.5 * ease_out, 0.0, TAU, 32, Color(accent.r, accent.g, accent.b, 0.6 * fade), 1.2)
