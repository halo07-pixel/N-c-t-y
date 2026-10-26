class_name FightCamera
extends Camera2D
## Keeps every tracked fighter in view: centers between them and zooms out as
## they move apart, without ever showing anything outside the stage bounds.

@export var margin: Vector2 = Vector2(90.0, 60.0)
@export var min_zoom: float = 0.6
@export var max_zoom: float = 1.4
@export var follow_speed: float = 6.0
@export var bounds: Rect2 = Rect2(-420.0, -300.0, 840.0, 600.0)

const CINEMATIC_ZOOM := 2.2
const CINEMATIC_FOLLOW_SPEED := 10.0

var _targets: Array[Node2D] = []
var _cinematic_frames_left: int = 0
var _cinematic_player_id: int = 0


func _ready() -> void:
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	position_smoothing_enabled = false
	Events.ultimate_started.connect(_on_ultimate_started)


func _on_ultimate_started(player_id: int, freeze_frames: int, _title: String) -> void:
	_cinematic_player_id = player_id
	_cinematic_frames_left = freeze_frames


func set_targets(targets: Array[Node2D]) -> void:
	_targets = targets
	_snap_to_framing()


func _physics_process(delta: float) -> void:
	var framing := _current_framing()
	var speed := follow_speed
	if _cinematic_frames_left > 0:
		_cinematic_frames_left -= 1
		speed = CINEMATIC_FOLLOW_SPEED
	var weight := 1.0 - exp(-speed * delta)
	var new_zoom := lerpf(zoom.x, framing["zoom"], weight)
	var new_center := position.lerp(framing["center"], weight)
	zoom = Vector2(new_zoom, new_zoom)
	position = clamp_center(new_center, new_zoom, get_viewport_rect().size, bounds)


## Where the camera should sit and how far it should zoom for these points.
static func compute_framing(
	points: PackedVector2Array,
	view_size: Vector2,
	framing_margin: Vector2,
	lowest_zoom: float,
	highest_zoom: float
) -> Dictionary:
	if points.is_empty():
		return {"center": Vector2.ZERO, "zoom": lowest_zoom}
	var top_left := points[0]
	var bottom_right := points[0]
	for point in points:
		top_left = Vector2(minf(top_left.x, point.x), minf(top_left.y, point.y))
		bottom_right = Vector2(maxf(bottom_right.x, point.x), maxf(bottom_right.y, point.y))
	var needed := (bottom_right - top_left) + framing_margin * 2.0
	var fit_zoom := minf(view_size.x / needed.x, view_size.y / needed.y)
	return {
		"center": (top_left + bottom_right) * 0.5,
		"zoom": clampf(fit_zoom, lowest_zoom, highest_zoom),
	}


## Moves a camera center so the visible area stays inside the bounds.
static func clamp_center(
	center: Vector2, zoom_level: float, view_size: Vector2, limit: Rect2
) -> Vector2:
	var half_view := view_size / (2.0 * zoom_level)
	var result := center
	if limit.size.x <= half_view.x * 2.0:
		result.x = limit.get_center().x
	else:
		result.x = clampf(center.x, limit.position.x + half_view.x, limit.end.x - half_view.x)
	if limit.size.y <= half_view.y * 2.0:
		result.y = limit.get_center().y
	else:
		result.y = clampf(center.y, limit.position.y + half_view.y, limit.end.y - half_view.y)
	return result


func _current_framing() -> Dictionary:
	if _cinematic_frames_left > 0:
		for target in _targets:
			if is_instance_valid(target) and target.get("player_id") == _cinematic_player_id:
				return {"center": target.global_position + Vector2(0.0, -15.0), "zoom": CINEMATIC_ZOOM}
	var points := PackedVector2Array()
	for target in _targets:
		if is_instance_valid(target) and target.visible:
			points.append(target.global_position + Vector2(0.0, -15.0))
	return compute_framing(points, get_viewport_rect().size, margin, min_zoom, max_zoom)


func _snap_to_framing() -> void:
	var framing := _current_framing()
	zoom = Vector2(framing["zoom"], framing["zoom"])
	position = clamp_center(framing["center"], framing["zoom"], get_viewport_rect().size, bounds)
