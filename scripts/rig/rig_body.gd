class_name RigBody
extends FighterBody
## A fighter drawn as a jointed paper-doll skeleton built from boxes (see
## CharacterRigData and RigPoses). It follows the same calls as SpriteBody and
## PlaceholderBody: the fighter reports its state, facing and attack, and this body
## picks an animation, moves smoothly toward each pose and adds secondary motion
## (hair and cape lag, squash and stretch). Hitboxes never come from this drawing.

const MARKER_GAP := 6.0
const LAND_SECONDS := 0.1
const SKID_SECONDS := 0.16
const SKID_MIN_SPEED := 60.0
const TURN_RATE := 16.0
const SQUASH_DECAY := 7.0
const HIP_FOLLOW_RATE := 30.0
const LAG_RATE := 9.0
const LAG_PER_SPEED := 0.12
const MAX_LAG := 50.0
const SPIN_SPEED := 14.0
const GHOST_INTERVAL := 0.035
const GHOST_MIN_SPEED := 150.0
## Spring damping per joint (1 settles without overshoot; lower swings past the pose and back).
const DAMPING := {
	"hip_x": 0.9, "hip_y": 0.9, "body": 0.8, "torso": 0.75, "head": 0.6,
	"arm_f": 0.55, "elbow_f": 0.5, "blade": 0.55, "arm_b": 0.6, "elbow_b": 0.55,
	"thigh_f": 0.75, "knee_f": 0.65, "foot_f": 0.6, "thigh_b": 0.75, "knee_b": 0.65, "foot_b": 0.6,
}
const DEFAULT_DAMPING := 0.7
const MAX_SPRING_STEP := 1.0 / 30.0
const SPRING_SUBSTEPS := 2
const OMEGA_PER_RATE := 0.9
const SPIN_PIVOT := Vector2(0.0, -16.0)
const AIRBORNE_STATES: Array[StringName] = [&"Jump", &"Fall", &"Hitstun"]

var rig: CharacterRigData

var _character: CharacterData
var _player_id: int = 1
var _spinner: Node2D
var _flip: Node2D
var _root: Node2D
var _hip: RigPart
var _torso: RigPart # the lower torso (belly)
var _chest: RigPart
var _skirt: RigOutfit
var _neck: RigPart
var _hand := {}
var _toe := {}
var _shoulder_base := {}
var _head: RigHead
var _thigh := {}
var _shin := {}
var _foot := {}
var _upper_arm := {}
var _forearm := {}
var _weapon: RigWeapon
var _hair_tail: Array[RigPart] = []
var _cape: Array[RigPart] = []
var _aura: AuraLayer
var _trail: RigTrail
var _ghosts: RigGhosts
var _stick_parts: Array[RigPart] = []
var _velocities: Dictionary = {}
var _ghost_timer: float = 0.0

var _pose: StringName = &"Fall"
var _facing: int = 1
var _velocity: Vector2 = Vector2.ZERO
var _attack_kind: StringName = &""
var _attack_phase: StringName = &"active"
var _attack_aerial: bool = false
var _attack_special: bool = false
var _animation: StringName = &"idle"
var _anim_time: float = 0.0
var _current: Dictionary = RigPoses.NEUTRAL.duplicate()
var _hip_y: float = 0.0
var _squash: float = 0.0
var _land_time: float = 0.0
var _skid_time: float = 0.0
var _flip_scale: float = 1.0
var _was_airborne: bool = false
var _spin: float = 0.0
var _spin_direction: float = 1.0
var _lag: float = 0.0
var _lag_2: float = 0.0
var _bankai: bool = false
## The colours currently worn (the rig itself, or its form look).
var _look: CharacterRigData
var _bow_draw: float = 0.0
var _result: StringName = &"" # "win" or "lose" once the match is over
var _form_back: FormFx
var _form_front: FormFx
var _target_info := {"pose": RigPoses.NEUTRAL, "rate": 12.0, "plant": true}


