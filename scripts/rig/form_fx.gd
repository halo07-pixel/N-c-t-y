class_name FormFx
extends Node2D
## The look of a transformed fighter, drawn by code over/behind the rig: a hollow mask and long
## hair (mask), light wings and a halo (wings), floating blades (blades) or big dark wings with
## a halo (dark_wings) tongues of spiritual pressure with a glowing eye (flames) or a giant segmented bone snake with a baboon's head coiling around the body (bone_snake). Two instances exist per body: one behind and one in front of the rig.
## Everything is positioned from two anchors the body keeps updating (head and back).

const STYLES: Array[StringName] = [&"mask", &"wings", &"blades", &"dark_wings", &"flames", &"bone_snake"]
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
	if style == &"flames":
		var glow := CanvasItemMaterial.new()
		glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = glow


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
		&"flames":
			_draw_flames(t)
		&"bone_snake":
			_draw_bone_snake(t)


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


## Tongues of spiritual pressure flickering up behind the body, and a glowing eye on the face.
func _draw_flames(t: float) -> void:
	if t <= 0.0:
		return
	if layer == &"back":
		for i in 9:
			var f := float(i) / 8.0
			var flick := 0.75 + 0.25 * sin(_time * 9.0 + float(i) * 1.9)
			var root := back_anchor + Vector2(-6.0 + 12.0 * f, 8.0 - absf(f - 0.5) * 6.0)
			var angle := -PI * 0.5 + (f - 0.5) * 0.9 + sin(_time * 5.0 + float(i)) * 0.08
			var length := (14.0 + 12.0 * sin(f * PI)) * flick * t
			draw_colored_polygon(feather(root, angle, length, 2.6), Color(color.r, color.g, color.b, 0.5))
			draw_colored_polygon(feather(root, angle, length * 0.6, 1.3), Color(1.0, 0.95, 0.6, 0.7))
		return
	var eye := head_anchor + Vector2(head_radius * 0.55, -head_radius * 0.12)
	draw_circle(eye, 1.7 * t, Color(1.0, 0.9, 0.4, 0.5))
	draw_line(eye + Vector2(-1.4, 0.0), eye + Vector2(1.4, 0.0), Color(1.0, 1.0, 0.8), 0.9)


## Hihio Zabimaru: a long snake of bone segments rising from the back, arching high over the
## fighter and ending in the baboon's skull in front of the head. The lower part of the arc is
## drawn behind the body, the upper part and the skull in front.
func _draw_bone_snake(t: float) -> void:
	if t <= 0.0:
		return
	var points := bone_snake_path(_time, back_anchor, head_anchor, t)
	var count := points.size()
	for i in count - 1:
		var behind := float(i) / float(count) < BONE_SNAKE_BEHIND
		if behind != (layer == &"back"):
			continue
		var f := float(i) / float(count)
		var along := points[i + 1] - points[i]
		var normal := along.normalized().orthogonal()
		var width := lerpf(4.4, 3.0, f)
		var shade := 0.6 if layer == &"back" else 1.0
		var seg := PackedVector2Array([
			points[i] + along * 0.08, points[i] + along * 0.5 + normal * width, points[i + 1] - along * 0.08, points[i] + along * 0.5 - normal * width,
		])
		draw_colored_polygon(seg, Color(0.95 * shade, 0.92 * shade, 0.84 * shade, 0.97))
		draw_polyline(PackedVector2Array([seg[0], seg[1], seg[2], seg[3], seg[0]]), Color(color.r, color.g, color.b, 0.95), 1.0)
		draw_line(points[i] + along * 0.5 + normal * width * 0.9, points[i] + along * 0.5 + normal * (width + 2.2), Color(color.r, color.g, color.b, 0.8 * shade), 1.0)
	if layer == &"front":
		_draw_baboon_head(points[count - 1], points[count - 1] - points[count - 3], t)


const BONE_SNAKE_BEHIND := 0.5


## The snake's spine in the body's space: a cubic curve from the back, up and over the head to a
## point in front of it, with a slow wave running along it.
static func bone_snake_path(time: float, root: Vector2, head: Vector2, grow_t: float) -> PackedVector2Array:
	var path := PackedVector2Array()
	var steps := 16
	var p1 := root + Vector2(-34.0, -6.0)
	var p2 := head + Vector2(-26.0, -46.0)
	var p3 := head + Vector2(17.0, -20.0)
	for i in steps + 1:
		var f := float(i) / float(steps) * grow_t
		var u := 1.0 - f
		var on_curve := u * u * u * root + 3.0 * u * u * f * p1 + 3.0 * u * f * f * p2 + f * f * f * p3
		var tangent := (3.0 * u * u * (p1 - root) + 6.0 * u * f * (p2 - p1) + 3.0 * f * f * (p3 - p2)).normalized()
		path.append(on_curve + tangent.orthogonal() * sin(f * TAU * 2.0 + time * 3.0) * 2.6 * sin(f * PI))
	return path


func _draw_baboon_head(at: Vector2, direction: Vector2, t: float) -> void:
	var facing := direction.normalized() if direction.length() > 0.01 else Vector2.RIGHT
	var side := facing.orthogonal()
	var jaw := 0.5 + 0.5 * sin(_time * 5.0)
	var skull := Color(0.97, 0.94, 0.86)
	var r := 6.5 * t
	draw_circle(at, r + 1.0, Color(color.r, color.g, color.b, 0.9))
	draw_circle(at, r, skull)
	var snout_tip := at + facing * r * 2.0
	var open := (1.0 + 2.6 * jaw) * t
	draw_colored_polygon(PackedVector2Array([at + side * r * 0.7, snout_tip + side * (1.4 + open), snout_tip - side * (1.4 + open), at - side * r * 0.7]), skull)
	draw_colored_polygon(PackedVector2Array([at + facing * r * 0.9, snout_tip - side * (1.4 + open) * 0.2, at + facing * r * 0.9 + side * open]), Color(0.45, 0.04, 0.06))
	draw_circle(at + side * r * 0.35 + facing * r * 0.1, r * 0.22, Color(0.8, 0.05, 0.05))
	for fang in 3:
		var base := snout_tip - facing * (1.2 + float(fang) * 2.4)
		draw_line(base + side * (1.4 + open), base + side * (1.4 + open) - side * 2.8, Color.WHITE, 1.1)
		draw_line(base - side * (1.4 + open), base - side * (1.4 + open) + side * 2.8, Color.WHITE, 1.1)
	for horn in 2:
		var root := at - facing * r * 0.2 + side * r * (0.6 if horn == 0 else -0.6)
		draw_line(root, root - facing * r * 0.8 + side * r * (0.5 if horn == 0 else -0.5), Color(color.r, color.g, color.b, 0.95), 1.6)
