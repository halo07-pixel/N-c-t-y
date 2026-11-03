extends TestCase

const SETTINGS_SCRIPT := preload("res://scripts/autoload/game_settings.gd")


func test_stocks_are_clamped_between_one_and_ten() -> void:
	check_eq(SETTINGS_SCRIPT.clamp_stocks(0), 1, "0 stocks rises to the minimum")
	check_eq(SETTINGS_SCRIPT.clamp_stocks(-5), 1, "negative stocks rise to the minimum")
	check_eq(SETTINGS_SCRIPT.clamp_stocks(3), 3, "3 stocks stay 3")
	check_eq(SETTINGS_SCRIPT.clamp_stocks(10), 10, "10 stocks stay 10")
	check_eq(SETTINGS_SCRIPT.clamp_stocks(11), 10, "11 stocks drop to the maximum")


func test_time_limit_is_unlimited_or_between_one_and_twenty_minutes() -> void:
	check_eq(SETTINGS_SCRIPT.clamp_time_minutes(0), 0, "0 means unlimited")
	check_eq(SETTINGS_SCRIPT.clamp_time_minutes(-3), 0, "negative means unlimited")
	check_eq(SETTINGS_SCRIPT.clamp_time_minutes(1), 1, "1 minute stays 1")
	check_eq(SETTINGS_SCRIPT.clamp_time_minutes(20), 20, "20 minutes stay 20")
	check_eq(SETTINGS_SCRIPT.clamp_time_minutes(25), 20, "25 minutes drop to 20")


func test_defaults_are_three_stocks_and_five_minutes() -> void:
	var settings = SETTINGS_SCRIPT.new()
	check_eq(settings.stocks, 3, "default stocks")
	check_eq(settings.time_minutes, 5, "default time")
	check_eq(settings.time_limit_seconds(), 300, "default time in seconds")
	check(not settings.is_time_unlimited(), "default time is limited")
	settings.free()


func test_window_mode_cycles_and_has_names() -> void:
	var settings = SETTINGS_SCRIPT.new()
	check_eq(settings.window_mode, SETTINGS_SCRIPT.WindowMode.WINDOWED, "starts windowed")
	check_eq(settings.window_mode_name(), "WINDOW", "windowed name")
	settings.cycle_window_mode()
	check_eq(settings.window_mode_name(), "FULLSCREEN", "second mode")
	settings.cycle_window_mode()
	check_eq(settings.window_mode_name(), "EXCLUSIVE", "third mode")
	settings.cycle_window_mode()
	check_eq(settings.window_mode, SETTINGS_SCRIPT.WindowMode.WINDOWED, "wraps to windowed")
	settings.set_window_mode(99)
	check_eq(settings.window_mode, SETTINGS_SCRIPT.WindowMode.EXCLUSIVE, "out of range is clamped")
	settings.free()


func test_f11_and_alt_enter_toggle_fullscreen() -> void:
	var settings = SETTINGS_SCRIPT.new()
	var f11 := InputEventKey.new()
	f11.keycode = KEY_F11
	f11.pressed = true
	settings._input(f11)
	check_eq(settings.window_mode, SETTINGS_SCRIPT.WindowMode.FULLSCREEN, "F11 enters fullscreen")
	var alt_enter := InputEventKey.new()
	alt_enter.keycode = KEY_ENTER
	alt_enter.alt_pressed = true
	alt_enter.pressed = true
	settings._input(alt_enter)
	check_eq(settings.window_mode, SETTINGS_SCRIPT.WindowMode.WINDOWED, "Alt+Enter goes back to a window")
	var plain_enter := InputEventKey.new()
	plain_enter.keycode = KEY_ENTER
	plain_enter.pressed = true
	settings._input(plain_enter)
	check_eq(settings.window_mode, SETTINGS_SCRIPT.WindowMode.WINDOWED, "plain Enter does nothing")
	settings.free()


func test_anti_aliasing_cycles_and_defaults_to_4x() -> void:
	var settings = SETTINGS_SCRIPT.new()
	check_eq(settings.anti_aliasing_name(), "4X", "smooth by default")
	settings.cycle_anti_aliasing()
	check_eq(settings.anti_aliasing_name(), "OFF", "wraps to off")
	settings.cycle_anti_aliasing()
	check_eq(settings.anti_aliasing_name(), "2X", "then 2x")
	settings.free()
