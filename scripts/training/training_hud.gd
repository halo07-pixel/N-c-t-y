class_name TrainingHud
extends CanvasLayer
## The Training HUD: combo counter, the dummy's behaviour, the infinite-resources switch and the
## key list. It draws what it is told; the scene feeds it from TrainingRules.

const SCREEN := Vector2(480.0, 270.0)
const PANEL_LEFT := 330.0
const PANEL_WIDTH := 144.0
const WARM := Color(1.0, 0.85, 0.4)
const DIM := Color(0.6, 0.65, 0.8)
const WHITE := Color(0.95, 0.95, 1.0)
const HELP_LINES: Array[String] = ["R reset positions", "T change dummy", "Y infinite on/off", "F2 hitboxes   F3 moves", "Esc back"]

var _canvas: Control
var _lines: PackedStringArray = []
var _combo_text: String = ""


func _ready() -> void:
	layer = 20
	scale = RenderScale.ui()
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_on_draw)
	add_child(_canvas)


## The text the panel shows for the given rules (pure, so it can be tested).
static func panel_lines(rules: TrainingRules) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("DUMMY: %s" % rules.mode_label())
	lines.append("INFINITE: %s" % ("ON" if rules.infinite_resources else "OFF"))
	lines.append("LAST COMBO: %d hits, %.1f%%" % [rules.last_hits, rules.last_damage])
	lines.append("BEST: %d hits" % rules.best_hits)
	return lines


static func combo_text(hits: int, damage: float) -> String:
	return "" if hits <= 1 else "%d HITS  %.1f%%" % [hits, damage]


func show_rules(rules: TrainingRules) -> void:
	_lines = panel_lines(rules)
	_combo_text = combo_text(rules.hits, rules.damage)
	_redraw()


func lines() -> PackedStringArray:
	return _lines


func _redraw() -> void:
	if _canvas != null:
		_canvas.queue_redraw()


func _on_draw() -> void:
	var font := UiFont.get_font()
	var rows := _lines.size() + HELP_LINES.size()
	_canvas.draw_rect(Rect2(PANEL_LEFT, 6.0, PANEL_WIDTH, 24.0 + 10.0 * float(rows)), Color(0.02, 0.02, 0.07, 0.72))
	_canvas.draw_string(font, Vector2(PANEL_LEFT + 6.0, 17.0), "TRAINING", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, WARM)
	for index in _lines.size():
		_canvas.draw_string(font, Vector2(PANEL_LEFT + 6.0, 29.0 + 10.0 * float(index)), _lines[index], HORIZONTAL_ALIGNMENT_LEFT, PANEL_WIDTH - 10.0, 7, WHITE)
	for index in HELP_LINES.size():
		var y := 33.0 + 10.0 * float(_lines.size() + index)
		_canvas.draw_string(font, Vector2(PANEL_LEFT + 6.0, y), HELP_LINES[index], HORIZONTAL_ALIGNMENT_LEFT, PANEL_WIDTH - 10.0, 6, DIM)
	if _combo_text != "":
		var width := font.get_string_size(_combo_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16).x
		var origin := Vector2((SCREEN.x - width) * 0.5, 70.0)
		_canvas.draw_string_outline(font, origin, _combo_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, 4, Color(0.03, 0.02, 0.06))
		_canvas.draw_string(font, origin, _combo_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, WARM)
