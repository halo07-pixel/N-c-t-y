extends TestCase
## Guard rails for the roster's numbers (tools/balance_sim.gd measures the real win rates):
## nobody's moves should be wildly stronger or weaker than the rest.

const NAMES: PackedStringArray = ["swordsman", "archer", "noble", "emperor"]


func _average_ground_damage(name: String) -> float:
	var moveset := load("res://resources/movesets/%s_moveset.tres" % name) as MoveSet
	var moves := [moveset.ground_neutral, moveset.ground_forward, moveset.ground_up, moveset.ground_down]
	var total := 0.0
	for move: MoveData in moves:
		total += move.damage
	return total / float(moves.size())


func test_melee_damage_is_within_a_band_around_the_swordsman() -> void:
	var reference := _average_ground_damage("swordsman")
	for name in NAMES:
		var ratio := _average_ground_damage(name) / reference
		check(ratio > 0.75 and ratio < 1.35, "%s melee damage is %d%% of Ichigo's" % [name, int(ratio * 100.0)])


func test_weights_are_close_enough_to_play_against_each_other() -> void:
	for name in NAMES:
		var data := load("res://resources/characters/%s.tres" % name) as CharacterData
		check(data.weight >= 85.0 and data.weight <= 110.0, "%s weighs %d" % [name, int(data.weight)])


func test_nobody_starts_with_a_big_gauge_lead() -> void:
	for name in NAMES:
		var data := load("res://resources/characters/%s.tres" % name) as CharacterData
		check(data.starting_gauge <= 25.0, "%s starts with %d gauge" % [name, int(data.starting_gauge)])
