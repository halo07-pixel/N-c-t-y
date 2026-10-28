class_name RigHead
extends Node2D
## The head: a face, a hair cap in one of a few styles and two eyes. The pivot is
## the neck; the head rises from it. Faces right (the rig is mirrored for left).
## Stick style: a round head, with optional glasses.

var rig: CharacterRigData
var look: StringName = &"calm" # "calm" or "fierce" (set by the body while attacking)


func _init() -> void:
	use_parent_material = true


func set_look(value: StringName) -> void:
	if value != look:
		look = value
		queue_redraw()


func is_stick() -> bool:
	return rig != null and rig.style == &"stick"


func _draw() -> void:
	if rig == null:
		return
	var size := rig.head_size
	var face := Rect2(-size.x * 0.5, -size.y, size.x, size.y)
	if is_stick():
		var radius := size.y * 0.5
		face = Rect2(-radius, -radius * 2.0, radius * 2.0, radius * 2.0)
		draw_circle(Vector2(0.0, -radius), radius + RigPart.HEAD_OUTLINE, rig.outline)
		draw_circle(Vector2(0.0, -radius), radius, rig.line)
	else:
		draw_colored_polygon(RigPart.rounded(face.grow(0.9), 3.4), rig.outline)
		draw_colored_polygon(RigPart.rounded(face, 2.6), rig.skin)
	_draw_hair(face)
	_draw_eyes(face)
	if rig.glasses:
		_draw_glasses(face)


func _draw_eyes(face: Rect2) -> void:
	var eye_y := face.position.y + face.size.y * 0.62
	var eye := Vector2(face.position.x + face.size.x * 0.68, eye_y)
	draw_rect(Rect2(eye + Vector2(-0.7, -1.0), Vector2(1.5, 2.2)), rig.outline)
	draw_rect(Rect2(eye + Vector2(-2.9, -1.0), Vector2(1.4, 2.2)), rig.outline)
	if look == &"fierce":
		draw_line(eye + Vector2(-3.4, -2.0), eye + Vector2(1.2, -1.2), rig.outline, 0.9)


## Round glasses over the eyes: two rings and a bridge.
func _draw_glasses(face: Rect2) -> void:
	var eye_y := face.position.y + face.size.y * 0.62
	var front := Vector2(face.position.x + face.size.x * 0.7, eye_y)
	var back := front + Vector2(-3.9, 0.0)
	draw_arc(front, 2.1, 0.0, TAU, 14, rig.glasses_color, 1.0)
	draw_arc(back, 2.1, 0.0, TAU, 14, rig.glasses_color, 1.0)
	draw_line(front + Vector2(-2.1, 0.0), back + Vector2(2.1, 0.0), rig.glasses_color, 0.8)


func _draw_hair(face: Rect2) -> void:
	var color := rig.hair
	var top := face.position.y
	var left := face.position.x
	var right := face.end.x
	match rig.hair_style:
		&"spiky":
			var cap := PackedVector2Array([
				Vector2(left - 0.8, top + face.size.y * 0.45), Vector2(left - 2.4, top - 1.6),
				Vector2(left + 1.8, top + 0.6), Vector2(left + 1.0, top - 3.8),
				Vector2(left + 4.0, top - 0.4), Vector2(left + 4.6, top - 4.2),
				Vector2(right - 3.4, top - 0.6), Vector2(right - 1.6, top - 3.2),
				Vector2(right + 0.6, top + 1.4), Vector2(right + 0.4, top + face.size.y * 0.3),
				Vector2(right - 3.0, top + face.size.y * 0.3), Vector2(right - 4.6, top + face.size.y * 0.1),
				Vector2(left + 3.0, top + face.size.y * 0.32),
			])
			draw_colored_polygon(cap, color)
		&"long":
			var cap := PackedVector2Array([
				Vector2(left - 1.0, top + face.size.y * 0.7), Vector2(left - 0.6, top - 0.8),
				Vector2(0.0, top - 1.4), Vector2(right + 0.6, top + 0.8),
				Vector2(right + 0.2, top + face.size.y * 0.34), Vector2(right - 3.6, top + face.size.y * 0.26),
				Vector2(left + 3.0, top + face.size.y * 0.3), Vector2(left + 2.6, top + face.size.y * 0.74),
			])
			draw_colored_polygon(cap, color)
			draw_rect(Rect2(right - 3.4, top + face.size.y * 0.12, 1.2, 2.2), rig.accent) # hair ornament
		&"short":
			var cap := PackedVector2Array([
				Vector2(left - 0.8, top + face.size.y * 0.5), Vector2(left - 0.4, top - 1.0),
				Vector2(right + 0.4, top - 0.4), Vector2(right + 0.4, top + face.size.y * 0.28),
				Vector2(right - 4.0, top + face.size.y * 0.22), Vector2(left + 3.4, top + face.size.y * 0.34),
				Vector2(left + 2.6, top + face.size.y * 0.52),
			])
			draw_colored_polygon(cap, color)
		_:
			pass
