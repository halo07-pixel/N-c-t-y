class_name TitleScreen
extends MenuScreen
## First screen: the game name and "press attack".

const BLINK_SECONDS := 0.6

var _blink_time: float = 0.0


func _process(delta: float) -> void:
	var before := _blink_on()
	_blink_time += delta
	if _blink_on() != before:
		queue_redraw()


func handle_action(action: StringName) -> void:
	if action == &"confirm":
		go_to(&"main_menu")


func _blink_on() -> bool:
	return int(_blink_time / BLINK_SECONDS) % 2 == 0


func _draw_content() -> void:
	draw_centered("BLEACH", Vector2(SCREEN.x * 0.5, 100.0), 44, WHITE)
	draw_centered("BLOOD WAR FIGHTERS", Vector2(SCREEN.x * 0.5, 130.0), 18, RED)
	if _blink_on():
		draw_centered("Press Attack (J / Numpad 1) or Enter", Vector2(SCREEN.x * 0.5, 190.0), 10, WARM)
	draw_centered(
		"Unofficial fan project - non-commercial", Vector2(SCREEN.x * 0.5, 256.0), 8, DIM
	)
