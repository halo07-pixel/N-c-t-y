class_name HitInfo
extends RefCounted
## Everything a hurtbox needs to know about one hit that landed on it.

var attacker_id: int = 0
var damage: float = 0.0
var base_knockback: float = 0.0
var knockback_growth: float = 0.0
## Unit vector the victim is launched along.
var direction: Vector2 = Vector2.RIGHT
## A throw grabs through a guard and through a parry.
var is_throw: bool = false
## The projectile that carries this hit, or null for a melee hit (a parry can send it back).
var projectile: Node = null
