class_name StageAtmosphere
extends Node2D
## Slow drifting fog, floating dust and fireflies behind the fighters.
## Amounts follow the Screen Effects setting (OFF keeps only a still fog).

enum Kind { FOG, DUST, FIREFLIES }

@export var kind: Kind = Kind.FOG
@export var seed_value: int = 3

const AREA := Rect2(-380.0, -200.0, 760.0, 340.0)
const DUST_COUNT := 36
const FIREFLY_COUNT := 12
const MAX_AMOUNT := 1.5

var _time: float = 0.0
var _seeds: Array[Vector4] = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in ceili(maxi(DUST_COUNT, FIREFLY_COUNT) * MAX_AMOUNT): # enough for the highest effects level
		_seeds.append(Vector4(rng.randf(), rng.randf(), rng.randf_range(0.3, 1.0), rng.randf() * TAU))
	if kind == Kind.FIREFLIES:
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = add


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func amount() -> float:
	return GameSettings.effect_amount()


func _draw() -> void:
	match kind:
		Kind.FOG:
			_draw_fog()
		Kind.DUST:
			_draw_dust()
		Kind.FIREFLIES:
			_draw_fireflies()


func _draw_fog() -> void:
	var drift := _time if amount() > 0.0 else 0.0
	for i in 3:
		var y := 30.0 + i * 26.0
		var strength := 0.10 + 0.05 * sin(drift * 0.25 + i * 1.7)
		var shift := sin(drift * 0.12 + i) * 40.0
		var clear := Color(StagePalette.FOG, 0.0)
		var tint := Color(StagePalette.FOG, strength)
		draw_polygon(
			PackedVector2Array([
				Vector2(-600.0 + shift, y - 22.0), Vector2(600.0 + shift, y - 22.0),
				Vector2(600.0 + shift, y), Vector2(-600.0 + shift, y),
			]),
			PackedColorArray([clear, clear, tint, tint])
		)
		draw_polygon(
			PackedVector2Array([
				Vector2(-600.0 + shift, y), Vector2(600.0 + shift, y),
				Vector2(600.0 + shift, y + 22.0), Vector2(-600.0 + shift, y + 22.0),
			]),
			PackedColorArray([tint, tint, clear, clear])
		)


func _draw_dust() -> void:
	var count := int(round(DUST_COUNT * minf(amount(), MAX_AMOUNT)))
	for i in count:
		var s := _seeds[i]
		var x := AREA.position.x + fposmod(s.x * AREA.size.x + _time * 4.0 * s.z, AREA.size.x)
		var y := AREA.position.y + fposmod(s.y * AREA.size.y - _time * 5.0 * s.z, AREA.size.y)
		x += sin(_time * 0.6 + s.w) * 6.0
		draw_circle(Vector2(x, y), 0.6 + s.z * 0.5, Color(StagePalette.DUST, 0.12 + 0.25 * s.z))


func _draw_fireflies() -> void:
	var count := int(round(FIREFLY_COUNT * minf(amount(), 1.5)))
	for i in count:
		var s := _seeds[i]
		var at := Vector2(
			AREA.position.x + s.x * AREA.size.x + sin(_time * 0.5 * s.z + s.w) * 14.0,
			AREA.position.y + 120.0 + s.y * 160.0 + cos(_time * 0.7 * s.z + s.w) * 9.0
		)
		var pulse := 0.5 + 0.5 * sin(_time * (1.2 + s.z) + s.w)
		draw_circle(at, 4.0, Color(StagePalette.FIREFLY, 0.05 * pulse))
		draw_circle(at, 2.0, Color(StagePalette.FIREFLY, 0.12 * pulse))
		draw_circle(at, 0.8, Color(StagePalette.FIREFLY, 0.4 + 0.5 * pulse))
