extends Node2D
## Simple pixel-style night sky with a moon and a distant skyline.
## Drawn in code so the test stage needs no image files.

const SKY_TOP := Color(0.05, 0.05, 0.14)
const SKY_BOTTOM := Color(0.42, 0.25, 0.42)
const MOON_COLOR := Color(0.95, 0.93, 0.8)
const SKYLINE_COLOR := Color(0.09, 0.07, 0.15)
const SKYLINE_HEIGHTS: Array[float] = [
	30.0, 52.0, 38.0, 70.0, 44.0, 60.0, 34.0, 56.0, 42.0, 66.0, 36.0, 50.0, 40.0, 58.0,
]
const BAND_COUNT := 15
const BAND_HEIGHT := 40.0
const SKY_LEFT := -700.0
const SKY_WIDTH := 1400.0
const SKY_TOP_Y := -420.0
const SKYLINE_BASE_Y := 120.0
const SKYLINE_BLOCK_WIDTH := 100.0


func _draw() -> void:
	for band in BAND_COUNT:
		var blend := float(band) / float(BAND_COUNT - 1)
		var rect := Rect2(SKY_LEFT, SKY_TOP_Y + band * BAND_HEIGHT, SKY_WIDTH, BAND_HEIGHT + 1.0)
		draw_rect(rect, SKY_TOP.lerp(SKY_BOTTOM, blend))
	draw_circle(Vector2(150.0, -110.0), 36.0, MOON_COLOR)

	var block_x := SKY_LEFT
	for height in SKYLINE_HEIGHTS:
		draw_rect(
			Rect2(block_x, SKYLINE_BASE_Y - height, SKYLINE_BLOCK_WIDTH, height + 200.0),
			SKYLINE_COLOR
		)
		block_x += SKYLINE_BLOCK_WIDTH
