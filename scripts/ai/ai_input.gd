class_name AIInput
extends InputSource
## A CPU opponent. It produces the same InputFrame a keyboard would, so the
## fighter cannot tell the difference. Behaviours: recover when off the stage,
## otherwise approach, attack, shoot from range, retreat, and manage Reiatsu.
## Difficulty (level 1 to 3 in menus, 4 for the Arcade boss) changes reaction time, aggression and mistakes.
## Every level uses the full set of tactics; from level 2 it also reads its opponent's habits, picks
## when to transform and stands where its Bankai works best; level 3+ also dodges shots, feints and
## sets traps for fighters it has launched.

const LEVELS := {
	1: {"reaction": 5, "attack": 0.85, "special": 0.40, "mistake": 0.03, "reiatsu": true, "guard": 0.6, "dash": 0.20},
	2: {"reaction": 4, "attack": 0.90, "special": 0.45, "mistake": 0.02, "reiatsu": true, "guard": 0.7, "dash": 0.25},
	3: {"reaction": 3, "attack": 0.95, "special": 0.50, "mistake": 0.01, "reiatsu": true, "guard": 0.8, "dash": 0.30},
	4: {"reaction": 2, "attack": 1.00, "special": 0.55, "mistake": 0.0, "reiatsu": true, "guard": 0.85, "dash": 0.35}, # boss
}
const MAX_LEVEL := 4
const STAGE_SAFE_HALF_WIDTH := 150.0
const FLOOR_Y := 60.0
const STAGE_EDGE := 280.0
const EDGE_MARGIN := 15.0
const EDGE_GRAB := 12.0
const UNDER_STAGE_DEPTH := 28.0
const MELEE_RANGE := 38.0
const FOLLOW_UP_CHANCE := 0.6
var _follow_up_in: int = 0
## The skill whose second press is pending: when that press has a third (a pull, then a slam) it is planned too.
var _pending_skill: SpecialData
## Frames to keep holding special after the follow-up press, when the follow-up is a stream.
var _follow_up_hold: int = 0
const TRAP_MIN := 110.0
const TRAP_CHANCE := 0.35
const OKI_TRAP_CHANCE := 0.7
const FEINT_CHANCE := 0.25
const DODGE_COOLDOWN := 40
const DODGE_REACH := 80.0
const RANGED_MIN := 90.0
const RANGED_MAX := 230.0
const FACING_NUDGE := 0.4 # small push: faces the target without counting as "forward"
const DEFEND_RANGE := 55.0
const DEFEND_COOLDOWN := 30
const CANCEL_SKILL_CHANCE := 0.12
const CANCEL_GAUGE_CHANCE := 0.05
const PARRY_HOLD_MIN := 11 # longer than the parry window, so the guard is never locked
const DASH_MIN_DISTANCE := 90.0

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
var _reader := CpuReader.new()
var _grab_bias: bool = false
var _feint_in: int = 0
var _dodge_cooldown: int = 0
var _gauge_full_frames: int = 0


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
	_reader.observe(target.get_state_name(), target.is_on_floor())
	_gauge_full_frames = _gauge_full_frames + 1 if fighter.can_bankai() else 0
	var state := fighter.get_state_name()
	if state == &"Hitstun" or state == &"Transform":
		return frame
	if _special_hold_left > 0:
		_special_hold_left -= 1
		frame.special_held = true
	if _follow_up_in > 0:
		_follow_up_in -= 1
		frame.special_just_pressed = _follow_up_in == 0 # press special again: the follow-up
		if _follow_up_in == 0 and _pending_skill != null and _pending_skill.follow_up != null and _pending_skill.follow_up.follow_up != null:
			_follow_up_in = _pending_skill.follow_up.startup_frames + _rng.randi_range(3, 8)
			_pending_skill = _pending_skill.follow_up
		if _follow_up_in == 0 and _follow_up_hold > 0:
			_special_hold_left = _rng.randi_range(4, _follow_up_hold)
			_follow_up_hold = 0
	if state == &"Attack" and fighter.hit_connected and fighter.attack_move() != null and fighter.attack_move().rhythm_bonus > 0.0:
		var timing := fighter.attack_timing()
		frame.attack_just_pressed = CpuTactics.rhythm_press(fighter.attack_move(), timing.x, timing.y, _rng) # in the beat: a perfect link
	elif state == &"Attack" and fighter.hit_connected and _rng.randf() < 0.3:
		frame.attack_just_pressed = true # continue the combo string
	elif state == &"Attack" and fighter.hit_confirm_left > 0:
		_try_cancel(frame)
	if _is_off_stage():
		_recover(frame)
	elif _guard_frames_left > 0:
		_keep_guarding(frame)
	elif level >= 3 and _dodge_projectile(frame):
		pass
	elif _try_defend(frame):
		pass
	else:
		_fight(frame)
	return frame


