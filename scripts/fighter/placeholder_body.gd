class_name PlaceholderBody
extends Node2D
## Original stand-in body drawn with rectangles so gameplay can be built and
## tuned before any real sprites exist. Replace it with an animated sprite
## later; hitboxes come from data, not from this drawing.

const OUTLINE_COLOR := Color(0.06, 0.05, 0.09)
const SKIN_COLOR := Color(0.93, 0.78, 0.65)
const STEEL_COLOR := Color(0.8, 0.85, 0.9)
const SLASH_COLOR := Color(1.0, 1.0, 1.0, 0.45)
const PLAYER_MARKER_COLORS := {
	1: Color(0.95, 0.3, 0.3),
	2: Color(0.3, 0.55, 0.95),
}
const RUN_STEP_SECONDS := 0.1
const LEG_HEIGHT := 10.0
const TORSO_HEIGHT := 12.0
const HEAD_SIZE := 8.0
const SHOULDER := Vector2(7.0, -24.0)
const SPIN_PIVOT := Vector2(0.0, -16.0)
const SPIN_SPEED := 14.0

## Sword tip for each attack kind and phase (startup / active / recovery), facing right.
const SWORD_TIPS := {
	&"neutral": {&"startup": Vector2(-4.0, -40.0), &"active": Vector2(32.0, -22.0), &"recovery": Vector2(20.0, -8.0)},
	&"forward": {&"startup": Vector2(-6.0, -40.0), &"active": Vector2(38.0, -22.0), &"recovery": Vector2(22.0, -6.0)},
	&"up": {&"startup": Vector2(16.0, -30.0), &"active": Vector2(6.0, -58.0), &"recovery": Vector2(14.0, -38.0)},
	&"down": {&"startup": Vector2(16.0, -30.0), &"active": Vector2(26.0, 2.0), &"recovery": Vector2(16.0, -8.0)},
}

var _character: CharacterData
var _player_id: int = 1
var _pose: StringName = &"Fall"
var _facing: int = 1
var _run_time: float = 0.0
var _attack_kind: StringName = &""
var _attack_phase: StringName = &""
var _spin: float = 0.0
var _spin_direction: float = 1.0


func setup(character: CharacterData, player_id: int) -> void:
	_character = character
	_player_id = player_id
	queue_redraw()


func set_pose(pose: StringName) -> void:
	_pose = pose
	queue_redraw()


func set_attack_visual(kind: StringName, phase: StringName) -> void:
	if kind != _attack_kind or phase != _attack_phase:
		_attack_kind = kind
		_attack_phase = phase
		queue_redraw()


func sync_to(pose: StringName, facing: int, velocity: Vector2) -> void:
	if absf(velocity.x) > 1.0:
		_spin_direction = signf(velocity.x)
	if pose != _pose or facing != _facing:
		_pose = pose
		_facing = facing
		queue_redraw()


func _process(delta: float) -> void:
	_update_spin(delta)
	if _pose != &"Run":
		return
	var step_before := _run_step()
	_run_time += delta
	if _run_step() != step_before:
		queue_redraw()


## Tumbling while launched: rotate around the body center, upright otherwise.
func _update_spin(delta: float) -> void:
	if _pose == &"Hitstun":
		_spin += SPIN_SPEED * delta * _spin_direction
	elif _spin != 0.0:
		_spin = 0.0
	rotation = _spin
	position = SPIN_PIVOT - SPIN_PIVOT.rotated(_spin)


func _run_step() -> int:
	return int(_run_time / RUN_STEP_SECONDS) % 2


func _draw() -> void:
	if _character == null:
		return
	var parts := _pose_parts()
	var lift: float = parts["lift"]
	var lean: float = parts["lean"]
	var torso_y := -LEG_HEIGHT - lift - TORSO_HEIGHT
	var head_y := torso_y - HEAD_SIZE

	draw_set_transform(Vector2.ZERO, 0.0, Vector2(float(_facing), 1.0))
	_box(parts["left_leg"], _character.body_color.darkened(0.25))
	_box(parts["right_leg"], _character.body_color.darkened(0.25))
	_box(Rect2(-7.0 + lean, torso_y, 14.0, TORSO_HEIGHT), _character.body_color)
	draw_rect(Rect2(-7.0 + lean, torso_y + 8.0, 14.0, 2.0), _character.accent_color)
	_box(Rect2(-4.0 + lean, head_y, HEAD_SIZE, HEAD_SIZE), SKIN_COLOR)
	draw_rect(Rect2(-4.0 + lean, head_y, HEAD_SIZE, 3.0), _character.accent_color)
	draw_rect(Rect2(1.0 + lean, head_y + 4.0, 2.0, 2.0), OUTLINE_COLOR)
	_draw_sword(parts, Vector2(lean, -lift))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_player_marker(head_y - 7.0)