func setup(character: CharacterData, player_id: int) -> void:
	_character = character
	_player_id = player_id
	rig = character.rig
	assert(rig != null, "RigBody needs CharacterData.rig; use BodyFactory")
	_build()
	if not Events.match_ended.is_connected(_on_match_ended):
		Events.match_ended.connect(_on_match_ended)
	_aura.configure(character.accent_color, rig.height())
	_aura.set_active(false)
	_snap(&"idle", 0.0, &"active")
	queue_redraw()


# --- Building the skeleton --------------------------------------------------------

func _part(parent: Node2D, size: Vector2, color: Color, position_in_parent: Vector2, up: bool = false, corner: float = 1.2) -> RigPart:
	var part := RigPart.new()
	part.size = size
	part.color = color
	part.outline = rig.outline
	part.up = up
	part.radius = corner
	part.position = position_in_parent
	if rig.style == &"stick":
		part.color = rig.line
		part.stick_width = rig.line_width
		part.band = Color(0.0, 0.0, 0.0, 0.0)
		_stick_parts.append(part)
	parent.add_child(part)
	return part


func _build() -> void:
	for child in get_children():
		child.queue_free()
	_aura = AuraLayer.new()
	add_child(_aura)
	_ghosts = RigGhosts.new()
	_ghosts.color = rig.line if rig.style == &"stick" else rig.accent
	add_child(_ghosts)
	_stick_parts.clear()
	_look = rig
	_trail = RigTrail.new()
	_trail.color = rig.trail_color if rig.trail_color.a > 0.0 else rig.weapon_color.lerp(Color.WHITE, 0.3)
	_trail.set_style(rig.trail_style)
	add_child(_trail)
	_spinner = Node2D.new()
	add_child(_spinner)
	_flip = Node2D.new()
	_spinner.add_child(_flip)
	_form_back = _make_form_fx(&"back")
	_flip.add_child(_form_back)
	_root = Node2D.new()
	_flip.add_child(_root)
	_form_front = _make_form_fx(&"front")
	_flip.add_child(_form_front)

	_hip = _part(_root, Vector2(0.1, 0.1), rig.cloth, Vector2.ZERO) # an invisible joint
	_hip.visible = true
	_hip.size = Vector2(0.01, 0.01)
	_hip.stick_width = 0.0 # the hip is only a joint
	_stick_parts.erase(_hip)
	var leg_width := rig.leg_width
	# Back leg first so the front leg is drawn over it, then the torso over both legs' tops.
	_build_leg(&"b", Vector2(-1.5, 0.0), leg_width)
	_build_leg(&"f", Vector2(1.5, 0.0), leg_width)
	# The torso is two bones (belly and chest) joined by a bendable spine, topped by a neck.
	var torso := rig.torso_size
	var belly_height := torso.y * 0.48
	var neck_length := 2.0
	var chest_height := torso.y - belly_height - neck_length + 0.2
	_torso = _part(_hip, Vector2(torso.x, belly_height), rig.cloth, Vector2.ZERO, true, 2.0)
	_torso.band = rig.accent
	_torso.band_at = 0.18
	_torso.band_height = 1.8
	if rig.outfit != &"":
		# The skirt is the belly's first child, so it is drawn over the legs and under the chest.
		_skirt = RigOutfit.new()
		_skirt.rig = rig
		_skirt.kind = &"skirt"
		_skirt.length = rig.outfit_length
		_torso.add_child(_skirt)
	_chest = _part(_torso, Vector2(torso.x, chest_height), rig.cloth, Vector2(0.0, -belly_height + 0.4), true, 2.0)
	if rig.style == &"stick":
		_torso.stick_width = rig.line_width * 1.35
		_chest.stick_width = rig.line_width * 1.35
	if rig.outfit != &"":
		var panel := RigOutfit.new()
		panel.rig = rig
		panel.kind = &"chest"
		panel.length = chest_height
		panel.drop = belly_height - 0.4
		_chest.add_child(panel)
	_build_cape(chest_height, belly_height)
	var shoulder_y := -(torso.y - belly_height) + 2.0
	_build_arm(&"b", Vector2(-1.0, shoulder_y))
	_neck = _part(_chest, Vector2(2.0, neck_length), rig.skin, Vector2(0.5, -chest_height + 0.2), true, 0.8)
	_head = RigHead.new()
	_head.rig = rig
	_head.position = Vector2(0.0, -neck_length + 0.2)
	_neck.add_child(_head)
	_build_hair_tail()
	_build_arm(&"f", Vector2(1.0, shoulder_y))


