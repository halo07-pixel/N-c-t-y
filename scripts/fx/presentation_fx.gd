class_name PresentationFx
extends CanvasLayer
## The screen presentation of a transformation or an ultimate: the world dims and a motif of the
## character grows around the fighter (the camera isolates them, so the middle of the screen),
## holds at its peak and releases in a flash. It only listens to the Events bus, sits above the
## world and below the HUD, and draws nothing when the effects are off.

const CENTER := Vector2(240.0, 128.0)
const SCREEN := Vector2(480.0, 270.0)
const MAX_DIM := 0.5

var _canvas: Control
var _profile: FxProfile
var _color: Color = Color.WHITE
var _accent: Color = Color.WHITE
var _total_frames: int = 0
var _age: float = 0.0
var _active: bool = false
var _strong: bool = false


func _ready() -> void:
	layer = 11
	scale = RenderScale.ui()
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_on_draw)
	add_child(_canvas)
	Events.transform_started.connect(_on_transform_started)
	Events.ultimate_started.connect(_on_ultimate_started)
	set_process(false)


## The three beats of a sequence `age` frames in, out of `total`: how dark the world is, how
## far the motif has grown, and the release flash. All 0..1.
static func sequence(age: float, total: int) -> Dictionary:
	var length := maxf(float(total), 1.0)
	var t := clampf(age / length, 0.0, 1.0)
	var dim := minf(t / 0.2, 1.0) if t < 0.85 else clampf((1.0 - t) / 0.15, 0.0, 1.0)
	var motif := 1.0 - pow(1.0 - clampf(t / 0.55, 0.0, 1.0), 3.0)
	if t > 0.9:
		motif *= clampf((1.0 - t) / 0.1, 0.0, 1.0)
	var flash := clampf(1.0 - absf(t - 0.78) / 0.07, 0.0, 1.0)
	# Energy gathers into the fighter until the flash, then the speed lines burst outward.
	var gather := clampf(t / 0.75, 0.0, 1.0) if t < 0.78 else 0.0
	var burst := clampf((t - 0.78) / 0.15, 0.0, 1.0) if t >= 0.78 else 0.0
	return {"dim": dim, "motif": motif, "flash": flash, "gather": gather, "burst": burst}


func _on_transform_started(player_id: int, _title: String, frames: int) -> void:
	_begin(player_id, frames, false)


func _on_ultimate_started(player_id: int, freeze_frames: int, _title: String) -> void:
	_begin(player_id, freeze_frames, true)


func _begin(player_id: int, frames: int, strong: bool) -> void:
	if not GameSettings.screen_effects:
		return
	var character := MatchConfig.character_for(player_id)
	_profile = character.fx_profile if character != null else null
	_color = _profile.primary if _profile != null else MatchHud.PLAYER_COLORS.get(player_id, Color.WHITE)
	_accent = _profile.accent if _profile != null else Color.WHITE
	_total_frames = frames
	_age = 0.0
	_strong = strong
	_active = true
	set_process(true)


func motif_name() -> StringName:
	return _profile.motif if _profile != null else &"frame"


func is_playing() -> bool:
	return _active


func _process(delta: float) -> void:
	if not _active:
		return
	_age += delta * 60.0
	if _age >= float(_total_frames) or not GameSettings.screen_effects:
		_active = false
		set_process(false)
	_canvas.queue_redraw()


func _on_draw() -> void:
	if not _active:
		return
	var beat := sequence(_age, _total_frames)
	var strength := 1.0 if _strong else 0.8
	var amount := GameSettings.effect_amount()
	_canvas.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0.0, 0.0, 0.06, MAX_DIM * float(beat["dim"]) * strength))
	var motif: float = beat["motif"]
	match motif_name():
		&"frame":
			_draw_frame(motif, amount)
		&"glyph":
			_draw_glyph(motif, amount)
		&"petal_ring":
			_draw_petal_ring(motif, amount)
		&"shadow":
			_draw_shadow(motif, amount)
		&"chain":
			_draw_chain(motif, amount)
		&"snow":
			_draw_snow(motif, amount)
		&"pressure":
			_draw_pressure(motif, amount)
	_draw_gather(float(beat["gather"]), amount)
	_draw_burst(float(beat["burst"]), amount)
	var flash: float = beat["flash"]
	if flash > 0.0:
		_canvas.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(_accent.r, _accent.g, _accent.b, 0.22 * flash * amount))


