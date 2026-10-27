class_name SpriteBody
extends FighterBody
## Shows a fighter with real sprite animations. It follows the same calls as
## PlaceholderBody: the fighter reports its state, facing and attack, and this
## body chooses the animation. Sprites face right and are mirrored for left.
## Animations a set lacks fall back to another one plus a small motion done in
## code (lean, stretch, tilt, spin and fade). Hitboxes never come from the art.

const FRAME_TICKS := 3 # physics frames each attack frame is held
const MARKER_GAP := 5.0
const AURA_COLOR_ALPHA := 0.35
const FALLBACK_ANIMATIONS := {
	&"ko": &"hitstun", &"charge": &"guard", &"hitstun": &"fall", &"guard": &"idle",
	&"land": &"idle", &"jump": &"fall", &"fall": &"idle", &"run": &"idle",
	&"air_attack": &"attack_neutral", &"special": &"attack_neutral",
	&"attack_forward": &"attack_neutral", &"attack_up": &"attack_neutral",
	&"attack_down": &"attack_neutral",
}
## Motion for animations that are borrowed from another one.
const BORROWED_MOTION := {&"ko": "spin_fade"}
const LEAN_DEGREES := 8.0
const BOB_PIXELS := 2.0
const BOB_SPEED := 18.0
const FLASH_TICKS := 6
const KO_FADE_TICKS := 40

var _character: CharacterData
var _player_id: int = 1
var _set: SpriteSet
var _pivot: Node2D
var _sprite: AnimatedSprite2D
var _pose: StringName = &"Fall"
var _facing: int = 1
var _animation: StringName = &""
var _motion: String = ""
var _pose_ticks: int = 0
var _bankai: bool = false
var _pulse: float = 0.0
var _attack_kind: StringName = &""
var _attack_phase: StringName = &""
var _attack_aerial: bool = false
var _attack_special: bool = false
var _phase_ticks: int = 0


func setup(character: CharacterData, player_id: int) -> void:
	_character = character
	_player_id = player_id
	_set = SpriteSetLoader.load_set(character.sprite_dir, character.sprite_id)
	assert(_set != null, "SpriteBody needs a sprite set; use BodyFactory")
	if _pivot == null:
		_pivot = Node2D.new()
		add_child(_pivot)
		_sprite = AnimatedSprite2D.new()
		_sprite.centered = false
		_pivot.add_child(_sprite)
	_sprite.sprite_frames = _set.frames
	_sprite.offset = -_set.anchor
	_animation = &""
	_refresh_animation()
	_apply_transform()
	queue_redraw()


func set_bankai(active: bool) -> void:
	_bankai = active
	queue_redraw()


func effect_texture(effect_name: StringName) -> Texture2D:
	if _set == null:
		return null
	return _set.effects.get(effect_name)


func set_pose(pose: StringName) -> void:
	if pose != _pose:
		_pose = pose
		_pose_ticks = 0
		_refresh_animation()


func set_attack_visual(kind: StringName, phase: StringName, aerial: bool = false, special: bool = false) -> void:
	if kind != _attack_kind or aerial != _attack_aerial or special != _attack_special:
		_phase_ticks = 0
	elif phase != _attack_phase:
		_phase_ticks = 0
	else:
		_phase_ticks += 1
	_attack_kind = kind
	_attack_phase = phase
	_attack_aerial = aerial
	_attack_special = special
	_refresh_animation()


func sync_to(pose: StringName, facing: int, _velocity: Vector2) -> void:
	if pose != _pose:
		set_pose(pose)
	_facing = facing
	_pose_ticks += 1
	_apply_transform()


func _process(delta: float) -> void:
	if _bankai or _pose == &"Charge" or _pose == &"Transform":
		_pulse += delta
		queue_redraw()


## Which animation shows the current state, and the first frame to put on it.
static func animation_for(
	pose: StringName, kind: StringName, aerial: bool, special: bool
) -> StringName:
	match pose:
		&"Idle":
			return &"idle"
		&"Run":
			return &"run"
		&"Jump":
			return &"jump"
		&"Fall":
			return &"fall"
		&"Hitstun":
			return &"hitstun"
		&"Ko":
			return &"ko"
		&"Charge", &"Transform":
			return &"charge"
		&"Attack":
			if special:
				return &"special"
			if aerial:
				return &"air_attack"
			return StringName("attack_%s" % kind) if kind != &"" else &"attack_neutral"
	return &"idle"


