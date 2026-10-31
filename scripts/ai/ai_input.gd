class_name AIInput
extends InputSource
## A CPU opponent. It produces the same InputFrame a keyboard would, so the
## fighter cannot tell the difference. Behaviours: recover when off the stage,
## otherwise approach, attack, shoot from range, retreat, and manage Reiatsu.
## Difficulty (level 1 to 3, 4 for the Arcade boss) changes reaction time, aggression and mistakes.

const LEVELS := {
	1: {"reaction": 22, "attack": 0.35, "special": 0.15, "mistake": 0.25, "reiatsu": false, "guard": 0.0, "shunpo": 0.0},
	2: {"reaction": 11, "attack": 0.60, "special": 0.30, "mistake": 0.10, "reiatsu": true, "guard": 0.35, "shunpo": 0.15},
	3: {"reaction": 5, "attack": 0.85, "special": 0.40, "mistake": 0.03, "reiatsu": true, "guard": 0.6, "shunpo": 0.3},
	4: {"reaction": 3, "attack": 0.95, "special": 0.50, "mistake": 0.01, "reiatsu": true, "guard": 0.75, "shunpo": 0.4}, # boss
}
const MAX_LEVEL := 4
const STAGE_SAFE_HALF_WIDTH := 150.0
const FLOOR_Y := 60.0
const STAGE_EDGE := 160.0
const EDGE_MARGIN := 15.0
const EDGE_GRAB := 12.0
const UNDER_STAGE_DEPTH := 28.0
const MELEE_RANGE := 38.0
var _follow_up_in: int = 0
const TRAP_MIN := 110.0
const TRAP_CHANCE := 0.35
const RANGED_MIN := 90.0
const RANGED_MAX := 230.0
const FACING_NUDGE := 0.4 # small push: faces the target without counting as "forward"
const DEFEND_RANGE := 55.0
const DEFEND_COOLDOWN := 30

var fighter: Fighter
var target: Fighter
var level: int = 2

var _rng := RandomNumberGenerator.new()
var _cooldown: int = 0
var _retreat_frames: int = 0
var _special_hold_left: int = 0
var _recover_cooldown: int = 0
var _guard_frames_left: int = 0
var _defend_cooldown: int = 0


func bind(self_fighter: Fighter, target_fighter: Fighter, ai_level: int, rng_seed: int = -1) -> void:
	fighter = self_fighter
	target = target_fighter
	level = clampi(ai_level, 1, MAX_LEVEL)
	if rng_seed >= 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()


func get_frame() -> InputFrame:
	var frame := InputFrame.new()
	if fighter == null or target == null or fighter.is_ko():
		return frame
	var state := fighter.get_state_name()
	if state == &"Hitstun" or state == &"Transform":
		return frame
	if _special_hold_left > 0:
		_special_hold_left -= 1
		frame.special_held = true
	if _follow_up_in > 0:
		_follow_up_in -= 1
		frame.special_just_pressed = _follow_up_in == 0 # press special again: the follow-up
	if state == &"Attack" and fighter.hit_connected and level >= 2 and _rng.randf() < 0.3:
		frame.attack_just_pressed = true # continue the combo string
	if _is_off_stage():
		_recover(frame)
	elif _guard_frames_left > 0:
		_keep_guarding(frame)
	elif _try_defend(frame):
		pass
	else:
		_fight(frame)
	return frame


func _params() -> Dictionary:
	return LEVELS[level]


func _is_off_stage() -> bool:
	var pos := fighter.global_position
	return absf(pos.x) > STAGE_SAFE_HALF_WIDTH or (pos.y > FLOOR_Y + 6.0 and not fighter.is_on_floor())


## Under the main platform the way back is around its edge, never toward the middle.
func _is_under_stage() -> bool:
	var pos := fighter.global_position
	return absf(pos.x) < STAGE_EDGE + EDGE_MARGIN and pos.y > FLOOR_Y + UNDER_STAGE_DEPTH


## Get back to the stage: swing out past the edge when under it, otherwise steer toward the
## middle, air jump, then use the up special (once per time in the air).
func _recover(frame: InputFrame) -> void:
	var pos := fighter.global_position
	var under := _is_under_stage()
	var outward := signf(pos.x) if absf(pos.x) > 4.0 else signf(target.global_position.x - pos.x)
	frame.move.x = outward if under else (-signf(pos.x) if absf(pos.x) > 4.0 else 0.0)
	_recover_cooldown -= 1
	if _recover_cooldown > 0 or fighter.velocity.y < 0.0 or pos.y < -20.0:
		return
	if fighter.can_air_jump():
		frame.up_just_pressed = true
		_recover_cooldown = 12
	elif pos.y > FLOOR_Y - 10.0 and fighter.can_use_up_special() and (not under or absf(pos.x) > STAGE_EDGE - EDGE_GRAB):
		frame.move.y = -1.0
		frame.special_just_pressed = true
		_recover_cooldown = 25


