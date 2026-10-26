class_name MatchManager
extends Node
## The rules of a match: stocks, time limit, respawn delay, sudden death and
## the winner. It only listens to and talks through the Events bus, so it knows
## nothing about fighters or the stage.

const RESPAWN_DELAY_FRAMES := 60
const SUDDEN_DEATH_PERCENT := 300.0
const FRAMES_PER_SECOND := 60
const NO_TIME_LIMIT := -1

var stocks: Dictionary = {}
var percents: Dictionary = {}
var running: bool = false
var sudden_death: bool = false

var _time_left_frames: int = NO_TIME_LIMIT
var _respawn_frames: Dictionary = {}


func _ready() -> void:
	Events.fighter_left_blast_zone.connect(_on_left_blast_zone)
	Events.fighter_percent_changed.connect(_on_percent_changed)


## time_limit_seconds <= 0 means no time limit.
func setup(player_ids: Array[int], stock_count: int, time_limit_seconds: int) -> void:
	stocks.clear()
	percents.clear()
	_respawn_frames.clear()
	sudden_death = false
	for id in player_ids:
		stocks[id] = stock_count
		percents[id] = 0.0
		Events.stocks_changed.emit(id, stock_count)
	if time_limit_seconds > 0:
		_time_left_frames = time_limit_seconds * FRAMES_PER_SECOND
		Events.match_time_changed.emit(time_limit_seconds)
	else:
		_time_left_frames = NO_TIME_LIMIT
		Events.match_time_changed.emit(NO_TIME_LIMIT)
	running = true
	Events.match_started.emit()


func _physics_process(_delta: float) -> void:
	if not running:
		return
	_tick_respawns()
	_tick_clock()


## Who wins when time runs out: most stocks, then lowest percent. 0 means a tie.
static func decide_timeout_winner(stock_map: Dictionary, percent_map: Dictionary) -> int:
	var best_id := 0
	var best_stocks := -1
	var best_percent := INF
	var tied := false
	for id: int in stock_map:
		var player_stocks: int = stock_map[id]
		var player_percent: float = percent_map.get(id, 0.0)
		if player_stocks > best_stocks or (
			player_stocks == best_stocks and player_percent < best_percent
		):
			best_id = id
			best_stocks = player_stocks
			best_percent = player_percent
			tied = false
		elif player_stocks == best_stocks and is_equal_approx(player_percent, best_percent):
			tied = true
	return 0 if tied else best_id


func _tick_respawns() -> void:
	for id: int in _respawn_frames.keys():
		_respawn_frames[id] -= 1
		if _respawn_frames[id] <= 0:
			_respawn_frames.erase(id)
			Events.fighter_respawn_due.emit(id)


func _tick_clock() -> void:
	if _time_left_frames == NO_TIME_LIMIT or sudden_death:
		return
	_time_left_frames -= 1
	if _time_left_frames % FRAMES_PER_SECOND == 0:
		Events.match_time_changed.emit(_time_left_frames / FRAMES_PER_SECOND)
	if _time_left_frames <= 0:
		_on_time_up()


func _on_time_up() -> void:
	var winner := decide_timeout_winner(stocks, percents)
	if winner == 0:
		_begin_sudden_death()
	else:
		_end(winner)


func _begin_sudden_death() -> void:
	sudden_death = true
	for id: int in stocks:
		stocks[id] = 1
		percents[id] = SUDDEN_DEATH_PERCENT
		Events.stocks_changed.emit(id, 1)
	Events.match_time_changed.emit(NO_TIME_LIMIT)
	Events.sudden_death_started.emit()


func _on_left_blast_zone(player_id: int) -> void:
	if not running or not stocks.has(player_id) or stocks[player_id] <= 0:
		return
	stocks[player_id] -= 1
	Events.stocks_changed.emit(player_id, stocks[player_id])
	if stocks[player_id] <= 0:
		_end(_last_player_standing())
		return
	_respawn_frames[player_id] = RESPAWN_DELAY_FRAMES


func _on_percent_changed(player_id: int, percent: float) -> void:
	if percents.has(player_id):
		percents[player_id] = percent


func _last_player_standing() -> int:
	var alive: Array[int] = []
	for id: int in stocks:
		if stocks[id] > 0:
			alive.append(id)
	return alive[0] if alive.size() == 1 else 0


func _end(winner_id: int) -> void:
	running = false
	Events.match_ended.emit(winner_id)
