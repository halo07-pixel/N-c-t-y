class_name ProjectileData
extends Resource
## One projectile a special move fires. Pure data, like everything else.

## Where it appears relative to the fighter's feet, facing right.
@export var offset: Vector2 = Vector2(16.0, -18.0)
## Velocity in pixels per second, facing right. Zero makes a stationary trap.
@export var velocity: Vector2 = Vector2(260.0, 0.0)
@export var lifetime_frames: int = 70
@export var size: Vector2 = Vector2(22.0, 14.0)
## A piercing projectile keeps flying after it hits (once per target).
@export var pierce: bool = false
@export var color: Color = Color(0.6, 0.9, 1.0)
## Name of an effect sprite in the owner's sprite set; empty draws the plain shape.
@export var art: StringName = &""
## Procedural look drawn by code: crescent, arrow, petal, orb or blast. Empty keeps the
## effect sprite (or the plain diamond).
@export var style: StringName = &""
## A trap stays where it was placed and explodes on the first enemy that touches it.
## Fighters keep a limited number of live traps (see SpecialData.limit_active).
@export var trap: bool = false
## A commandable projectile (a petal cloud) can be sent flying by a command move.
@export var commandable: bool = false
## An absorbing projectile (a petal wall, a void sphere) destroys enemy projectiles that touch it.
@export var absorbs: bool = false