## Ichigo: black cuts slashing across the screen with red edges, leaving a hard frame.
func _draw_frame(motif: float, amount: float) -> void:
	for i in 4: # kept above and below the fighter so the body stays readable
		var y := CENTER.y + (-78.0 if i < 2 else 56.0) + float(i % 2) * 18.0
		var reach := SCREEN.x * clampf(motif * 1.4 - float(i) * 0.12, 0.0, 1.0)
		var tilt := -26.0
		var shape := PackedVector2Array([
			Vector2(0.0, y), Vector2(reach, y + tilt), Vector2(reach, y + tilt + 12.0 + 6.0 * float(i % 2)), Vector2(0.0, y + 12.0),
		])
		_canvas.draw_colored_polygon(shape, Color(0.0, 0.0, 0.0, 0.65))
		_canvas.draw_line(shape[0], shape[1], Color(_color.r, _color.g, _color.b, 0.9 * amount), 1.5)
		_canvas.draw_line(shape[3], shape[2], Color(1.0, 1.0, 1.0, 0.7 * amount), 1.0)


## Uryu: a Quincy glyph, thin concentric circles with a rotating cross-star, in silver blue.
func _draw_glyph(motif: float, amount: float) -> void:
	var radius := 70.0 * motif
	var tone := Color(_color.r, _color.g, _color.b, 0.8 * amount)
	_canvas.draw_arc(CENTER, radius, 0.0, TAU, 48, tone, 1.4)
	_canvas.draw_arc(CENTER, radius * 0.72, 0.0, TAU, 40, Color(_accent.r, _accent.g, _accent.b, 0.7 * amount), 1.0)
	var spin := _age * 0.02
	for i in 4:
		var a := spin + float(i) * PI * 0.5
		var dir := Vector2.from_angle(a)
		_canvas.draw_line(CENTER + dir * radius * 0.25, CENTER + dir * radius * 1.12, tone, 1.4)
		var side := Vector2.from_angle(a + PI * 0.5) * radius * 0.12
		_canvas.draw_line(CENTER + dir * radius * 0.72 - side, CENTER + dir * radius * 0.72 + side, tone, 1.0)
	for i in int(round(6.0 * amount)):
		var a := -spin * 1.5 + float(i) * TAU / 6.0
		_canvas.draw_circle(CENTER + Vector2.from_angle(a) * radius * 0.86, 1.6, Color(_accent.r, _accent.g, _accent.b, 0.9))


## Byakuya: a ring of petals orbiting the fighter, widening as the sequence builds.
func _draw_petal_ring(motif: float, amount: float) -> void:
	var count := int(round(18.0 * amount))
	for i in count:
		var ring := float(i % 2)
		var a := _age * (0.05 + 0.02 * ring) + float(i) * TAU / float(maxi(count, 1))
		var r := (46.0 + 26.0 * ring) * motif
		var center := CENTER + Vector2(cos(a) * r, sin(a) * r * 0.7)
		var petal := PackedVector2Array()
		for step in 8:
			var p := float(step) * TAU / 8.0
			petal.append(center + Vector2(cos(p) * 5.0, sin(p) * 2.2).rotated(a + 1.2))
		_canvas.draw_colored_polygon(petal, Color(_color.r, _color.g, _color.b, 0.85 * motif))


## Kenpachi: raw spiritual pressure, heavy rings pulsing outward and flame spikes rising around the fighter.
func _draw_pressure(motif: float, amount: float) -> void:
	for ring in 3:
		var phase := fposmod(_age * 0.012 + float(ring) / 3.0, 1.0)
		_canvas.draw_arc(CENTER, (20.0 + 70.0 * phase) * motif, 0.0, TAU, 40, Color(_color.r, _color.g, _color.b, (1.0 - phase) * 0.85 * amount), 3.0 * (1.0 - phase) + 0.6)
	for i in int(round(16.0 * amount)):
		var a := float(i) * TAU / 16.0
		var base := CENTER + Vector2.from_angle(a) * 22.0 * motif
		var flick := 0.7 + 0.3 * sin(_age * 0.2 + float(i) * 1.7)
		var tip := base + Vector2.from_angle(a) * (26.0 + 22.0 * float(i % 3)) * motif * flick
		_canvas.draw_line(base, tip, Color(_accent.r, _accent.g, _accent.b, 0.8 * motif), 2.0)


