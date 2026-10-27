extends CanvasLayer
## Tiny developer overlay: key help, who is playing and the state of each fighter.
## Listens to the Events bus only. F1 hides it, F2 shows hitboxes.

const FONT_SIZE := 8
const HELP_TEXT := "F1 hide  F2 hitboxes  Esc menu"

var _label: Label
var _states: Dictionary = {}


func _ready() -> void:
	layer = 100
	scale = RenderScale.ui()
	_label = Label.new()
	_label.position = Vector2(4.0, 3.0)
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.08))
	_label.add_theme_constant_override("outline_size", 3)
	add_child(_label)
	Events.fighter_state_changed.connect(_on_fighter_state_changed)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_F1:
		_label.visible = not _label.visible
	elif key_event.keycode == KEY_F2:
		Hitbox.show_debug = not Hitbox.show_debug


func _on_fighter_state_changed(player_id: int, state_name: StringName) -> void:
	_states[player_id] = state_name
	_refresh()


func _refresh() -> void:
	var lines := PackedStringArray([HELP_TEXT, MatchConfig.describe()])
	var player_ids := _states.keys()
	player_ids.sort()
	for player_id in player_ids:
		lines.append("P%d: %s" % [player_id, _states[player_id]])
	_label.text = "\n".join(lines)
