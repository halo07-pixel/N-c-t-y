extends TestCase

var _manager: MatchManager
var _winners: Array[int] = []
var _respawns: Array[int] = []
var _sudden_death_events: int = 0


func _on_match_ended(winner_id: int) -> void:
	_winners.append(winner_id)


func _on_respawn_due(player_id: int) -> void:
	_respawns.append(player_id)


func _on_sudden_death() -> void:
	_sudden_death_events += 1


func _start(stock_count: int, seconds: int) -> void:
	_winners.clear()
	_respawns.clear()
	_sudden_death_events = 0
	Events.match_ended.connect(_on_match_ended)
	Events.fighter_respawn_due.connect(_on_respawn_due)
	Events.sudden_death_started.connect(_on_sudden_death)
	_manager = MatchManager.new()
	tree.root.add_child(_manager)
	var ids: Array[int] = [1, 2]
	_manager.setup(ids, stock_count, seconds)


func _finish() -> void:
	Events.match_ended.disconnect(_on_match_ended)
	Events.fighter_respawn_due.disconnect(_on_respawn_due)
	Events.sudden_death_started.disconnect(_on_sudden_death)
	_manager.free()


func test_timeout_winner_prefers_stocks_then_lower_percent() -> void:
	check_eq(MatchManager.decide_timeout_winner({1: 3, 2: 2}, {1: 90.0, 2: 10.0}), 1, "more stocks wins")
	check_eq(MatchManager.decide_timeout_winner({1: 2, 2: 2}, {1: 90.0, 2: 10.0}), 2, "lower percent wins")
	check_eq(MatchManager.decide_timeout_winner({1: 2, 2: 2}, {1: 50.0, 2: 50.0}), 0, "full tie")
	check_eq(MatchManager.decide_timeout_winner({1: 1, 2: 3}, {1: 0.0, 2: 200.0}), 2, "stocks beat percent")


func test_setup_gives_every_player_the_chosen_stocks() -> void:
	_start(5, 0)
	check_eq(_manager.stocks[1], 5, "player 1 stocks")
	check_eq(_manager.stocks[2], 5, "player 2 stocks")
	check(_manager.running, "match is running")
	_finish()


func test_leaving_the_blast_zone_costs_a_stock_and_schedules_a_respawn() -> void:
	_start(3, 0)
	Events.fighter_left_blast_zone.emit(1)
	check_eq(_manager.stocks[1], 2, "one stock lost")
	check_eq(_manager.stocks[2], 3, "the other player is untouched")
	check_eq(_respawns.size(), 0, "no instant respawn")
	await wait_frames(MatchManager.RESPAWN_DELAY_FRAMES + 2)
	check_eq(_respawns, [1] as Array[int], "respawn requested after the delay")
	_finish()


func test_losing_the_last_stock_ends_the_match() -> void:
	_start(2, 0)
	Events.fighter_left_blast_zone.emit(2)
	check_eq(_winners.size(), 0, "still going with one stock left")
	Events.fighter_left_blast_zone.emit(2)
	check_eq(_winners, [1] as Array[int], "player 1 wins")
	check(not _manager.running, "match stopped")
	Events.fighter_left_blast_zone.emit(1)
	check_eq(_manager.stocks[1], 2, "no stock changes after the end")
	_finish()


func test_one_stock_match_ends_on_the_first_ko() -> void:
	_start(1, 0)
	Events.fighter_left_blast_zone.emit(1)
	check_eq(_winners, [2] as Array[int], "player 2 wins")
	_finish()


func test_time_out_awards_the_win_to_the_lower_percent() -> void:
	_start(3, 1)
	Events.fighter_percent_changed.emit(1, 80.0)
	Events.fighter_percent_changed.emit(2, 35.0)
	await wait_frames(70)
	check_eq(_winners, [2] as Array[int], "player 2 had less damage")
	_finish()


func test_time_out_tie_starts_sudden_death_and_next_ko_decides() -> void:
	_start(3, 1)
	await wait_frames(70)
	check_eq(_winners.size(), 0, "nobody won yet")
	check(_manager.sudden_death, "sudden death began")
	check_eq(_sudden_death_events, 1, "announced once")
	check_eq(_manager.stocks[1], 1, "one stock each")
	check_eq(_manager.stocks[2], 1, "one stock each")
	Events.fighter_left_blast_zone.emit(1)
	check_eq(_winners, [2] as Array[int], "the first KO loses")
	_finish()


func test_unlimited_time_never_times_out() -> void:
	_start(3, 0)
	await wait_frames(120)
	check_eq(_winners.size(), 0, "still running")
	check(not _manager.sudden_death, "no sudden death")
	_finish()
