class_name ArcadeStory
extends MenuScreen
## Shown before each Arcade fight: which fight it is, the opponent and a few
## lines of story.

const LINE_START_Y := 150.0
const LINE_HEIGHT := 16.0


func handle_action(action: StringName) -> void:
	match action:
		&"confirm":
			go_to(&"versus_match")
		&"back":
			ArcadeRun.quit_run()
			go_to(&"main_menu")


func heading() -> String:
	if ArcadeRun.is_boss_fight():
		return "FINAL FIGHT"
	return "FIGHT %d / %d" % [ArcadeRun.fight_index + 1, ArcadeRun.FIGHT_COUNT]


func _draw_content() -> void:
	var middle := SCREEN.x * 0.5
	draw_centered(heading(), Vector2(middle, 50.0), 12, WARM)
	draw_centered(
		"%s  vs  %s" % [ArcadeRun.player_name().to_upper(), ArcadeRun.opponent_name().to_upper()],
		Vector2(middle, 86.0), 20, WHITE
	)
	draw_centered("CPU LEVEL %d" % ArcadeRun.cpu_level_for(), Vector2(middle, 110.0), 10, RED)
	var lines := ArcadeRun.intro_lines()
	for row in lines.size():
		draw_centered(lines[row], Vector2(middle, LINE_START_Y + row * LINE_HEIGHT), 10, WHITE)
	draw_centered("Attack: fight    Guard: quit Arcade", Vector2(middle, 256.0), 8, DIM)
