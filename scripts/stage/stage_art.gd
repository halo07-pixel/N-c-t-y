class_name StageArt
extends Node2D
## The look of the platforms: stone with brick courses, a lit top edge, a ragged underside
## and a soft shadow. Pure drawing, the collision shapes live on the StaticBody2D nodes.

const MAIN := Rect2(-160.0, 60.0, 320.0, 28.0)
const SOFT := [Rect2(-125.0, 18.0, 70.0, 6.0), Rect2(55.0, 18.0, 70.0, 6.0), Rect2(-30.0, -24.0, 60.0, 6.0)]


func _draw() -> void:
	_draw_shadow(MAIN, 14.0)
	_draw_main()
	for slab: Rect2 in SOFT:
		_draw_shadow(slab, 5.0)
		_draw_soft(slab)


func _draw_shadow(rect: Rect2, spread: float) -> void:
	for ring in 5:
		var grow := spread * (ring + 1) / 5.0
		draw_rect(
			Rect2(rect.position + Vector2(-grow * 0.4, rect.size.y), Vector2(rect.size.x + grow * 0.8, grow)),
			Color(0.0, 0.0, 0.0, 0.07)
		)


func _draw_main() -> void:
	var r := MAIN
	draw_polygon(
		PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0.0), r.end, r.position + Vector2(0.0, r.size.y)]),
		PackedColorArray([StagePalette.STONE, StagePalette.STONE, StagePalette.STONE_DARK, StagePalette.STONE_DARK])
	)
	# Brick courses: horizontal joints and staggered vertical ones.
	var joint := Color(StagePalette.STONE_DARK, 0.7)
	for row in 3:
		var y := r.position.y + 7.0 + row * 7.0
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), joint, 1.0)
		var offset := 0.0 if row % 2 == 0 else 10.0
		var x := r.position.x + offset
		while x < r.end.x:
			draw_line(Vector2(x, y - 7.0), Vector2(x, y), joint, 1.0)
			x += 20.0
	# Ragged underside hanging below the stone.
	var teeth := PackedVector2Array([Vector2(r.position.x, r.end.y)])
	var x2 := r.position.x
	var step := 16.0
	var index := 0
	while x2 < r.end.x:
		teeth.append(Vector2(x2 + step * 0.5, r.end.y + (7.0 if index % 3 == 0 else 3.0 + (index % 2) * 2.0)))
		teeth.append(Vector2(x2 + step, r.end.y))
		x2 += step
		index += 1
	draw_colored_polygon(teeth, StagePalette.STONE_DARK)
	# Lit top edge and a soft glow along it.
	draw_rect(Rect2(r.position.x, r.position.y - 1.0, r.size.x, 3.0), StagePalette.STONE_LIGHT)
	draw_rect(Rect2(r.position.x, r.position.y - 1.0, r.size.x, 1.0), Color(StagePalette.RIM, 0.9))
	draw_rect(Rect2(r.position.x, r.position.y - 4.0, r.size.x, 3.0), Color(StagePalette.RIM, 0.08))
	draw_rect(Rect2(r.position.x, r.position.y, 2.0, r.size.y), Color(StagePalette.RIM, 0.25))


func _draw_soft(slab: Rect2) -> void:
	draw_rect(slab, StagePalette.STONE)
	draw_rect(Rect2(slab.position.x, slab.position.y + slab.size.y - 2.0, slab.size.x, 2.0), StagePalette.STONE_DARK)
	draw_rect(Rect2(slab.position.x, slab.position.y, slab.size.x, 1.5), StagePalette.RIM)
	draw_rect(Rect2(slab.position.x, slab.position.y - 2.0, slab.size.x, 2.0), Color(StagePalette.RIM, 0.10))
	for i in 3:
		var at := Vector2(slab.position.x + slab.size.x * (0.25 + 0.25 * i), slab.position.y + 3.0)
		draw_circle(at, 0.8, Color(StagePalette.RIM, 0.8))
