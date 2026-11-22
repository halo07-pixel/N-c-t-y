class_name AfterimageTrail
extends Node2D
## A fading trail behind a fighter who was launched hard: it samples the fighter's position
## each frame and draws the recent path as a tapering streak with ghost heads. Purely visual;
## it never touches the fighter. Frees itself when the time is up or the fighter is gone.

const LIFETIME := 0.45
const MAX_POINTS := 14
## Launches at or above this speed leave a trail.
const MIN_SPEED := 650.0

var color: Color = Color(1.0, 1.0, 1.0)
var amount: float = 1.0
var _target: Node2D
var _points: Array[Vector2] = []
var _age: float = 0.0


func _init() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	z_index = 12


static func wants_trail(launch_speed: float) -> bool:
	return launch_speed >= MIN_SPEED


func follow(target: Node2D) -> void:
	_target = target


## Opacity of the trail segment `index` of `count` (0 oldest): older parts are fainter.
static func segment_alpha(index: int, count: int) -> float:
	return float(index + 1) / float(maxi(count, 1))


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME or _target == null or not is_instance_valid(_target):
		queue_free()
		return
	_points.append(_target.global_position + Vector2(0.0, -14.0))
	if _points.size() > MAX_POINTS:
		_points.pop_front()
	queue_redraw()


func _draw() -> void:
	var fade := 1.0 - _age / LIFETIME
	var count := _points.size()
	for i in range(1, count):
		var alpha := segment_alpha(i, count) * fade * 0.7 * amount
		var width := 1.0 + 4.0 * segment_alpha(i, count)
		draw_line(to_local(_points[i - 1]), to_local(_points[i]), Color(color.r, color.g, color.b, alpha), width)
	if count > 3:
		var ghost := count - 4
		draw_circle(to_local(_points[ghost]), 6.0, Color(color.r, color.g, color.b, 0.25 * fade * amount))
