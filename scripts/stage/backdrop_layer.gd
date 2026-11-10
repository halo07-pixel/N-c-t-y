class_name BackdropLayer
extends Node2D
## One painted layer of the backdrop, drawn once in code (no image files).
## The StageBackdrop moves it with the camera: depth 0 stays on screen, depth 1 moves with the world.

enum Kind { SKY, STARS, FAR, MID, NEAR }

@export var kind: Kind = Kind.SKY
@export var depth: float = 0.0
@export var seed_value: int = 1

const LEFT := -1300.0
const RIGHT := 1300.0


## Everything a layer paints is gathered as coloured triangles and drawn as ONE mesh, so a layer
## costs a single draw call however many stars, towers or spires it has (the order is kept, so
## translucent shapes still stack the same way).
var _vertices := PackedVector2Array()
var _colors := PackedColorArray()
var _mesh: ArrayMesh # kept: the canvas item only holds the mesh's RID, so freeing it would blank the layer


func _draw() -> void:
	_vertices.clear()
	_colors.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	match kind:
		Kind.SKY:
			_draw_sky()
		Kind.STARS:
			_draw_stars(rng)
			_draw_moon()
		Kind.FAR:
			_draw_far(rng)
		Kind.MID:
			_draw_mid(rng)
		Kind.NEAR:
			_draw_near(rng)
	_flush()


func _flush() -> void:
	if _vertices.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_COLOR] = _colors
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	draw_mesh(_mesh, null)


func _add_triangle(a: Vector2, b: Vector2, c: Vector2, ca: Color, cb: Color, cc: Color) -> void:
	_vertices.append_array(PackedVector2Array([a, b, c]))
	_colors.append_array(PackedColorArray([ca, cb, cc]))


func _fill_rect(rect: Rect2, color: Color) -> void:
	var tl := rect.position
	var br := rect.end
	_add_triangle(tl, Vector2(br.x, tl.y), br, color, color, color)
	_add_triangle(tl, br, Vector2(tl.x, br.y), color, color, color)


func _fill_polygon(points: PackedVector2Array, color: Color) -> void:
	var indices := Geometry2D.triangulate_polygon(points)
	for i in range(0, indices.size(), 3):
		_add_triangle(points[indices[i]], points[indices[i + 1]], points[indices[i + 2]], color, color, color)


func _fill_circle(center: Vector2, radius: float, color: Color) -> void:
	var segments := clampi(int(radius * 2.0) + 6, 8, 40)
	for i in segments:
		var a := Vector2.from_angle(TAU * float(i) / float(segments)) * radius
		var b := Vector2.from_angle(TAU * float(i + 1) / float(segments)) * radius
		_add_triangle(center, center + a, center + b, color, color, color)


func _band(top: float, bottom: float, from: Color, to: Color) -> void:
	var tl := Vector2(LEFT, top)
	var tr := Vector2(RIGHT, top)
	var br := Vector2(RIGHT, bottom)
	var bl := Vector2(LEFT, bottom)
	_add_triangle(tl, tr, br, from, from, to)
	_add_triangle(tl, br, bl, from, to, to)


func _draw_sky() -> void:
	_band(-420.0, -60.0, StagePalette.SKY_TOP, StagePalette.SKY_MID)
	_band(-60.0, 150.0, StagePalette.SKY_MID, StagePalette.SKY_HORIZON)
	_band(150.0, 420.0, StagePalette.SKY_HORIZON, StagePalette.MID)


func _draw_stars(rng: RandomNumberGenerator) -> void:
	for i in 110:
		var at := Vector2(rng.randf_range(LEFT, RIGHT), rng.randf_range(-260.0, 60.0))
		var fade := clampf(1.0 - (at.y + 260.0) / 340.0, 0.15, 1.0)
		var size := rng.randf_range(0.6, 1.3)
		_fill_circle(at, size, Color(1.0, 0.97, 0.92, fade * rng.randf_range(0.5, 1.0)))


