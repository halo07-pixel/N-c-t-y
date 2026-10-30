class_name MatchHud
extends CanvasLayer
## On-screen match info: percent, stocks and Reiatsu per player, the clock, the
## ultimate cinematic bars and the result. It only listens to the Events bus
## and draws; it never touches fighters.

const WHITE := Color(1.0, 1.0, 1.0)
const WARM := Color(1.0, 0.85, 0.3)
const HOT := Color(0.95, 0.2, 0.15)
const OUTLINE := Color(0.05, 0.03, 0.08)
const BAR_BACK := Color(0.1, 0.08, 0.16)
const BAR_NORMAL := Color(0.35, 0.65, 1.0)
const BAR_READY := Color(1.0, 0.8, 0.25)
const GAUGE_COLOR := Color(0.75, 0.35, 0.95)
const GAUGE_READY := Color(1.0, 0.45, 0.35)
const PLAYER_COLORS := {1: Color(0.95, 0.3, 0.3), 2: Color(0.3, 0.55, 0.95)}
const SCREEN := Vector2(480.0, 270.0)
const PERCENT_FULL_HEAT := 150.0
const BAR_WIDTH := 60.0
const BAR_HEIGHT := 4.0
const LETTERBOX_HEIGHT := 28.0
const CUTIN_SLIDE_FRAMES := 10.0
const CUTIN_FRAME := Vector2(72.0, 96.0)
const PLAYER_NAMES := {1: "PLAYER 1", 2: "PLAYER 2"}

var _percents: Dictionary = {}
var _stocks: Dictionary = {}
var _reiatsu: Dictionary = {}
var _bankai: Dictionary = {}
var _gauge: Dictionary = {}
var _transform_title: String = ""
var _transform_frames: int = 0
var _transform_total: int = 0
var _transform_player: int = 0
var _seconds_left: int = -1
var _sudden_death: bool = false
var _result_shown: bool = false
var _winner_id: int = 0
var _cinematic_frames: int = 0
var _cinematic_title: String = ""
var _cinematic_total: int = 0
var _cinematic_player: int = 1

var _canvas: Control


func _ready() -> void:
	layer = 50
	scale = RenderScale.ui() # laid out in 480x270, shown on the 720x405 screen
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_on_canvas_draw)
	add_child(_canvas)
	Events.fighter_percent_changed.connect(_on_percent_changed)
	Events.fighter_reiatsu_changed.connect(_on_reiatsu_changed)
	Events.fighter_bankai_changed.connect(_on_bankai_changed)
	Events.fighter_gauge_changed.connect(_on_gauge_changed)
	Events.transform_started.connect(_on_transform_started)
	Events.stocks_changed.connect(_on_stocks_changed)
	Events.match_time_changed.connect(_on_time_changed)
	Events.sudden_death_started.connect(_on_sudden_death_started)
	Events.match_ended.connect(_on_match_ended)
	Events.ultimate_started.connect(_on_ultimate_started)


func _physics_process(_delta: float) -> void:
	if _transform_frames > 0:
		_transform_frames -= 1
		_canvas.queue_redraw()
	if _cinematic_frames > 0:
		_cinematic_frames -= 1
		_canvas.queue_redraw()


func _on_percent_changed(player_id: int, percent: float) -> void:
	_percents[player_id] = percent
	_canvas.queue_redraw()


func _on_reiatsu_changed(player_id: int, reiatsu: float) -> void:
	_reiatsu[player_id] = reiatsu
	_canvas.queue_redraw()


func _on_bankai_changed(player_id: int, active: bool) -> void:
	_bankai[player_id] = active
	_canvas.queue_redraw()


func _on_stocks_changed(player_id: int, stocks: int) -> void:
	_stocks[player_id] = stocks
	_canvas.queue_redraw()


func _on_time_changed(seconds_left: int) -> void:
	_seconds_left = seconds_left
	_canvas.queue_redraw()


func _on_sudden_death_started() -> void:
	_sudden_death = true
	_canvas.queue_redraw()


func _on_match_ended(winner_id: int) -> void:
	_result_shown = true
	_winner_id = winner_id
	_canvas.queue_redraw()


func _on_gauge_changed(player_id: int, gauge: float) -> void:
	_gauge[player_id] = gauge
	_canvas.queue_redraw()


func _on_transform_started(player_id: int, title: String, frames: int) -> void:
	_transform_player = player_id
	_transform_title = title
	_transform_total = frames
	_transform_frames = frames
	_canvas.queue_redraw()


func _on_ultimate_started(player_id: int, freeze_frames: int, title: String) -> void:
	_cinematic_player = player_id
	_cinematic_total = freeze_frames
	_cinematic_frames = freeze_frames
	_cinematic_title = title
	_canvas.queue_redraw()


# --- Drawing ----------------------------------------------------------------

