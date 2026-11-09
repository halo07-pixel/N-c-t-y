class_name ProjectileArt
extends RefCounted
## Vector looks for projectiles, drawn by code onto a CanvasItem (additive blending is set
## by the projectile): a Getsuga-like crescent, light arrows, petals, dark orbs.
## Everything is facing +x; `angle` turns it along the flight direction.

const TRAIL_POINTS := 9
const STYLES: Array[StringName] = [&"crescent", &"arrow", &"petal", &"orb", &"blast", &"beam", &"bolt", &"blade", &"swirl", &"chain", &"baboon", &"coil", &"rune", &"pillar"]


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
	trail: PackedVector2Array = PackedVector2Array(), rim: Color = Color(0.0, 0.0, 0.0, 0.0),
	glow: Color = Color(0.0, 0.0, 0.0, 0.0)
) -> void:
	_draw_halo(item, style, size, color, glow, age)
	_draw_trail(item, trail, color, size)
	item.draw_set_transform(Vector2.ZERO, 0.0 if style == &"pillar" else angle, Vector2.ONE)
	match style:
		&"crescent":
			_crescent(item, size, color, 1.0, rim)
		&"blast":
			_crescent(item, size, color, 1.6, rim)
		&"beam":
			_beam(item, size, color)
		&"bolt":
			_bolt(item, size, color, age)
		&"blade":
			_blade(item, size, color)
		&"swirl":
			_swirl(item, size, color, age)
		&"chain":
			_chain(item, size, color, age)
		&"baboon":
			_baboon(item, size, color, age)
		&"coil":
			_coil(item, size, color, age)
		&"rune":
			_rune(item, size, color, age)
		&"pillar":
			_pillar(item, size, color, age)
		&"arrow":
			_arrow(item, size, color)
		&"petal":
			_petals(item, size, color, age)
		&"orb":
			_orb(item, size, color, age)
		&"wall":
			_wall(item, size, color, age)
		&"mine":
			_mine(item, size, color, age)
		_:
			_crescent(item, size, color, 1.0, rim)
	item.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Styles that are terrain or zones, not flying light: no halo.
const NO_HALO: Array[StringName] = [&"pillar", &"wall", &"mine", &"rune"]


## The halo's strength: a normal shot glows faintly in its own colour, a shot with a `glow` brightly in that.
static func halo_alpha(glow: Color) -> float:
	return 0.32 if glow.a > 0.0 else 0.12


static func _draw_halo(item: CanvasItem, style: StringName, size: Vector2, color: Color, glow: Color, age: float) -> void:
	if NO_HALO.has(style):
		return
	var tint := Color(glow.r, glow.g, glow.b, 1.0) if glow.a > 0.0 else color
	var strength := halo_alpha(glow) * (0.85 + 0.15 * sin(age * 14.0))
	var radius := maxf(size.y, size.x * 0.45) * (1.1 if glow.a > 0.0 else 0.85)
	item.draw_circle(Vector2.ZERO, radius * 1.5, _alpha(tint, strength * 0.35))
	item.draw_circle(Vector2.ZERO, radius, _alpha(tint, strength * 0.6))
	item.draw_circle(Vector2.ZERO, radius * 0.55, _alpha(tint.lerp(Color.WHITE, 0.5), strength))


static func _draw_trail(item: CanvasItem, trail: PackedVector2Array, color: Color, size: Vector2) -> void:
	var count := trail.size()
	for i in range(1, count):
		var t := float(i) / float(count)
		item.draw_line(trail[i - 1], trail[i], _alpha(color, 0.5 * t), maxf(size.y * 0.5 * t, 1.0))


static func _crescent(item: CanvasItem, size: Vector2, color: Color, boost: float, rim: Color = Color(0.0, 0.0, 0.0, 0.0)) -> void:
	var body := crescent_points(size.x * boost, size.y * boost)
	if rim.a > 0.0:
		# A dark solid crescent with a glowing edge (the black Getsuga with its red rim).
		var edge := body.duplicate()
		edge.append(body[0])
		item.draw_colored_polygon(_scaled(body, 1.3), _alpha(rim, 0.3))
		item.draw_colored_polygon(body, color)
		item.draw_polyline(edge, rim, 1.8)
		item.draw_colored_polygon(_scaled(body, 0.45), _alpha(rim, 0.55))
		return
	item.draw_colored_polygon(_scaled(body, 1.35), _alpha(color, 0.18))
	item.draw_colored_polygon(body, color)
	item.draw_colored_polygon(_scaled(body, 0.6), Color(1.0, 1.0, 1.0, 0.7))


