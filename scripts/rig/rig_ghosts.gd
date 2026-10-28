class_name RigGhosts
extends Node2D
## Afterimages: faint copies of the body's lines left behind during fast motion. Each ghost
## is a list of line segments in world coordinates that fades out. Drawn with additive
## blending. Visual only.

const LIFETIME := 0.22
const MAX_GHOSTS := 7
const START_ALPHA := 0.42

var color: Color = Color(1.0, 1.0, 1.0)
var _ghosts: Array = [] # each: {"segments": Array, "age": float}


func _init() -> void:
	top_level = true
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	z_index = -1


## Leaves a ghost made of `segments` ([from, to, width] in world coordinates).
func add_ghost(segments: Array) -> void:
	_ghosts.append({"segments": segments, "age": 0.0})
	if _ghosts.size() > MAX_GHOSTS:
		_ghosts.pop_front()


func count() -> int:
	return _ghosts.size()


func clear() -> void:
	_ghosts.clear()
	queue_redraw()


func _process(delta: float) -> void:
	if _ghosts.is_empty():
		return
	for ghost: Dictionary in _ghosts:
		ghost["age"] += delta
	while not _ghosts.is_empty() and _ghosts[0]["age"] > LIFETIME:
		_ghosts.pop_front()
	queue_redraw()


func _draw() -> void:
	for ghost: Dictionary in _ghosts:
		var fade := 1.0 - clampf(float(ghost["age"]) / LIFETIME, 0.0, 1.0)
		var tint := Color(color.r, color.g, color.b, START_ALPHA * fade * fade)
		for segment: Array in ghost["segments"]:
			draw_line(segment[0], segment[1], tint, segment[2])