func _make_form_fx(which: StringName) -> FormFx:
	var form := FormFx.new()
	form.layer = which
	form.style = rig.form_style
	form.color = rig.form_color if rig.form_color.a > 0.0 else rig.accent
	form.hair_color = rig.hair
	form.head_radius = rig.head_size.y * 0.5
	return form


## Keeps the form overlays on the head and back of the body (they live in the flip node).
func _update_form_anchors() -> void:
	if _form_back == null or not (_bankai and rig.form_style != &""):
		return
	# The anchor is the middle of the head (the head pivot is the neck, at its base).
	var head := _flip.to_local(_head.to_global(Vector2(0.0, -rig.head_size.y * 0.5)))
	var back := _flip.to_local(_chest.to_global(Vector2(-rig.torso_size.x * 0.3, -rig.torso_size.y * 0.12)))
	for form in [_form_back, _form_front]:
		form.head_anchor = head
		form.back_anchor = back


func _build_leg(side: StringName, hip_offset: Vector2, width: float) -> void:
	var color := rig.cloth_dark
	var thigh := _part(_hip, Vector2(width, rig.leg_length.x), color, hip_offset)
	var shin := _part(thigh, Vector2(width * 0.92, rig.leg_length.y), color, Vector2(0.0, rig.leg_length.x - 0.4))
	shin.band = rig.accent
	shin.band_at = 0.78
	shin.band_height = 1.3
	var foot := _part(shin, rig.foot_size, rig.cloth_dark.darkened(0.2), Vector2(0.0, rig.leg_length.y - 0.4), false, 0.9)
	foot.origin = Vector2(-1.4, -0.6)
	var toe := _part(foot, Vector2(1.8, rig.foot_size.y), rig.cloth_dark.darkened(0.3), Vector2(-1.4 + rig.foot_size.x - 0.3, 0.0), false, 0.8)
	toe.origin = Vector2(0.0, -0.6)
	_toe[side] = toe
	_thigh[side] = thigh
	_shin[side] = shin
	_foot[side] = foot


func _build_arm(side: StringName, shoulder: Vector2) -> void:
	var width := rig.arm_width
	var upper := _part(_chest, Vector2(width, rig.arm_length.x), rig.cloth, shoulder)
	_shoulder_base[side] = shoulder
	var lower := _part(upper, Vector2(width * 0.9, rig.arm_length.y), rig.skin, Vector2(0.0, rig.arm_length.x - 0.3))
	var hand := _part(lower, Vector2(width * 0.9, 2.0), rig.skin, Vector2(0.0, rig.arm_length.y - 0.2), false, 0.9)
	_hand[side] = hand
	if side == &"b":
		upper.show_behind_parent = true
	else:
		_weapon = RigWeapon.new()
		_weapon.rig = rig
		hand.add_child(_weapon)
	_upper_arm[side] = upper
	_forearm[side] = lower


## Hair and cape keep their own color and a thicker line in the stick style.
func _style_trailing(part: RigPart, tint: Color, width: float) -> void:
	if rig.style != &"stick":
		return
	part.color = tint
	part.stick_width = width
	_stick_parts.erase(part)


func _build_hair_tail() -> void:
	if rig.hair_tail <= 0.0:
		return
	var anchor := Vector2(-rig.head_size.x * 0.5 + 1.2, -rig.head_size.y * 0.6)
	var first := _part(_head, Vector2(3.4, rig.hair_tail * 0.55), rig.hair, anchor, false, 1.4)
	first.show_behind_parent = true
	_style_trailing(first, rig.hair, 3.4)
	var second := _part(first, Vector2(3.0, rig.hair_tail * 0.5), rig.hair, Vector2(0.0, rig.hair_tail * 0.5), false, 1.2)
	_style_trailing(second, rig.hair, 2.6)
	_hair_tail = [first, second]


