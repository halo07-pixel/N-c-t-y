class_name RigHead
extends Node2D
## The head: a face, a hair cap in one of a few styles and two eyes. The pivot is
## the neck; the head rises from it. Faces right (the rig is mirrored for left).
## Stick style: a round head, with optional glasses.

var rig: CharacterRigData
## The expression, set by the body: calm, fierce, hurt, ko, happy or sad.
var look: StringName = &"calm"
const BLINK_SECONDS := 0.12
const BLINK_LOOKS: Array[StringName] = [&"calm", &"sad"]
var _blink_left: float = 0.0
var _next_blink: float = 2.5
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	use_parent_material = true


func set_look(value: StringName) -> void:
	if value != look:
		look = value
		queue_redraw()


func _process(delta: float) -> void:
	if _blink_left > 0.0:
		_blink_left -= delta
		if _blink_left <= 0.0:
			queue_redraw()
		return
	_next_blink -= delta
	if _next_blink <= 0.0:
		_next_blink = _rng.randf_range(2.2, 5.0)
		if BLINK_LOOKS.has(look):
			_blink_left = BLINK_SECONDS
			queue_redraw()


func is_blinking() -> bool:
	return _blink_left > 0.0 and BLINK_LOOKS.has(look)


## Closes the eyes for one frame (tools and tests).
func force_blink() -> void:
	_blink_left = BLINK_SECONDS
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
	_draw_headwear(face)
	_draw_eyes(face)
	_draw_mouth(face)
	if rig.eyepatch:
		_draw_eyepatch(face)
	if rig.glasses:
		_draw_glasses(face)


func _draw_eyes(face: Rect2) -> void:
	var eye_y := face.position.y + face.size.y * 0.62
	var eye := Vector2(face.position.x + face.size.x * 0.68, eye_y)
	var front := eye + Vector2(0.0, 0.0)
	var back := eye + Vector2(-2.2, 0.0)
	var ink := rig.outline
	match look:
		&"hurt": # eyes squeezed shut: > <
			for centre: Vector2 in [front, back]:
				draw_line(centre + Vector2(-1.2, -1.3), centre + Vector2(0.9, 0.0), ink, 0.8)
				draw_line(centre + Vector2(-1.2, 1.3), centre + Vector2(0.9, 0.0), ink, 0.8)
		&"ko": # crossed out
			for centre: Vector2 in [front, back]:
				draw_line(centre + Vector2(-1.1, -1.1), centre + Vector2(1.1, 1.1), ink, 0.8)
				draw_line(centre + Vector2(-1.1, 1.1), centre + Vector2(1.1, -1.1), ink, 0.8)
		&"happy": # closed smiling arcs
			for centre: Vector2 in [front, back]:
				draw_arc(centre + Vector2(0.0, 0.8), 1.3, PI * 1.1, PI * 1.9, 6, ink, 0.8)
		_:
			if is_blinking():
				draw_line(front + Vector2(-0.8, 0.0), front + Vector2(0.9, 0.0), ink, 0.7)
				draw_line(back + Vector2(-0.8, 0.0), back + Vector2(0.9, 0.0), ink, 0.7)
				return
			var drop := 0.7 if look == &"sad" else 0.0
			draw_rect(Rect2(front + Vector2(-0.7, -1.0 + drop), Vector2(1.5, 2.2)), ink)
			draw_rect(Rect2(back + Vector2(-0.7, -1.0 + drop), Vector2(1.4, 2.2)), ink)
			if look == &"fierce":
				draw_line(eye + Vector2(-3.4, -2.0), eye + Vector2(1.2, -1.2), ink, 0.9)
			elif look == &"sad": # brows slanting up towards the middle
				draw_line(back + Vector2(-1.2, -1.6), back + Vector2(0.9, -2.6), ink, 0.7)
				draw_line(front + Vector2(-0.9, -2.6), front + Vector2(1.2, -1.6), ink, 0.7)


## A dark patch over the front eye with its strap running back over the head.
func _draw_eyepatch(face: Rect2) -> void:
	var eye := Vector2(face.position.x + face.size.x * 0.68, face.position.y + face.size.y * 0.62)
	draw_line(eye + Vector2(-1.0, -0.6), Vector2(face.position.x + face.size.x * 0.1, face.position.y + face.size.y * 0.18), rig.outline, 0.8)
	draw_rect(Rect2(eye + Vector2(-2.0, -2.0), Vector2(4.0, 4.0)), rig.outline)
	draw_rect(Rect2(eye + Vector2(-1.2, -1.2), Vector2(2.4, 2.4)), Color(0.2, 0.18, 0.22))


## A small mouth: open when hurt, a smile when happy, a flat line when out cold or sad.
func _draw_mouth(face: Rect2) -> void:
	var mouth := Vector2(face.position.x + face.size.x * 0.66, face.position.y + face.size.y * 0.86)
	match look:
		&"hurt":
			draw_rect(Rect2(mouth + Vector2(-0.8, -0.9), Vector2(1.6, 1.9)), rig.outline)
		&"happy":
			draw_arc(mouth + Vector2(0.0, -1.0), 2.0, PI * 0.15, PI * 0.85, 8, rig.outline, 0.8)
		&"ko", &"sad":
			draw_line(mouth + Vector2(-1.2, 0.3), mouth + Vector2(1.2, 0.3), rig.outline, 0.7)
		_:
			pass


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
			if rig.hair_bells: # small gold bells hanging from the spikes
				for bell: Vector2 in [Vector2(left - 2.0, top - 0.2), Vector2(left + 1.0, top - 3.0), Vector2(left + 4.4, top - 3.4)]:
					draw_circle(bell + Vector2(0.0, 1.2), 0.95, Color(1.0, 0.82, 0.3))
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


## Crown: three points standing on top of the hair.
func _draw_headwear(face: Rect2) -> void:
	if rig.headwear != &"crown":
		return
	var top := face.position.y - 1.2
	var base_y := top + 1.6
	for index in 3:
		var x := face.position.x + face.size.x * (0.22 + 0.28 * index)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 1.6, base_y), Vector2(x, base_y - 3.4 - (1.2 if index == 1 else 0.0)), Vector2(x + 1.6, base_y),
		]), rig.accent)
	draw_rect(Rect2(face.position.x + face.size.x * 0.12, base_y - 0.2, face.size.x * 0.76, 1.3), rig.accent.darkened(0.25))
