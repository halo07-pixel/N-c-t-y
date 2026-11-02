class_name TrialSelect
extends MenuScreen
## Combo trial menu: Left / Right chooses the character, Up / Down the exercise, Attack starts it.
## A tick marks the exercises already completed.

const ROW_HEIGHT := 22.0

var character_index: int = 0
var trial_cursor := MenuCursor.new(4)


func _ready() -> void:
	super()
	character_index = clampi(MatchConfig.p1_index, 0, MatchConfig.roster_size() - 1)


func character() -> CharacterData:
	return load(MatchConfig.ROSTER_PATHS[character_index]) as CharacterData


func trials() -> Array[ComboTrial]:
	return TrialLibrary.for_character(character())


func handle_action(action: StringName) -> void:
	match action:
		&"left":
			character_index = posmod(character_index - 1, MatchConfig.roster_size())
			trial_cursor.index = 0
		&"right":
			character_index = posmod(character_index + 1, MatchConfig.roster_size())
			trial_cursor.index = 0
		&"up":
			trial_cursor.step(-1)
		&"down":
			trial_cursor.step(1)
		&"confirm":
			_start()
		&"back":
			go_to(&"main_menu")
	queue_redraw()


func _start() -> void:
	MatchConfig.p1_index = character_index
	MatchConfig.p2_index = character_index
	MatchConfig.cpu_level = MatchConfig.CPU_OFF
	MatchConfig.arcade = false
	MatchConfig.trial_character = character_index
	MatchConfig.trial_index = trial_cursor.index
	go_to(&"trial_match")


func _draw_content() -> void:
	draw_centered("COMBO TRIAL", Vector2(SCREEN.x * 0.5, 40.0), 18, WHITE)
	var who := character()
	draw_centered("< %s >" % who.display_name.to_upper(), Vector2(SCREEN.x * 0.5, 66.0), 14, WARM)
	var list := trials()
	for row in list.size():
		var item := list[row]
		var y := 100.0 + float(row) * ROW_HEIGHT
		var mark := "[x] " if GameSettings.is_trial_done(item.key) else "[ ] "
		var selected := row == trial_cursor.index
		draw_left("%s%d. %s" % [mark, row + 1, item.title], Vector2(110.0, y), 12 if selected else 11, WARM if selected else WHITE)
	var chosen := list[trial_cursor.index]
	draw_centered(chosen.description, Vector2(SCREEN.x * 0.5, 212.0), 8, DIM)
	var steps := PackedStringArray()
	for step in chosen.steps:
		steps.append(ComboTrial.step_label(step))
	draw_centered(" > ".join(steps), Vector2(SCREEN.x * 0.5, 226.0), 8, WHITE)
	draw_centered("Left / Right: fighter    Up / Down: exercise    Attack: start    Guard: back", Vector2(SCREEN.x * 0.5, 256.0), 8, DIM)
