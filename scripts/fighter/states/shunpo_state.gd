extends FighterState
## A quick step in the held direction. The first frames are a dodge window: hits are avoided
## (and the attacker gets nothing out of them). An attack may follow once the window ends.

var _frames: int = 0
var _direction: float = 1.0


func enter(_previous: StringName) -> void:
	fighter.face_input()
	_direction = signf(fighter.input.move.x) if fighter.input.move.x != 0.0 else float(fighter.facing)
	_frames = 0
	fighter.begin_shunpo()
	Events.fighter_shunpo.emit(fighter.player_id, fighter.global_position, int(_direction))


func physics_update(delta: float) -> StringName:
	var speed := GuardRules.SHUNPO_DISTANCE / (float(GuardRules.SHUNPO_FRAMES) / 60.0)
	fighter.velocity.x = _direction * speed
	if fighter.is_on_floor():
		fighter.apply_gravity(delta)
	else:
		fighter.velocity.y = 0.0
	_frames += 1
	if _frames >= GuardRules.SHUNPO_DODGE_FRAMES and fighter.wants_attack():
		fighter.velocity.x *= 0.2
		return &"Attack"
	if _frames < GuardRules.SHUNPO_FRAMES:
		return &""
	fighter.velocity.x *= 0.15
	return &"Idle" if fighter.is_on_floor() else &"Fall"
