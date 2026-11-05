class_name MainMenu
extends MenuScreen
## Mode list: Arcade, Versus 2 Players, Versus CPU, Combo Trial, Training, Settings, Quit.

const ITEMS: Array[StringName] = [&"arcade", &"versus", &"versus_cpu", &"trial", &"training", &"settings", &"quit"]
const LABELS := {
	&"arcade": "ARCADE",
	&"versus": "VERSUS  2 PLAYERS",
	&"versus_cpu": "VERSUS  CPU",
	&"trial": "COMBO TRIAL",
	&"training": "TRAINING",
	&"settings": "SETTINGS",
	&"quit": "QUIT",
}
const DEFAULT_CPU_LEVEL := 2
const ROW_HEIGHT := 22.0

var cursor := MenuCursor.new(ITEMS.size())


func handle_action(action: StringName) -> void:
	match action:
		&"up":
			cursor.step(-1)
		&"down":
			cursor.step(1)
		&"confirm":
			activate(ITEMS[cursor.index])
		&"back":
			go_to(&"title")
	queue_redraw()


func activate(item: StringName) -> void:
	ArcadeRun.quit_run() # every mode starts clean; Arcade sets itself up below
	MatchConfig.training = false
	match item:
		&"arcade":
			MatchConfig.arcade = true
			MatchConfig.cpu_level = DEFAULT_CPU_LEVEL
			go_to(&"character_select")
		&"versus":
			go_to(&"character_select")
		&"versus_cpu":
			MatchConfig.cpu_level = DEFAULT_CPU_LEVEL
			go_to(&"character_select")
		&"trial":
			go_to(&"trial_select")
		&"training":
			MatchConfig.training = true
			MatchConfig.arcade = false
			MatchConfig.cpu_level = DEFAULT_CPU_LEVEL # you pick your fighter, then the dummy
			go_to(&"character_select")
		&"settings":
			go_to(&"settings")
		&"quit":
			get_tree().quit()


func _draw_content() -> void:
	draw_centered("MAIN MENU", Vector2(SCREEN.x * 0.5, 56.0), 20, WHITE)
	for row in ITEMS.size():
		var item := ITEMS[row]
		var y := 88.0 + row * ROW_HEIGHT
		var color := DIM if cursor.is_disabled(row) else WHITE
		if row == cursor.index:
			color = WARM
			draw_centered("> %s <" % LABELS[item], Vector2(SCREEN.x * 0.5, y), 14, color)
		else:
			draw_centered(LABELS[item], Vector2(SCREEN.x * 0.5, y), 12, color)
	draw_centered("Up / Down: move    Attack: select    Guard: back", Vector2(SCREEN.x * 0.5, 256.0), 8, DIM)