## Which frame of an attack animation to show: the wind-up frames during
## startup, the strike during active, the follow-through during recovery.
static func attack_frame(frame_count: int, phase: StringName, ticks: int) -> int:
	if frame_count <= 1:
		return 0
	var startup := 1
	var active := 1
	if frame_count > 2:
		active = 1 if frame_count <= 4 else 2
		startup = frame_count - active - 1
	else:
		active = 1
	var first := 0
	var length := startup
	if phase == &"active":
		first = startup if frame_count > 2 else 1
		length = active
	elif phase == &"recovery":
		first = frame_count - 1
		length = 1
	return first + mini(ticks / FRAME_TICKS, length - 1)


## The animation that exists in this set: the wanted one or its fallback chain.
func resolve_animation(wanted: StringName) -> StringName:
	var current := wanted
	for _step in FALLBACK_ANIMATIONS.size():
		if _set.has_animation(current):
			return current
		current = FALLBACK_ANIMATIONS.get(current, &"idle")
	return &"idle"


func _refresh_animation() -> void:
	if _set == null or _sprite == null:
		return
	var attacking := _pose == &"Attack" and _attack_kind != &""
	var wanted := animation_for(_pose, _attack_kind if attacking else &"", _attack_aerial, _attack_special)
	var animation := resolve_animation(wanted)
	_motion = String(_set.code_motion.get(wanted, BORROWED_MOTION.get(wanted, "") if animation != wanted else ""))
	if attacking:
		_show_attack_frame(animation)
		return
	if animation != _animation:
		_animation = animation
		_sprite.play(animation)


func _show_attack_frame(animation: StringName) -> void:
	if animation != _animation:
		_animation = animation
		_sprite.animation = animation
	_sprite.pause()
	var count := _set.frame_count(animation)
	_sprite.frame = attack_frame(count, _attack_phase, _phase_ticks)


## Mirrors for facing and applies the code motion of the current animation.
func _apply_transform() -> void:
	if _pivot == null:
		return
	var base := RenderScale.sprite()
	var stretch := 1.0
	var tilt := 0.0
	var bob := 0.0
	var flash := false
	var alpha := 1.0
	match _motion:
		"lean_forward_8deg_bob_2px":
			tilt = deg_to_rad(LEAN_DEGREES)
			bob = -absf(sin(float(_pose_ticks) / BOB_SPEED * TAU * 0.5)) * BOB_PIXELS
		"stretch_up":
			stretch = 1.12
		"tilt_back_flash_white":
			tilt = -deg_to_rad(LEAN_DEGREES + 2.0)
			flash = _pose_ticks <= FLASH_TICKS
		"spin_fade":
			tilt = float(_pose_ticks) * 0.35
			alpha = clampf(1.0 - float(_pose_ticks) / KO_FADE_TICKS, 0.0, 1.0)
	_pivot.scale = Vector2(float(_facing) * base, base * stretch)
	_pivot.rotation = tilt * float(_facing)
	_pivot.position = Vector2.ZERO
	_sprite.position = Vector2(0.0, bob)
	_sprite.modulate = Color(2.0, 2.0, 2.0, alpha) if flash else Color(1.0, 1.0, 1.0, alpha)


func _draw() -> void:
	if _set == null:
		return
	var height := _set.top_px * RenderScale.sprite()
	if _bankai or _pose == &"Charge" or _pose == &"Transform":
		_draw_aura(height)
	_draw_player_marker(-height - MARKER_GAP)


func _draw_aura(height: float) -> void:
	var color := _character.accent_color
	var pulse := 1.0 + 0.12 * sin(_pulse * 10.0)
	var center := Vector2(0.0, -height * 0.5)
	var radius := Vector2(height * 0.42, height * 0.62) * pulse
	draw_set_transform(center, 0.0, Vector2(1.0, radius.y / radius.x))
	draw_circle(Vector2.ZERO, radius.x, Color(color.r, color.g, color.b, AURA_COLOR_ALPHA))
	draw_circle(Vector2.ZERO, radius.x * 0.7, Color(1.0, 1.0, 1.0, AURA_COLOR_ALPHA * 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_player_marker(top_y: float) -> void:
	var marker_color: Color = PlaceholderBody.PLAYER_MARKER_COLORS.get(_player_id, Color.WHITE)
	draw_colored_polygon(
		PackedVector2Array([Vector2(-3.0, top_y), Vector2(3.0, top_y), Vector2(0.0, top_y + 4.0)]),
		marker_color
	)
