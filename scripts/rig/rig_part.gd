class_name RigPart
extends Node2D
## One box of the skeleton: a rounded rectangle that hangs from (or, for the torso and
## head, rises from) its pivot, drawn with an outline, a darker back and a light edge.
## Rotating the node swings the part around its joint.

const OUTLINE_WIDTH := 0.9
const CORNER_STEPS := 3

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


func _draw() -> void:
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
