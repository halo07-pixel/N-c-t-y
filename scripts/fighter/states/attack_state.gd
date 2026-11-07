extends FighterState
## Performing one attack or special, frame by frame:
## startup (harmless wind-up), active (hitbox / projectiles / dash), recovery.
## The move is either queued by the fighter (an ultimate) or picked from the
## attack or special button and the held direction.

var _move: MoveData
var _special: SpecialData
var _frame: int = 0
var _aerial: bool = false
var _charge: int = 0
var _released_charge: float = 0.0
var _chain_buffered: bool = false
## A stream (hold special to keep firing): shots fired so far and frames to wait for the next.
var _stream_shots: int = 1
var _stream_wait: int = 0
## A spin (hold special to keep the hitbox turning): frames spent and frames to wait for the next strike.
var _spin_spent: int = 0
var _spin_wait: int = 0
## The frame of this move on which the attack key was pressed to continue the string.
var _press_frame: int = 0
## Where the fighter was on the previous active frame (a dash covers the ground in between).
var _path_from: Vector2 = Vector2.ZERO

const FREE_CHARGE_FALLBACK := 0.6


func enter(_previous: StringName) -> void:
	fighter.face_input()
	_aerial = not fighter.is_on_floor()
	_move = fighter.take_queued_move()
	var chosen_by_button := _move == null
	if chosen_by_button:
		_move = fighter.pick_move(_aerial)
	_special = _move as SpecialData
	Events.fighter_attack_started.emit(fighter.player_id, _move.display_name)
	_frame = 0
	_chain_buffered = false
	fighter.hit_connected = false
	fighter.hit_confirm_left = 0
	_charge = 0
	_released_charge = 0.0
	_take_perfect_link()
	if chosen_by_button and _special != null:
		fighter.try_spend_reiatsu(_special.cost)
		fighter.begin_special_use(_special, _aerial)
	if _special != null and _special.face_enemy:
		fighter.face_nearest_enemy()
	elif _special != null and _special.flip_facing:
		fighter.facing = -fighter.facing
	if _special != null and _special.cinematic_frames > 0:
		Events.ultimate_started.emit(fighter.player_id, _special.cinematic_frames, _special.title)


func exit() -> void:
	fighter.gathering = false
	fighter.armored = false
	fighter.empower_scale = 1.0
	fighter.special_charge = 0.0
	fighter.set_counter(null)
	fighter.hitbox.deactivate()
	fighter.set_attack_visual(&"", &"")


func physics_update(delta: float) -> StringName:
	var cut_short := _apply_movement(delta)
	if cut_short != &"":
		return cut_short
	var cancelled := _check_cancel()
	if cancelled != &"":
		return cancelled
	var follow := _check_follow_up()
	if follow != &"":
		return follow
	var chained := _check_chain()
	if chained != &"":
		return chained
	if fighter.slow_skips_frame():
		return &"" # in a snow veil the attack plays slower too
	_advance_move()
	_update_counter()
	if _frame >= _move.total_frames():
		return &"Idle" if fighter.is_on_floor() else &"Fall"
	return &""


## A counter stance catches hits during its active frames.
func _update_counter() -> void:
	if _special == null or _special.counter_move == null:
		return
	var in_window := _frame > _move.startup_frames and _frame <= _move.startup_frames + _move.active_frames
	fighter.set_counter(_special.counter_move if in_window else null)


## Moves the fighter for this tick. Returns a state name if the attack is cut short.
func _apply_movement(delta: float) -> StringName:
	var stats := fighter.data
	if _aerial:
		var drift := fighter.input.move.x
		fighter.apply_horizontal(delta, drift, stats.air_speed, stats.air_accel, stats.air_friction)
		fighter.apply_gravity(delta, fighter.is_fast_falling)
		if fighter.is_on_floor() and fighter.velocity.y >= 0.0:
			fighter.notify_landed()
			return &"Idle"
		return &""
	fighter.apply_horizontal(delta, 0.0, stats.run_speed, stats.ground_accel, stats.ground_friction)
	fighter.apply_gravity(delta)
	if not fighter.is_on_floor():
		return &"Fall"
	return &""


## Cancels: the charge key while the attack is hitting is a Gauge Cancel (the fighter is free at once);
## the skill key right after a normal attack hit cancels it into a zone/rush/combo/heavy skill.
func _check_cancel() -> StringName:
	if fighter.input.charge_just_pressed and fighter.can_gauge_cancel():
		fighter.gauge_cancel()
		return &"Idle" if fighter.is_on_floor() else &"Fall"
	if _special == null and not _move.is_throw and fighter.skill_cancel_target() != null:
		return &"Attack" # the new attack picks the same skill from the same key press
	return &""


