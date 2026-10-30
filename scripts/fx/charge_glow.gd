class_name ChargeGlow
extends Node2D
## A glow gathering around a fighter who is charging a special: a ring that closes in and
## brightens, flashing when the charge is full. Gameplay feedback, so it ignores the effects setting.

var _fighter: Fighter
var _time: float = 0.0


func _init() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	z_index = 12
	visible = false


func setup(fighter: Fighter) -> void:
	_fighter = fighter
	position = Vector2(0.0, -fighter.data.body_size.y * 0.5)


func _process(delta: float) -> void:
	var charging := _fighter != null and _fighter.special_charge > 0.0
	if visible != charging:
		visible = charging
	if charging:
		_time += delta
		queue_redraw()


func _draw() -> void:
	var level := _fighter.special_charge
	var full := level >= 0.999
	var color := Color(1.0, 0.95, 0.6) if full else Color(1.0, 0.55, 0.2)
	var pulse := 0.5 + 0.5 * sin(_time * (30.0 if full else 14.0))
	for i in 3:
		var radius := lerpf(26.0, 12.0, level) + float(i) * 4.0 - fmod(_time * 30.0, 4.0)
		draw_arc(Vector2.ZERO, maxf(radius, 6.0), 0.0, TAU, 24, Color(color.r, color.g, color.b, (0.25 + 0.4 * level) * (0.6 + 0.4 * pulse)), 1.2)
	draw_circle(Vector2.ZERO, 5.0 + 8.0 * level, Color(color.r, color.g, color.b, 0.12 + 0.2 * level))
