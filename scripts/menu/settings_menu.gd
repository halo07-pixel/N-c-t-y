class_name SettingsMenu
extends MenuScreen
## Match rules (stocks, time limit), volume and a read-only key list.
## Changes go to GameSettings at once and are saved when leaving.

const ROWS: Array[StringName] = [&"stocks", &"time", &"music", &"sfx", &"effects", &"controls", &"back"]
const LABELS := {
	&"stocks": "STOCKS", &"time": "TIME LIMIT", &"music": "MUSIC VOLUME",
	&"sfx": "SFX VOLUME", &"effects": "SCREEN EFFECTS", &"controls": "CONTROLS", &"back": "BACK",
}
const ROW_HEIGHT := 22.0
const FIRST_ROW_Y := 84.0
const ACTION_LABELS := {
	&"left": "Left", &"right": "Right", &"up": "Jump", &"down": "Down / drop",
	&"attack": "Attack", &"special": "Special", &"guard": "Guard / Shunpo",
	&"charge": "Charge / Bankai / Ult",
}

var cursor := MenuCursor.new(ROWS.size())
var showing_controls: bool = false


func handle_action(action: StringName) -> void:
	if showing_controls:
		if action == &"confirm" or action == &"back":
			showing_controls = false
		queue_redraw()
		return
	match action:
		&"up":
			cursor.step(-1)
		&"down":
			cursor.step(1)
		&"left":
			change(ROWS[cursor.index], -1)
		&"right":
			change(ROWS[cursor.index], 1)
		&"confirm":
			_activate(ROWS[cursor.index])
		&"back":
			leave()
	queue_redraw()


## Changes the value of one row by a step (left -1, right +1).
func change(row: StringName, direction: int) -> void:
	match row:
		&"stocks":
			GameSettings.step_stocks(direction)
		&"time":
			GameSettings.step_time_minutes(direction)
		&"music":
			GameSettings.step_music_volume(direction)
		&"sfx":
			GameSettings.step_sfx_volume(direction)
		&"effects":
			GameSettings.toggle_screen_effects()


func leave() -> void:
	GameSettings.save_settings()
	go_to(&"main_menu")


func _activate(row: StringName) -> void:
	match row:
		&"controls":
			showing_controls = true
		&"back":
			leave()
		_:
			change(row, 1)


func value_text(row: StringName) -> String:
	match row:
		&"stocks":
			return str(GameSettings.stocks)
		&"time":
			if GameSettings.is_time_unlimited():
				return "Unlimited"
			return "%d min" % GameSettings.time_minutes
		&"music":
			return _volume_text(GameSettings.music_volume)
		&"sfx":
			return _volume_text(GameSettings.sfx_volume)
		&"effects":
			return "ON" if GameSettings.screen_effects else "OFF"
	return ""


func _volume_text(volume: int) -> String:
	return "#".repeat(volume) + "-".repeat(GameSettings.MAX_VOLUME - volume)


func _draw_content() -> void:
	draw_centered("SETTINGS", Vector2(SCREEN.x * 0.5, 50.0), 20, WHITE)
	if showing_controls:
		_draw_controls()
		return
	for row in ROWS.size():
		_draw_row(row)
	draw_centered(
		"Up / Down: move    Left / Right: change    Guard: back", Vector2(SCREEN.x * 0.5, 256.0), 8, DIM
	)


func _draw_row(row: int) -> void:
	var id := ROWS[row]
	var y := FIRST_ROW_Y + row * ROW_HEIGHT
	var color := WARM if row == cursor.index else WHITE
	draw_left(LABELS[id], Vector2(110.0, y), 12, color)
	var value := value_text(id)
	if value != "":
		var text := "< %s >" % value if row == cursor.index else value
		draw_left(text, Vector2(260.0, y), 12, color)


func _draw_controls() -> void:
	draw_left("ACTION", Vector2(60.0, 82.0), 9, DIM)
	draw_left("PLAYER 1", Vector2(250.0, 82.0), 9, RED)
	draw_left("PLAYER 2", Vector2(350.0, 82.0), 9, BLUE)
	for row in InputBindings.ACTIONS.size():
		var action := InputBindings.ACTIONS[row]
		var y := 100.0 + row * 17.0
		draw_left(ACTION_LABELS[action], Vector2(60.0, y), 9, WHITE)
		draw_left(_key_name(1, action), Vector2(250.0, y), 9, WHITE)
		draw_left(_key_name(2, action), Vector2(350.0, y), 9, WHITE)
	draw_centered("Attack or Guard: close", Vector2(SCREEN.x * 0.5, 256.0), 8, DIM)


func _key_name(player_id: int, action: StringName) -> String:
	var keycode: Key = InputBindings.DEFAULT_KEYS[player_id][action]
	return OS.get_keycode_string(keycode).replace("Kp ", "Numpad ")
