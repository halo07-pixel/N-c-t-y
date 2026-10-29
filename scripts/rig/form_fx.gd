class_name FormFx
extends Node2D
## The look of a transformed fighter, drawn by code over/behind the rig: a hollow mask and long
## hair (mask), light wings and a halo (wings), floating blades (blades) or big dark wings with
## a halo (dark_wings). Two instances exist per body: one behind and one in front of the rig.
## Everything is positioned from two anchors the body keeps updating (head and back).

const STYLES: Array[StringName] = [&"mask", &"wings", &"blades", &"dark_wings"]
const GROW_SECONDS := 0.45
const BLADE_COUNT := 8

## &"back" is drawn behind the rig, &"front" over it.
var layer: StringName = &"back"
var style: StringName = &""
var color: Color = Color(1.0, 0.3, 0.2)
var head_radius: float = 5.0
var head_anchor: Vector2 = Vector2(0.0, -28.0)
var back_anchor: Vector2 = Vector2(-2.0, -18.0)
var hair_color: Color = Color(1.0, 0.8, 0.3)

var _time: float = 0.0
var _amount: float = 0.0
var _active: bool = false


func set_active(active: bool) -> void:
	_active = active and style != &""
	if _active:
		visible = true
		set_process(true)


func _ready() -> void:
	visible = false
	if style == &"wings" or style == &"mask":
		var additive := CanvasItemMaterial.new()
		additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		if style == &"wings":
			material = additive


## 0..1 unfolding progress after `seconds` of being active.
static func grow(seconds: float) -> float:
	var t := clampf(seconds / GROW_SECONDS, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


## Feather polygon from `root` along `angle` (radians): a tapered leaf shape.
static func feather(root: Vector2, angle: float, length: float, width: float) -> PackedVector2Array:
	var along := Vector2.from_angle(angle)
	var across := along.orthogonal()
	return PackedVector2Array([
		root,
		root + along * length * 0.45 + across * width,
		root + along * length,
		root + along * length * 0.45 - across * width,
	])


## Positions of the orbiting blades: [position, depth] with depth in -1..1 (positive = behind).
static func blade_orbit(time: float, count: int, radius: Vector2, center: Vector2) -> Array:
	var result: Array = []
	for i in count:
		var a := time * 1.6 + float(i) * TAU / float(count)
		result.append([center + Vector2(cos(a) * radius.x, sin(a) * radius.y - sin(time * 2.0 + float(i)) * 1.5), sin(a)])
	return result


func _process(delta: float) -> void:
	_time += delta
	_amount = move_toward(_amount, 1.0 if _active else 0.0, delta / GROW_SECONDS)
	if not _active and _amount <= 0.0:
		visible = false
		set_process(false)
		_time = 0.0
		return
	queue_redraw()


func _draw() -> void:
	var t := _amount * _amount * (3.0 - 2.0 * _amount)
	match style:
		&"mask":
			_draw_mask(t)
		&"wings":
			_draw_wings(t, 1.5, Color(0.7, 0.9, 1.0, 0.5), false)
			_draw_halo(t, Color(0.8, 0.95, 1.0))
		&"dark_wings":
			_draw_wings(t, 1.7, Color(0.16, 0.04, 0.1, 0.92), true)
			_draw_halo(t, Color(0.9, 0.15, 0.3))
		&"blades":
			_draw_blades(t)


func _draw_mask(t: float) -> void:
	if layer == &"back":
		# long hair streaming behind the head
		for i in 4:
			var sway := sin(_time * 6.0 + float(i)) * 1.5
			var root := head_anchor + Vector2(-head_radius * 0.6, -head_radius * 0.2 + float(i) * 1.4)
			draw_colored_polygon(feather(root, PI * 0.82 + float(i) * 0.12 + sway * 0.03, (11.0 + float(i) * 3.0) * t, 1.9), hair_color)
		return
	var face := head_anchor + Vector2(head_radius * 0.15, 0.0)
	draw_circle(face, head_radius * 0.92 * t, Color(0.96, 0.96, 0.98))
	draw_line(face + Vector2(-0.2, -head_radius * 0.7), face + Vector2(0.4, head_radius * 0.6), Color(0.85, 0.1, 0.1), 1.0)
	draw_colored_polygon(
		PackedVector2Array([face + Vector2(1.0, -1.6), face + Vector2(3.4, -0.6), face + Vector2(1.0, -0.2)]),
		Color(0.05, 0.0, 0.0)
	)
	draw_line(face + Vector2(-2.0, 2.0), face + Vector2(2.4, 2.2), Color(0.85, 0.1, 0.1), 1.0)


func _draw_wings(t: float, scale_factor: float, fill: Color, dark: bool) -> void:
	if layer != &"back" or t <= 0.0:
		return
	var flap := sin(_time * 3.2) * 0.12
	for wing in 2:
		var lift := 1.0 if wing == 0 else 0.72
		var root := back_anchor + Vector2(-1.0, -1.0 * float(wing))
		for i in 7:
			var f := float(i) / 6.0
			var angle := -PI * (0.58 + 0.28 * f) + flap * (0.6 + f) - float(wing) * 0.12
			var length := (9.0 + 16.0 * sin(f * PI * 0.9 + 0.3)) * scale_factor * lift * t
			draw_colored_polygon(feather(root, angle, length, 2.2 * scale_factor), fill)
			if dark:
				draw_line(root, root + Vector2.from_angle(angle) * length, Color(0.85, 0.1, 0.25, 0.9), 0.8)


func _draw_halo(t: float, ring: Color) -> void:
	if layer != &"front" or t <= 0.0:
		return
	var center := head_anchor + Vector2(0.0, -head_radius - 3.5 - sin(_time * 3.0) * 0.6)
	var points := PackedVector2Array()
	for i in 21:
		var a := float(i) * TAU / 20.0
		points.append(center + Vector2(cos(a) * 5.0, sin(a) * 1.6) * t)
	draw_polyline(points, Color(ring.r, ring.g, ring.b, 0.35), 3.0)
	draw_polyline(points, ring, 1.1)


func _draw_blades(t: float) -> void:
	var center := head_anchor + Vector2(0.0, 12.0)
	for entry in blade_orbit(_time, BLADE_COUNT, Vector2(17.0, 5.0) * t, center):
		var depth: float = entry[1]
		if (layer == &"back") != (depth > 0.0):
			continue
		var p: Vector2 = entry[0]
		var tilt := _time * 2.0 + p.x * 0.2
		var blade := PackedVector2Array([
			p + Vector2.from_angle(tilt) * 4.5, p + Vector2.from_angle(tilt + PI * 0.5) * 0.9,
			p - Vector2.from_angle(tilt) * 4.5, p + Vector2.from_angle(tilt - PI * 0.5) * 0.9,
		])
		var alpha := 0.55 if depth > 0.0 else 0.95
		draw_colored_polygon(blade, Color(1.0, 0.7, 0.88, alpha))