func _build_cape(_chest_height: float, belly_height: float) -> void:
	if rig.cape_length <= 0.0:
		return
	var anchor := Vector2(-rig.torso_size.x * 0.5 + 1.0, -(rig.torso_size.y - belly_height) + 1.2)
	var first := _part(_chest, Vector2(4.2, rig.cape_length * 0.5), rig.cape_color, anchor, false, 1.4)
	first.show_behind_parent = true
	_style_trailing(first, rig.cape_color, 4.6)
	var second := _part(first, Vector2(4.0, rig.cape_length * 0.5), rig.cape_color.darkened(0.1), Vector2(0.0, rig.cape_length * 0.5 - 0.4), false, 1.2)
	_style_trailing(second, rig.cape_color.darkened(0.1), 4.0)
	_cape = [first, second]


# --- FighterBody interface ----------------------------------------------------------

## Match over: the winner celebrates and the loser slumps while standing (signal up from the match).
func _on_match_ended(winner_id: int) -> void:
	_result = &"" if winner_id == 0 else (&"win" if winner_id == _player_id else &"lose")


## The expression for a fighter state (and the match result, once it is over and the fighter stands).
static func look_for(pose: StringName, result: StringName = &"") -> StringName:
	match pose:
		&"Attack", &"Charge":
			return &"fierce"
		&"Hitstun":
			return &"hurt"
		&"Ko":
			return &"ko"
		&"Taunt":
			return &"happy"
		&"Idle", &"Run":
			if result == &"win":
				return &"happy"
			if result == &"lose":
				return &"sad"
	return &"calm"


func set_bankai(active: bool) -> void:
	_bankai = active
	_apply_look(rig.form_look if active and rig.form_look != null else rig)
	_update_aura()


## Dresses the body in `look`'s colours (the form look while transformed, the normal rig otherwise).
func _apply_look(look: CharacterRigData) -> void:
	if _head == null or _look == look:
		return
	_look = look
	_head.rig = look
	_weapon.rig = look
	for outfit in find_children("*", "RigOutfit", true, false):
		outfit.rig = look
		outfit.queue_redraw()
	if rig.style == &"stick":
		for part in _stick_parts:
			part.color = look.line
	for part in _hair_tail:
		part.color = look.hair
	_head.queue_redraw()
	_weapon.queue_redraw()


func effect_texture(effect_name: StringName) -> Texture2D:
	if _character == null:
		return null
	var set := SpriteSetLoader.load_set(_character.sprite_dir, _character.sprite_id)
	return null if set == null else set.effects.get(effect_name)


func set_pose(pose: StringName) -> void:
	if pose == _pose:
		return
	var was_air := AIRBORNE_STATES.has(_pose)
	_pose = pose
	if was_air and (pose == &"Idle" or pose == &"Run"):
		_land_time = LAND_SECONDS
		_squash = 1.0
	elif pose == &"Jump":
		_squash = -1.0
	_update_aura()


func set_attack_visual(kind: StringName, phase: StringName, aerial: bool = false, special: bool = false) -> void:
	_attack_kind = kind
	_attack_phase = phase if phase != &"" else &"active"
	_attack_aerial = aerial
	_attack_special = special


func sync_to(pose: StringName, facing: int, velocity: Vector2) -> void:
	if _pose == &"Run" and pose == &"Idle" and absf(_velocity.x) > SKID_MIN_SPEED:
		_skid_time = SKID_SECONDS # stopping from a run: lean back and slide
		Events.dust_puff.emit(global_position, 0.6)
	set_pose(pose)
	_facing = facing
	_velocity = velocity
	if absf(velocity.x) > 1.0:
		_spin_direction = signf(velocity.x)


func _flash_target() -> CanvasItem:
	return _root


# --- Per frame ---------------------------------------------------------------------

