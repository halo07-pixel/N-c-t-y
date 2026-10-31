class_name MoveData
extends Resource
## One attack, described purely as data. Frame counts are physics ticks (60/s).

@export var display_name: String = "Move"
## Used by the placeholder body to pick a swing pose: neutral, forward, up, down.
@export var direction: StringName = &"neutral"

@export_group("Damage")
@export var damage: float = 5.0
@export var base_knockback: float = 200.0
@export var knockback_growth: float = 100.0
## Launch angle in degrees: 0 = straight ahead, 90 = up, negative = downward (spike).
## Mirrored automatically for a fighter facing left.
@export var angle_degrees: float = 45.0

@export_group("Timing (frames)")
@export var startup_frames: int = 6
@export var active_frames: int = 3
@export var recovery_frames: int = 14

@export_group("Hitbox")
## Size of the hitbox rectangle.
@export var hitbox_size: Vector2 = Vector2(24.0, 18.0)
## Center of the hitbox relative to the fighter's feet, facing right.
@export var hitbox_offset: Vector2 = Vector2(20.0, -16.0)
## Forward speed given when the hitbox becomes active (0 = none).
@export var lunge_speed: float = 0.0


@export_group("Chain")
## Pressing attack again after this move's active frames plays this move next (a combo string).
## Holding up or down picks the branch instead when one is set.
@export var next_in_chain: MoveData
@export var chain_up: MoveData
@export var chain_down: MoveData
## Chains only continue after this move has hit something.
@export var chain_requires_hit: bool = true


func has_chain() -> bool:
	return next_in_chain != null or chain_up != null or chain_down != null


## The move to continue with, given the held vertical direction (-1 up, 1 down, 0 none).
func chain_for(vertical: float) -> MoveData:
	if vertical < -0.5 and chain_up != null:
		return chain_up
	if vertical > 0.5 and chain_down != null:
		return chain_down
	return next_in_chain


func total_frames() -> int:
	return startup_frames + active_frames + recovery_frames
