class_name RigWeapon
extends Node2D
## The weapon held in the front hand, drawn along +Y from the hand (so it points
## the same way as the forearm when its own rotation is 0). A bow is drawn across
## the hand instead: its limbs run along the local X axis and bulge toward +Y.

var rig: CharacterRigData


func _init() -> void:
	use_parent_material = true


## The far end of the weapon in this node's own coordinates.
func tip() -> Vector2:
	if rig == null:
		return Vector2.ZERO
	if rig.weapon == &"bow":
		return Vector2(rig.weapon_length * 0.5, 0.0)
	return Vector2(0.0, 3.0 + rig.weapon_length)


func _draw() -> void:
	if rig == null:
		return
	if rig.weapon == &"bow":
		_draw_bow()
		return
	var width := rig.weapon_width
	var length := rig.weapon_length
	# Blade first (so the guard and grip sit over its base), then guard and grip.
	var blade := PackedVector2Array([
		Vector2(-width * 0.5, 3.0), Vector2(width * 0.5, 3.0),
		Vector2(width * 0.5, 3.0 + length - 2.0), Vector2(0.0, 3.0 + length),
		Vector2(-width * 0.5, 3.0 + length - 2.0),
	])
	var grown := PackedVector2Array()
	for point in blade:
		grown.append(point + Vector2(point.x, point.y - 3.0 - length * 0.5).normalized() * 0.7)
	draw_colored_polygon(grown, rig.outline)
	draw_colored_polygon(blade, rig.weapon_color)
	draw_line(Vector2(0.0, 3.4), Vector2(0.0, 3.0 + length - 1.5), rig.weapon_color.darkened(0.25), 0.5)
	draw_rect(Rect2(-width * 0.5 - 0.6, -1.2, width + 1.2, 4.4), rig.outline)
	draw_rect(Rect2(-width * 0.5, -0.8, width, 3.6), rig.grip_color)
	draw_rect(Rect2(-width - 1.4, 2.6, width * 2.0 + 2.8, 1.1), rig.accent)


func _draw_bow() -> void:
	var half := rig.weapon_length * 0.5
	var points := PackedVector2Array()
	for step in 9:
		var t := float(step) / 8.0
		points.append(Vector2(lerpf(-half, half, t), 3.2 * sin(t * PI)))
	draw_polyline(points, rig.outline, 2.8)
	draw_polyline(points, rig.weapon_color, 1.4)
	draw_line(Vector2(-half, 0.0), Vector2(half, 0.0), Color(1.0, 1.0, 1.0, 0.6), 0.5)
