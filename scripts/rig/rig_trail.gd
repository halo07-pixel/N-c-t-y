class_name RigTrail
extends Node2D
## The streak a swinging weapon leaves: the area swept between the blade tip and a point
## partway down the blade over the last moments, fading out. Drawn in world coordinates
## with additive blending so it glows. Visual only.

const MAX_SAMPLES := 20
## Per style: how long a sample lives, where on the blade the streak starts (0 hilt, 1 tip),
## whether it is filled, and how wide the glow and core are.
const STYLES := {
	&"slash": {"life": 0.16, "base": 0.35, "fill": 0.6, "glow": 3.0, "core": 1.2, "ribbons": false},
	&"lines": {"life": 0.24, "base": 0.35, "fill": 0.0, "glow": 1.6, "core": 0.9, "ribbons": true},
	&"wide": {"life": 0.26, "base": 0.05, "fill": 0.5, "glow": 4.5, "core": 1.6, "ribbons": false},
	&"whip": {"life": 0.3, "base": 0.0, "fill": 0.35, "glow": 2.5, "core": 1.0, "ribbons": false},
	&"thin": {"life": 0.2, "base": 0.65, "fill": 0.4, "glow": 2.0, "core": 0.9, "ribbons": false},
}

var color: Color = Color(1.0, 1.0, 1.0)
var style: StringName = &"slash"
var _spec: Dictionary = STYLES[&"slash"]
var _samples: Array = [] # each: {"tip": Vector2, "base": Vector2, "age": float}


func _init() -> void:
	top_level = true
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	z_index = 5


func set_style(value: StringName) -> void:
	style = value if STYLES.has(value) else &"slash"
	_spec = STYLES[style]


func lifetime() -> float:
	return _spec["life"]


## Records where the blade is right now (world positions of the tip and of the hilt end).
func add_sample(tip: Vector2, hilt: Vector2) -> void:
	_samples.append({"tip": tip, "base": hilt.lerp(tip, float(_spec["base"])), "age": 0.0})
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
	while not _samples.is_empty() and _samples[0]["age"] > lifetime():
		_samples.pop_front()
	queue_redraw()


func _draw() -> void:
	for index in range(1, _samples.size()):
		var older: Dictionary = _samples[index - 1]
		var newer: Dictionary = _samples[index]
		var fade := 1.0 - clampf(float(newer["age"]) / lifetime(), 0.0, 1.0)
		var core := Color(1.0, 1.0, 1.0, fade)
		var strength := clampf(GameSettings.effect_amount(), 0.4, 1.4)
		var tint := Color(color.r, color.g, color.b, float(_spec["fill"]) * fade * strength)
		# Two triangles, not one quad: a swinging blade can cross over itself, which a
		# single polygon cannot draw. Skip triangles with no area (the blade did not move).
		if float(_spec["fill"]) > 0.0:
			_triangle(older["base"], older["tip"], newer["tip"], tint)
			_triangle(older["base"], newer["tip"], newer["base"], tint)
		if _spec["ribbons"]:
			# Three thin ribbons along the blade instead of a filled sweep.
			for along in [0.5, 0.75, 1.0]:
				var from: Vector2 = (older["base"] as Vector2).lerp(older["tip"], along)
				var to: Vector2 = (newer["base"] as Vector2).lerp(newer["tip"], along)
				draw_line(from, to, Color(color.r, color.g, color.b, 0.7 * fade * strength), float(_spec["core"]) * (0.6 + along * 0.5))
			continue
		# A soft outer edge beyond the tip, a bright core line along it and a short tail streak.
		var out_a: Vector2 = older["tip"] + (older["tip"] - older["base"]).normalized() * 2.5
		var out_b: Vector2 = newer["tip"] + (newer["tip"] - newer["base"]).normalized() * 2.5
		draw_line(out_a, out_b, Color(color.r, color.g, color.b, 0.3 * fade * strength), float(_spec["glow"]))
		draw_line(older["tip"], newer["tip"], core.lerp(Color(color.r, color.g, color.b, 1.0), 0.0 if style == &"slash" or style == &"thin" else 0.6), float(_spec["core"]) + 0.6 * strength)


func _triangle(a: Vector2, b: Vector2, c: Vector2, tint: Color) -> void:
	if absf((b - a).cross(c - a)) > 0.1:
		draw_colored_polygon(PackedVector2Array([a, b, c]), tint)
