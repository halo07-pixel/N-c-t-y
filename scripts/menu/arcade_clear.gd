class_name ArcadeClear
extends MenuScreen
## The ending, shown after the boss falls.

const LINE_START_Y := 140.0
const LINE_HEIGHT := 16.0


func handle_action(action: StringName) -> void:
	if action == &"confirm" or action == &"back":
		ArcadeRun.quit_run()
		go_to(&"main_menu")


func _draw_content() -> void:
	var middle := SCREEN.x * 0.5
	draw_centered("ARCADE CLEAR", Vector2(middle, 70.0), 26, WARM)
	var result := "%s cleared all %d fights" % [ArcadeRun.player_name(), ArcadeRun.FIGHT_COUNT]
	if ArcadeRun.continues_used == 0:
		result += " without a continue!"
	else:
		result += " with %d continue(s)." % ArcadeRun.continues_used
	draw_centered(result, Vector2(middle, 98.0), 10, WHITE)
	var lines := ArcadeRun.ending_lines()
	for row in lines.size():
		draw_centered(lines[row], Vector2(middle, LINE_START_Y + row * LINE_HEIGHT), 10, WHITE)
	draw_centered("Attack: back to the menu", Vector2(middle, 256.0), 8, DIM)
