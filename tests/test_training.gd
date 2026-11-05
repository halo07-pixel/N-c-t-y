extends TestCase
## Training mode: the rules (combo, damage wipe, dummy behaviour), the dummy's input, the HUD
## text, the menu entry and select routing, and the room itself with a real dummy.

const ROOM: PackedScene = preload("res://scenes/match/training_match.tscn")
const SELECT_SCENE: PackedScene = preload("res://scenes/ui/character_select.tscn")

var _requested: Array[StringName] = []


func _on_screen_requested(screen: StringName) -> void:
	_requested.append(screen)


func _tick(rules: TrainingRules, frames: int, percent: float = 0.0) -> void:
	for _i in frames:
		rules.tick(percent)


# --- The rules ----------------------------------------------------------------------------

func test_only_the_players_hits_on_the_dummy_count_as_a_combo() -> void:
	var rules := TrainingRules.new()
	rules.on_hit(1, 2, 4.0)
	rules.on_hit(2, 1, 9.0)
	rules.on_hit(1, 1, 9.0)
	rules.on_hit(1, 2, 3.5)
	check_eq(rules.hits, 2, "two hits on the dummy")
	check_near(rules.damage, 7.5, 0.001, "and their damage")


func test_a_combo_ends_after_a_pause_and_is_remembered() -> void:
	var rules := TrainingRules.new()
	var ended: Array = []
	rules.combo_ended.connect(func(hits: int, damage: float) -> void: ended.append([hits, damage]))
	rules.on_hit(1, 2, 5.0)
	rules.on_hit(1, 2, 5.0)
	rules.on_hit(1, 2, 5.0)
	_tick(rules, TrainingRules.COMBO_END_FRAMES - 1)
	check(ended.is_empty() and rules.hits == 3, "still going just before the pause")
	_tick(rules, 1)
	check_eq(ended, [[3, 15.0]], "the combo ended with its totals")
	check_eq(rules.hits, 0, "a new one starts at zero")
	check_eq(rules.last_hits, 3, "the last combo is kept")
	check_eq(rules.best_hits, 3, "and the best")
	rules.on_hit(1, 2, 2.0)
	_tick(rules, TrainingRules.COMBO_END_FRAMES)
	check_eq(rules.best_hits, 3, "a shorter combo does not lower the best")
	check_eq(rules.last_hits, 1, "but is the last one")


func test_the_dummys_damage_is_wiped_after_a_pause_and_never_when_clean() -> void:
	var rules := TrainingRules.new()
	var wipes := [0]
	rules.percent_reset_due.connect(func() -> void: wipes[0] += 1)
	_tick(rules, TrainingRules.PERCENT_RESET_FRAMES * 2, 0.0)
	check_eq(wipes[0], 0, "nothing to wipe at 0%")
	rules.on_hit(1, 2, 10.0)
	_tick(rules, TrainingRules.PERCENT_RESET_FRAMES - 1, 40.0)
	check_eq(wipes[0], 0, "not while the combo may still go on")
	_tick(rules, 1, 40.0)
	check_eq(wipes[0], 1, "wiped after the pause")


func test_dummy_modes_cycle_and_map_to_cpu_levels() -> void:
	var rules := TrainingRules.new()
	check_eq(rules.mode(), &"stand", "it starts by standing still")
	check_eq(rules.cpu_level(), 0, "no CPU")
	var seen: Array[StringName] = [rules.mode()]
	for _i in TrainingRules.MODES.size():
		seen.append(rules.next_mode())
	check_eq(seen.back(), &"stand", "the cycle wraps around")
	check_eq(seen.size(), TrainingRules.MODES.size() + 1, "every mode is visited")
	rules.mode_index = TrainingRules.MODES.find(&"cpu3")
	check_eq(rules.cpu_level(), 3, "cpu3 is level 3")
	check_eq(rules.mode_label(), "CPU 3", "and says so")


func test_infinite_resources_can_be_switched() -> void:
	var rules := TrainingRules.new()
	check(rules.infinite_resources, "on by default")
	rules.toggle_resources()
	check(not rules.infinite_resources, "off after a press")


func test_reset_clears_the_combo_in_progress() -> void:
	var rules := TrainingRules.new()
	rules.on_hit(1, 2, 5.0)
	rules.reset()
	check_eq(rules.hits, 0, "no combo")
	check_near(rules.damage, 0.0, 0.001, "no damage")


# --- The dummy and the HUD text ----------------------------------------------------------

func test_the_dummy_stands_guards_or_jumps() -> void:
	var dummy := DummyInput.new()
	var presses := 0
	for _i in 200:
		var frame := dummy.get_frame()
		check(not frame.guard_held and not frame.up_just_pressed, "standing does nothing")
		if frame.up_just_pressed:
			presses += 1
	dummy.mode = &"guard"
	var guard_taps := 0
	for _i in 200:
		var frame := dummy.get_frame()
		check(frame.guard_held, "guarding holds the guard")
		if frame.guard_just_pressed:
			guard_taps += 1
	check(guard_taps >= 2, "and presses it again now and then")
	dummy.mode = &"jump"
	for _i in 200:
		if dummy.get_frame().up_just_pressed:
			presses += 1
	check(presses >= 2, "jumping jumps repeatedly")
	dummy.free()


