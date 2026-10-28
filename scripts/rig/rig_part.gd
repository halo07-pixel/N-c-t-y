class_name RigPart
extends Node2D
## One bone of the skeleton. In the box style it is a rounded rectangle that hangs from (or,
## for the torso, rises from) its pivot, with an outline, a darker back and a light edge.
## In the stick style it is a tapered line with round ends. Rotating the node swings the
## part around its joint.

const OUTLINE_WIDTH := 0.9
const CORNER_STEPS := 3
## Stick limbs have no outline (overlapping outlines leave seams at the joints); the head keeps a thin one.
const STICK_OUTLINE := 0.0
const HEAD_OUTLINE := 0.7
const STICK_TAPER := 0.78

var size: Vector2 = Vector2(3.0, 5.0)
## Rises from the pivot instead of hanging down.
var up: bool = false
var color: Color = Color.WHITE
var outline: Color = Color(0.06, 0.05, 0.09)
var radius: float = 1.2
## Overrides where the rectangle starts, relative to the pivot (used by the foot).
var origin: Variant = null
## A band of another color across the part (belt, cuff); alpha 0 means none.
var band: Color = Color(0.0, 0.0, 0.0, 0.0)
var band_at: float = 0.5 # 0 at the pivot end, 1 at the far end
var band_height: float = 1.6
## Stick style: draw a line of this width (size.y is its length) instead of a box.
var stick_width: float = 0.0


func _init() -> void:
	use_parent_material = true # the hit flash is set on one ancestor


## Rounded rectangle outline as polygon points.
static func rounded(rect: Rect2, corner: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var r := minf(corner, minf(rect.size.x, rect.size.y) * 0.5)
	var corners := [
		[rect.position + Vector2(r, r), PI],
		[Vector2(rect.end.x - r, rect.position.y + r), PI * 1.5],
		[rect.end - Vector2(r, r), 0.0],
		[Vector2(rect.position.x + r, rect.end.y - r), PI * 0.5],
	]
	for entry in corners:
		for step in CORNER_STEPS + 1:
			var angle: float = entry[1] + (PI * 0.5) * float(step) / float(CORNER_STEPS)
			points.append(entry[0] + Vector2.from_angle(angle) * r)
	return points


func rect() -> Rect2:
	if origin != null:
		return Rect2(origin, size)
	return Rect2(Vector2(-size.x * 0.5, -size.y if up else 0.0), size)


func is_stick() -> bool:
	return stick_width > 0.0


## The bone as a line in world coordinates: where it starts, where it ends and how wide it is.
## Used for the afterimages.
func segment() -> Array:
	if origin != null:
		var foot_start: Vector2 = origin
		return [to_global(foot_start + Vector2(0.0, size.y * 0.5)), to_global(foot_start + Vector2(size.x, size.y * 0.5)), maxf(stick_width, 1.0)]
	var end := Vector2(0.0, -size.y if up else size.y)
	return [to_global(Vector2.ZERO), to_global(end), maxf(stick_width, 1.5)]


func _draw() -> void:
	if is_stick():
		_draw_stick()
		return
	var box := rect()
	draw_colored_polygon(rounded(box.grow(OUTLINE_WIDTH), radius + OUTLINE_WIDTH), outline)
	draw_colored_polygon(rounded(box, radius), color)
	# Darker back, lighter front edge: the light comes from the front.
	var back := Rect2(box.position, Vector2(box.size.x * 0.4, box.size.y))
	draw_colored_polygon(rounded(back, radius), color.darkened(0.22))
	var edge := Rect2(Vector2(box.end.x - box.size.x * 0.22, box.position.y + radius), Vector2(box.size.x * 0.12, box.size.y - radius * 2.0))
	if edge.size.y > 0.0:
		draw_rect(edge, color.lightened(0.18))
	if band.a > 0.0:
		var y := box.position.y + (box.size.y - band_height) * (band_at if not up else 1.0 - band_at)
		draw_rect(Rect2(box.position.x, y, box.size.x, band_height), band)


func _draw_stick() -> void:
	var from := Vector2.ZERO
	var to := Vector2(0.0, -size.y if up else size.y)
	var start_width := stick_width
	var end_width := stick_width * STICK_TAPER
	if origin != null: # the foot: a short stub pointing forward
		from = Vector2(origin.x, origin.y + size.y * 0.5)
		to = Vector2(origin.x + size.x, from.y)
		end_width = stick_width * 0.8
	_capsule(from, to, start_width, end_width, color)


func _capsule(from: Vector2, to: Vector2, from_width: float, to_width: float, tint: Color) -> void:
	var direction := (to - from).normalized()
	var normal := Vector2(-direction.y, direction.x)
	var quad := PackedVector2Array([
		from + normal * from_width * 0.5, from - normal * from_width * 0.5,
		to - normal * to_width * 0.5, to + normal * to_width * 0.5,
	])
	draw_colored_polygon(quad, tint)
	draw_circle(from, from_width * 0.5, tint)
	draw_circle(to, to_width * 0.5, tint)
