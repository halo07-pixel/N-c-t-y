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
	return fighter.empowered or fighter.in_petal_zone or has_petal_ring(fighter) or has_form_trait(fighter) or fighter.arrow_streak() >= 2 or fighter.gathering


## Byakuya's Bankai keeps a ring of blades turning around him.
static func has_petal_ring(fighter: Fighter) -> bool:
	return fighter.is_bankai() and fighter.data.mechanic == &"petals"


## Getsuga charge pips over Ichigo, lightning between Uryu's blades.
static func has_form_trait(fighter: Fighter) -> bool:
	if not fighter.is_bankai():
		return false
	return fighter.getsuga_stacks > 0 or fighter.fury_stacks > 0 or fighter.memory_damage > 0.0 or (fighter.data.mechanic == &"heartless" and not BankaiTraits.lattice_pairs(fighter).is_empty())


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
	if _fighter.is_bankai() and _fighter.getsuga_stacks > 0:
		_draw_getsuga_pips(size)
	if _fighter.is_bankai() and _fighter.data.mechanic == &"heartless":
		_draw_lattice()
	if _fighter.is_bankai() and _fighter.fury_stacks > 0:
		_draw_fury(size)
	if _fighter.is_bankai() and _fighter.memory_damage > 0.0:
		_draw_memory(size)
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


func _draw_getsuga_pips(size: Vector2) -> void:
	var ready := _fighter.getsuga_stacks >= BankaiTraits.GETSUGA_MIN
	for i in _fighter.getsuga_stacks:
		var at := Vector2((float(i) - float(BankaiTraits.GETSUGA_MAX - 1) * 0.5) * 6.0, -size.y - 12.0)
		var glow := 0.55 + (0.35 * sin(_time * 12.0 + float(i)) if ready else 0.0)
		draw_rect(Rect2(at - Vector2(2.0, 3.0), Vector2(4.0, 6.0)), Color(1.0, 0.15, 0.2, glow))
		draw_rect(Rect2(at - Vector2(1.0, 2.0), Vector2(2.0, 4.0)), Color(0.05, 0.0, 0.07, 0.9))


## Kenpachi's fury: golden flame ticks that rise with every hit he has taken.
func _draw_fury(size: Vector2) -> void:
	var colors := MechanicBurst.palette(&"zeal")
	for i in _fighter.fury_stacks:
		var x := (float(i) - float(BankaiTraits.FURY_MAX - 1) * 0.5) * size.x * 0.22
		var height := 8.0 + 8.0 * (0.5 + 0.5 * sin(_time * 10.0 + float(i) * 1.3))
		draw_line(Vector2(x, -size.y * 0.3), Vector2(x, -size.y * 0.3 - height), Color(colors[0].r, colors[0].g, colors[0].b, 0.7), 2.0)
		draw_line(Vector2(x, -size.y * 0.3), Vector2(x, -size.y * 0.3 - height * 0.6), Color(colors[1].r, colors[1].g, colors[1].b, 0.8), 1.0)


## Yhwach's memory: dark red motes circling him, one per 8% of damage he is holding on to.
func _draw_memory(size: Vector2) -> void:
	var motes := clampi(int(ceil(_fighter.memory_damage / 8.0)), 1, 3)
	for i in motes:
		var angle := _time * 3.0 + TAU * float(i) / float(motes)
		var at := Vector2(cos(angle) * 14.0, -size.y * 0.5 + sin(angle) * 10.0)
		draw_circle(at, 2.5, Color(0.9, 0.1, 0.25, 0.9))
		draw_circle(at, 1.2, Color(1.0, 0.8, 0.85, 0.9))


func _draw_lattice() -> void:
	var colors := MechanicBurst.palette(&"heartless")
	for pair in BankaiTraits.lattice_pairs(_fighter):
		var a: Vector2 = _fighter.to_local(pair[0]) + Vector2(0.0, -20.0)
		var b: Vector2 = _fighter.to_local(pair[1]) + Vector2(0.0, -20.0)
		var points := PackedVector2Array([a])
		var steps := 8
		for k in range(1, steps):
			var t := float(k) / float(steps)
			points.append(a.lerp(b, t) + Vector2(0.0, sin(_time * 40.0 + float(k) * 1.7) * 3.0))
		points.append(b)
		draw_polyline(points, Color(colors[0].r, colors[0].g, colors[0].b, 0.8), 1.4)
		draw_polyline(points, Color(colors[1].r, colors[1].g, colors[1].b, 0.5), 0.6)


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
