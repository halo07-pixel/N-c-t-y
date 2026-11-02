class_name PortraitArt
extends RefCounted
## Small portraits and stock icons drawn in code from a character's colours (no artwork).

const OUTLINE := Color(0.05, 0.03, 0.08)


static func draw_portrait(canvas: CanvasItem, center: Vector2, radius: float, character: CharacterData, ring: Color) -> void:
	canvas.draw_circle(center, radius + 1.5, ring)
	canvas.draw_circle(center, radius, Color(0.10, 0.07, 0.16))
	draw_head(canvas, center + Vector2(0.0, radius * 0.12), radius * 0.62, character)


static func draw_head(canvas: CanvasItem, center: Vector2, radius: float, character: CharacterData) -> void:
	canvas.draw_circle(center, radius + 0.8, OUTLINE)
	canvas.draw_circle(center, radius, character.body_color)
	var cap := PackedVector2Array()
	for step in 9:
		var angle := PI + PI * float(step) / 8.0
		cap.append(center + Vector2(cos(angle), sin(angle) * 0.9) * radius)
	canvas.draw_colored_polygon(cap, character.accent_color)
	var eye := maxf(1.0, radius * 0.18)
	canvas.draw_rect(Rect2(center + Vector2(-radius * 0.45, radius * 0.15), Vector2(radius * 0.25, eye)), OUTLINE)
	canvas.draw_rect(Rect2(center + Vector2(radius * 0.2, radius * 0.15), Vector2(radius * 0.25, eye)), OUTLINE)


static func draw_stock_icon(canvas: CanvasItem, center: Vector2, radius: float, character: CharacterData, ring: Color) -> void:
	canvas.draw_circle(center, radius + 1.0, OUTLINE)
	canvas.draw_circle(center, radius, character.body_color)
	canvas.draw_arc(center, radius, PI, TAU, 8, character.accent_color, 1.6)
	canvas.draw_rect(Rect2(center + Vector2(-radius, radius + 1.2), Vector2(radius * 2.0, 1.0)), ring)
