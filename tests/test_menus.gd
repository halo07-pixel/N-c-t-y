extends TestCase
## Menu logic: cursor, key mapping, screen flow, settings steps. The screens are
## built without entering the tree, and the router is switched off so the test
## scene is not replaced.

const SETTINGS_SCRIPT := preload("res://scripts/autoload/game_settings.gd")
const SELECT_SCENE: PackedScene = preload("res://scenes/ui/character_select.tscn")
const MAIN_MENU_SCENE: PackedScene = preload("res://scenes/ui/main_menu.tscn")
const SETTINGS_SCENE: PackedScene = preload("res://scenes/ui/settings_menu.tscn")

var _requested: Array[StringName] = []
var _saved_cpu: int
var _saved_stocks: int
var _saved_time: int


func _on_screen_requested(screen: StringName) -> void:
	_requested.append(screen)


func _begin() -> void:
	_requested.clear()
	ScreenRouter.enabled = false
	Events.screen_requested.connect(_on_screen_requested)
	_saved_cpu = MatchConfig.cpu_level
	_saved_stocks = GameSettings.stocks
	_saved_time = GameSettings.time_minutes


func _end() -> void:
	Events.screen_requested.disconnect(_on_screen_requested)
	ScreenRouter.enabled = true
	MatchConfig.cpu_level = _saved_cpu
	MatchConfig.p1_index = 0
	MatchConfig.p2_index = 1
	MatchConfig.arcade = false
	GameSettings.stocks = _saved_stocks
	GameSettings.time_minutes = _saved_time


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	return event


func test_every_screen_name_points_to_a_scene() -> void:
	for screen: StringName in ScreenRouter.SCREENS:
		check(ResourceLoader.exists(ScreenRouter.path_for(screen)), "%s exists" % screen)
	check_eq(ScreenRouter.path_for(&"nowhere"), "", "unknown screens have no path")


func test_cursor_wraps_and_skips_disabled_items() -> void:
	var cursor := MenuCursor.new(4, [0] as Array[int])
	check_eq(cursor.index, 1, "starts on the first enabled item")
	cursor.step(-1)
	check_eq(cursor.index, 3, "moving up from the first enabled item wraps to the last")
	cursor.step(1)
	check_eq(cursor.index, 1, "moving down wraps past the disabled item")


func test_menu_keys_map_to_actions_for_both_players() -> void:
	check_eq(MenuNav.read(_key(KEY_J)), &"confirm", "P1 attack confirms")
	check_eq(MenuNav.read(_key(KEY_KP_1)), &"confirm", "P2 attack confirms")
	check_eq(MenuNav.read(_key(KEY_L)), &"back", "P1 guard goes back")
	check_eq(MenuNav.read(_key(KEY_W)), &"up", "P1 up")
	check_eq(MenuNav.read(_key(KEY_ENTER)), &"confirm", "Enter confirms")
	check_eq(MenuNav.read(_key(KEY_ESCAPE)), &"back", "Escape goes back")
	check_eq(MenuNav.read(_key(KEY_J), 2), &"", "P1 keys do nothing for player 2's cursor")
	check_eq(MenuNav.read(_key(KEY_KP_1), 2), &"confirm", "P2 keys work for player 2's cursor")
	check_eq(MenuNav.read(_key(KEY_Q)), &"", "other keys are ignored")


func test_settings_steps_stocks_and_time() -> void:
	_begin()
	var settings = SETTINGS_SCRIPT.new()
	settings.stocks = 10
	settings.step_stocks(1)
	check_eq(settings.stocks, 10, "stocks stop at 10")
	settings.stocks = 1
	settings.step_stocks(-1)
	check_eq(settings.stocks, 1, "stocks stop at 1")
	settings.time_minutes = 20
	settings.step_time_minutes(1)
	check(settings.is_time_unlimited(), "after 20 minutes comes unlimited")
	settings.step_time_minutes(1)
	check_eq(settings.time_minutes, 1, "after unlimited it wraps to 1 minute")
	settings.step_time_minutes(-1)
	check(settings.is_time_unlimited(), "1 minute steps back to unlimited")
	settings.music_volume = 10
	settings.step_music_volume(1)
	check_eq(settings.music_volume, 10, "volume stops at 10")
	settings.sfx_volume = 0
	settings.step_sfx_volume(-1)
	check_eq(settings.sfx_volume, 0, "volume stops at 0")
	settings.free()
	_end()