## A Cero: a thick tapering beam, glowing at the edge, white-hot in the middle.
static func _beam(item: CanvasItem, size: Vector2, color: Color) -> void:
	var w := size.x * 0.5
	var h := size.y * 0.5
	var shape := PackedVector2Array([
		Vector2(-w, 0.0), Vector2(-w * 0.55, -h * 1.3), Vector2(w * 0.7, -h * 1.1), Vector2(w, 0.0),
		Vector2(w * 0.7, h * 1.1), Vector2(-w * 0.55, h * 1.3),
	])
	item.draw_colored_polygon(shape, _alpha(color, 0.3))
	item.draw_colored_polygon(_scaled(shape, 0.75), _alpha(color, 0.75))
	item.draw_colored_polygon(_scaled(shape, 0.4), Color(1.0, 0.95, 0.9, 0.95))


## A bolt of lightning: a jagged line that re-jitters a few times a second (Byakurai).
static func _bolt(item: CanvasItem, size: Vector2, color: Color, age: float) -> void:
	var w := size.x * 0.5
	var h := maxf(size.y, 6.0)
	var tick := int(age * 30.0)
	var points := PackedVector2Array()
	var steps := 8
	for i in steps + 1:
		var x := -w + size.x * float(i) / float(steps)
		var edge := 0.0 if i == 0 or i == steps else 1.0
		points.append(Vector2(x, sin(float(i) * 12.9898 + float(tick) * 3.1) * h * 0.5 * edge))
	item.draw_polyline(points, _alpha(color, 0.3), 5.0)
	item.draw_polyline(points, color, 2.0)
	item.draw_polyline(points, Color(1.0, 1.0, 1.0, 0.95), 0.9)


## A glowing sword blade seen from the side, point first (a Senbonzakura blade).
static func _blade(item: CanvasItem, size: Vector2, color: Color) -> void:
	var w := size.x * 0.5
	var h := size.y * 0.5
	var shape := PackedVector2Array([Vector2(-w, 0.0), Vector2(-w * 0.55, -h), Vector2(w, 0.0), Vector2(-w * 0.55, h)])
	item.draw_colored_polygon(_scaled(shape, 1.35), _alpha(color, 0.22))
	item.draw_colored_polygon(shape, _alpha(color, 0.85))
	item.draw_colored_polygon(_scaled(shape, 0.5), Color(1.0, 1.0, 1.0, 0.95))
	item.draw_line(Vector2(-w, 0.0), Vector2(w, 0.0), Color(1.0, 1.0, 1.0, 0.8), 0.8)


## Blades swirling around a spot and closing in again and again (Gōkei).
static func _swirl(item: CanvasItem, size: Vector2, color: Color, age: float) -> void:
	var radius := maxf(size.x, size.y) * 0.5
	var squeeze := fposmod(age, 0.9) / 0.9
	var ring := radius * (1.0 - 0.75 * squeeze)
	item.draw_arc(Vector2.ZERO, ring, 0.0, TAU, 28, _alpha(color, 0.35 + 0.4 * squeeze), 1.0)
	for i in 8:
		var turn := age * 7.0 + float(i) * TAU / 8.0
		var center := Vector2(cos(turn), sin(turn)) * ring
		var tip := center + Vector2(-sin(turn), cos(turn)) * 5.0
		var tail := center - Vector2(-sin(turn), cos(turn)) * 5.0
		item.draw_line(tail, tip, _alpha(color, 0.9), 2.0)
		item.draw_line(tail, tip, Color(1.0, 1.0, 1.0, 0.8), 0.8)
	if squeeze > 0.8:
		item.draw_circle(Vector2.ZERO, radius * 0.25 * (squeeze - 0.8) * 5.0, _alpha(Color.WHITE, 0.5))


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


