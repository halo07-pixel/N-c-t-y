class_name RigBody
extends FighterBody
## A fighter drawn as a jointed paper-doll skeleton built from boxes (see
## CharacterRigData and RigPoses). It follows the same calls as SpriteBody and
## PlaceholderBody: the fighter reports its state, facing and attack, and this body
## picks an animation, moves smoothly toward each pose and adds secondary motion
## (hair and cape lag, squash and stretch). Hitboxes never come from this drawing.

const MARKER_GAP := 6.0
const LAND_SECONDS := 0.1
const SQUASH_DECAY := 7.0
const HIP_FOLLOW_RATE := 30.0
const LAG_RATE := 9.0
const LAG_PER_SPEED := 0.12
const MAX_LAG := 50.0
const SPIN_SPEED := 14.0
const SPIN_PIVOT := Vector2(0.0, -16.0)
const AIRBORNE_STATES: Array[StringName] = [&"Jump", &"Fall", &"Hitstun"]

var rig: CharacterRigData

var _character: CharacterData
var _player_id: int = 1
var _spinner: Node2D
var _flip: Node2D
var _root: Node2D
var _hip: RigPart
var _torso: RigPart
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
var _was_airborne: bool = false
var _spin: float = 0.0
var _spin_direction: float = 1.0
var _lag: float = 0.0
var _lag_2: float = 0.0
var _bankai: bool = false
var _target_info := {"pose": RigPoses.NEUTRAL, "rate": 12.0, "plant": true}


func setup(character: CharacterData, player_id: int) -> void:
	_character = character
	_player_id = player_id
	rig = character.rig
	assert(rig != null, "RigBody needs CharacterData.rig; use BodyFactory")
	_build()
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
	parent.add_child(part)
	return part


func _build() -> void:
	for child in get_children():
		child.queue_free()
	_aura = AuraLayer.new()
	add_child(_aura)
	_trail = RigTrail.new()
	_trail.color = rig.weapon_color.lerp(Color.WHITE, 0.3)
	add_child(_trail)
	_spinner = Node2D.new()
	add_child(_spinner)
	_flip = Node2D.new()
	_spinner.add_child(_flip)
	_root = Node2D.new()
	_flip.add_child(_root)

	_hip = _part(_root, Vector2(0.1, 0.1), rig.cloth, Vector2.ZERO) # an invisible joint
	_hip.visible = true
	_hip.size = Vector2(0.01, 0.01)
	var leg_width := rig.leg_width
	# Back leg first so the front leg is drawn over it, then the torso over both legs' tops.
	_build_leg(&"b", Vector2(-1.5, 0.0), leg_width)
	_build_leg(&"f", Vector2(1.5, 0.0), leg_width)
	_torso = _part(_hip, rig.torso_size, rig.cloth, Vector2.ZERO, true, 2.0)
	_torso.band = rig.accent
	_torso.band_at = 0.18
	_torso.band_height = 1.8
	_build_cape()
	_build_arm(&"b", Vector2(-1.0, -rig.torso_size.y + 2.4))
	_head = RigHead.new()
	_head.rig = rig
	_head.position = Vector2(0.5, -rig.torso_size.y + 0.6)
	_torso.add_child(_head)
	_build_hair_tail()
	_build_arm(&"f", Vector2(1.0, -rig.torso_size.y + 2.4))


func _build_leg(side: StringName, hip_offset: Vector2, width: float) -> void:
	var color := rig.cloth_dark
	var thigh := _part(_hip, Vector2(width, rig.leg_length.x), color, hip_offset)
	var shin := _part(thigh, Vector2(width * 0.92, rig.leg_length.y), color, Vector2(0.0, rig.leg_length.x - 0.4))
	shin.band = rig.accent
	shin.band_at = 0.78
	shin.band_height = 1.3
	var foot := _part(shin, rig.foot_size, rig.cloth_dark.darkened(0.2), Vector2(0.0, rig.leg_length.y - 0.4), false, 0.9)
	foot.origin = Vector2(-1.4, -0.6)
	_thigh[side] = thigh
	_shin[side] = shin
	_foot[side] = foot


func _build_arm(side: StringName, shoulder: Vector2) -> void:
	var width := rig.arm_width
	var upper := _part(_torso, Vector2(width, rig.arm_length.x), rig.cloth, shoulder)
	var lower := _part(upper, Vector2(width * 0.9, rig.arm_length.y), rig.skin, Vector2(0.0, rig.arm_length.x - 0.3))
	if side == &"b":
		upper.show_behind_parent = true
	else:
		_weapon = RigWeapon.new()
		_weapon.rig = rig
		_weapon.position = Vector2(0.0, rig.arm_length.y - 0.2)
		lower.add_child(_weapon)
	_upper_arm[side] = upper
	_forearm[side] = lower


