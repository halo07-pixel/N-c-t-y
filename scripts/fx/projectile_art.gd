class_name ProjectileArt
extends RefCounted
## Vector looks for projectiles, drawn by code onto a CanvasItem (additive blending is set
## by the projectile): a Getsuga-like crescent, light arrows, petals, dark orbs.
## Everything is facing +x; `angle` turns it along the flight direction.

const TRAIL_POINTS := 9
const STYLES: Array[StringName] = [&"crescent", &"arrow", &"petal", &"orb", &"blast"]


## Outline of a crescent `width` long and `height` tall, convex side toward +x.
static func crescent_points(width: float, height: float) -> PackedVector2Array:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var steps := 14
	for i in steps + 1:
		var u := -1.0 + 2.0 * float(i) / float(steps)
		var bulge := 1.0 - u * u
		var x_outer := width * 0.5 * bulge
		var x_inner := x_outer - width * 0.3 * pow(bulge, 0.7)
		outer.append(Vector2(x_outer, u * height * 0.5))
		inner.append(Vector2(x_inner, u * height * 0.5))
	inner.reverse()
	outer.append_array(inner)
	return outer


static func _scaled(points: PackedVector2Array, factor: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(point * factor)
	return result


static func _alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)


## Draws one projectile. `trail` holds recent positions in the item's local space.
static func draw(
	item: CanvasItem, style: StringName, size: Vector2, color: Color, angle: float, age: float,
	trail: PackedVector2Array = PackedVector2Array()
) -> void:
	_draw_trail(item, trail, color, size)
	item.draw_set_transform(Vector2.ZERO, angle, Vector2.ONE)
	match style:
		&"crescent":
			_crescent(item, size, color, 1.0)
		&"blast":
			_crescent(item, size, color, 1.6)
		&"arrow":
			_arrow(item, size, color)
		&"petal":
			_petals(item, size, color, age)
		&"orb":
			_orb(item, size, color, age)
		&"mine":
			_mine(item, size, color, age)
		_:
			_crescent(item, size, color, 1.0)
	item.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _draw_trail(item: CanvasItem, trail: PackedVector2Array, color: Color, size: Vector2) -> void:
	var count := trail.size()
	for i in range(1, count):
		var t := float(i) / float(count)
		item.draw_line(trail[i - 1], trail[i], _alpha(color, 0.5 * t), maxf(size.y * 0.5 * t, 1.0))


static func _crescent(item: CanvasItem, size: Vector2, color: Color, boost: float) -> void:
	var body := crescent_points(size.x * boost, size.y * boost)
	item.draw_colored_polygon(_scaled(body, 1.35), _alpha(color, 0.18))
	item.draw_colored_polygon(body, color)
	item.draw_colored_polygon(_scaled(body, 0.6), Color(1.0, 1.0, 1.0, 0.7))


static func _arrow(item: CanvasItem, size: Vector2, color: Color) -> void:
	var half := size.x * 0.5
	item.draw_line(Vector2(-half, 0.0), Vector2(half, 0.0), _alpha(color, 0.25), 5.0)
	item.draw_line(Vector2(-half, 0.0), Vector2(half, 0.0), color, 2.2)
	item.draw_line(Vector2(-half * 0.2, 0.0), Vector2(half, 0.0), Color.WHITE, 1.0)
	item.draw_colored_polygon(
		PackedVector2Array([Vector2(half + 4.0, 0.0), Vector2(half - 2.0, -2.6), Vector2(half - 2.0, 2.6)]),
		Color.WHITE
	)
	item.draw_circle(Vector2(half, 0.0), 3.4, _alpha(color, 0.4))


static func _petals(item: CanvasItem, size: Vector2, color: Color, age: float) -> void:
	var radius := maxf(size.x, size.y) * 0.5
	for i in 5:
		var turn := age * 9.0 + float(i) * TAU / 5.0
		var center := Vector2(cos(turn), sin(turn)) * radius * 0.45
		var petal := PackedVector2Array()
		for step in 8:
			var a := float(step) * TAU / 8.0
			petal.append(center + Vector2(cos(a) * 3.2, sin(a) * 1.4).rotated(turn))
		item.draw_colored_polygon(petal, color)
	item.draw_circle(Vector2.ZERO, radius * 0.25, _alpha(Color.WHITE, 0.8))


static func _orb(item: CanvasItem, size: Vector2, color: Color, age: float) -> void:
	var radius := maxf(size.x, size.y) * 0.5
	item.draw_circle(Vector2.ZERO, radius * 1.5, _alpha(color, 0.25))
	item.draw_circle(Vector2.ZERO, radius, Color(0.12, 0.02, 0.1, 1.0))
	item.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, color, 1.6)
	var tick := int(age * 24.0)
	for i in 4:
		var a := float(i) * TAU / 4.0 + float(tick) * 1.3
		var jitter := 0.5 + 0.5 * sin(float(tick + i) * 2.7)
		var mid := Vector2(cos(a + 0.4), sin(a + 0.4)) * radius * (1.1 + 0.3 * jitter)
		var tip := Vector2(cos(a), sin(a)) * radius * 1.8
		item.draw_polyline(PackedVector2Array([Vector2(cos(a), sin(a)) * radius, mid, tip]), Color.WHITE, 1.0)


## A stationary trap: a pulsing ring with a spinning cross, so it reads as "armed".
static func _mine(item: CanvasItem, size: Vector2, color: Color, age: float) -> void:
	var radius := maxf(size.x, size.y) * 0.5
	var pulse := 0.5 + 0.5 * sin(age * 6.0)
	item.draw_circle(Vector2.ZERO, radius * (1.0 + 0.25 * pulse), _alpha(color, 0.12 + 0.12 * pulse))
	item.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, _alpha(color, 0.85), 1.2)
	item.draw_arc(Vector2.ZERO, radius * 0.55, 0.0, TAU, 20, _alpha(color, 0.6), 1.0)
	var spin := age * 2.2
	for i in 4:
		var a := spin + float(i) * TAU / 4.0
		item.draw_line(Vector2(cos(a), sin(a)) * radius * 0.25, Vector2(cos(a), sin(a)) * radius * 0.8, _alpha(color, 0.9), 1.0)
	item.draw_circle(Vector2.ZERO, 1.6, _alpha(Color.WHITE, 0.7))
