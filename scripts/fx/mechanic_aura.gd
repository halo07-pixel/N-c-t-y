class_name MechanicAura
extends Node2D
## The standing look of a character mechanic, drawn while it is active: red-black flames when
## Ichigo's Hollow boost is charged, Quincy crosses over Uryu's head for his arrow streak, and a
## faint ring of drifting petals with wind streaks while Byakuya stands in his petal zone.
## Reads the fighter, never changes it.

var _fighter: Fighter
var _time: float = 0.0


func _init() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	visible = false


func setup(fighter: Fighter) -> void:
	_fighter = fighter


## True while the fighter has any mechanic to show.
static func is_showing(fighter: Fighter) -> bool:
	return fighter.empowered or fighter.in_petal_zone or has_petal_ring(fighter) or fighter.arrow_streak() >= 2 or fighter.gathering


## Byakuya's Bankai keeps a ring of blades turning around him.
static func has_petal_ring(fighter: Fighter) -> bool:
	return fighter.is_bankai() and fighter.data.mechanic == &"petals"


func _process(delta: float) -> void:
	if _fighter == null:
		return
	var show := GameSettings.screen_effects and not _fighter.is_ko() and is_showing(_fighter)
	if visible != show:
		visible = show
	if show:
		_time += delta
		queue_redraw()


func _draw() -> void:
	var size := _fighter.data.body_size
	var amount := GameSettings.effect_amount()
	var center := Vector2(0.0, -size.y * 0.5)
	if _fighter.empowered:
		_draw_hollow(size, amount)
	if _fighter.arrow_streak() >= 2:
		_draw_streak(size, amount)
	if _fighter.in_petal_zone:
		_draw_petals(size, center, amount)
	if has_petal_ring(_fighter):
		_draw_ring(center, amount)
	if _fighter.gathering:
		_draw_gather(size, amount)


func _draw_ring(center: Vector2, amount: float) -> void:
	var colors := MechanicBurst.palette(&"cut")
	var blades := maxi(int(round(10.0 * amount)), 4)
	for i in blades:
		var angle := _time * 2.6 + TAU * float(i) / float(blades)
		var at := center + Vector2(cos(angle), sin(angle) * 0.7) * BankaiTraits.RING_RADIUS
		var along := Vector2(-sin(angle), cos(angle) * 0.7).normalized()
		draw_line(at - along * 4.0, at + along * 4.0, Color(colors[0].r, colors[0].g, colors[0].b, 0.85), 2.0)
		draw_line(at - along * 2.0, at + along * 2.0, Color(colors[1].r, colors[1].g, colors[1].b, 0.9), 1.0)


func _draw_hollow(size: Vector2, amount: float) -> void:
	var colors := MechanicBurst.palette(&"hollow")
	var tongues := int(round(7.0 * amount))
	for i in tongues:
		var phase := float(i) * 1.9
		var x := (float(i) - float(tongues - 1) * 0.5) * size.x * 0.28
		var height := size.y * (0.5 + 0.35 * sin(_time * 9.0 + phase) * 0.5 + 0.25)
		var base := Vector2(x, 0.0)
		var tip := Vector2(x + sin(_time * 5.0 + phase) * 3.0, -height)
		draw_line(base, tip, Color(colors[1].r, colors[1].g, colors[1].b, 0.55), 3.0)
		draw_line(base, tip, Color(colors[0].r, colors[0].g, colors[0].b, 0.55), 1.4)
	# A mask-like flash at the head every so often.
	var flash := maxf(0.0, sin(_time * 3.0))
	if flash > 0.85:
		draw_arc(Vector2(0.0, -size.y), 5.0, PI * 0.2, PI * 0.8, 8, Color(1.0, 1.0, 1.0, 0.7), 1.5)


func _draw_streak(size: Vector2, amount: float) -> void:
	var colors := MechanicBurst.palette(&"heartless")
	var count := mini(_fighter.arrow_streak(), 2)
	for i in count:
		var spot := Vector2((float(i) - float(count - 1) * 0.5) * 9.0, -size.y - 7.0 + sin(_time * 6.0 + float(i)) * 1.2)
		for direction in [Vector2.RIGHT, Vector2.UP]:
			draw_line(spot - direction * 3.0, spot + direction * 3.0, Color(colors[0].r, colors[0].g, colors[0].b, 0.9 * minf(amount, 1.0)), 1.2)
	# One more hit and the next arrow bounces: the cross pulses.
	if _fighter.arrow_streak() >= Fighter.HEARTLESS_HITS - 1:
		draw_arc(Vector2(0.0, -size.y - 7.0), 6.0 + 1.5 * sin(_time * 10.0), 0.0, TAU, 12, Color(colors[1].r, colors[1].g, colors[1].b, 0.6), 1.0)


func _draw_petals(size: Vector2, center: Vector2, amount: float) -> void:
	var ring := Fighter.PETAL_ZONE_RADIUS * 0.45
	var dots := int(round(10.0 * amount))
	for i in dots:
		var angle := _time * 0.9 + float(i) * TAU / float(maxi(dots, 1))
		var spot := center + Vector2(cos(angle) * ring, sin(angle) * ring * 0.55)
		draw_circle(spot, 1.2, Color(1.0, 0.72, 0.85, 0.75))
	draw_set_transform(center, 0.0, Vector2(1.0, 0.55))
	draw_arc(Vector2.ZERO, ring, 0.0, TAU, 28, Color(1.0, 0.7, 0.85, 0.25), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Wind streaks behind a runner.
	if absf(_fighter.velocity.x) > 40.0:
		var behind := -signf(_fighter.velocity.x)
		for i in 3:
			var y := -size.y * (0.25 + 0.22 * float(i))
			draw_line(Vector2(behind * 6.0, y), Vector2(behind * (14.0 + 4.0 * float(i)), y), Color(1.0, 0.8, 0.9, 0.4), 1.0)


## Quincy gathering reishi: blue motes drift in from the air and stream into the bow arm.
func _draw_gather(size: Vector2, amount: float) -> void:
	var colors := MechanicBurst.palette(&"heartless")
	var hand := Vector2(float(_fighter.facing) * size.x * 0.9, -size.y * 0.62)
	var motes := int(round(12.0 * amount))
	for i in motes:
		var phase := fposmod(_time * 1.6 + float(i) * 0.37, 1.0) # 0 far away .. 1 arrived
		var angle := float(i) * 2.39996
		var start := hand + Vector2(cos(angle), sin(angle) * 0.7) * 34.0
		var spot := start.lerp(hand, phase * phase)
		var behind := start.lerp(hand, maxf(phase - 0.12, 0.0) * maxf(phase - 0.12, 0.0))
		draw_line(behind, spot, Color(colors[0].r, colors[0].g, colors[0].b, 0.6 * phase), 1.0)
		draw_circle(spot, 1.0 + phase, Color(colors[1].r, colors[1].g, colors[1].b, 0.4 + 0.5 * phase))
	draw_circle(hand, 2.5 + 1.5 * sin(_time * 14.0), Color(colors[0].r, colors[0].g, colors[0].b, 0.6))
