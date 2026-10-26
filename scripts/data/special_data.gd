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

@export_group("Ultimate")
## More than zero makes this a cinematic move: everyone else freezes for this
## many frames and the camera zooms in on the fighter.
@export var cinematic_frames: int = 0
@export var title: String = ""