## Pressing special again after the active frames begin plays the follow-up, if it can be paid.
func _check_follow_up() -> StringName:
	if _special == null or _special.follow_up == null or not _special_pressed():
		return &""
	var first := _move.startup_frames
	if _frame <= first or _frame > first + _special.follow_up_window:
		return &""
	if not fighter.try_spend_reiatsu(_special.follow_up_cost):
		return &""
	fighter.queue_move(_special.follow_up)
	return &"Attack"


func _special_pressed() -> bool:
	return fighter.input.special_just_pressed


func _special_held() -> bool:
	return fighter.input.special_held


## Where this attack is in its move, for the CPU's timing: the frame and the frame the hit ends on.
func timing() -> Vector2i:
	if _move == null:
		return Vector2i(-1, -1)
	return Vector2i(_frame, _move.startup_frames + _move.active_frames)


func current_move() -> MoveData:
	return _move


func move_name() -> String:
	return _move.display_name if _move != null else ""


## Pressing attack again once the active frames are over continues a combo string: after a hit, with
## the next move picked by the held direction. A press during the active frames is remembered.
func _check_chain() -> StringName:
	if _special != null or not _move.has_chain():
		return &""
	if fighter.input.attack_just_pressed and _frame >= _move.startup_frames:
		if not _chain_buffered:
			_press_frame = _frame
		_chain_buffered = true
	if not _chain_buffered or _frame < _move.startup_frames + _move.active_frames:
		return &""
	if _move.chain_requires_hit and not fighter.hit_connected:
		return &""
	var next := _move.chain_for(fighter.input.move.y)
	if next == null:
		return &""
	fighter.queue_move(next)
	var on_time := NormalRiders.is_perfect(_press_frame, _move.startup_frames + _move.active_frames)
	fighter.rhythm_scale = 1.0 + _move.rhythm_bonus if _move.rhythm_bonus > 0.0 and on_time else 1.0
	return &"Attack"


## A move linked on time hits harder and pays back a little Reiatsu (Ichigo's rhythm).
func _take_perfect_link() -> void:
	if fighter.rhythm_scale <= 1.0:
		return
	fighter.empower_scale = maxf(fighter.empower_scale, fighter.rhythm_scale)
	fighter.rhythm_scale = 1.0
	fighter.add_reiatsu(NormalRiders.RHYTHM_REIATSU)
	Events.mechanic_triggered.emit(fighter.player_id, &"rhythm", fighter.global_position + Vector2(float(fighter.facing) * 22.0, -16.0))


## At the end of the wind-up of a chargeable special: keep the move waiting while the special
## button is held, until the charge is full (or as far as the fighter can pay for).
func _hold_charge() -> bool:
	var share := _special.max_charge_share(fighter.can_afford(_special.charge_cost))
	var level := float(_charge) / float(_special.charge_max_frames)
	if _special_held() and level < share:
		_charge += 1
		fighter.special_charge = float(_charge) / float(_special.charge_max_frames)
		return true
	if _charge > 0:
		_released_charge = clampf(level, 0.0, 1.0)
		if _released_charge >= 0.999 and not fighter.try_spend_reiatsu(_special.charge_cost):
			_released_charge = FREE_CHARGE_FALLBACK
		fighter.special_charge = 0.0
		_charge = 0
	return false


func _advance_move() -> void:
	var active_start := _move.startup_frames
	var active_end := _move.startup_frames + _move.active_frames
	if _hold_stream() or _hold_spin():
		return
	if _special != null and _special.is_chargeable() and _frame == active_start and _released_charge == 0.0:
		if _hold_charge():
			fighter.set_attack_visual(_move.direction, &"startup", _aerial, true)
			return
	if _frame == active_start:
		_begin_active()
	elif _frame == active_end:
		fighter.hitbox.deactivate()
	elif NormalRiders.is_flurry_frame(_move, _frame):
		fighter.hitbox.strike_again(_move, fighter.facing, fighter.outgoing_multiplier() * fighter.empower_scale)
	if _special != null and _frame > active_start:
		_spawn_delayed()
	if _special != null and _frame >= active_start and _frame < active_end:
		_hold_special_motion()
	if _frame > active_start and _frame <= active_end and _moves_while_hitting():
		fighter.hitbox.cover_path(_path_from, fighter.global_position)
	_path_from = fighter.global_position
	fighter.gathering = _special != null and _special.gather and _frame < active_start
	fighter.armored = _move.armor and _frame < active_end
	fighter.set_attack_visual(_move.direction, _phase(active_start, active_end), _aerial, _special != null)
	_frame += 1