func _draw_moon() -> void:
	var at := Vector2(80.0, -100.0)
	for ring in 12:
		_fill_circle(at, 20.0 + ring * 4.0, Color(StagePalette.MOON_GLOW, 0.018))
	_fill_circle(at, 20.0, StagePalette.MOON)
	_fill_circle(at + Vector2(-6.0, -4.0), 4.0, Color(0.85, 0.82, 0.7, 0.5))
	_fill_circle(at + Vector2(7.0, 5.0), 3.0, Color(0.85, 0.82, 0.7, 0.4))
	_fill_circle(at + Vector2(3.0, -9.0), 2.0, Color(0.85, 0.82, 0.7, 0.35))


func _draw_far(rng: RandomNumberGenerator) -> void:
	var points := PackedVector2Array()
	var phase := rng.randf() * TAU
	var x := LEFT
	while x <= RIGHT:
		var wave := sin(x * 0.011 + phase) * 22.0 + sin(x * 0.027 + phase * 2.0) * 11.0
		points.append(Vector2(x, 128.0 - 30.0 - wave + rng.randf_range(-4.0, 4.0)))
		x += 30.0
	points.append(Vector2(RIGHT, 420.0))
	points.append(Vector2(LEFT, 420.0))
	_fill_polygon(points, StagePalette.FAR)
	# A pale haze at the foot of the far hills.
	_band(100.0, 190.0, Color(StagePalette.SKY_HORIZON, 0.0), Color(StagePalette.SKY_HORIZON, 0.55))


func _draw_mid(rng: RandomNumberGenerator) -> void:
	var x := LEFT
	while x < RIGHT:
		var width := rng.randf_range(36.0, 84.0)
		var height := rng.randf_range(55.0, 150.0)
		var top := 170.0 - height
		var body := Rect2(x, top, width, height + 260.0)
		_fill_rect(body, StagePalette.MID)
		match rng.randi() % 3:
			0: # broken, slanted top
				_fill_polygon(
					PackedVector2Array([Vector2(x, top), Vector2(x + width, top), Vector2(x + width * 0.4, top - 14.0)]),
					StagePalette.MID
				)
			1: # a thin spire
				_fill_polygon(
					PackedVector2Array([
						Vector2(x + width * 0.35, top), Vector2(x + width * 0.65, top), Vector2(x + width * 0.5, top - 34.0)
					]),
					StagePalette.MID
				)
			_: # crenellations
				var tooth := width / 5.0
				for i in 3:
					_fill_rect(Rect2(x + tooth * (i * 2.0), top - 6.0, tooth, 6.0), StagePalette.MID)
		_fill_rect(Rect2(x + width - 1.5, top, 1.5, height + 260.0), Color(StagePalette.RIM, 0.22))
		for i in rng.randi_range(0, 2):
			var window := Vector2(x + rng.randf_range(6.0, width - 10.0), top + rng.randf_range(12.0, height - 10.0))
			_fill_rect(Rect2(window, Vector2(2.0, 3.0)), Color(StagePalette.WINDOW, rng.randf_range(0.5, 0.9)))
		x += width + rng.randf_range(6.0, 30.0)


func _draw_near(rng: RandomNumberGenerator) -> void:
	# Dark rock spires rising beside and below the stage.
	var x := LEFT
	while x < RIGHT:
		var width := rng.randf_range(50.0, 110.0)
		var height := rng.randf_range(40.0, 120.0)
		var base := 260.0
		_fill_polygon(
			PackedVector2Array([
				Vector2(x, base), Vector2(x + width * rng.randf_range(0.2, 0.5), base - height),
				Vector2(x + width * rng.randf_range(0.6, 0.9), base - height * 0.7), Vector2(x + width, base),
			]),
			StagePalette.NEAR
		)
		x += width * rng.randf_range(0.6, 1.0)
	_fill_rect(Rect2(LEFT, 150.0, RIGHT - LEFT, 300.0), StagePalette.NEAR)
