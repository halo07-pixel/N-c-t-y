class_name RigOutfit
extends Node2D
## Clothing drawn over the line body so each fighter reads as dressed in its own way: a chest
## panel with a collar and an emblem, and a skirt, robe or coat tail hanging from the hip.
## Pure drawing in code (original shapes, no artwork). `kind` is &"chest" or &"skirt".

var rig: CharacterRigData
var kind: StringName = &"chest"
## Chest: height of the chest bone. Skirt: how far it hangs from the hip.
var length: float = 8.0
## Chest only: how far the panel continues below the chest bone, down over the belly to the hip.
var drop: float = 0.0
var _sway: float = 0.0


func _init() -> void:
	use_parent_material = true # the hit flash is set on one ancestor


## Skirt only: lets the hem trail behind the motion (positive = backward).
func set_sway(value: float) -> void:
	if absf(value - _sway) > 0.25:
		_sway = value
		queue_redraw()


func _draw() -> void:
	if rig == null:
		return
	if kind == &"chest":
		_draw_chest()
	else:
		_draw_skirt()


func _draw_chest() -> void:
	var width := rig.torso_size.x * 0.82
	var top_width := width * 0.86
	var panel := PackedVector2Array([
		Vector2(-width * 0.5, drop), Vector2(width * 0.5, drop),
		Vector2(top_width * 0.5, -length), Vector2(-top_width * 0.5, -length),
	])
	draw_colored_polygon(_grow(panel, 0.8), rig.outline)
	draw_colored_polygon(panel, rig.cloth)
	# Collar: a V in the accent colour, and a belt at the waist.
	var neck := Vector2(0.0, -length + (length + drop) * 0.3)
	draw_line(Vector2(-top_width * 0.5, -length), neck, rig.accent, 0.8)
	draw_line(Vector2(top_width * 0.5, -length), neck, rig.accent, 0.8)
	draw_rect(Rect2(-width * 0.5, drop - 1.8, width, 1.3), rig.accent.darkened(0.2))
	_draw_emblem(Vector2(0.0, -length + (length + drop) * 0.55))


func _draw_emblem(center: Vector2) -> void:
	var color := rig.accent
	match rig.emblem:
		&"cross":
			draw_line(center + Vector2(0.0, -2.4), center + Vector2(0.0, 2.4), color, 1.0)
			draw_line(center + Vector2(-2.0, -0.6), center + Vector2(2.0, -0.6), color, 1.0)
		&"diamond":
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0.0, -2.2), center + Vector2(1.8, 0.0),
				center + Vector2(0.0, 2.2), center + Vector2(-1.8, 0.0),
			]), color)
		&"strap":
			var half := rig.torso_size.x * 0.38
			draw_line(Vector2(-half, -length + 0.6), Vector2(half, -0.8), color, 1.3)
		&"trim":
			draw_rect(Rect2(-rig.torso_size.x * 0.41, -1.6, rig.torso_size.x * 0.82, 1.2), color)


func _draw_skirt() -> void:
	var top := rig.torso_size.x * 0.8
	var bottom := rig.torso_size.x * (1.5 if rig.outfit == &"robe" else 0.9)
	var back := -_sway * 0.12
	var shape: PackedVector2Array
	if rig.outfit == &"coat":
		# A coat tail hanging behind the hip.
		shape = PackedVector2Array([
			Vector2(-top * 0.5, 0.0), Vector2(top * 0.1, 0.0),
			Vector2(top * 0.0 + back, length), Vector2(-bottom * 0.7 + back, length * 1.05),
		])
	else:
		shape = PackedVector2Array([
			Vector2(-top * 0.5, 0.0), Vector2(top * 0.5, 0.0),
			Vector2(bottom * 0.5 + back, length), Vector2(-bottom * 0.5 + back, length),
		])
	draw_colored_polygon(_grow(shape, 0.7), rig.outline)
	draw_colored_polygon(shape, rig.cloth_dark if rig.outfit == &"robe" else rig.cloth)
	# Folds and a hem line.
	var left := shape[3]
	var right := shape[2]
	draw_line(left, right, Color(rig.accent, 0.8), 0.7)
	if rig.outfit != &"robe":
		return
	for fraction in [0.33, 0.66]:
		var from := shape[0].lerp(shape[1], fraction)
		var to := left.lerp(right, fraction)
		draw_line(from, to, Color(rig.outline, 0.55), 0.7)


static func _grow(points: PackedVector2Array, amount: float) -> PackedVector2Array:
	var center := Vector2.ZERO
	for point in points:
		center += point
	center /= float(points.size())
	var result := PackedVector2Array()
	for point in points:
		result.append(point + (point - center).normalized() * amount)
	return result
