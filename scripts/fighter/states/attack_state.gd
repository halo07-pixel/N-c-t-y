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

const FREE_CHARGE_FALLBACK := 0.6


func enter(_previous: StringName) -> void:
	fighter.face_input()
	_aerial = not fighter.is_on_floor()
	_move = fighter.take_queued_move()
	var chosen_by_button := _move == null
	if chosen_by_button:
		_move = fighter.pick_move(_aerial)
	_special = _move as SpecialData
	_frame = 0
	_chain_buffered = false
	fighter.hit_connected = false
	_charge = 0
	_released_charge = 0.0
	if chosen_by_button and _special != null:
		fighter.try_spend_reiatsu(_special.cost)
		fighter.begin_special_use(_special, _aerial)
	if _special != null and _special.flip_facing:
		fighter.facing = -fighter.facing
	if _special != null and _special.cinematic_frames > 0:
		Events.ultimate_started.emit(fighter.player_id, _special.cinematic_frames, _special.title)


func exit() -> void:
	fighter.special_charge = 0.0
	fighter.set_counter(null)
	fighter.hitbox.deactivate()
	fighter.set_attack_visual(&"", &"")


func physics_update(delta: float) -> StringName:
	var cut_short := _apply_movement(delta)
	if cut_short != &"":
		return cut_short
	var follow := _check_follow_up()
	if follow != &"":
		return follow
	var chained := _check_chain()
	if chained != &"":
		return chained
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


## Pressing special again after the active frames begin plays the follow-up, if it can be paid.
func _check_follow_up() -> StringName:
	if _special == null or _special.follow_up == null or not fighter.input.special_just_pressed:
		return &""
	var first := _move.startup_frames
	if _frame <= first or _frame > first + _special.follow_up_window:
		return &""
	if not fighter.try_spend_reiatsu(_special.follow_up_cost):
		return &""
	fighter.queue_move(_special.follow_up)
	return &"Attack"


func move_name() -> String:
	return _move.display_name if _move != null else ""


## Pressing attack again once the active frames are over continues a combo string: after a hit, with
## the next move picked by the held direction. A press during the active frames is remembered.
func _check_chain() -> StringName:
	if _special != null or not _move.has_chain():
		return &""
	if fighter.input.attack_just_pressed and _frame >= _move.startup_frames:
		_chain_buffered = true
	if not _chain_buffered or _frame < _move.startup_frames + _move.active_frames:
		return &""
	if _move.chain_requires_hit and not fighter.hit_connected:
		return &""
	var next := _move.chain_for(fighter.input.move.y)
	if next == null:
		return &""
	fighter.queue_move(next)
	return &"Attack"


## At the end of the wind-up of a chargeable special: keep the move waiting while the special
## button is held, until the charge is full (or as far as the fighter can pay for).
func _hold_charge() -> bool:
	var share := _special.max_charge_share(fighter.can_afford(_special.charge_cost))
	var level := float(_charge) / float(_special.charge_max_frames)
	if fighter.input.special_held and level < share:
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
	if _special != null and _special.is_chargeable() and _frame == active_start and _released_charge == 0.0:
		if _hold_charge():
			fighter.set_attack_visual(_move.direction, &"startup", _aerial, true)
			return
	if _frame == active_start:
		_begin_active()
	elif _frame == active_end:
		fighter.hitbox.deactivate()
	if _special != null and _frame >= active_start and _frame < active_end:
		_hold_special_motion()
	fighter.set_attack_visual(_move.direction, _phase(active_start, active_end), _aerial, _special != null)
	_frame += 1


func _begin_active() -> void:
	if _move.hitbox_size.x > 0.0:
		fighter.hitbox.activate(_move, fighter.facing, fighter.damage_multiplier)
	if _move.lunge_speed != 0.0:
		fighter.velocity.x = float(fighter.facing) * _move.lunge_speed
	if _special == null:
		return
	fighter.global_position += Vector2(_special.teleport.x * float(fighter.facing), _special.teleport.y)
	if _special.teleport.y < 0.0:
		fighter.velocity.y = minf(fighter.velocity.y, 0.0) # a teleport up cancels the fall
	if _special.self_velocity.y != 0.0:
		fighter.velocity.y = _special.self_velocity.y
		_aerial = true # leaving the ground on purpose must not cancel the move
	if _special.command_speed > 0.0:
		fighter.command_projectiles(_special.command_speed)
	if _special.limit_active > 0:
		fighter.prepare_trap(_special)
	for projectile_data in _special.projectiles:
		fighter.spawn_projectile(projectile_data, _special, _released_charge)


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
