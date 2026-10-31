class_name MechanicBurst
extends Node2D
## The one-shot flash of a character mechanic: a red Hollow flare, a Quincy cross that bounces
## up, or a golden beam of Reiatsu flying from the victim to Yhwach. Additive, short, visual only.

const LIFETIME := 0.45

var kind: StringName = &"hollow"
var amount: float = 1.0
## The end of the beam for &"steal".
var to_point: Vector2 = Vector2.ZERO
var _age: float = 0.0


func _init() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	z_index = 16


## The colors (main, rim) of a mechanic.
static func palette(mechanic: StringName) -> Array[Color]:
	match mechanic:
		&"heartless":
			return [Color(0.65, 0.9, 1.0), Color(1.0, 1.0, 1.0)]
		&"steal":
			return [Color(1.0, 0.85, 0.4), Color(0.55, 0.25, 0.75)]
	return [Color(1.0, 0.15, 0.2), Color(0.1, 0.0, 0.05)]


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _age / LIFETIME
	var fade := 1.0 - t
	var colors := palette(kind)
	match kind:
		&"heartless":
			_draw_cross(t, fade, colors)
		&"steal":
			_draw_beam(t, fade, colors)
		_:
			_draw_flare(t, fade, colors)


## Hollow: a ring that grows and flame spikes that rise from it.
func _draw_flare(t: float, fade: float, colors: Array[Color]) -> void:
	var radius := 6.0 + 26.0 * t
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, Color(colors[0].r, colors[0].g, colors[0].b, 0.8 * fade * amount), 2.0 * fade + 0.5)
	draw_arc(Vector2.ZERO, radius * 0.6, 0.0, TAU, 20, Color(colors[1].r, colors[1].g, colors[1].b, 0.6 * fade), 1.0)
	var spikes := int(round(7.0 * amount))
	for i in spikes:
		var angle := -PI * 0.5 + (float(i) - float(spikes - 1) * 0.5) * 0.42
		var length := (8.0 + 14.0 * sin(float(i) * 2.3 + 1.0) * 0.5 + 10.0) * (0.4 + t)
		var base := Vector2(cos(angle), sin(angle)) * radius * 0.7
		draw_line(base, base + Vector2(cos(angle), sin(angle)) * length, Color(colors[0].r, colors[0].g, colors[0].b, 0.7 * fade), 1.5)


## Heartless: the four-pointed Quincy star, with a ring that rises like a bounce.
func _draw_cross(t: float, fade: float, colors: Array[Color]) -> void:
	var rise := Vector2(0.0, -28.0 * t)
	var reach := 6.0 + 20.0 * sin(minf(t * 3.0, PI * 0.5))
	for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		draw_line(rise, rise + direction * reach, Color(colors[0].r, colors[0].g, colors[0].b, 0.9 * fade * amount), 2.0)
		draw_line(rise, rise + direction * reach * 0.5, Color(colors[1].r, colors[1].g, colors[1].b, fade), 1.0)
	draw_set_transform(rise, 0.0, Vector2(1.0, 0.35))
	draw_arc(Vector2.ZERO, 8.0 + 22.0 * t, 0.0, TAU, 24, Color(colors[0].r, colors[0].g, colors[0].b, 0.6 * fade), 1.4)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Steal: a line from the victim to the thief with bright beads running along it.
func _draw_beam(t: float, fade: float, colors: Array[Color]) -> void:
	var end := to_point - global_position
	draw_line(Vector2.ZERO, end, Color(colors[1].r, colors[1].g, colors[1].b, 0.5 * fade), 3.0)
	draw_line(Vector2.ZERO, end, Color(colors[0].r, colors[0].g, colors[0].b, 0.8 * fade * amount), 1.2)
	var beads := int(round(5.0 * amount))
	for i in beads:
		var along := fposmod(t * 1.6 + float(i) / float(maxi(beads, 1)), 1.0)
		draw_circle(Vector2.ZERO.lerp(end, along), 2.0, Color(1.0, 1.0, 1.0, fade))
	draw_circle(Vector2.ZERO, 5.0 * fade + 1.0, Color(colors[0].r, colors[0].g, colors[0].b, 0.6 * fade))
