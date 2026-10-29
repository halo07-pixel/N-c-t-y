class_name AIInput
extends InputSource
## A CPU opponent. It produces the same InputFrame a keyboard would, so the
## fighter cannot tell the difference. Behaviours: recover when off the stage,
## otherwise approach, attack, shoot from range, retreat, and manage Reiatsu.
## Difficulty (level 1 to 3, 4 for the Arcade boss) changes reaction time, aggression and mistakes.

const LEVELS := {
	1: {"reaction": 22, "attack": 0.35, "special": 0.15, "mistake": 0.25, "reiatsu": false},
	2: {"reaction": 11, "attack": 0.60, "special": 0.30, "mistake": 0.10, "reiatsu": true},
	3: {"reaction": 5, "attack": 0.85, "special": 0.40, "mistake": 0.03, "reiatsu": true},
	4: {"reaction": 3, "attack": 0.95, "special": 0.50, "mistake": 0.01, "reiatsu": true}, # boss
}
const MAX_LEVEL := 4
const STAGE_SAFE_HALF_WIDTH := 150.0
const FLOOR_Y := 60.0
const MELEE_RANGE := 38.0
const RANGED_MIN := 90.0
const RANGED_MAX := 230.0
const FACING_NUDGE := 0.4 # small push: faces the target without counting as "forward"
const CHARGE_FRAMES := 70
const SAFE_CHARGE_DISTANCE := 150.0
const CHARGE_ABORT_DISTANCE := 100.0
const CHARGE_CHANCE := 0.6

var fighter: Fighter
var target: Fighter
var level: int = 2

var _rng := RandomNumberGenerator.new()
var _cooldown: int = 0
var _retreat_frames: int = 0
var _charge_frames_left: int = 0
var _recover_cooldown: int = 0


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
	if _is_off_stage():
		_recover(frame)
	elif _charge_frames_left > 0:
		_keep_charging(frame)
	else:
		_fight(frame)
	return frame


func _params() -> Dictionary:
	return LEVELS[level]


func _is_off_stage() -> bool:
	var pos := fighter.global_position
	return absf(pos.x) > STAGE_SAFE_HALF_WIDTH or (pos.y > FLOOR_Y + 6.0 and not fighter.is_on_floor())


## Get back to the stage: steer toward the middle, air jump, then use the up special.
func _recover(frame: InputFrame) -> void:
	var pos := fighter.global_position
	frame.move.x = -signf(pos.x) if absf(pos.x) > 4.0 else 0.0
	_recover_cooldown -= 1
	if _recover_cooldown > 0 or fighter.velocity.y < 0.0 or pos.y < -20.0:
		return
	if fighter.can_air_jump():
		frame.up_just_pressed = true
		_recover_cooldown = 12
	elif pos.y > FLOOR_Y - 10.0:
		frame.move.y = -1.0
		frame.special_just_pressed = true
		_recover_cooldown = 25


## Charging is only done while the opponent is far away; stop as soon as they close in.
func _keep_charging(frame: InputFrame) -> void:
	var distance := absf(target.global_position.x - fighter.global_position.x)
	if distance < CHARGE_ABORT_DISTANCE or fighter.reiatsu >= Reiatsu.ULTIMATE_COST:
		_charge_frames_left = 0
		return
	frame.charge_held = true
	frame.charge_just_pressed = _charge_frames_left == CHARGE_FRAMES
	_charge_frames_left -= 1


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
	if distance <= MELEE_RANGE and absf(rise) < 50.0:
		_melee(frame, toward, distance, rise)
	elif distance >= RANGED_MIN and distance <= RANGED_MAX and _rng.randf() < params["special"]:
		frame.special_just_pressed = true
		frame.move.x = FACING_NUDGE * toward # neutral special, facing the target


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
	var wants_charge := (
		fighter.is_bankai() and fighter.reiatsu < Reiatsu.ULTIMATE_COST and distance > SAFE_CHARGE_DISTANCE
	)
	if wants_charge and fighter.is_on_floor() and _rng.randf() < CHARGE_CHANCE:
		_charge_frames_left = CHARGE_FRAMES
		return true
	return false
