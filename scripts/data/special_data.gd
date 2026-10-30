class_name SpecialData
extends MoveData
## A special move: everything a normal attack has, plus projectiles,
## self-propulsion (dashes, recoveries) and teleports.
## A pure movement special simply has a zero-size hitbox and no damage.

@export_group("Special effects")
## Fired when the active frames begin.
@export var projectiles: Array[ProjectileData] = []
## Speed given to the fighter, facing right. X is held through the active
## frames (a dash); Y is a one-time impulse (a rising recovery).
@export var self_velocity: Vector2 = Vector2.ZERO
## Instant displacement when the active frames begin, facing right.
@export var teleport: Vector2 = Vector2.ZERO
## Cancels gravity during the active frames (air dashes).
@export var ignore_gravity: bool = false

@export_group("Charge")
## More than zero lets the player hold the special button at the end of the wind-up to charge it,
## up to this many frames. Releasing fires it, stronger the longer it was held.
@export var charge_max_frames: int = 0
## Reiatsu paid when released at full charge. Charging past 60% needs that much Reiatsu.
@export var charge_cost: float = 0.0
@export var charge_damage_scale: float = 1.0
@export var charge_size_scale: float = 1.0
@export var charge_speed_scale: float = 1.0
## A full charge makes the projectiles pierce.
@export var charge_pierce: bool = false

@export_group("Follow-up")
## Pressing special again after this move's active frames begin plays this move.
@export var follow_up: SpecialData
@export var follow_up_cost: float = 0.0
@export var follow_up_window: int = 26
## Turns the fighter around when the move starts (a slash back through the opponent).
@export var flip_facing: bool = false

@export_group("Ultimate")
## More than zero makes this a cinematic move: everyone else freezes for this
## many frames and the camera zooms in on the fighter.
@export var cinematic_frames: int = 0
@export var title: String = ""


const FREE_CHARGE_SHARE := 0.6


func is_chargeable() -> bool:
	return charge_max_frames > 0


## How far a charge may go: up to FREE_CHARGE_SHARE for free, all the way when the fighter can pay.
func max_charge_share(can_pay: bool) -> float:
	return 1.0 if can_pay or charge_cost <= 0.0 else FREE_CHARGE_SHARE


## Scales of a projectile fired after charging `charge` (0..1).
func charge_scales(charge: float) -> Dictionary:
	var t := clampf(charge, 0.0, 1.0)
	return {
		"damage": lerpf(1.0, charge_damage_scale, t),
		"size": lerpf(1.0, charge_size_scale, t),
		"speed": lerpf(1.0, charge_speed_scale, t),
		"pierce": charge_pierce and t >= 0.999,
	}