func _process(delta: float) -> void:
	if _root == null:
		return
	_land_time = maxf(_land_time - delta, 0.0)
	_skid_time = maxf(_skid_time - delta, 0.0)
	var wanted := _wanted_animation()
	if wanted != _animation:
		_animation = wanted
		_anim_time = 0.0
	_anim_time += delta * _time_scale()
	_target_info = RigPoses.target(_animation, _anim_time, _attack_phase, rig.weapon, rig.motion)
	_spring_toward(_target_info["pose"], float(_target_info["rate"]), delta)
	_bow_draw = move_toward(_bow_draw, _bow_draw_target(), delta * (6.0 if _bow_draw_target() > 0.0 else 30.0))
	_update_secondary(delta)
	_update_spin(delta)
	_apply(_current, _target_info["plant"], delta)
	_update_trail()
	_update_ghosts(delta)
	_update_form_anchors()
	_head.set_look(look_for(_pose, _result))


## One step of a damped spring: where `x` (moving at `v`) is after `dt` when pulled toward
## `target`. `omega` is how stiff the spring is, `zeta` how damped (below 1 it overshoots).
static func spring(x: float, v: float, target: float, omega: float, zeta: float, dt: float) -> Vector2:
	var step := dt / float(SPRING_SUBSTEPS)
	for _i in SPRING_SUBSTEPS:
		var acceleration := omega * omega * (target - x) - 2.0 * zeta * omega * v
		v += acceleration * step
		x += v * step
	return Vector2(x, v)


## Moves every joint toward the target pose with a spring, so motion snaps, overshoots a little
## and settles instead of sliding at a constant rate.
func _spring_toward(target: Dictionary, rate: float, delta: float) -> void:
	var dt := minf(delta, MAX_SPRING_STEP)
	var omega := rate * OMEGA_PER_RATE
	for key: String in target:
		var result := spring(
			_current.get(key, target[key]), _velocities.get(key, 0.0), target[key],
			omega, DAMPING.get(key, DEFAULT_DAMPING), dt
		)
		_current[key] = result.x
		_velocities[key] = result.y


func _wanted_animation() -> StringName:
	if _result != &"" and (_pose == &"Idle" or _pose == &"Run"):
		return _result
	if _pose == &"Taunt":
		return &"win"
	if _land_time > 0.0 and (_pose == &"Idle" or _pose == &"Run"):
		return &"land"
	if _skid_time > 0.0 and _pose == &"Idle":
		return &"skid"
	var attacking := _pose == &"Attack" and _attack_kind != &""
	if attacking and _attack_aerial and not _attack_special and (_attack_kind == &"up" or _attack_kind == &"down"):
		return &"air_up" if _attack_kind == &"up" else &"air_down"
	return SpriteBody.animation_for(_pose, _attack_kind if attacking else &"", _attack_aerial, _attack_special)


## Run cycles speed up with the fighter's speed; everything else plays at normal speed.
func _time_scale() -> float:
	if _animation == &"run" and _character != null:
		return clampf(absf(_velocity.x) / maxf(_character.run_speed, 1.0), 0.5, 1.4)
	return 1.0


func _update_secondary(delta: float) -> void:
	_squash = move_toward(_squash, 0.0, SQUASH_DECAY * delta)
	# Hair and cape trail behind the motion: backward when moving forward, up when falling.
	var forward_speed := _velocity.x * float(_facing)
	var wanted := clampf(-forward_speed * LAG_PER_SPEED - _velocity.y * 0.04, -MAX_LAG, MAX_LAG)
	var follow := 1.0 - exp(-LAG_RATE * delta)
	_lag = lerpf(_lag, wanted, follow)
	_lag_2 = lerpf(_lag_2, _lag, follow)
	if _skirt != null:
		_skirt.set_sway(_lag)


func _update_spin(delta: float) -> void:
	if _pose == &"Hitstun":
		_spin += SPIN_SPEED * delta * _spin_direction
	elif _spin != 0.0:
		_spin = 0.0
	_spinner.rotation = _spin
	_spinner.position = SPIN_PIVOT - SPIN_PIVOT.rotated(_spin)