func test_settings_screen_edits_and_leaves_to_the_main_menu() -> void:
	_begin()
	var screen := SETTINGS_SCENE.instantiate() as SettingsMenu
	GameSettings.stocks = 3
	screen.handle_action(&"right")
	check_eq(GameSettings.stocks, 4, "right raises the first row (stocks)")
	screen.handle_action(&"down")
	GameSettings.time_minutes = 5
	screen.handle_action(&"left")
	check_eq(GameSettings.time_minutes, 4, "left lowers the time limit")
	check_eq(screen.value_text(&"time"), "4 min", "time is shown in minutes")
	screen.handle_action(&"back")
	check_eq(_requested, [&"main_menu"] as Array[StringName], "back returns to the main menu")
	screen.free()
	_end()


func test_main_menu_modes_set_the_cpu_and_open_character_select() -> void:
	_begin()
	var menu := MAIN_MENU_SCENE.instantiate() as MainMenu
	menu.handle_action(&"down")
	menu.handle_action(&"confirm")
	check_eq(MatchConfig.cpu_level, 0, "2-player versus has no CPU")
	menu.handle_action(&"down")
	menu.handle_action(&"confirm")
	check(MatchConfig.cpu_level > 0, "versus CPU turns the CPU on")
	check_eq(_requested, [&"character_select", &"character_select"] as Array[StringName], "both open the select screen")
	menu.free()
	_end()


func test_two_player_select_needs_both_players_ready() -> void:
	_begin()
	MatchConfig.cpu_level = 0
	var screen := SELECT_SCENE.instantiate() as CharacterSelect
	screen.handle_player_action(2, &"right")
	check_eq(MatchConfig.p2_index, 2, "player 2 moves only their own pick")
	check_eq(MatchConfig.p1_index, 0, "player 1 is untouched")
	screen.handle_player_action(1, &"confirm")
	check(_requested.is_empty(), "one ready player is not enough")
	screen.handle_player_action(1, &"right")
	check_eq(MatchConfig.p1_index, 0, "a ready player cannot change their pick")
	screen.handle_player_action(2, &"confirm")
	check_eq(_requested, [&"versus_match"] as Array[StringName], "both ready starts the match")
	screen.free()
	_end()


func test_cpu_select_picks_the_player_then_the_opponent_and_level() -> void:
	_begin()
	MatchConfig.cpu_level = 2
	var screen := SELECT_SCENE.instantiate() as CharacterSelect
	screen.handle_player_action(2, &"right")
	check_eq(MatchConfig.p2_index, 1, "the CPU's keys do nothing")
	screen.handle_player_action(1, &"right")
	check_eq(MatchConfig.p1_index, 1, "player 1 chooses first")
	screen.handle_player_action(1, &"confirm")
	check(screen.picking_opponent, "then the opponent is chosen")
	screen.handle_player_action(1, &"right")
	check_eq(MatchConfig.p2_index, 2, "right now moves the opponent's pick")
	screen.handle_player_action(1, &"up")
	check_eq(MatchConfig.cpu_level, 3, "up raises the CPU level")
	screen.handle_player_action(1, &"up")
	check_eq(MatchConfig.cpu_level, 3, "the level stops at 3")
	screen.handle_player_action(1, &"back")
	check(not screen.picking_opponent, "back returns to picking the player")
	screen.handle_player_action(1, &"confirm")
	screen.handle_player_action(1, &"confirm")
	check_eq(_requested, [&"versus_match"] as Array[StringName], "confirming the opponent starts the match")
	screen.free()
	_end()