func _draw_sword(parts: Dictionary, offset: Vector2) -> void:
	var sword_from: Vector2 = parts["sword_from"] + offset
	var sword_to: Vector2 = parts["sword_to"] + offset
	if _pose == &"Attack" and _attack_phase == &"active":
		var trail_from: Vector2 = SWORD_TIPS[_attack_kind][&"startup"]
		draw_colored_polygon(PackedVector2Array([sword_from, trail_from, sword_to]), SLASH_COLOR)
	draw_line(sword_from, sword_to, OUTLINE_COLOR, 4.0)
	draw_line(sword_from, sword_to, STEEL_COLOR, 2.0)


## Where the limbs go for the current pose, in "facing right" coordinates.
func _pose_parts() -> Dictionary:
	var parts := {
		"lift": 0.0,
		"lean": 0.0,
		"left_leg": Rect2(-6.0, -LEG_HEIGHT, 5.0, LEG_HEIGHT),
		"right_leg": Rect2(1.0, -LEG_HEIGHT, 5.0, LEG_HEIGHT),
		"sword_from": Vector2(9.0, -8.0),
		"sword_to": Vector2(9.0, -26.0),
	}
	match _pose:
		&"Run":
			_pose_run(parts)
		&"Jump":
			parts["lift"] = 4.0
			parts["left_leg"] = Rect2(-6.0, -LEG_HEIGHT - 4.0, 5.0, LEG_HEIGHT - 3.0)
			parts["right_leg"] = Rect2(1.0, -LEG_HEIGHT - 4.0, 5.0, LEG_HEIGHT - 3.0)
			parts["sword_from"] = Vector2(8.0, -20.0)
			parts["sword_to"] = Vector2(12.0, -34.0)
		&"Fall", &"Hitstun":
			parts["lift"] = 2.0
			parts["left_leg"] = Rect2(-8.0, -LEG_HEIGHT - 2.0, 5.0, LEG_HEIGHT)
			parts["right_leg"] = Rect2(3.0, -LEG_HEIGHT - 2.0, 5.0, LEG_HEIGHT)
			parts["sword_from"] = Vector2(8.0, -22.0)
			parts["sword_to"] = Vector2(10.0, -8.0)
		&"Attack":
			_pose_attack(parts)
	return parts


func _pose_run(parts: Dictionary) -> void:
	parts["lean"] = 1.0
	parts["sword_from"] = Vector2(-7.0, -18.0)
	parts["sword_to"] = Vector2(-15.0, -13.0)
	if _run_step() == 0:
		parts["left_leg"] = Rect2(-8.0, -LEG_HEIGHT + 2.0, 5.0, LEG_HEIGHT - 2.0)
		parts["right_leg"] = Rect2(3.0, -LEG_HEIGHT, 5.0, LEG_HEIGHT)
	else:
		parts["left_leg"] = Rect2(-3.0, -LEG_HEIGHT, 5.0, LEG_HEIGHT)
		parts["right_leg"] = Rect2(1.0, -LEG_HEIGHT + 2.0, 5.0, LEG_HEIGHT - 2.0)


func _pose_attack(parts: Dictionary) -> void:
	if not SWORD_TIPS.has(_attack_kind):
		return
	parts["sword_from"] = SHOULDER
	parts["sword_to"] = SWORD_TIPS[_attack_kind][_attack_phase]
	parts["lean"] = 2.0 if _attack_phase == &"active" else 0.0
	parts["left_leg"] = Rect2(-8.0, -LEG_HEIGHT, 5.0, LEG_HEIGHT)
	parts["right_leg"] = Rect2(3.0, -LEG_HEIGHT, 5.0, LEG_HEIGHT)


func _draw_player_marker(top_y: float) -> void:
	var marker_color: Color = PLAYER_MARKER_COLORS.get(_player_id, Color.WHITE)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-3.0, top_y), Vector2(3.0, top_y), Vector2(0.0, top_y + 4.0)
		]),
		marker_color
	)


func _box(rect: Rect2, color: Color) -> void:
	draw_rect(rect.grow(1.0), OUTLINE_COLOR)
	draw_rect(rect, color)
