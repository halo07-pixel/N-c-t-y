extends TestCase
## The roster data helpers and the select grid's layout and cursor movement.


func test_the_grid_has_a_random_slot_after_every_character() -> void:
	var grid := RosterGrid.new(6)
	check_eq(grid.slot_count(), 7, "six characters and Random")
	check_eq(grid.random_slot(), 6, "Random is last")
	check(grid.is_random_slot(6) and not grid.is_random_slot(5), "only the last slot is Random")


func test_layout_is_wider_than_tall_and_never_loses_a_slot() -> void:
	for count in range(1, 17):
		var grid := RosterGrid.new(count)
		check(grid.columns >= 1 and grid.columns <= 6, "%d characters: sensible column count (%d)" % [count, grid.columns])
		check(grid.columns * grid.rows() >= grid.slot_count(), "%d characters: every slot has a cell" % count)
		check(grid.columns >= grid.rows() or grid.slot_count() <= 4, "%d characters: not taller than wide" % count)
		for slot in grid.slot_count():
			var at := grid.cell(slot)
			check_eq(grid.slot_at(at.x, at.y), slot, "%d characters: cell and slot round-trip (%d)" % [count, slot])


func test_moving_sideways_wraps_inside_the_row() -> void:
	var grid := RosterGrid.new(6) # 4 columns: row 0 has 4 cells, row 1 has 3 (slots 4, 5, 6)
	check_eq(grid.columns, 4, "four columns")
	check_eq(grid.move(0, Vector2i(-1, 0)), 3, "left from the first wraps to the end of the row")
	check_eq(grid.move(3, Vector2i(1, 0)), 0, "right from the last wraps to the start")
	check_eq(grid.move(6, Vector2i(1, 0)), 4, "the short last row wraps inside itself")
	check_eq(grid.move(4, Vector2i(-1, 0)), 6, "and the other way")


func test_moving_vertically_wraps_and_skips_empty_cells() -> void:
	var grid := RosterGrid.new(6)
	check_eq(grid.move(0, Vector2i(0, 1)), 4, "down from the top row")
	check_eq(grid.move(4, Vector2i(0, 1)), 0, "down from the bottom wraps to the top")
	check_eq(grid.move(0, Vector2i(0, -1)), 4, "up from the top wraps to the bottom")
	check_eq(grid.move(3, Vector2i(0, 1)), 3, "a column with no cell below stays put")
	check_eq(grid.move(3, Vector2i(0, -1)), 3, "and above too")


func test_a_random_pick_is_decided_when_locked_in() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var before := [MatchConfig.p1_index, MatchConfig.p2_index]
	MatchConfig.p1_index = MatchConfig.RANDOM_PICK
	check(MatchConfig.is_random(1), "the pick is Random")
	var chosen := MatchConfig.lock_in(1, rng)
	check(chosen >= 0 and chosen < MatchConfig.roster_size(), "locking in picks a real fighter")
	check_eq(MatchConfig.p1_index, chosen, "and it is stored")
	check(not MatchConfig.is_random(1), "no longer Random")
	MatchConfig.p2_index = MatchConfig.RANDOM_PICK
	check(MatchConfig.character_for(2) != null, "a match never starts with an undecided pick")
	check(MatchConfig.p2_index != MatchConfig.RANDOM_PICK, "asking for the character settles it")
	MatchConfig.p1_index = before[0]
	MatchConfig.p2_index = before[1]


func test_random_can_reach_every_fighter() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var seen := {}
	for _i in 300:
		MatchConfig.p1_index = MatchConfig.RANDOM_PICK
		seen[MatchConfig.lock_in(1, rng)] = true
	check_eq(seen.size(), MatchConfig.roster_size(), "every roster fighter can come up")
	MatchConfig.p1_index = 0


func test_the_roster_lists_its_characters_in_order() -> void:
	var roster := MatchConfig.roster()
	check_eq(roster.size(), MatchConfig.roster_size(), "one character per path")
	check_eq(roster[0].display_name, "Ichigo", "Ichigo first")
	var names := {}
	for character in roster:
		names[character.display_name] = true
	check_eq(names.size(), roster.size(), "no duplicates")
	check(not names.has("Yhwach"), "the boss is not selectable")