## Puts the skeleton into `pose`. When `plant` is set the lowest foot rests on the ground.
func _apply(pose: Dictionary, plant: bool, delta: float) -> void:
	# Turning around swings the body through a thin edge instead of snapping.
	if delta <= 0.0:
		_flip_scale = float(_facing)
	else:
		_flip_scale = move_toward(_flip_scale, float(_facing), TURN_RATE * delta)
	_flip.scale.x = _flip_scale if absf(_flip_scale) >= 0.06 else 0.06 * signf(float(_facing))
	_root.scale = Vector2(1.0 + 0.15 * _squash, 1.0 - 0.2 * _squash)
	_hip.rotation = deg_to_rad(pose["body"])
	_torso.rotation = deg_to_rad(pose["torso"] * 0.45)
	_chest.rotation = deg_to_rad(pose["torso"] * 0.55 + pose["chest"])
	_neck.rotation = deg_to_rad(pose["head"] * 0.4 + pose["neck"])
	_head.rotation = deg_to_rad(pose["head"] * 0.6)
	for side: StringName in [&"f", &"b"]:
		_thigh[side].rotation = -deg_to_rad(pose["thigh_" + side])
		_shin[side].rotation = deg_to_rad(pose["knee_" + side])
		_foot[side].rotation = -deg_to_rad(pose["foot_" + side])
		_upper_arm[side].rotation = -deg_to_rad(pose["arm_" + side])
		_forearm[side].rotation = -deg_to_rad(pose["elbow_" + side])
		_hand[side].rotation = -deg_to_rad(pose["wrist_" + side])
		_toe[side].rotation = -deg_to_rad(pose["toe_" + side])
		_upper_arm[side].position = (_shoulder_base[side] as Vector2) + Vector2(0.0, -float(pose["shrug_" + side]))
	_weapon.set_blade_mode(_animation.begins_with("attack_") or _animation.begins_with("air_"))
	var weapon_angle := 0.0 if _weapon.is_bow() else RigPoses.weapon_relative(pose)
	_weapon.rotation = -deg_to_rad(weapon_angle) + deg_to_rad(pose["wrist_f"]) # the wrist flexes, the blade angle stays
	if _weapon.is_bow():
		_hold_bow_upright()
	_update_bow_string()
	_apply_trailing_parts()
	_hip.position.x = pose["hip_x"]
	var standing := rig.leg_length.x + rig.leg_length.y
	_hip.position.y = -standing + pose["hip_y"]
	var wanted_y := _hip.position.y
	if plant:
		wanted_y -= _lowest_foot_y()
	else:
		wanted_y = -standing * 0.9 + pose["hip_y"]
	var follow := 1.0 if delta <= 0.0 else 1.0 - exp(-HIP_FOLLOW_RATE * delta)
	_hip_y = lerpf(_hip_y, wanted_y, follow)
	_hip.position.y = _hip_y


func _apply_trailing_parts() -> void:
	for index in _hair_tail.size():
		var swing := _lag if index == 0 else _lag_2 - _lag
		_hair_tail[index].rotation = -deg_to_rad((-8.0 if index == 0 else 0.0) + swing)
	for index in _cape.size():
		var swing := _lag if index == 0 else _lag_2 - _lag
		_cape[index].rotation = -deg_to_rad((-10.0 if index == 0 else 0.0) + swing)


## How far below the ground (positive) the lowest foot is, in the rig's own space.
func _lowest_foot_y() -> float:
	var lowest := -INF
	for side: StringName in [&"f", &"b"]:
		var foot: RigPart = _foot[side]
		var bottom := _root.to_local(foot.to_global(Vector2(0.6, foot.rect().end.y)))
		lowest = maxf(lowest, bottom.y)
	return lowest


## The bow stays upright (limbs vertical, belly towards the target) whatever the arm does, so it
## never tilts or points at the floor.
func _hold_bow_upright() -> void:
	var hand_basis: float = (_flip.global_transform.affine_inverse() * _hand[&"f"].global_transform).get_rotation()
	_weapon.rotation = -hand_basis - PI * 0.5