func _build_hair_tail() -> void:
	if rig.hair_tail <= 0.0:
		return
	var anchor := Vector2(-rig.head_size.x * 0.5 + 1.2, -rig.head_size.y * 0.6)
	var first := _part(_head, Vector2(3.4, rig.hair_tail * 0.55), rig.hair, anchor, false, 1.4)
	first.show_behind_parent = true
	var second := _part(first, Vector2(3.0, rig.hair_tail * 0.5), rig.hair, Vector2(0.0, rig.hair_tail * 0.5), false, 1.2)
	_hair_tail = [first, second]


func _build_cape() -> void:
	if rig.cape_length <= 0.0:
		return
	var anchor := Vector2(-rig.torso_size.x * 0.5 + 1.0, -rig.torso_size.y + 1.6)
	var first := _part(_torso, Vector2(4.2, rig.cape_length * 0.5), rig.cape_color, anchor, false, 1.4)
	first.show_behind_parent = true
	var second := _part(first, Vector2(4.0, rig.cape_length * 0.5), rig.cape_color.darkened(0.1), Vector2(0.0, rig.cape_length * 0.5 - 0.4), false, 1.2)
	_cape = [first, second]


# --- FighterBody interface ----------------------------------------------------------

func set_bankai(active: bool) -> void:
	_bankai = active
	_update_aura()


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
	var wanted := _wanted_animation()
	if wanted != _animation:
		_animation = wanted
		_anim_time = 0.0
	_anim_time += delta * _time_scale()
	_target_info = RigPoses.target(_animation, _anim_time, _attack_phase, rig.weapon)
	var weight := 1.0 - exp(-float(_target_info["rate"]) * delta)
	var target: Dictionary = _target_info["pose"]
	for key: String in target:
		_current[key] = lerpf(_current.get(key, target[key]), target[key], weight)
	_update_secondary(delta)
	_update_spin(delta)
	_apply(_current, _target_info["plant"], delta)
	_update_trail()
	_head.set_look(&"fierce" if _pose == &"Attack" or _pose == &"Hitstun" or _pose == &"Charge" else &"calm")


func _wanted_animation() -> StringName:
	if _land_time > 0.0 and (_pose == &"Idle" or _pose == &"Run"):
		return &"land"
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


func _update_spin(delta: float) -> void:
	if _pose == &"Hitstun":
		_spin += SPIN_SPEED * delta * _spin_direction
	elif _spin != 0.0:
		_spin = 0.0
	_spinner.rotation = _spin
	_spinner.position = SPIN_PIVOT - SPIN_PIVOT.rotated(_spin)


## Puts the skeleton into `pose`. When `plant` is set the lowest foot rests on the ground.
func _apply(pose: Dictionary, plant: bool, delta: float) -> void:
	_flip.scale.x = float(_facing)
	_root.scale = Vector2(1.0 + 0.15 * _squash, 1.0 - 0.2 * _squash)
	_hip.rotation = deg_to_rad(pose["body"])
	_torso.rotation = deg_to_rad(pose["torso"])
	_head.rotation = deg_to_rad(pose["head"])
	for side: StringName in [&"f", &"b"]:
		_thigh[side].rotation = -deg_to_rad(pose["thigh_" + side])
		_shin[side].rotation = deg_to_rad(pose["knee_" + side])
		_foot[side].rotation = -deg_to_rad(pose["foot_" + side])
		_upper_arm[side].rotation = -deg_to_rad(pose["arm_" + side])
		_forearm[side].rotation = -deg_to_rad(pose["elbow_" + side])
	_weapon.set_blade_mode(_animation.begins_with("attack_") or _animation.begins_with("air_"))
	var weapon_angle := 0.0 if _weapon.is_bow() else RigPoses.weapon_relative(pose)
	_weapon.rotation = -deg_to_rad(weapon_angle)
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


## The streak follows the blade while a swing is active and for a moment after.
func _update_trail() -> void:
	var swinging := _pose == &"Attack" and _attack_kind != &"" and not _attack_special \
		and _attack_phase != &"startup" and GameSettings.screen_effects
	if swinging:
		var hilt := _weapon.to_global(Vector2.ZERO)
		_trail.add_sample(_weapon.to_global(_weapon.tip()), hilt)


func _update_aura() -> void:
	if _aura != null:
		_aura.set_active(_bankai or _pose == &"Charge" or _pose == &"Transform")


## Shows one animation frame and stops the body from animating by itself. Used by tools and tests.
func preview(animation: StringName, time: float = 0.0, phase: StringName = &"active") -> void:
	set_process(false)
	_snap(animation, time, phase)


func _snap(animation: StringName, time: float, phase: StringName) -> void:
	_animation = animation
	_anim_time = time
	_attack_phase = phase
	_target_info = RigPoses.target(animation, time, phase, rig.weapon)
	_current = (_target_info["pose"] as Dictionary).duplicate()
	_hip_y = 0.0
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