## Level 3+ cancels a hit that just connected into a skill, now and then, or pays for a Gauge Cancel.
func _try_cancel(frame: InputFrame) -> void:
	if fighter.can_gauge_cancel() and _rng.randf() < CANCEL_GAUGE_CHANCE:
		frame.charge_just_pressed = true
		return
	if _rng.randf() >= CANCEL_SKILL_CHANCE:
		return
	frame.special_just_pressed = true
	frame.move = Vector2(FACING_NUDGE * signf(target.global_position.x - fighter.global_position.x), 0.0)


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
## Raises the guard when the opponent attacks close by, a parry when the guard goes up just as the hit arrives.
func _try_defend(frame: InputFrame) -> bool:
	_defend_cooldown -= 1
	var params := _params()
	var chance: float = params["guard"]
	if level >= 2:
		chance = minf(chance + float(_reader.advice()["defend"]), 0.95)
	if chance <= 0.0 or _defend_cooldown > 0 or not fighter.is_on_floor():
		return false
	var gap := target.global_position.x - fighter.global_position.x
	if target.get_state_name() != &"Attack" or absf(gap) > DEFEND_RANGE:
		return false
	_defend_cooldown = DEFEND_COOLDOWN
	if _rng.randf() >= chance:
		return false
	var down := fighter.current_specials().down
	if down != null and down.counter_move != null and fighter.can_afford(down.cost) and _rng.randf() < 0.6:
		frame.special_just_pressed = true # a counter stance instead of a guard
		frame.move.y = 1.0
		return true
	frame.guard_just_pressed = true
	frame.guard_held = true
	_guard_frames_left = _rng.randi_range(PARRY_HOLD_MIN, 24) # holds past the parry window, then drops
	return true


func _keep_guarding(frame: InputFrame) -> void:
	frame.guard_held = true
	if fighter.get_state_name() == &"Guard" and fighter.can_throw() and _rng.randf() < (0.6 if _grab_bias else 0.25):
		frame.attack_just_pressed = true # grab the opponent through their guard
	_guard_frames_left -= 1
	if _guard_frames_left <= 0:
		_grab_bias = false


func _fight(frame: InputFrame) -> void:
	var gap := target.global_position.x - fighter.global_position.x
	var rise := target.global_position.y - fighter.global_position.y
	var toward := signf(gap)
	var distance := absf(gap)
	frame.move.x = toward if distance > MELEE_RANGE * 0.8 else FACING_NUDGE * toward
	if _retreat_frames > 0:
		_retreat_frames -= 1
		frame.move.x = -toward
	elif level >= 2 and fighter.is_bankai():
		frame.move.x = _bankai_spacing_move(toward, distance, frame.move.x)
	if _feint_in > 0:
		_feint_in -= 1
		if _feint_in == 0:
			_retreat_frames = 14 # the rush was a bluff
	if level >= 2 and _try_mixup(frame, distance):
		return
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
	if distance > DASH_MIN_DISTANCE and _retreat_frames <= 0 and fighter.can_dash() and _rng.randf() < params["dash"]:
		frame.dash_just_pressed = true # close the gap with a dash
		frame.dash_direction = int(toward)
		if level >= 3 and distance < 150.0 and _rng.randf() < FEINT_CHANCE:
			_feint_in = 8 # ...or pretend to
		return
	if level >= 3 and target.get_state_name() == &"Hitstun" and distance >= TRAP_MIN and _wants_trap(distance, OKI_TRAP_CHANCE):
		frame.special_just_pressed = true # lay a trap where the launched fighter will land
		frame.move = Vector2(FACING_NUDGE * toward, 1.0)
		return
	if level >= 2 and _anti_air(frame, toward, distance, rise):
		return
	if _try_skill(frame, toward, distance, rise, params["special"]):
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
		if charge_special != null and charge_special.follow_up != null:
			_plan_follow_up(charge_special, gap_distance(), 12)
		if charge_special != null and charge_special.is_chargeable() and _follow_up_in <= 0:
			_special_hold_left = _rng.randi_range(0, charge_special.charge_max_frames)