static func format_time(seconds_left: int) -> String:
	if seconds_left < 0:
		return "INF"
	return "%d:%02d" % [seconds_left / 60, seconds_left % 60]


static func percent_color(percent: float) -> Color:
	var heat := clampf(percent / PERCENT_FULL_HEAT, 0.0, 1.0)
	if heat < 0.5:
		return WHITE.lerp(WARM, heat * 2.0)
	return WARM.lerp(HOT, (heat - 0.5) * 2.0)


func _on_canvas_draw() -> void:
	var ids := _percents.keys()
	ids.sort()
	for index in ids.size():
		var panel_x := SCREEN.x * float(index + 1) / float(ids.size() + 1)
		_draw_player_panel(ids[index], panel_x)
	var clock := "SUDDEN DEATH" if _sudden_death else format_time(_seconds_left)
	_text(clock, Vector2(SCREEN.x * 0.5, 18.0), 14, WHITE)
	if _cinematic_frames > 0:
		_draw_cinematic()
	if _transform_frames > 0:
		_draw_transform()
	if _result_shown:
		_draw_result()


func _draw_player_panel(player_id: int, center_x: float) -> void:
	var color: Color = PLAYER_COLORS.get(player_id, WHITE)
	_text(_player_label(player_id), Vector2(center_x, 216.0), 8, color)
	var percent: float = _percents.get(player_id, 0.0)
	_text("%d%%" % int(percent), Vector2(center_x, 240.0), 24, percent_color(percent))
	var stock_count: int = _stocks.get(player_id, 0)
	var pip_gap := 9.0
	var first_x := center_x - pip_gap * float(stock_count - 1) * 0.5
	for pip in stock_count:
		var pip_rect := Rect2(first_x + pip_gap * float(pip) - 3.0, 246.0, 6.0, 6.0)
		_canvas.draw_rect(pip_rect.grow(1.0), OUTLINE)
		_canvas.draw_rect(pip_rect, color)
	_draw_gauge_bar(player_id, center_x)
	_draw_reiatsu_bar(player_id, center_x)


func _player_label(player_id: int) -> String:
	var label := "P%d" % player_id
	if player_id == 2 and MatchConfig.cpu_level > MatchConfig.CPU_OFF:
		label += " CPU"
	if _bankai.get(player_id, false):
		label += "  FORM"
	return label


## The Reiatsu meter as three blocks that fill one after the other; all three lit means the
## ultimate is possible (while transformed).
func _draw_reiatsu_bar(player_id: int, center_x: float) -> void:
	var value: float = _reiatsu.get(player_id, 0.0)
	var gap := 2.0
	var cell := (BAR_WIDTH - gap * float(Reiatsu.BLOCKS - 1)) / float(Reiatsu.BLOCKS)
	var left := center_x - BAR_WIDTH * 0.5
	for index in Reiatsu.BLOCKS:
		var area := Rect2(left + (cell + gap) * float(index), 258.0, cell, BAR_HEIGHT)
		_canvas.draw_rect(area.grow(1.0), OUTLINE)
		_canvas.draw_rect(area, BAR_BACK)
		var share := clampf((value - Reiatsu.BLOCK * float(index)) / Reiatsu.BLOCK, 0.0, 1.0)
		var full := value >= Reiatsu.ULTIMATE_COST
		_canvas.draw_rect(Rect2(area.position, Vector2(cell * share, BAR_HEIGHT)), BAR_READY if full or share >= 1.0 else BAR_NORMAL)


## The Combat Gauge above the Reiatsu bar; it pulses when a transformation is ready.
func _draw_gauge_bar(player_id: int, center_x: float) -> void:
	var value: float = _gauge.get(player_id, 0.0)
	var left := center_x - BAR_WIDTH * 0.5
	var area := Rect2(left, 253.0, BAR_WIDTH, BAR_HEIGHT)
	_canvas.draw_rect(area.grow(1.0), OUTLINE)
	_canvas.draw_rect(area, BAR_BACK)
	var ready := value >= CombatGauge.MAX
	var color := GAUGE_COLOR
	if ready:
		var pulse := 0.5 + 0.5 * sin(float(Engine.get_process_frames()) * 0.3)
		color = GAUGE_READY.lerp(WHITE, pulse * 0.6)
	_canvas.draw_rect(Rect2(left, area.position.y, BAR_WIDTH * value / CombatGauge.MAX, BAR_HEIGHT), color)
	if ready:
		_text("READY", Vector2(center_x, 251.0), 8, GAUGE_READY)


