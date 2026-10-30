class_name AuraFx
extends Node2D
## Spiritual pressure made visible: an irregularly pulsing glow around the fighter, particles
## orbiting the body and a shimmer on the ground. How strong it is follows the fighter's
## Combat Gauge, Reiatsu blocks, form and charge, so you can read a fighter's pressure at a
## glance. Additive and visual only; it reads the fighter and never changes it.

const THRESHOLD := 0.1
const MAX_ORBITERS := 14

var _fighter: Fighter
var _time: float = 0.0
var _intensity: float = 0.0
var _primary: Color = Color(1.0, 0.8, 0.3)
var _accent: Color = Color.WHITE


func _init() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	visible = false


func setup(fighter: Fighter) -> void:
	_fighter = fighter
	var profile := fighter.data.fx_profile
	if profile != null:
		_primary = profile.primary
		_accent = profile.accent
	else:
		_primary = fighter.data.accent_color


## 0..1 pressure from the gauge (0..100), the Reiatsu (0..300), the form and the charge level.
static func intensity_for(gauge: float, reiatsu: float, form_active: bool, charge: float) -> float:
	var value := 0.15 * clampf(gauge / CombatGauge.MAX, 0.0, 1.0)
	value += 0.3 * clampf(reiatsu / Reiatsu.MAX, 0.0, 1.0)
	value += 0.45 if form_active else 0.0
	value += 0.15 * clampf(charge, 0.0, 1.0)
	return clampf(value, 0.0, 1.0)


## An uneven pulse: several sines that never line up, 0..1.
static func pulse(time: float) -> float:
	return clampf(0.5 + 0.25 * sin(time * 5.1) + 0.15 * sin(time * 8.7 + 1.3) + 0.1 * sin(time * 13.3 + 0.4), 0.0, 1.0)


## How many particles orbit at this pressure and effects amount.
static func orbiter_count(pressure: float, amount: float) -> int:
	return mini(int(round(pressure * 10.0 * amount)), MAX_ORBITERS)


func _process(delta: float) -> void:
	if _fighter == null:
		return
	_intensity = intensity_for(_fighter.gauge, _fighter.reiatsu, _fighter.is_bankai(), _fighter.special_charge)
	var show := _intensity >= THRESHOLD and GameSettings.screen_effects and not _fighter.is_ko()
	if visible != show:
		visible = show
	if show:
		_time += delta
		queue_redraw()


func _draw() -> void:
	var size := _fighter.data.body_size
	var amount := GameSettings.effect_amount()
	var beat := pulse(_time)
	var center := Vector2(0.0, -size.y * 0.5)
	var strength := _intensity * amount
	var tone := _primary.lerp(_accent, 0.25 + 0.35 * beat) if _fighter.is_bankai() else _primary
	# Glow: stacked ellipses; more of them and brighter as the pressure rises.
	var layers := 2 + int(round(_intensity * 4.0))
	for layer in layers:
		var grow := 1.0 + 0.16 * float(layer) + 0.08 * beat
		draw_set_transform(center, 0.0, Vector2(1.0, 1.7))
		draw_circle(Vector2.ZERO, size.x * 0.55 * grow, Color(tone.r, tone.g, tone.b, 0.05 * strength * (1.0 - float(layer) / float(layers + 1))))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Orbiting particles, each on its own speed and phase.
	for i in orbiter_count(_intensity, amount):
		var phase := float(i) * 2.39996 # golden angle keeps them spread out
		var speed := 1.4 + 0.5 * float(i % 3)
		var angle := _time * speed + phase
		var rx := size.x * (0.85 + 0.12 * sin(_time * 2.0 + phase))
		var ry := size.y * 0.62
		var spot := center + Vector2(cos(angle) * rx, sin(angle) * ry)
		var tail := center + Vector2(cos(angle - 0.35) * rx, sin(angle - 0.35) * ry)
		var flicker := 0.55 + 0.45 * sin(_time * 9.0 + phase * 3.0)
		draw_line(tail, spot, Color(tone.r, tone.g, tone.b, 0.5 * flicker), 1.0)
		draw_circle(spot, 1.1, Color(_accent.r, _accent.g, _accent.b, 0.85 * flicker))
	# Ground shimmer: widening ripples at the feet once the pressure is high.
	if _fighter.is_on_floor() and _intensity > 0.45:
		for ripple in 2:
			var t := fposmod(_time * 0.8 + float(ripple) * 0.5, 1.0)
			draw_set_transform(Vector2(0.0, -1.0), 0.0, Vector2(1.0, 0.22))
			draw_arc(Vector2.ZERO, size.x * (0.6 + 1.6 * t), 0.0, TAU, 28, Color(tone.r, tone.g, tone.b, (1.0 - t) * 0.5 * strength), 1.4)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
