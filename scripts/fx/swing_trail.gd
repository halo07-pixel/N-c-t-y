class_name SwingTrail
extends Node2D
## The streak a melee swing leaves while its hitbox is out. Each character's profile picks the
## look (slash, shards, petals, lash, frost, quake, ink); it only follows the hitbox, so it
## never changes what hits. Additive; frees itself.

const LIFETIME := 0.16
const ARC_STEPS := 10

var color: Color = Color.WHITE
var accent: Color = Color(1.0, 1.0, 1.0)
var style: StringName = &"slash"
## The hitbox's size and which way the fighter faces; the streak is drawn inside and just past it.
var box: Vector2 = Vector2(30.0, 16.0)
var facing: int = 1
var amount: float = 1.0
var _age: float = 0.0


func _init() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	z_index = 18


## Points of the swing arc in local space (origin at the hitbox centre), `t` 0..1 along its life:
## it sweeps from behind-and-above to ahead-and-below the box, a little further for a lash.
static func arc_points(size: Vector2, facing: int, t: float, stretch: float = 1.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	var radius_x := size.x * 0.6 * stretch
	var radius_y := maxf(size.y * 1.1, 12.0)
	var sweep := clampf(t, 0.05, 1.0)
	for i in ARC_STEPS + 1:
		var u := float(i) / float(ARC_STEPS)
		var angle := lerpf(-1.2, 1.2, u * sweep)
		points.append(Vector2(sin(angle) * radius_x * float(facing), -cos(angle) * radius_y + radius_y * 0.9))
	return points


## How far a style's streak reaches past the hitbox (a lash trails long, a shard is a straight line).
static func stretch_for(trail_style: StringName) -> float:
	match trail_style:
		&"lash":
			return 1.6
		&"shards":
			return 1.3
		&"quake":
			return 0.9
		_:
			return 1.0


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := clampf(_age / LIFETIME, 0.0, 1.0)
	var fade := 1.0 - t
	var points := arc_points(box, facing, minf(t * 2.5, 1.0), stretch_for(style))
	var width := maxf(box.y * 0.35, 3.0) * amount
	match style:
		&"shards":
			var start := Vector2(-box.x * 0.3 * float(facing), 0.0)
			var finish := Vector2(box.x * 0.9 * float(facing), 0.0)
			draw_line(start, finish, Color(accent.r, accent.g, accent.b, 0.9 * fade), 1.5 * amount)
			draw_line(start, finish, Color(color.r, color.g, color.b, 0.35 * fade), 4.0 * amount)
		&"petals":
			for i in range(0, points.size(), 2):
				var p := points[i]
				draw_circle(p, (2.4 - float(i) * 0.12) * amount, Color(color.r, color.g, color.b, 0.8 * fade))
			draw_polyline(points, Color(accent.r, accent.g, accent.b, 0.35 * fade), 1.2 * amount)
		&"frost":
			draw_polyline(points, Color(color.r, color.g, color.b, 0.7 * fade), width * 0.6)
			for i in range(2, points.size(), 3):
				var p := points[i]
				draw_line(p + Vector2(-2.0, -2.0), p + Vector2(2.0, 2.0), Color(1.0, 1.0, 1.0, 0.9 * fade), 1.2 * amount)
				draw_line(p + Vector2(2.0, -2.0), p + Vector2(-2.0, 2.0), Color(1.0, 1.0, 1.0, 0.9 * fade), 1.2 * amount)
		&"quake":
			draw_polyline(points, Color(color.r, color.g, color.b, 0.8 * fade), width * 1.5)
			draw_polyline(points, Color(accent.r, accent.g, accent.b, 0.7 * fade), width * 0.5)
		&"lash":
			draw_polyline(points, Color(color.r, color.g, color.b, 0.7 * fade), width * 0.5)
			draw_circle(points[points.size() - 1], 2.6 * amount, Color(accent.r, accent.g, accent.b, 0.9 * fade))
		&"ink":
			draw_polyline(points, Color(color.r, color.g, color.b, 0.75 * fade), width * 0.9)
		_: # slash: a bright crescent with a hot core
			draw_polyline(points, Color(color.r, color.g, color.b, 0.7 * fade), width)
			draw_polyline(points, Color(accent.r, accent.g, accent.b, 0.9 * fade), width * 0.35)
