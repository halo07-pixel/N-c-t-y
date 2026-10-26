class_name MatchHud
extends CanvasLayer
## On-screen match info: percent and stocks per player, the clock and the
## result. It only listens to the Events bus and draws; it never touches fighters.

const WHITE := Color(1.0, 1.0, 1.0)
const WARM := Color(1.0, 0.85, 0.3)
const HOT := Color(0.95, 0.2, 0.15)
const OUTLINE := Color(0.05, 0.03, 0.08)
const PLAYER_COLORS := {1: Color(0.95, 0.3, 0.3), 2: Color(0.3, 0.55, 0.95)}
const SCREEN := Vector2(480.0, 270.0)
const PERCENT_FULL_HEAT := 150.0

var _percents: Dictionary = {}
var _stocks: Dictionary = {}
var _seconds_left: int = -1
var _sudden_death: bool = false
var _result_shown: bool = false
var _winner_id: int = 0

var _canvas: Control


func _ready() -> void:
	layer = 50
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_on_canvas_draw)
	add_child(_canvas)
	Events.fighter_percent_changed.connect(_on_percent_changed)
	Events.stocks_changed.connect(_on_stocks_changed)
	Events.match_time_changed.connect(_on_time_changed)
	Events.sudden_death_started.connect(_on_sudden_death_started)
	Events.match_ended.connect(_on_match_ended)


func _on_percent_changed(player_id: int, percent: float) -> void:
	_percents[player_id] = percent
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
	if _result_shown:
		_draw_result()


func _draw_player_panel(player_id: int, center_x: float) -> void:
	var color: Color = PLAYER_COLORS.get(player_id, WHITE)
	_text("P%d" % player_id, Vector2(center_x, 226.0), 8, color)
	var percent: float = _percents.get(player_id, 0.0)
	_text("%d%%" % int(percent), Vector2(center_x, 248.0), 24, percent_color(percent))
	var stock_count: int = _stocks.get(player_id, 0)
	var pip_gap := 9.0
	var first_x := center_x - pip_gap * float(stock_count - 1) * 0.5
	for pip in stock_count:
		var pip_rect := Rect2(first_x + pip_gap * float(pip) - 3.0, 254.0, 6.0, 6.0)
		_canvas.draw_rect(pip_rect.grow(1.0), OUTLINE)
		_canvas.draw_rect(pip_rect, color)


func _draw_result() -> void:
	_canvas.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0.0, 0.0, 0.0, 0.5))
	var headline := "DRAW" if _winner_id == 0 else "PLAYER %d WINS!" % _winner_id
	var headline_color: Color = PLAYER_COLORS.get(_winner_id, WHITE)
	_text(headline, Vector2(SCREEN.x * 0.5, 130.0), 26, headline_color)
	_text("Press Enter to play again", Vector2(SCREEN.x * 0.5, 156.0), 10, WHITE)


## Centered outlined text. `position` is the middle of the baseline.
func _text(text: String, position: Vector2, font_size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var origin := Vector2(position.x - width * 0.5, position.y)
	_canvas.draw_string_outline(
		font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 3, OUTLINE
	)
	_canvas.draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
