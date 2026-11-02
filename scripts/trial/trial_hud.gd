class_name TrialHud
extends CanvasLayer
## The practice HUD: the exercise name, its steps with the current one highlighted, and a
## COMPLETE / RETRY banner. It draws what it is told; the practice scene feeds it from the tracker.

const SCREEN := Vector2(480.0, 270.0)
const LINE_HEIGHT := 14.0
const PANEL_WIDTH := 190.0
const PANEL_LEFT := 284.0 # the right side; the debug text owns the top left
const DONE_COLOR := Color(0.5, 0.95, 0.6)
const NOW_COLOR := Color(1.0, 0.85, 0.4)
const LATER_COLOR := Color(0.72, 0.75, 0.9)

var _canvas: Control
var _trial: ComboTrial
var _index: int = 0
var _banner: String = ""
var _banner_color: Color = Color.WHITE


func _ready() -> void:
	layer = 20
	scale = RenderScale.ui()
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_on_draw)
	add_child(_canvas)


func show_trial(trial: ComboTrial) -> void:
	_trial = trial
	_index = 0
	_banner = ""
	_redraw()


func set_progress(next_index: int) -> void:
	_index = next_index
	_redraw()


func show_banner(text: String, color: Color) -> void:
	_banner = text
	_banner_color = color
	_redraw()


func clear_banner() -> void:
	_banner = ""
	_redraw()


func banner_text() -> String:
	return _banner


func step_marks() -> PackedStringArray:
	var marks := PackedStringArray()
	if _trial == null:
		return marks
	for i in _trial.steps.size():
		marks.append("[x]" if i < _index else ("> " if i == _index else "[ ]"))
	return marks


func _redraw() -> void:
	if _canvas != null:
		_canvas.queue_redraw()


func _on_draw() -> void:
	if _trial == null:
		return
	var font := ThemeDB.fallback_font
	_canvas.draw_rect(Rect2(PANEL_LEFT, 6.0, PANEL_WIDTH, 30.0 + LINE_HEIGHT * float(_trial.steps.size())), Color(0.02, 0.02, 0.07, 0.72))
	_canvas.draw_string(font, Vector2(PANEL_LEFT + 6.0, 20.0), "COMBO TRIAL: %s" % _trial.title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, PANEL_WIDTH - 10.0, 9, Color(1.0, 0.85, 0.4))
	var marks := step_marks()
	for i in _trial.steps.size():
		var color := DONE_COLOR if i < _index else (NOW_COLOR if i == _index else LATER_COLOR)
		var line := "%s %s" % [marks[i], ComboTrial.step_label(_trial.steps[i])]
		_canvas.draw_string(font, Vector2(PANEL_LEFT + 6.0, 36.0 + LINE_HEIGHT * float(i)), line, HORIZONTAL_ALIGNMENT_LEFT, PANEL_WIDTH - 10.0, 8, color)
	if _banner != "":
		var width := font.get_string_size(_banner, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20).x
		var origin := Vector2((SCREEN.x - width) * 0.5, 120.0)
		_canvas.draw_string_outline(font, origin, _banner, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, 4, Color(0.03, 0.02, 0.06))
		_canvas.draw_string(font, origin, _banner, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, _banner_color)
	_canvas.draw_string(font, Vector2(8.0, SCREEN.y - 6.0), "R: retry    Esc: back    F3: move list", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color(0.6, 0.65, 0.8))
