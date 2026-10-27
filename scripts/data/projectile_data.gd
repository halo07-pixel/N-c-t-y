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