## Uses a skill that suits the distance: a rush at mid range, a shot from far away, the rising
## skill when the opponent is overhead, the down skill when they are close.
func _try_skill(frame: InputFrame, toward: float, distance: float, rise: float, special_chance: float) -> bool:
	if _recall_planted(frame, toward, distance):
		return true
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
	frame.special_just_pressed = true
	frame.move = pick
	var specials := fighter.current_specials()
	if specials != null and specials.select(pick) != null and specials.select(pick).follow_up != null:
		_plan_follow_up(specials.select(pick), distance, 0)
		return true
	var delay := follow_up_delay(specials.select(pick) if specials != null else null, _rng)
	if delay >= 0 and _rng.randf() < FOLLOW_UP_CHANCE:
		_follow_up_in = delay # the second press: dance back, chop, shockwave...
		_follow_up_hold = stream_hold_frames(specials.select(pick) if specials != null else null)
	return true


## Blades planted on the floor are called home when the opponent walks up to them (level 3+).
func _recall_planted(frame: InputFrame, toward: float, distance: float) -> bool:
	var specials := fighter.current_specials()
	if specials == null or specials.forward == null or not specials.forward.recall_planted:
		return false
	if not fighter.has_planted_projectiles() or distance > CpuTactics.NEAR + 40.0 or _rng.randf() > 0.25:
		return false
	frame.special_just_pressed = true
	frame.move = Vector2(toward, 0.0)
	return true


func gap_distance() -> float:
	return absf(target.global_position.x - fighter.global_position.x)


## Level 3+: the second press of a skill is planned from what the skill is for (CpuTactics).
func _plan_follow_up(skill: SpecialData, distance: float, extra_delay: int) -> void:
	var plan := CpuTactics.plan(skill, {
		"distance": distance,
		"target_attacking": target.get_state_name() == &"Attack",
		"self_percent": fighter.percent,
		"target_percent": target.percent,
		"released": fighter.release_frames > 0,
	}, _rng)
	if plan["use"]:
		_pending_skill = skill
		_follow_up_in = int(plan["delay"]) + extra_delay
		_follow_up_hold = int(plan["hold"])


## How long to hold special after pressing it for `skill`'s follow-up, when that is a stream (else 0).
static func stream_hold_frames(skill: SpecialData) -> int:
	if skill == null or skill.follow_up == null:
		return 0
	if skill.follow_up.is_spin():
		return skill.follow_up.spin_frames
	if not skill.follow_up.is_stream():
		return 0
	return skill.follow_up.stream_interval * maxi(1, skill.follow_up.stream_max_shots - 1)


## Frames to wait before pressing special again for `skill`'s follow-up (inside its window, once the
## wind-up is over), or -1 when the skill has none.
static func follow_up_delay(skill: SpecialData, rng: RandomNumberGenerator) -> int:
	if skill == null or skill.follow_up == null:
		return -1
	return skill.startup_frames + rng.randi_range(2, maxi(3, skill.follow_up_window - 4))


## Trap users lay one at mid range now and then, never stacking more than their limit.
func _wants_trap(distance: float, chance: float = TRAP_CHANCE) -> bool:
	var down := fighter.current_specials().down
	if down == null or down.projectiles.is_empty() or not down.projectiles[0].trap:
		return false
	return distance >= TRAP_MIN and fighter.live_traps().size() < down.limit_active and _rng.randf() < chance


