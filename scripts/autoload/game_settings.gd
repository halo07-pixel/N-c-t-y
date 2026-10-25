extends Node
## Match rules chosen by the player, saved to user://settings.cfg.
## Stocks: 1 to 10. Time limit: 1 to 20 minutes, or unlimited (0).

const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "match"

const MIN_STOCKS := 1
const MAX_STOCKS := 10
const DEFAULT_STOCKS := 3

const TIME_UNLIMITED := 0
const MIN_TIME_MINUTES := 1
const MAX_TIME_MINUTES := 20
const DEFAULT_TIME_MINUTES := 5

var stocks: int = DEFAULT_STOCKS
var time_minutes: int = DEFAULT_TIME_MINUTES


static func clamp_stocks(value: int) -> int:
	return clampi(value, MIN_STOCKS, MAX_STOCKS)


static func clamp_time_minutes(value: int) -> int:
	if value <= TIME_UNLIMITED:
		return TIME_UNLIMITED
	return clampi(value, MIN_TIME_MINUTES, MAX_TIME_MINUTES)


func _ready() -> void:
	load_settings()


func set_stocks(value: int) -> void:
	stocks = clamp_stocks(value)
	Events.settings_changed.emit()


func set_time_minutes(value: int) -> void:
	time_minutes = clamp_time_minutes(value)
	Events.settings_changed.emit()


func is_time_unlimited() -> bool:
	return time_minutes == TIME_UNLIMITED


func time_limit_seconds() -> int:
	return time_minutes * 60


func save_settings() -> Error:
	var config := ConfigFile.new()
	config.set_value(SECTION, "stocks", stocks)
	config.set_value(SECTION, "time_minutes", time_minutes)
	return config.save(SETTINGS_PATH)


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	stocks = clamp_stocks(int(config.get_value(SECTION, "stocks", DEFAULT_STOCKS)))
	time_minutes = clamp_time_minutes(
		int(config.get_value(SECTION, "time_minutes", DEFAULT_TIME_MINUTES))
	)