## A standing wall of petals: a translucent column with petals drifting up through it.
static func _wall(item: CanvasItem, size: Vector2, color: Color, age: float) -> void:
	item.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var half := size * 0.5
	item.draw_rect(Rect2(-half, size), _alpha(color, 0.12))
	item.draw_line(Vector2(-half.x, -half.y), Vector2(-half.x, half.y), _alpha(color, 0.5), 1.0)
	item.draw_line(Vector2(half.x, -half.y), Vector2(half.x, half.y), _alpha(color, 0.5), 1.0)
	for i in 14:
		var t := fposmod(age * 0.7 + float(i) * 0.37, 1.0)
		var x := sin(float(i) * 2.4 + age * 3.0) * half.x
		var y := half.y - t * size.y
		var petal := PackedVector2Array()
		for step in 6:
			var a := float(step) * TAU / 6.0
			petal.append(Vector2(x, y) + Vector2(cos(a) * 3.0, sin(a) * 1.3).rotated(age * 4.0 + float(i)))
		item.draw_colored_polygon(petal, _alpha(color, 0.85))


## Zabimaru's extended blade: a row of bone segments joined by a glowing cord, ending in a spike.
## The segments pull slightly apart toward the tip, as if the blade were being stretched.
static func _chain(item: CanvasItem, size: Vector2, color: Color, age: float) -> void:
	var half := size.x * 0.5
	var count := clampi(int(size.x / 9.0), 3, 14)
	item.draw_line(Vector2(-half, 0.0), Vector2(half, 0.0), _alpha(color, 0.3), size.y * 0.9)
	item.draw_line(Vector2(-half, 0.0), Vector2(half, 0.0), color, 1.2)
	for i in count:
		var f := float(i) / float(count)
		var centre := Vector2(lerpf(-half, half - 8.0, f) + 4.0, sin(age * 30.0 + float(i) * 1.7) * 0.6)
		var reach := 4.0 + 3.0 * f
		var seg := PackedVector2Array([
			centre + Vector2(-reach, 0.0), centre + Vector2(0.0, -size.y * 0.45),
			centre + Vector2(reach, 0.0), centre + Vector2(0.0, size.y * 0.45),
		])
		item.draw_colored_polygon(seg, Color(0.95, 0.92, 0.85, 0.95))
		item.draw_polyline(PackedVector2Array([seg[0], seg[1], seg[2], seg[3], seg[0]]), color, 1.0)
	var tip := PackedVector2Array([Vector2(half - 7.0, -size.y * 0.5), Vector2(half + 4.0, 0.0), Vector2(half - 7.0, size.y * 0.5)])
	item.draw_colored_polygon(tip, Color(1.0, 1.0, 1.0, 0.95))
	item.draw_polyline(PackedVector2Array([tip[0], tip[1], tip[2]]), color, 1.2)


## The Hikotsu Taiho: a red blast with the baboon's skull at its head, jaws open.
static func _baboon(item: CanvasItem, size: Vector2, color: Color, age: float) -> void:
	var w := size.x * 0.5
	var h := size.y * 0.5
	var shape := PackedVector2Array([
		Vector2(-w, 0.0), Vector2(-w * 0.5, -h * 1.1), Vector2(w * 0.55, -h * 0.9), Vector2(w * 0.55, h * 0.9), Vector2(-w * 0.5, h * 1.1),
	])
	item.draw_colored_polygon(_scaled(shape, 1.25), _alpha(color, 0.22))
	item.draw_colored_polygon(shape, _alpha(color, 0.8))
	item.draw_colored_polygon(_scaled(shape, 0.45), Color(1.0, 0.95, 0.85, 0.95))
	var head := Vector2(w * 0.55, 0.0)
	var jaw := 0.5 + 0.5 * sin(age * 18.0)
	var r := h * 1.0
	item.draw_circle(head, r, Color(0.93, 0.9, 0.82))
	item.draw_circle(head, r, _alpha(color, 0.0))
	item.draw_arc(head, r, 0.0, TAU, 18, color, 1.2)
	var snout := PackedVector2Array([head + Vector2(r * 0.3, -r * 0.35), head + Vector2(r * 1.5, -r * (0.1 + 0.35 * jaw)), head + Vector2(r * 1.5, r * (0.1 + 0.35 * jaw)), head + Vector2(r * 0.3, r * 0.35)])
	item.draw_colored_polygon(snout, Color(0.93, 0.9, 0.82))
	for fang in 3:
		var fx := head.x + r * (0.7 + 0.3 * float(fang))
		item.draw_colored_polygon(PackedVector2Array([Vector2(fx, head.y - r * 0.15 * (1.0 + jaw)), Vector2(fx + 1.2, head.y - r * (0.15 + 0.2 * jaw)), Vector2(fx + 2.4, head.y - r * 0.15 * (1.0 + jaw))]), color)
	item.draw_circle(head + Vector2(r * 0.15, -r * 0.3), maxf(r * 0.16, 1.0), Color(0.6, 0.05, 0.05))


