class_name Hurtbox
extends Area2D
## The part of a fighter that can be hit. It never decides what a hit does:
## it only announces it with a signal and the fighter reacts.

signal hit_received(info: HitInfo)

var fighter_id: int = 0
## False while the fighter is invincible or knocked out.
var is_active: bool = true
## True while a counter stance catches every hit (even a throw).
var evading: bool = false
## True during the parry window: every hit except a throw is parried.
var parrying: bool = false

@onready var _shape: CollisionShape2D = $CollisionShape2D


func setup(id: int, body_size: Vector2) -> void:
	fighter_id = id
	var rectangle := RectangleShape2D.new()
	rectangle.size = body_size
	_shape.shape = rectangle
	_shape.position = Vector2(0.0, -body_size.y * 0.5)


func set_active(active: bool) -> void:
	is_active = active
	set_deferred("monitorable", active)


## Whether this hit is answered by the defender (a counter or a parry) instead of landing. The
## attacker gets nothing from such a hit (no hitlag, no gauge); the fighter is told with `hit_received`.
func evades(info: HitInfo) -> bool:
	return evading or (parrying and not info.is_throw)


func receive_hit(info: HitInfo) -> void:
	if is_active:
		hit_received.emit(info)
