class_name ArcadeContinue
extends MenuScreen
## Shown after losing an Arcade fight: try the same fight again or give up.


func handle_action(action: StringName) -> void:
	match action:
		&"confirm":
			go_to(&"versus_match")
		&"back":
			ArcadeRun.quit_run()
			go_to(&"main_menu")


func _draw_content() -> void:
	var middle := SCREEN.x * 0.5
	draw_centered("DEFEATED", Vector2(middle, 90.0), 28, RED)
	draw_centered("Continues used: %d" % ArcadeRun.continues_used, Vector2(middle, 116.0), 10, DIM)
	draw_centered("Try this fight again?", Vector2(middle, 160.0), 14, WHITE)
	draw_centered("Attack: continue    Guard: give up", Vector2(middle, 256.0), 8, DIM)