## A bow fighter's special: the string is drawn back to the rear hand while winding up and
## snaps back when the arrow is loosed.
func _update_bow_string() -> void:
	if not _weapon.is_bow():
		return
	var hand_end := _hand[&"b"].to_global(Vector2(0.0, 1.0)) as Vector2
	_weapon.set_draw(_bow_draw, _weapon.to_local(hand_end))


func _bow_draw_target() -> float:
	return 1.0 if _animation == &"special" and _attack_phase == &"startup" and _weapon.is_bow() else 0.0


## The streak follows the blade while a swing is active and for a moment after.
func _update_trail() -> void:
	var swinging := _pose == &"Attack" and _attack_kind != &"" and _attack_phase != &"startup" \
		and GameSettings.screen_effects and not _weapon.is_bow()
	if swinging:
		var hilt := _weapon.to_global(Vector2.ZERO)
		_trail.add_sample(_weapon.to_global(_weapon.tip()), hilt)


## Afterimages during fast motion: attacks past the wind-up and lunges or dashes.
func _update_ghosts(delta: float) -> void:
	_ghost_timer -= delta
	if _ghost_timer > 0.0 or not GameSettings.screen_effects:
		return
	var fast := _velocity.length() > GHOST_MIN_SPEED
	var swinging := _pose == &"Attack" and _attack_kind != &"" and _attack_phase != &"startup"
	if not (fast or swinging):
		return
	_ghost_timer = GHOST_INTERVAL
	_ghosts.add_ghost(snapshot())


## The body's lines in world coordinates ([from, to, width] each), including the weapon.
func snapshot() -> Array:
	var segments: Array = []
	for part in _stick_parts:
		segments.append(part.segment())
	var head_center := _head.to_global(Vector2(0.0, -rig.head_size.y * 0.5))
	segments.append([head_center, head_center + Vector2(0.01, 0.0), rig.head_size.y])
	segments.append([_weapon.to_global(Vector2.ZERO), _weapon.to_global(_weapon.tip()), rig.line_width])
	return segments


func _update_aura() -> void:
	if _aura != null:
		var color := rig.form_color if rig.form_color.a > 0.0 else _character.accent_color
		_aura.configure(color if _bankai else _character.accent_color, rig.height())
		_aura.set_active(_bankai or _pose == &"Charge" or _pose == &"Transform")
	if _form_back != null:
		_form_back.set_active(_bankai)
		_form_front.set_active(_bankai)


## Shows one animation frame and stops the body from animating by itself. Used by tools and tests.
func preview(animation: StringName, time: float = 0.0, phase: StringName = &"active") -> void:
	set_process(false)
	_snap(animation, time, phase)
	var pose_name := {&"hitstun": &"Hitstun", &"ko": &"Ko", &"charge": &"Charge"}.get(animation, &"Idle") as StringName
	_head.set_look(look_for(pose_name, animation if animation == &"win" or animation == &"lose" else &""))


func _snap(animation: StringName, time: float, phase: StringName) -> void:
	_animation = animation
	_anim_time = time
	_attack_phase = phase
	_target_info = RigPoses.target(animation, time, phase, rig.weapon, rig.motion)
	_current = (_target_info["pose"] as Dictionary).duplicate()
	_velocities.clear()
	_hip_y = 0.0
	_bow_draw = _bow_draw_target()
	_apply(_current, _target_info["plant"], 0.0)
	_hip_y = _hip.position.y
	_apply(_current, _target_info["plant"], 0.0)


## The weapon tip in this body's coordinates (for aligning hitboxes by eye).
func weapon_tip() -> Vector2:
	return to_local(_weapon.to_global(_weapon.tip()))


func _draw() -> void:
	if rig == null:
		return
	_draw_player_marker(-rig.height() - MARKER_GAP)


func _draw_player_marker(top_y: float) -> void:
	var marker_color: Color = PlaceholderBody.PLAYER_MARKER_COLORS.get(_player_id, Color.WHITE)
	draw_colored_polygon(
		PackedVector2Array([Vector2(-3.0, top_y), Vector2(3.0, top_y), Vector2(0.0, top_y + 4.0)]),
		marker_color
	)
