class_name RigTrail
extends Node2D
## The streak a swinging weapon leaves: the area swept between the blade tip and a point
## partway down the blade over the last moments, fading out. Drawn in world coordinates
## with additive blending so it glows. Visual only.

const LIFETIME := 0.16
const MAX_SAMPLES := 14
const BASE_FRACTION := 0.35

var color: Color = Color(1.0, 1.0, 1.0)
var _samples: Array = [] # each: {"tip": Vector2, "base": Vector2, "age": float}


func _init() -> void:
	top_level = true
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	z_index = 5


## Records where the blade is right now (world positions of the tip and of the hilt end).
func add_sample(tip: Vector2, hilt: Vector2) -> void:
	_samples.append({"tip": tip, "base": hilt.lerp(tip, BASE_FRACTION), "age": 0.0})
	if _samples.size() > MAX_SAMPLES:
		_samples.pop_front()


func clear() -> void:
	_samples.clear()
	queue_redraw()


func is_empty() -> bool:
	return _samples.is_empty()


func _process(delta: float) -> void:
	if _samples.is_empty():
		return
	for sample: Dictionary in _samples:
		sample["age"] += delta
	while not _samples.is_empty() and _samples[0]["age"] > LIFETIME:
		_samples.pop_front()
	queue_redraw()


func _draw() -> void:
	for index in range(1, _samples.size()):
		var older: Dictionary = _samples[index - 1]
		var newer: Dictionary = _samples[index]
		var fade := 1.0 - clampf(float(newer["age"]) / LIFETIME, 0.0, 1.0)
		var tint := Color(color.r, color.g, color.b, 0.75 * fade)
		# Two triangles, not one quad: a swinging blade can cross over itself, which a
		# single polygon cannot draw. Skip triangles with no area (the blade did not move).
		_triangle(older["base"], older["tip"], newer["tip"], tint)
		_triangle(older["base"], newer["tip"], newer["base"], tint)
		draw_line(older["tip"], newer["tip"], Color(1.0, 1.0, 1.0, fade), 1.2)


func _triangle(a: Vector2, b: Vector2, c: Vector2, tint: Color) -> void:
	if absf((b - a).cross(c - a)) > 0.1:
		draw_colored_polygon(PackedVector2Array([a, b, c]), tint)
