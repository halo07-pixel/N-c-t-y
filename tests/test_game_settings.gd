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