func test_hud_text() -> void:
	var rules := TrainingRules.new()
	rules.on_hit(1, 2, 4.0)
	rules.on_hit(1, 2, 3.0)
	var lines := TrainingHud.panel_lines(rules)
	check_eq(lines[0], "DUMMY: STAND", "the dummy mode")
	check_eq(lines[1], "INFINITE: ON", "the switch")
	check_eq(TrainingHud.combo_text(0, 0.0), "", "no combo, no text")
	check_eq(TrainingHud.combo_text(1, 4.0), "", "a single hit is no combo")
	check_eq(TrainingHud.combo_text(2, 7.0), "2 HITS  7.0%", "the counter")


# --- The menu ------------------------------------------------------------------------------

func test_the_router_and_main_menu_know_training() -> void:
	check(ScreenRouter.path_for(&"training_match") != "", "the room is routed")
	check(MainMenu.ITEMS.has(&"training") and MainMenu.LABELS.has(&"training"), "listed and labelled")


func test_training_from_the_menu_sets_the_flag_and_the_select_leads_to_the_room() -> void:
	_requested.clear()
	ScreenRouter.enabled = false
	Events.screen_requested.connect(_on_screen_requested)
	var menu := MainMenu.new()
	menu.activate(&"training")
	check(MatchConfig.training, "training is on")
	check(not MatchConfig.arcade, "and Arcade is off")
	var screen := SELECT_SCENE.instantiate() as CharacterSelect
	screen.handle_player_action(1, &"confirm")
	screen.handle_player_action(1, &"confirm")
	check_eq(_requested.back(), &"training_match", "your fighter, then the dummy, starts training")
	screen.free()
	_requested.clear()
	menu.activate(&"versus")
	check(not MatchConfig.training, "any other mode turns training off")
	menu.free()
	Events.screen_requested.disconnect(_on_screen_requested)
	ScreenRouter.enabled = true
	MatchConfig.cpu_level = MatchConfig.CPU_OFF


# --- The room ------------------------------------------------------------------------------

func _room() -> Node:
	MatchConfig.training = true
	MatchConfig.cpu_level = MatchConfig.CPU_OFF
	var room := ROOM.instantiate()
	tree.root.add_child(room)
	return room


func _leave(room: Node) -> void:
	room.queue_free()
	MatchConfig.training = false


func test_the_room_keeps_the_players_resources_full() -> void:
	var room := _room()
	await wait_frames(3)
	var player: Fighter = room._player
	player.set_reiatsu(0.0)
	await wait_frames(2)
	check_near(player.reiatsu, Reiatsu.MAX, 0.001, "Reiatsu is full again")
	room.rules.toggle_resources()
	player.set_reiatsu(0.0)
	await wait_frames(2)
	check(player.reiatsu < Reiatsu.MAX * 0.5, "with the switch off it is not refilled")
	_leave(room)


func test_whoever_leaves_the_stage_comes_straight_back_with_no_ko() -> void:
	var room := _room()
	await wait_frames(3)
	var dummy: Fighter = room._dummy
	dummy.global_position = Vector2(5000.0, 5000.0)
	await wait_frames(2)
	check(not dummy.is_ko(), "the dummy is not KO'd")
	check(room._stage.is_inside_blast_zone(dummy.global_position), "it is back on the stage")
	var player: Fighter = room._player
	player.global_position = Vector2(-5000.0, 5000.0)
	await wait_frames(2)
	check(not player.is_ko() and room._stage.is_inside_blast_zone(player.global_position), "so is the player")
	_leave(room)


func test_the_dummys_damage_wears_off_and_a_hit_counts_in_the_combo() -> void:
	var room := _room()
	await wait_frames(3)
	var dummy: Fighter = room._dummy
	Events.fighter_hit.emit(1, 2, 6.0)
	check_eq(room.rules.hits, 1, "the scene feeds hits to the rules")
	dummy.set_percent(80.0)
	await wait_frames(TrainingRules.PERCENT_RESET_FRAMES + 5)
	check_near(dummy.percent, 0.0, 0.001, "the damage was wiped")
	_leave(room)


func test_the_t_key_changes_the_dummy_behaviour() -> void:
	var room := _room()
	await wait_frames(3)
	var press := InputEventKey.new()
	press.keycode = KEY_T
	press.pressed = true
	room._unhandled_input(press)
	check_eq(room.rules.mode(), &"guard", "next mode")
	check_eq(room._dummy_input.mode, &"guard", "the dummy follows")
	for _i in 2:
		room._unhandled_input(press)
	check_eq(room.rules.mode(), &"cpu1", "and on to the CPU")
	check(room._dummy._input_source is AIInput, "the dummy is now steered by the CPU")
	_leave(room)