## Charging is only done while the opponent is far away; stop as soon as they close in.
## Raises the guard when the opponent attacks close by, sometimes slipping behind with a Shunpo.
func _try_defend(frame: InputFrame) -> bool:
	_defend_cooldown -= 1
	var params := _params()
	var chance: float = params["guard"]
	if chance <= 0.0 or _defend_cooldown > 0 or not fighter.is_on_floor():
		return false
	var gap := target.global_position.x - fighter.global_position.x
	if target.get_state_name() != &"Attack" or absf(gap) > DEFEND_RANGE:
		return false
	_defend_cooldown = DEFEND_COOLDOWN
	if _rng.randf() >= chance:
		return false
	var down := fighter.current_specials().down
	if down != null and down.counter_move != null and fighter.can_afford(down.cost) and _rng.randf() < 0.3:
		frame.special_just_pressed = true # a counter stance instead of a guard
		frame.move.y = 1.0
		return true
	frame.guard_just_pressed = true
	frame.guard_held = true
	if _rng.randf() < params["shunpo"]:
		frame.move.x = signf(gap) # step through them, ending up behind
		_guard_frames_left = 0
	else:
		_guard_frames_left = _rng.randi_range(10, 24)
	return true


func _keep_guarding(frame: InputFrame) -> void:
	frame.guard_held = true
	if level >= 2 and fighter.get_state_name() == &"Guard" and fighter.can_throw() and _rng.randf() < 0.25:
		frame.attack_just_pressed = true # grab the opponent through their guard
	_guard_frames_left -= 1


func _fight(frame: InputFrame) -> void:
	var gap := target.global_position.x - fighter.global_position.x
	var rise := target.global_position.y - fighter.global_position.y
	var toward := signf(gap)
	var distance := absf(gap)
	frame.move.x = toward if distance > MELEE_RANGE * 0.8 else FACING_NUDGE * toward
	if _retreat_frames > 0:
		_retreat_frames -= 1
		frame.move.x = -toward
	if rise < -50.0 and distance < 80.0 and fighter.is_on_floor() and _rng.randf() < 0.05:
		frame.up_just_pressed = true
	_cooldown -= 1
	if _cooldown <= 0:
		_decide(frame, gap, rise)


func _decide(frame: InputFrame, gap: float, rise: float) -> void:
	var params := _params()
	var reaction: int = params["reaction"]
	_cooldown = reaction + _rng.randi_range(0, reaction)
	if _rng.randf() < params["mistake"]:
		return
	var toward := signf(gap)
	var distance := absf(gap)
	if params["reiatsu"] and _manage_reiatsu(frame, distance):
		return
	if level >= 2 and _try_special2(frame, toward, distance, rise, params["special"]):
		return
	if distance <= MELEE_RANGE and absf(rise) < 50.0:
		_melee(frame, toward, distance, rise)
	elif distance >= RANGED_MIN and distance <= RANGED_MAX and _rng.randf() < params["special"]:
		frame.special_just_pressed = true
		frame.special_held = true
		frame.move.x = FACING_NUDGE * toward # neutral special, facing the target
		if _wants_trap(distance):
			frame.move.y = 1.0 # down special: lay a trap
			frame.special_held = false
			return
		var charge_special := fighter.current_specials().neutral
		if level >= 2 and charge_special != null and charge_special.follow_up != null and _rng.randf() < 0.6:
			_follow_up_in = _rng.randi_range(16, 36)
		if level >= 2 and charge_special != null and charge_special.is_chargeable():
			_special_hold_left = _rng.randi_range(0, charge_special.charge_max_frames)


## Uses a Special 2 skill that suits the distance: a dash or teleport at mid range, a shot from far
## away, the rising skill when the opponent is overhead, the down skill when they are close.
func _try_special2(frame: InputFrame, toward: float, distance: float, rise: float, special_chance: float) -> bool:
	if _rng.randf() >= special_chance * 0.6:
		return false
	var pick := Vector2.ZERO
	if rise < -70.0 and distance < 80.0:
		pick = Vector2(0.0, -1.0)
	elif distance <= MELEE_RANGE:
		pick = Vector2(0.0, 1.0)
	elif distance <= RANGED_MIN + 40.0:
		pick = Vector2(toward, 0.0)
	elif distance <= RANGED_MAX:
		pick = Vector2(FACING_NUDGE * toward, 0.0)
	else:
		return false
	frame.special2_just_pressed = true
	frame.move = pick
	return true


## Trap users lay one at mid range now and then, never stacking more than their limit.
func _wants_trap(distance: float) -> bool:
	var down := fighter.current_specials().down
	if down == null or down.projectiles.is_empty() or not down.projectiles[0].trap:
		return false
	return distance >= TRAP_MIN and fighter.live_traps().size() < down.limit_active and _rng.randf() < TRAP_CHANCE


func _melee(frame: InputFrame, toward: float, distance: float, rise: float) -> void:
	if _rng.randf() >= _params()["attack"]:
		return
	frame.attack_just_pressed = true
	frame.move.x = toward if distance > 20.0 else FACING_NUDGE * toward
	if rise < -30.0:
		frame.move.y = -1.0
	if level >= 2:
		_retreat_frames = _rng.randi_range(0, 14)


## Returns true if it used this decision on the gauge, the form or the Reiatsu meter.
func _manage_reiatsu(frame: InputFrame, distance: float) -> bool:
	if fighter.can_ultimate() and distance < 220.0 and fighter.is_on_floor():
		frame.charge_just_pressed = true
		return true
	if fighter.can_bankai() and distance > 60.0 and fighter.is_on_floor():
		frame.charge_just_pressed = true
		return true
	return false