## The transformation title: a dark band across the screen with the name popping in.
func _draw_transform() -> void:
	var age := _transform_total - _transform_frames
	var t := clampf(float(age) / 18.0, 0.0, 1.0)
	var pop := 1.0 - pow(1.0 - t, 3.0)
	var fade := clampf(float(_transform_frames) / 12.0, 0.0, 1.0)
	var color: Color = PLAYER_COLORS.get(_transform_player, WHITE)
	_canvas.draw_rect(Rect2(0.0, 0.0, SCREEN.x, LETTERBOX_HEIGHT * pop), Color.BLACK)
	_canvas.draw_rect(Rect2(0.0, SCREEN.y - LETTERBOX_HEIGHT * pop, SCREEN.x, LETTERBOX_HEIGHT), Color.BLACK)
	var band_height := 30.0 * pop
	var band := Rect2(0.0, SCREEN.y * 0.22 - band_height * 0.5, SCREEN.x, band_height)
	_canvas.draw_rect(band, Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.85 * fade))
	_canvas.draw_rect(Rect2(band.position.x, band.position.y, SCREEN.x, 1.5), Color(1.0, 1.0, 1.0, fade))
	_canvas.draw_rect(Rect2(band.position.x, band.end.y - 1.5, SCREEN.x, 1.5), Color(color.r, color.g, color.b, fade))
	if pop > 0.3:
		_text(_transform_title, Vector2(SCREEN.x * 0.5, band.get_center().y + 7.0 + (1.0 - pop) * 12.0), 20, Color(WARM.r, WARM.g, WARM.b, fade))


## 0..1 slide-in progress of the cut-in `age` frames after it started.
static func cutin_slide(age: int) -> float:
	var t := clampf(float(age) / CUTIN_SLIDE_FRAMES, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


func _draw_cinematic() -> void:
	_canvas.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0.0, 0.0, 0.05, 0.35))
	_canvas.draw_rect(Rect2(0.0, 0.0, SCREEN.x, LETTERBOX_HEIGHT), Color.BLACK)
	_canvas.draw_rect(Rect2(0.0, SCREEN.y - LETTERBOX_HEIGHT, SCREEN.x, LETTERBOX_HEIGHT), Color.BLACK)
	var slide := cutin_slide(_cinematic_total - _cinematic_frames)
	var color: Color = PLAYER_COLORS.get(_cinematic_player, WHITE)
	# A slanted band that sweeps in from the left, with the move name on it.
	var shift := (1.0 - slide) * -SCREEN.x
	var band := PackedVector2Array([
		Vector2(shift, 44.0), Vector2(shift + SCREEN.x, 36.0),
		Vector2(shift + SCREEN.x, 74.0), Vector2(shift, 82.0),
	])
	_canvas.draw_colored_polygon(band, Color(color.r * 0.35, color.g * 0.35, color.b * 0.35, 0.9))
	_canvas.draw_line(band[0], band[1], WHITE, 2.0)
	_canvas.draw_line(band[3], band[2], color, 2.0)
	# Placeholder portrait frame (a real portrait can replace the fill later).
	var on_left := _cinematic_player == 1
	var frame_x := 36.0 if on_left else SCREEN.x - 36.0 - CUTIN_FRAME.x
	var frame_shift := (1.0 - slide) * (-120.0 if on_left else 120.0)
	var frame := Rect2(Vector2(frame_x + frame_shift, 98.0), CUTIN_FRAME)
	_canvas.draw_rect(frame.grow(2.0), OUTLINE)
	_canvas.draw_rect(frame, Color(color.r * 0.25, color.g * 0.25, color.b * 0.25, 0.95))
	_canvas.draw_rect(frame, color, false, 2.0)
	_text(PLAYER_NAMES.get(_cinematic_player, "P%d" % _cinematic_player), frame.get_center() + Vector2(0.0, 4.0), 12, WHITE)
	var title_x := SCREEN.x * 0.5 + (60.0 if on_left else -60.0)
	_text(_cinematic_title, Vector2(title_x + shift * 0.4, 66.0), 20, WARM)


func _draw_result() -> void:
	_canvas.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0.0, 0.0, 0.0, 0.5))
	var headline := "DRAW" if _winner_id == 0 else "PLAYER %d WINS!" % _winner_id
	if ArcadeRun.active:
		headline = "YOU WIN!" if _winner_id == 1 else "YOU LOSE"
	var headline_color: Color = PLAYER_COLORS.get(_winner_id, WHITE)
	_text(headline, Vector2(SCREEN.x * 0.5, 130.0), 26, headline_color)
	var hint := "Enter: continue     Esc: quit Arcade" if ArcadeRun.active else "Enter: play again     Esc: menu"
	_text(hint, Vector2(SCREEN.x * 0.5, 156.0), 10, WHITE)


## Centered outlined text. `position` is the middle of the baseline.
func _text(text: String, position: Vector2, font_size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var origin := Vector2(position.x - width * 0.5, position.y)
	_canvas.draw_string_outline(
		font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 3, OUTLINE
	)
	_canvas.draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