func _begin_active() -> void:
	var origin := fighter.global_position
	_path_from = origin
	if _special != null:
		fighter.global_position += Vector2(_special.teleport.x * float(fighter.facing), _special.teleport.y)
	if _move.hitbox_size.x > 0.0:
		fighter.hitbox.activate(_move, fighter.facing, fighter.outgoing_multiplier() * fighter.empower_scale)
		if fighter.global_position != origin:
			fighter.hitbox.cover_path(origin, fighter.global_position) # a teleport hurts along its path
	if _move.lunge_speed != 0.0:
		fighter.velocity.x = float(fighter.facing) * _move.lunge_speed
	if _special == null:
		return
	if _special.teleport.y < 0.0:
		fighter.velocity.y = minf(fighter.velocity.y, 0.0) # a teleport up cancels the fall
	if _special.self_velocity.y != 0.0:
		fighter.velocity.y = _special.self_velocity.y
		_aerial = true # leaving the ground on purpose must not cancel the move
	if _special.release_frames > 0:
		fighter.begin_release(_special)
	if _special.command_speed > 0.0:
		fighter.command_projectiles(_special.command_speed, _special.command_recall)
	if _special.limit_active > 0:
		fighter.prepare_trap(_special)
	for projectile_data in _special.projectiles:
		if _special.is_stream() and projectile_data != _special.projectiles[0]:
			continue # a stream fires its projectiles one at a time, in turn
		if projectile_data.delay_frames <= 0:
			fighter.spawn_projectile(projectile_data, _special, _released_charge)


## Once the first shot is out, a held special button keeps a stream going: the move waits at the end
## of its active frames and fires the next projectile every `stream_interval` frames.
func _hold_stream() -> bool:
	if _special == null or not _special.is_stream() or _frame != _move.startup_frames + _move.active_frames:
		return false
	if _stream_wait > 0:
		_stream_wait -= 1
		return true
	if _special_held() and _stream_shots < _special.stream_max_shots and fighter.try_spend_reiatsu(_special.stream_cost):
		var shot := _special.projectiles[_stream_shots % _special.projectiles.size()]
		_stream_shots += 1
		_stream_wait = _special.stream_interval
		fighter.spawn_projectile(shot, _special, 0.0)
		return true
	return false


## Renji's ring: while special stays held at the end of the active frames the hitbox strikes again
## every `spin_gap` frames, until the time runs out, the Reiatsu does, or the button is let go.
func _hold_spin() -> bool:
	if _special == null or not _special.is_spin() or _frame != _move.startup_frames + _move.active_frames:
		return false
	if _spin_wait > 0:
		_spin_wait -= 1
		_spin_spent += 1
		return true
	if _special_held() and _spin_spent < _special.spin_frames and fighter.try_spend_reiatsu(_special.spin_cost):
		_spin_wait = _special.spin_gap
		fighter.hitbox.strike_again(_move, fighter.facing, fighter.outgoing_multiplier() * fighter.empower_scale)
		Events.mechanic_triggered.emit(fighter.player_id, &"spin", fighter.global_position + Vector2(0.0, -16.0))
		return true
	return false


## The projectiles of a move that fires in beats appear `delay_frames` after the active frames began.
func _spawn_delayed() -> void:
	for projectile_data in _special.projectiles:
		if projectile_data.delay_frames > 0 and _frame == _move.startup_frames + projectile_data.delay_frames:
			fighter.spawn_projectile(projectile_data, _special, _released_charge)


## True for moves that carry the fighter while the hitbox is out (a lunge or a dash).
func _moves_while_hitting() -> bool:
	if _move.lunge_speed != 0.0:
		return true
	return _special != null and (_special.self_velocity != Vector2.ZERO)


## Dashes keep pushing for the whole active window; air dashes ignore gravity.
func _hold_special_motion() -> void:
	if _special.self_velocity.x != 0.0:
		fighter.velocity.x = float(fighter.facing) * _special.self_velocity.x
	if _special.ignore_gravity:
		fighter.velocity.y = 0.0


func _phase(active_start: int, active_end: int) -> StringName:
	if _frame < active_start:
		return &"startup"
	if _frame < active_end:
		return &"active"
	return &"recovery"
