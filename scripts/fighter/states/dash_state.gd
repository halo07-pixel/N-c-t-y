extends FighterState
## A quick step in the direction that was double-tapped, on the ground or in the air. It is not
## invincible and cannot change direction. An attack pressed late enough in the dash comes out as a
## dash attack: the forward attack, keeping part of the dash speed.

var _frames: int = 0
var _direction: float = 1.0


func enter(_previous: StringName) -> void:
	fighter.begin_dash()
	_direction = float(fighter.dash_direction)
	fighter.facing = fighter.dash_direction
	_frames = 0
	Events.fighter_dashed.emit(fighter.player_id, fighter.global_position, fighter.dash_direction)


func physics_update(delta: float) -> StringName:
	var speed := GuardRules.DASH_DISTANCE / (float(GuardRules.DASH_FRAMES) / 60.0)
	fighter.velocity.x = _direction * speed
	if fighter.is_on_floor():
		fighter.apply_gravity(delta)
	else:
		fighter.velocity.y = 0.0
	_frames += 1
	if _frames >= GuardRules.DASH_ATTACK_FRAME and fighter.wants_attack():
		fighter.dash_attack = fighter.input.attack_just_pressed
		fighter.velocity.x *= GuardRules.DASH_ATTACK_CARRY
		return &"Attack"
	if _frames < GuardRules.DASH_FRAMES:
		return &""
	fighter.velocity.x *= 0.15
	return &"Idle" if fighter.is_on_floor() else &"Fall"