## Rukia: hexagonal frost rings widening around the fighter, with snow drifting down.
func _draw_snow(motif: float, amount: float) -> void:
	for ring in 3:
		var radius := (26.0 + 24.0 * float(ring)) * motif
		var points := PackedVector2Array()
		for step in 7:
			points.append(CENTER + Vector2.from_angle(float(step) * TAU / 6.0 + _age * 0.01 * (1.0 - 0.5 * float(ring))) * radius)
		_canvas.draw_polyline(points, Color(_color.r, _color.g, _color.b, (0.9 - 0.2 * float(ring)) * amount), 1.4)
	for i in int(round(14.0 * amount)):
		var seed := float(i) * 2.9
		var fall := fposmod(_age * 0.01 + seed, 1.0)
		var x := CENTER.x + sin(seed * 1.7) * 110.0 * motif
		_canvas.draw_circle(Vector2(x + sin(fall * 6.0 + seed) * 4.0, CENTER.y - 90.0 + fall * 150.0), 1.5, Color(_accent.r, _accent.g, _accent.b, 0.85 * motif * (1.0 - fall * 0.5)))


## Renji: a ring of jointed bone segments snapping outward around the fighter, like Zabimaru's blade.
func _draw_chain(motif: float, amount: float) -> void:
	var count := int(round(14.0 * amount))
	for i in count:
		var a := _age * 0.03 + float(i) * TAU / float(maxi(count, 1))
		var radius := (38.0 + 34.0 * float(i % 2)) * motif
		var centre := CENTER + Vector2(cos(a) * radius, sin(a) * radius * 0.7)
		var along := Vector2.from_angle(a + PI * 0.5)
		var half := along * 7.0 * motif
		_canvas.draw_line(centre - half, centre + half, Color(0.0, 0.0, 0.0, 0.8 * motif), 4.0)
		_canvas.draw_line(centre - half, centre + half, Color(_color.r, _color.g, _color.b, 0.9 * motif), 2.4)
		_canvas.draw_circle(centre + half, 1.8, Color(_accent.r, _accent.g, _accent.b, 0.9 * motif))


## Yhwach: the dark closes in from the edges and a shadow spreads along the ground.
func _draw_shadow(motif: float, amount: float) -> void:
	var inset := 90.0 * motif
	var black := Color(0.0, 0.0, 0.0, 0.85)
	_canvas.draw_rect(Rect2(0.0, 0.0, inset, SCREEN.y), black)
	_canvas.draw_rect(Rect2(SCREEN.x - inset, 0.0, inset, SCREEN.y), black)
	var ground := SCREEN.y * 0.66
	var spread := SCREEN.x * 0.5 * motif
	var shape := PackedVector2Array()
	for step in 24:
		var a := float(step) * TAU / 24.0
		shape.append(Vector2(CENTER.x + cos(a) * spread, ground + sin(a) * 9.0 * motif))
	_canvas.draw_colored_polygon(shape, Color(0.02, 0.0, 0.05, 0.9))
	for i in int(round(10.0 * amount)):
		var seed := float(i) * 3.7
		var t := fposmod(_age * 0.012 + seed, 1.0)
		var x := CENTER.x + sin(seed * 2.1) * spread
		_canvas.draw_circle(Vector2(x, ground - t * 80.0), 1.4, Color(_color.r, _color.g, _color.b, (1.0 - t) * 0.8 * motif))


## Motes drawn in from the edge of the screen toward the fighter while the sequence builds.
func _draw_gather(gather: float, amount: float) -> void:
	if gather <= 0.0:
		return
	for i in int(round(14.0 * amount)):
		var angle := float(i) * 2.399 # golden angle keeps the motes evenly spread
		var start := 150.0 + 30.0 * float(i % 3)
		var radius := lerpf(start, 14.0, pow(gather, 1.6))
		var tail := radius + 12.0 * (1.0 - gather)
		var dir := Vector2.from_angle(angle)
		_canvas.draw_line(CENTER + dir * tail, CENTER + dir * radius, Color(_accent.r, _accent.g, _accent.b, 0.7 * gather), 1.2)


## Speed lines flung outward from the fighter in the release.
func _draw_burst(burst: float, amount: float) -> void:
	if burst <= 0.0 or burst >= 1.0:
		return
	for i in int(round(20.0 * amount)):
		var angle := float(i) * TAU / 20.0 + 0.13 * float(i % 3)
		var dir := Vector2.from_angle(angle)
		var inner := 30.0 + 150.0 * burst
		var outer := inner + 40.0 + 20.0 * float(i % 2)
		_canvas.draw_line(CENTER + dir * inner, CENTER + dir * outer, Color(1.0, 1.0, 1.0, 0.8 * (1.0 - burst)), 1.6)
