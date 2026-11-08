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


func _draw() -> void:
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


func _band(top: float, bottom: float, from: Color, to: Color) -> void:
	draw_polygon(
		PackedVector2Array([Vector2(LEFT, top), Vector2(RIGHT, top), Vector2(RIGHT, bottom), Vector2(LEFT, bottom)]),
		PackedColorArray([from, from, to, to])
	)


func _draw_sky() -> void:
	_band(-420.0, -60.0, StagePalette.SKY_TOP, StagePalette.SKY_MID)
	_band(-60.0, 150.0, StagePalette.SKY_MID, StagePalette.SKY_HORIZON)
	_band(150.0, 420.0, StagePalette.SKY_HORIZON, StagePalette.MID)


func _draw_stars(rng: RandomNumberGenerator) -> void:
	for i in 110:
		var at := Vector2(rng.randf_range(LEFT, RIGHT), rng.randf_range(-260.0, 60.0))
		var fade := clampf(1.0 - (at.y + 260.0) / 340.0, 0.15, 1.0)
		var size := rng.randf_range(0.6, 1.3)
		draw_circle(at, size, Color(1.0, 0.97, 0.92, fade * rng.randf_range(0.5, 1.0)))


func _draw_moon() -> void:
	var at := Vector2(80.0, -100.0)
	for ring in 12:
		draw_circle(at, 20.0 + ring * 4.0, Color(StagePalette.MOON_GLOW, 0.018))
	draw_circle(at, 20.0, StagePalette.MOON)
	draw_circle(at + Vector2(-6.0, -4.0), 4.0, Color(0.85, 0.82, 0.7, 0.5))
	draw_circle(at + Vector2(7.0, 5.0), 3.0, Color(0.85, 0.82, 0.7, 0.4))
	draw_circle(at + Vector2(3.0, -9.0), 2.0, Color(0.85, 0.82, 0.7, 0.35))


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
	draw_colored_polygon(points, StagePalette.FAR)
	# A pale haze at the foot of the far hills.
	_band(100.0, 190.0, Color(StagePalette.SKY_HORIZON, 0.0), Color(StagePalette.SKY_HORIZON, 0.55))


func _draw_mid(rng: RandomNumberGenerator) -> void:
	var x := LEFT
	while x < RIGHT:
		var width := rng.randf_range(36.0, 84.0)
		var height := rng.randf_range(55.0, 150.0)
		var top := 170.0 - height
		var body := Rect2(x, top, width, height + 260.0)
		draw_rect(body, StagePalette.MID)
		match rng.randi() % 3:
			0: # broken, slanted top
				draw_colored_polygon(
					PackedVector2Array([Vector2(x, top), Vector2(x + width, top), Vector2(x + width * 0.4, top - 14.0)]),
					StagePalette.MID
				)
			1: # a thin spire
				draw_colored_polygon(
					PackedVector2Array([
						Vector2(x + width * 0.35, top), Vector2(x + width * 0.65, top), Vector2(x + width * 0.5, top - 34.0)
					]),
					StagePalette.MID
				)
			_: # crenellations
				var tooth := width / 5.0
				for i in 3:
					draw_rect(Rect2(x + tooth * (i * 2.0), top - 6.0, tooth, 6.0), StagePalette.MID)
		draw_rect(Rect2(x + width - 1.5, top, 1.5, height + 260.0), Color(StagePalette.RIM, 0.22))
		for i in rng.randi_range(0, 2):
			var window := Vector2(x + rng.randf_range(6.0, width - 10.0), top + rng.randf_range(12.0, height - 10.0))
			draw_rect(Rect2(window, Vector2(2.0, 3.0)), Color(StagePalette.WINDOW, rng.randf_range(0.5, 0.9)))
		x += width + rng.randf_range(6.0, 30.0)


func _draw_near(rng: RandomNumberGenerator) -> void:
	# Dark rock spires rising beside and below the stage.
	var x := LEFT
	while x < RIGHT:
		var width := rng.randf_range(50.0, 110.0)
		var height := rng.randf_range(40.0, 120.0)
		var base := 260.0
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(x, base), Vector2(x + width * rng.randf_range(0.2, 0.5), base - height),
				Vector2(x + width * rng.randf_range(0.6, 0.9), base - height * 0.7), Vector2(x + width, base),
			]),
			StagePalette.NEAR
		)
		x += width * rng.randf_range(0.6, 1.0)
	draw_rect(Rect2(LEFT, 150.0, RIGHT - LEFT, 300.0), StagePalette.NEAR)