## A trap of coiled bone segments lying on the ground: a spiral that slowly turns until touched.
static func _coil(item: CanvasItem, size: Vector2, color: Color, age: float) -> void:
	item.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	var radius := maxf(size.x, size.y) * 0.5
	var pulse := 0.5 + 0.5 * sin(age * 6.0)
	item.draw_circle(Vector2.ZERO, radius * (1.0 + 0.2 * pulse), _alpha(color, 0.1 + 0.1 * pulse))
	for i in 16:
		var f := float(i) / 15.0
		var a := age * 1.4 + f * TAU * 1.7
		var at := Vector2(cos(a), sin(a)) * radius * (1.0 - 0.7 * f)
		item.draw_colored_polygon(PackedVector2Array([at + Vector2(-2.6, 0.0), at + Vector2(0.0, -2.4), at + Vector2(2.6, 0.0), at + Vector2(0.0, 2.4)]), Color(0.95, 0.92, 0.85, 0.95))
		item.draw_circle(at, 0.9, _alpha(color, 0.95))
	item.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, _alpha(color, 0.8), 1.2)


## Tsukishiro: a flat circle of white-blue light on the ground with a turning six-armed snowflake,
## pulsing faster the longer it waits, until an enemy steps in and a pillar of ice rises.
static func _rune(item: CanvasItem, size: Vector2, color: Color, age: float) -> void:
	item.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	var radius := maxf(size.x, size.y) * 0.5
	var pulse := 0.5 + 0.5 * sin(age * 5.0)
	item.draw_circle(Vector2.ZERO, radius * (1.0 + 0.15 * pulse), _alpha(color, 0.12 + 0.1 * pulse))
	item.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, _alpha(color, 0.9), 1.4)
	item.draw_arc(Vector2.ZERO, radius * 0.72, 0.0, TAU, 24, _alpha(Color.WHITE, 0.6), 1.0)
	for arm in 6:
		var a := age * 0.9 + float(arm) * TAU / 6.0
		var v := Vector2.from_angle(a)
		item.draw_line(v * radius * 0.1, v * radius * 0.7, _alpha(Color.WHITE, 0.9), 1.2)
		item.draw_line(v * radius * 0.45, v * radius * 0.45 + Vector2.from_angle(a + 0.8) * radius * 0.2, _alpha(color, 0.9), 1.0)
		item.draw_line(v * radius * 0.45, v * radius * 0.45 + Vector2.from_angle(a - 0.8) * radius * 0.2, _alpha(color, 0.9), 1.0)


## A column of ice thrusting up out of the ground, jagged at the top, growing for its first tenth of a second.
static func _pillar(item: CanvasItem, size: Vector2, color: Color, age: float) -> void:
	var grow := 1.0 - pow(1.0 - clampf(age / 0.1, 0.0, 1.0), 3.0)
	var w := size.x * 0.5
	var bottom := size.y * 0.5
	var h := size.y * grow
	var top := bottom - h
	var body := PackedVector2Array([
		Vector2(-w, bottom), Vector2(-w * 0.85, top + h * 0.2), Vector2(-w * 0.4, top + h * 0.06), Vector2(0.0, top),
		Vector2(w * 0.35, top + h * 0.08), Vector2(w * 0.85, top + h * 0.22), Vector2(w, bottom),
	])
	item.draw_colored_polygon(_scaled(body, 1.25), _alpha(color, 0.16))
	item.draw_colored_polygon(body, _alpha(color, 0.85))
	item.draw_polyline(PackedVector2Array([body[0], body[1], body[2], body[3], body[4], body[5], body[6]]), Color(1.0, 1.0, 1.0, 0.9), 1.2)
	item.draw_line(Vector2(-w * 0.35, bottom), Vector2(-w * 0.2, top + h * 0.25), Color(1.0, 1.0, 1.0, 0.8), 1.4)
	item.draw_line(Vector2(w * 0.25, bottom), Vector2(w * 0.1, top + h * 0.4), Color(1.0, 1.0, 1.0, 0.45), 1.0)
