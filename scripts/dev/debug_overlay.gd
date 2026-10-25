extends CanvasLayer
## Tiny developer overlay: key help and the current state of each fighter.
## Listens to the Events bus only. F1 hides it.

const FONT_SIZE := 8
const HELP_TEXT := "P1: WASD (W jump, S drop/fast-fall)   P2: arrows (same)   F1: hide"

var _label: Label
var _states: Dictionary = {}


func _ready() -> void:
	layer = 100
	_label = Label.new()
	_label.position = Vector2(4.0, 3.0)
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	add_child(_label)
	Events.fighter_state_changed.connect(_on_fighter_state_changed)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_F1:
		_label.visible = not _label.visible


func _on_fighter_state_changed(player_id: int, state_name: StringName) -> void:
	_states[player_id] = state_name
	_refresh()


func _refresh() -> void:
	var lines := PackedStringArray([HELP_TEXT])
	var player_ids := _states.keys()
	player_ids.sort()
	for player_id in player_ids:
		lines.append("P%d: %s" % [player_id, _states[player_id]])
	_label.text = "\n".join(lines)
