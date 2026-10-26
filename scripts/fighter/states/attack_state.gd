extends FighterState
## Performing one attack from the fighter's MoveSet, frame by frame:
## startup (harmless wind-up), active (hitbox on), recovery (cool-down).

var _move: MoveData
var _frame: int = 0
var _aerial: bool = false


func enter(_previous: StringName) -> void:
	fighter.face_input()
	_aerial = not fighter.is_on_floor()
	_move = fighter.data.moveset.select(_aerial, fighter.input.move)
	_frame = 0


func exit() -> void:
	fighter.hitbox.deactivate()
	fighter.set_attack_visual(&"", &"")


func physics_update(delta: float) -> StringName:
	var landing := _apply_movement(delta)
	if landing != &"":
		return landing
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
		fighter.hitbox.activate(_move, fighter.facing)
		if _move.lunge_speed != 0.0:
			fighter.velocity.x = float(fighter.facing) * _move.lunge_speed
	elif _frame == active_end:
		fighter.hitbox.deactivate()
	fighter.set_attack_visual(_move.direction, _phase(active_start, active_end))
	_frame += 1


func _phase(active_start: int, active_end: int) -> StringName:
	if _frame < active_start:
		return &"startup"
	if _frame < active_end:
		return &"active"
	return &"recovery"
