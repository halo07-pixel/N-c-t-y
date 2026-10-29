class_name GuardShield
extends Node2D
## The bubble around a guarding fighter: it fades as the guard energy drains and flashes
## brighter during the Perfect Guard window. Gameplay feedback, so it ignores the effects setting.

const RADIUS := 15.0

var _fighter: Fighter


func _init() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	z_index = 12
	visible = false


func setup(fighter: Fighter) -> void:
	_fighter = fighter
	position = Vector2(0.0, -fighter.data.body_size.y * 0.5)


## Opacity 0..1 from the energy left; low energy looks thin.
static func strength(energy: float) -> float:
	return clampf(energy / GuardRules.ENERGY_MAX, 0.15, 1.0)


func _process(_delta: float) -> void:
	var guarding := _fighter != null and _fighter.is_guarding()
	if visible != guarding:
		visible = guarding
	if guarding:
		queue_redraw()


func _draw() -> void:
	var perfect := _fighter.guard_age < GuardRules.PERFECT_WINDOW_FRAMES
	var s := strength(_fighter.guard_energy)
	var tint := Color(1.0, 0.9, 0.5) if perfect else Color(0.5, 0.8, 1.0)
	var radius := RADIUS * (1.1 if perfect else 1.0)
	draw_circle(Vector2.ZERO, radius, Color(tint.r, tint.g, tint.b, 0.12 + 0.12 * s))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, Color(tint.r, tint.g, tint.b, 0.4 + 0.5 * s), 1.4)
