extends FighterState
## Performing one attack or special, frame by frame:
## startup (harmless wind-up), active (hitbox / projectiles / dash), recovery.
## The move is either queued by the fighter (an ultimate) or picked from the
## attack or special button and the held direction.

var _move: MoveData
var _special: SpecialData
var _frame: int = 0
var _aerial: bool = false


func enter(_previous: StringName) -> void:
	fighter.face_input()
	_aerial = not fighter.is_on_floor()
	_move = fighter.take_queued_move()
	if _move == null:
		_move = fighter.pick_move(_aerial)
	_special = _move as SpecialData
	_frame = 0
	if _special != null and _special.cinematic_frames > 0:
		Events.ultimate_started.emit(fighter.player_id, _special.cinematic_frames, _special.title)


func exit() -> void:
	fighter.hitbox.deactivate()
	fighter.set_attack_visual(&"", &"")


func physics_update(delta: float) -> StringName:
	var cut_short := _apply_movement(delta)
	if cut_short != &"":
		return cut_short
	_advance_move()
	if _frame >= _move.total_frames():
		return &"Idle" if fighter.is_on_floor() else &"Fall"
	return &""


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


func _advance_move() -> void:
	var active_start := _move.startup_frames
	var active_end := _move.startup_frames + _move.active_frames
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
	if _special.self_velocity.y != 0.0:
		fighter.velocity.y = _special.self_velocity.y
		_aerial = true # leaving the ground on purpose must not cancel the move
	for projectile_data in _special.projectiles:
		fighter.spawn_projectile(projectile_data, _special)


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
