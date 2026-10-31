class_name MoveListOverlay
extends CanvasLayer
## The move list of both fighters, shown with F3 during a match: every attack with its button,
## the specials with their cooldowns, throw, Shunpo, form and ultimate. It reads the characters'
## data only, so it is always in step with the game.

const FONT_SIZE := 8
const LINE_HEIGHT := 10.0
const SCREEN := Vector2(480.0, 270.0)

var _canvas: Control
var _blocks: Array = []


func _ready() -> void:
	layer = 110 # above the debug overlay
	scale = RenderScale.ui()
	visible = false
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_on_draw)
	add_child(_canvas)


func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_F3:
		toggle()


func toggle() -> void:
	visible = not visible
	if visible:
		_blocks.clear()
		for player_id in [1, 2]:
			var character := MatchConfig.character_for(player_id)
			if character != null:
				_blocks.append(lines_for(character, player_id))
	_canvas.queue_redraw()


func _on_draw() -> void:
	_canvas.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0.03, 0.02, 0.08, 0.97))
	var font := ThemeDB.fallback_font
	for index in _blocks.size():
		var lines: PackedStringArray = _blocks[index]
		var x := 8.0 + float(index) * SCREEN.x * 0.5
		for line_index in lines.size():
			var color := Color(1.0, 0.85, 0.4) if line_index == 0 else Color(0.92, 0.94, 1.0)
			_canvas.draw_string(font, Vector2(x, 14.0 + float(line_index) * LINE_HEIGHT), lines[line_index], HORIZONTAL_ALIGNMENT_LEFT, SCREEN.x * 0.5 - 12.0, FONT_SIZE, color)
	_canvas.draw_string(font, Vector2(8.0, SCREEN.y - 6.0), "F3: close", HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, Color(0.6, 0.65, 0.8))


static func _key(player_id: int, action: StringName) -> String:
	return MatchHud.skill_key_label(player_id, action)


static func _seconds(frames: int) -> String:
	return "%.1fs" % (float(frames) / 60.0)


## One line per skill: "  hold direction  name  cooldown (cost)".
static func _skill_line(direction: String, skill: SpecialData) -> String:
	if skill == null:
		return "  %s  -" % direction
	var text := "  %s  %s  %s" % [direction, skill.display_name, _seconds(skill.cooldown_frames)]
	if skill.cost > 0.0:
		text += "  (%d Reiatsu)" % int(skill.cost)
	elif skill.is_chargeable():
		text += "  (hold to charge)"
	elif skill.follow_up != null:
		text += "  (again: %s)" % skill.follow_up.display_name
	return text


## The move list of a character as text lines; the first line is its name.
static func lines_for(character: CharacterData, player_id: int) -> PackedStringArray:
	var attack := _key(player_id, &"attack")
	var special := _key(player_id, &"special")
	var special2 := _key(player_id, &"special2")
	var guard := _key(player_id, &"guard")
	var charge := _key(player_id, &"charge")
	var moves := character.moveset
	var lines := PackedStringArray()
	lines.append("%s" % character.display_name.to_upper())
	var jab := moves.ground_neutral
	var second := jab.next_in_chain
	lines.append("%s  %s > %s > %s" % [attack, jab.display_name, second.display_name, second.next_in_chain.display_name])
	lines.append("  2nd hit + Up: %s   + Down: %s" % [second.chain_up.display_name, second.chain_down.display_name])
	lines.append("%s+Fwd %s   +Up %s" % [attack, moves.ground_forward.display_name, moves.ground_up.display_name])
	lines.append("  +Down %s" % moves.ground_down.display_name)
	lines.append("Air %s: %s / %s / %s / %s" % [attack, moves.air_neutral.display_name, moves.air_forward.display_name, moves.air_up.display_name, moves.air_down.display_name])
	lines.append("%s+%s close: %s (throw, 2s)" % [guard, attack, moves.throw_move.display_name])
	lines.append("%s+direction: Shunpo" % guard)
	var kit := character.specials
	lines.append("%s  Special" % special)
	lines.append(_skill_line("none", kit.neutral))
	lines.append(_skill_line("fwd ", kit.forward))
	lines.append(_skill_line("up  ", kit.up))
	lines.append(_skill_line("down", kit.down))
	lines.append("%s  Special 2" % special2)
	lines.append(_skill_line("none", kit.alt_neutral))
	lines.append(_skill_line("fwd ", kit.alt_forward))
	lines.append(_skill_line("up  ", kit.alt_up))
	lines.append(_skill_line("down", kit.alt_down))
	var ultimate := character.ultimate.display_name if character.ultimate != null else "-"
	lines.append("%s  Form: %s" % [charge, character.transform_title])
	lines.append("%s  Ultimate: %s (form + full Reiatsu)" % [charge, ultimate])
	return lines