func _melee(frame: InputFrame, toward: float, distance: float, rise: float) -> void:
	var poke: float = _params()["attack"]
	if level >= 2:
		poke *= float(_reader.advice()["poke_scale"]) # a guarder is not worth poking at
	if _rng.randf() >= poke:
		return
	frame.attack_just_pressed = true
	frame.move.x = toward if distance > 20.0 else FACING_NUDGE * toward
	if rise < -30.0:
		frame.move.y = -1.0
	if fighter.release_frames <= 0 and not _keeps_close():
		_retreat_frames = _rng.randi_range(0, 14) # in a release he never backs off


## Returns true if it used this decision on the gauge, the form or the Reiatsu meter.
func _manage_reiatsu(frame: InputFrame, distance: float) -> bool:
	var situation := {
		"distance": distance,
		"target_attacking": target.get_state_name() == &"Attack",
		"self_percent": fighter.percent,
		"target_percent": target.percent,
		"waited": _gauge_full_frames,
		"form_frames_left": fighter.bankai_frames_left,
	}
	if fighter.can_ultimate() and fighter.is_on_floor() and CpuTactics.ultimate_wanted(level, situation):
		frame.charge_just_pressed = true
		return true
	if fighter.can_bankai() and fighter.is_on_floor() and CpuTactics.bankai_wanted(level, situation):
		frame.charge_just_pressed = true
		return true
	return false


## Where to stand while the Bankai lasts so its own mechanic works (see CpuTactics.bankai_spacing).
func _bankai_spacing_move(toward: float, distance: float, current: float) -> float:
	var spacing := CpuTactics.bankai_spacing(fighter.data.mechanic)
	if spacing == Vector2.ZERO:
		return current
	if distance > spacing.y:
		return toward
	if distance < spacing.x:
		return -toward
	return FACING_NUDGE * toward


## Fighters whose Bankai wants them in the opponent's face never back off.
func _keeps_close() -> bool:
	if not fighter.is_bankai():
		return false
	var spacing := CpuTactics.bankai_spacing(fighter.data.mechanic)
	return spacing != Vector2.ZERO and spacing.x <= 0.0


## Against someone who hides behind the guard, step up and grab instead of poking at it.
func _try_mixup(frame: InputFrame, distance: float) -> bool:
	if _guard_frames_left > 0 or target.get_state_name() != &"Guard" or distance > 34.0 or not fighter.is_on_floor():
		return false
	if _rng.randf() >= float(_reader.advice()["mixup"]) * 0.3:
		return false
	_grab_bias = true
	frame.guard_just_pressed = true
	frame.guard_held = true
	_guard_frames_left = 8
	return true


## Against someone who keeps jumping, hit upward when they are above and close.
func _anti_air(frame: InputFrame, toward: float, distance: float, rise: float) -> bool:
	if target.is_on_floor() or rise > -20.0 or distance > 70.0:
		return false
	if _rng.randf() >= float(_reader.advice()["anti_air"]):
		return false
	frame.attack_just_pressed = true
	frame.move = Vector2(FACING_NUDGE * toward, -1.0)
	return true


## Hops over a low shot that is about to reach us (level 3+).
func _dodge_projectile(frame: InputFrame) -> bool:
	_dodge_cooldown -= 1
	if _dodge_cooldown > 0 or not fighter.is_on_floor():
		return false
	for node in fighter.get_tree().get_nodes_in_group(Projectile.SHOT_GROUP):
		var shot := node as Projectile
		if shot == null or shot.owner_id == fighter.player_id or shot.is_trap() or shot.is_queued_for_deletion():
			continue
		var offset := fighter.global_position - shot.global_position
		var heading := signf(shot._velocity.x)
		if heading == 0.0 or signf(offset.x) != heading or absf(offset.x) > DODGE_REACH:
			continue
		if absf(offset.y + 14.0) > 22.0 or shot.is_planted_blade():
			continue
		if _rng.randf() < 0.7:
			frame.up_just_pressed = true
			_dodge_cooldown = DODGE_COOLDOWN
			return true
	return false
