class_name FightCamera
extends Camera2D
## Keeps every tracked fighter in view: centers between them and zooms out as
## they move apart, without ever showing anything outside the stage bounds.

@export var margin: Vector2 = Vector2(90.0, 60.0)
@export var min_zoom: float = 0.6 * RenderScale.FACTOR
@export var max_zoom: float = 1.4 * RenderScale.FACTOR
@export var follow_speed: float = 6.0
@export var bounds: Rect2 = Rect2(-420.0, -300.0, 840.0, 600.0)

const CINEMATIC_ZOOM := 2.2 * RenderScale.FACTOR
const CINEMATIC_FOLLOW_SPEED := 10.0

# Screen effects (all off when GameSettings.screen_effects is false).
const SHAKE_MIN_SPEED := 220.0
const SHAKE_MAX_SPEED := 700.0
const SHAKE_MAX_AMPLITUDE := 5.0 # world units
const SHAKE_DECAY := 28.0 # amplitude lost per second
const KO_SHAKE := 6.0
const KO_PUSH_ZOOM := 1.14
const KO_PUSH_DECAY := 0.3 # the push-in relaxes by this much zoom per second

## Round the picture to whole screen pixels so sprites do not shimmer while the camera moves.
@export var snap_to_pixels: bool = true
## Zoom levels the camera may rest at (multiples of the base scale), or empty for a free zoom.
@export var zoom_steps: PackedFloat32Array = PackedFloat32Array()

var _targets: Array[Node2D] = []
var _cinematic_frames_left: int = 0
var _cinematic_player_id: int = 0
var _shake_amplitude: float = 0.0
var _push: float = 1.0
var _base_zoom: float = 1.0 # zoom before the KO push-in, so the push never feeds back
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	position_smoothing_enabled = false
	Events.ultimate_started.connect(_on_ultimate_started)
	Events.fighter_launched.connect(_on_fighter_launched)
	Events.fighter_ko.connect(_on_fighter_ko)


## Shake strength (world units) for a hit that launches at `speed`; 0 for weak hits.
static func shake_for_launch(speed: float) -> float:
	var strength := inverse_lerp(SHAKE_MIN_SPEED, SHAKE_MAX_SPEED, speed)
	if strength <= 0.0:
		return 0.0
	return lerpf(1.0, SHAKE_MAX_AMPLITUDE, clampf(strength, 0.0, 1.0))


## Nearest allowed zoom that still shows everything wanted (never closer than `wanted`).
static func snap_zoom(wanted: float, steps: PackedFloat32Array) -> float:
	if steps.is_empty():
		return wanted
	if wanted < steps[0]:
		return wanted
	var result := steps[0]
	for step in steps:
		if step <= wanted and step > result:
			result = step
	return result


## `value` rounded to a whole number of screen pixels at this zoom.
static func snap_to_pixel_grid(value: Vector2, zoom_level: float) -> Vector2:
	return (value * zoom_level).round() / zoom_level


func _on_fighter_launched(_victim_id: int, speed: float, _direction: Vector2) -> void:
	if GameSettings.screen_effects:
		_shake_amplitude = maxf(_shake_amplitude, shake_for_launch(speed))


func _on_fighter_ko(_player_id: int, _position: Vector2) -> void:
	if GameSettings.screen_effects:
		_shake_amplitude = maxf(_shake_amplitude, KO_SHAKE)
		_push = KO_PUSH_ZOOM


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
	var target_zoom: float = snap_zoom(framing["zoom"], zoom_steps)
	var new_zoom := lerpf(_base_zoom, target_zoom, weight)
	_base_zoom = new_zoom
	var new_center := position.lerp(framing["center"], weight)
	zoom = Vector2(new_zoom, new_zoom) * _push_factor(delta)
	position = clamp_center(new_center, new_zoom, get_viewport_rect().size, bounds)
	offset = _effect_offset(delta, new_zoom)


## The KO push-in multiplier: starts closer and relaxes back to 1.
func _push_factor(delta: float) -> float:
	_push = move_toward(_push, 1.0, KO_PUSH_DECAY * delta)
	return _push


## Shake plus the shift that keeps the picture on whole pixels.
func _effect_offset(delta: float, zoom_level: float) -> Vector2:
	var result := Vector2.ZERO
	if _shake_amplitude > 0.0:
		result = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * _shake_amplitude
		_shake_amplitude = maxf(_shake_amplitude - SHAKE_DECAY * delta, 0.0)
	if snap_to_pixels:
		var shown := position + result
		result += snap_to_pixel_grid(shown, zoom_level * _push) - shown
	return result


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
	_base_zoom = framing["zoom"]
	zoom = Vector2(framing["zoom"], framing["zoom"])
	position = clamp_center(framing["center"], framing["zoom"], get_viewport_rect().size, bounds)
