class_name ResidueFx
extends Node2D
## The afterglow a spell leaves where it ended: embers drift up, petals drift down, frost
## glints hang and twinkle. One node, a handful of motes, ~1 second. Additive; purely visual.

const LIFETIME := 1.1
const MOTES := 7

var color: Color = Color(1.0, 0.5, 0.2)
var amount: float = 1.0
var kind: StringName = &"ember"
var _age: float = 0.0
var _seeds: Array[Vector3] = [] # per mote: x offset, y offset, phase


func _init() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	z_index = 9


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(position.x * 7.0 + position.y * 13.0)
	for i in motes_for(amount):
		_seeds.append(Vector3(rng.randf_range(-14.0, 14.0), rng.randf_range(-10.0, 8.0), rng.randf() * TAU))


## Which kind of afterglow a spell colour leaves: cold colours glint, pink petals fall, the rest rise as embers.
static func kind_for(spell_color: Color) -> StringName:
	if spell_color.b > spell_color.r + 0.15:
		return &"frost"
	if spell_color.r > 0.8 and spell_color.b > 0.45 and spell_color.g < 0.55:
		return &"petal"
	return &"ember"


static func motes_for(effect_amount: float) -> int:
	return maxi(int(round(float(MOTES) * effect_amount)), 1)


## Vertical drift (px) of a mote `t` (0..1) through its life.
static func drift(mote_kind: StringName, t: float) -> float:
	match mote_kind:
		&"frost":
			return 0.0
		&"petal":
			return 26.0 * t
		_:
			return -30.0 * t


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _age / LIFETIME
	var fade := 1.0 - t
	for seed_value in _seeds:
		var sway := sin(seed_value.z + _age * 4.0) * 4.0
		var spot := Vector2(seed_value.x + sway, seed_value.y + drift(kind, t))
		var twinkle := 0.6 + 0.4 * sin(seed_value.z * 3.0 + _age * 18.0) if kind == &"frost" else 1.0
		var alpha := 0.8 * fade * twinkle
		if kind == &"petal":
			draw_line(spot, spot + Vector2(3.0, 2.0), Color(color.r, color.g, color.b, alpha), 2.5)
		else:
			draw_circle(spot, 1.6 + 1.2 * fade, Color(color.r, color.g, color.b, alpha))
