extends TestCase
## Combo trials: the tracker rules, the exercises built from each character's data, the saved
## progress, the menu, and a scripted solution for every exercise played on a real dummy.

const STAGE_SCENE: PackedScene = preload("res://scenes/stages/test_stage.tscn")
const FIGHTER_SCENE: PackedScene = preload("res://scenes/fighter/fighter.tscn")
const SELECT_SCENE: PackedScene = preload("res://scenes/ui/trial_select.tscn")
const MAX_SOLVE_FRAMES := 900

var _stage: Stage
var _player: Fighter
var _dummy: Fighter
var _input: ScriptedInput
var _tracker: TrialTracker
var _requested: Array[StringName] = []
var _dash_frames: int = 0
var _cooldown: int = 0
var _fail_reason: String = ""
var _last_dummy_x: float = 0.0


func _on_screen_requested(screen: StringName) -> void:
	_requested.append(screen)


func _on_projectile(projectile: Projectile) -> void:
	tree.root.add_child(projectile)


func _on_attack(id: int, move_name: String) -> void:
	_tracker.on_attack_started(id, move_name)


func _on_hit(attacker: int, victim: int, _damage: float) -> void:
	_tracker.on_hit(attacker, victim)


func _on_dash(id: int, _spot: Vector2, _direction: int) -> void:
	_tracker.on_dashed(id)


func _on_gauge_cancel(id: int, _spot: Vector2) -> void:
	_tracker.on_gauge_cancelled(id)


func _library() -> Array:
	var all: Array = []
	for path in MatchConfig.ROSTER_PATHS:
		var character := load(path) as CharacterData
		all.append([character, TrialLibrary.for_character(character)])
	return all


# --- Tracker rules ---------------------------------------------------------------------

func _tracker_for(steps: Array) -> TrialTracker:
	var trial := ComboTrial.new()
	trial.steps = PackedStringArray(steps)
	var tracker := TrialTracker.new()
	tracker.setup(trial)
	return tracker


func test_steps_in_order_complete_the_trial() -> void:
	var tracker := _tracker_for(["A", "B"])
	var done: Array = []
	tracker.completed.connect(func() -> void: done.append(true))
	tracker.on_attack_started(1, "A")
	tracker.on_hit(1, 2)
	check_eq(tracker.index, 1, "the first step is done")
	tracker.on_attack_started(1, "B")
	tracker.on_hit(1, 2)
	check(tracker.finished and done.size() == 1, "completed after the last step")


func test_a_wrong_move_fails_the_trial() -> void:
	var tracker := _tracker_for(["A", "B"])
	var reasons: Array = []
	tracker.failed.connect(func(reason: String) -> void: reasons.append(reason))
	tracker.on_attack_started(1, "A")
	tracker.on_hit(1, 2)
	tracker.on_attack_started(1, "C")
	tracker.on_hit(1, 2)
	check_eq(reasons.size(), 1, "failed once")
	check(String(reasons[0]).contains("C"), "the reason names the wrong move")
	check(tracker.finished, "nothing counts after a failure")


func test_a_second_hit_of_the_same_move_is_ignored() -> void:
	var tracker := _tracker_for(["A", "B"])
	tracker.on_attack_started(1, "A")
	tracker.on_hit(1, 2)
	tracker.on_hit(1, 2) # a multi-hit skill
	check(not tracker.finished and tracker.index == 1, "still waiting for B")


func test_only_our_hits_on_the_dummy_count() -> void:
	var tracker := _tracker_for(["A"])
	tracker.on_attack_started(1, "A")
	tracker.on_hit(2, 1)
	tracker.on_hit(1, 1)
	check(not tracker.finished and tracker.index == 0, "the dummy hitting us, or us hitting ourselves, is nothing")


func test_taking_too_long_fails_after_the_first_step() -> void:
	var tracker := _tracker_for(["A", "B"])
	var reasons: Array = []
	tracker.failed.connect(func(reason: String) -> void: reasons.append(reason))
	for i in TrialTracker.TIMEOUT_FRAMES + 5:
		tracker.tick()
	check(reasons.is_empty(), "no clock before the exercise has started")
	tracker.on_attack_started(1, "A")
	tracker.on_hit(1, 2)
	for i in TrialTracker.TIMEOUT_FRAMES + 5:
		tracker.tick()
	check_eq(reasons.size(), 1, "too slow once it has started")


func test_token_steps() -> void:
	var tracker := _tracker_for([ComboTrial.TOKEN_DASH, "A", ComboTrial.TOKEN_GAUGE_CANCEL])
	tracker.on_dashed(2)
	check_eq(tracker.index, 0, "the dummy's dash is not ours")
	tracker.on_dashed(1)
	check_eq(tracker.index, 1, "a dash is the first step")
	tracker.on_attack_started(1, "A")
	tracker.on_hit(1, 2)
	tracker.on_gauge_cancelled(1)
	check(tracker.finished, "the Gauge Cancel finishes it")


func test_hitting_before_the_dash_fails() -> void:
	var tracker := _tracker_for([ComboTrial.TOKEN_DASH, "A"])
	tracker.on_attack_started(1, "A")
	tracker.on_hit(1, 2)
	check(tracker.finished and tracker.index == 0, "an attack when a dash was needed is a mistake")


func test_reset_starts_over() -> void:
	var tracker := _tracker_for(["A"])
	tracker.on_attack_started(1, "A")
	tracker.on_hit(1, 2)
	tracker.reset()
	check(not tracker.finished and tracker.index == 0, "ready again")


# --- The exercises ---------------------------------------------------------------------

func test_every_character_has_four_exercises_with_real_moves() -> void:
	for entry in _library():
		var character: CharacterData = entry[0]
		var trials: Array = entry[1]
		check_eq(trials.size(), 4, "%s has four exercises" % character.display_name)
		var keys := {}
		for trial: ComboTrial in trials:
			keys[trial.key] = true
			check(trial.title != "" and trial.description != "", "%s / %s: has text" % [character.display_name, trial.title])
			check(trial.steps.size() >= 2, "%s / %s: has steps" % [character.display_name, trial.title])
			for step in trial.steps:
				if not ComboTrial.is_token(step):
					check(_move_named(character, step) != null, "%s / %s: '%s' is a real move" % [character.display_name, trial.title, step])
		check_eq(keys.size(), 4, "%s: the keys are unique" % character.display_name)


func test_the_gauge_exercise_starts_with_enough_gauge() -> void:
	for entry in _library():
		var trials: Array = entry[1]
		check(trials[3].start_gauge >= CombatGauge.GAUGE_CANCEL_COST, "the Gauge Cancel exercise starts with enough")


func test_cancel_exercises_use_skills_that_can_be_cancelled_into() -> void:
	for entry in _library():
		var character: CharacterData = entry[0]
		var trials: Array = entry[1]
		for index in [1, 2]:
			var skill_name: String = trials[index].steps[trials[index].steps.size() - 1]
			var skill := _move_named(character, skill_name) as SpecialData
			check(skill != null and CombatGauge.CANCEL_ROLES.has(skill.role), "%s / %s: '%s' can be cancelled into" % [character.display_name, trials[index].title, skill_name])


func _move_named(character: CharacterData, move_name: String) -> MoveData:
	var moves := character.moveset
	var candidates: Array = [
		moves.ground_neutral, moves.ground_neutral.next_in_chain, moves.ground_neutral.next_in_chain.next_in_chain,
		moves.ground_forward, character.specials.neutral, character.specials.forward,
	]
	for move: MoveData in candidates:
		if move != null and move.display_name == move_name:
			return move
	return null


# --- Saved progress --------------------------------------------------------------------

func test_completed_trials_are_remembered() -> void:
	var before := GameSettings.trials_done.duplicate()
	GameSettings.trials_done = PackedStringArray()
	check(not GameSettings.is_trial_done("x_1"), "not done yet")
	GameSettings.mark_trial_done("x_1")
	GameSettings.mark_trial_done("x_1")
	check(GameSettings.is_trial_done("x_1"), "done")
	check_eq(GameSettings.trials_done.size(), 1, "recorded once")
	GameSettings.trials_done = before
	GameSettings.save_settings()


# --- The menu ---------------------------------------------------------------------------

func test_trial_menu_picks_a_character_and_an_exercise() -> void:
	_requested.clear()
	ScreenRouter.enabled = false
	Events.screen_requested.connect(_on_screen_requested)
	var menu := SELECT_SCENE.instantiate() as TrialSelect
	menu.handle_action(&"right")
	menu.handle_action(&"down")
	menu.handle_action(&"down")
	menu.handle_action(&"confirm")
	check_eq(MatchConfig.trial_character, 1, "the second character")
	check_eq(MatchConfig.trial_index, 2, "the third exercise")
	check_eq(MatchConfig.p1_index, 1, "the F3 list follows")
	check_eq(_requested, [&"trial_match"] as Array[StringName], "opens the practice scene")
	menu.handle_action(&"back")
	check_eq(_requested.back(), &"main_menu", "back leaves to the main menu")
	menu.free()
	Events.screen_requested.disconnect(_on_screen_requested)
	ScreenRouter.enabled = true


func test_the_router_knows_the_trial_screens() -> void:
	check(ScreenRouter.path_for(&"trial_select") != "", "trial select")
	check(ScreenRouter.path_for(&"trial_match") != "", "trial match")


func test_main_menu_has_the_trial_mode() -> void:
	check(MainMenu.ITEMS.has(&"trial"), "listed")
	check(MainMenu.LABELS.has(&"trial"), "labelled")


# --- A scripted solution for every exercise --------------------------------------------

func _build_world(character: CharacterData) -> void:
	_stage = STAGE_SCENE.instantiate() as Stage
	tree.root.add_child(_stage)
	_player = _spawn(1, character)
	_dummy = _spawn(2, character)
	_dummy.knockback_scale = 0.35
	_input = ScriptedInput.new()
	_player.set_input_source(_input)
	_dummy.set_input_source(InputSource.new())
	Events.fighter_attack_started.connect(_on_attack)
	Events.fighter_hit.connect(_on_hit)
	Events.fighter_dashed.connect(_on_dash)
	Events.fighter_gauge_cancelled.connect(_on_gauge_cancel)


func _spawn(id: int, character: CharacterData) -> Fighter:
	var fighter := FIGHTER_SCENE.instantiate() as Fighter
	fighter.player_id = id
	fighter.data = character
	fighter.position = TrialLibrary.PRACTICE_ORIGIN
	fighter.projectile_spawned.connect(_on_projectile)
	tree.root.add_child(fighter)
	return fighter


func _teardown_world() -> void:
	Events.fighter_attack_started.disconnect(_on_attack)
	Events.fighter_hit.disconnect(_on_hit)
	Events.fighter_dashed.disconnect(_on_dash)
	Events.fighter_gauge_cancelled.disconnect(_on_gauge_cancel)
	for node in tree.root.get_children():
		if node is Projectile:
			node.free()
	_player.free()
	_dummy.free()
	_stage.free()


## Plays the exercise the way a player would; returns true when the tracker completes it.
func _solve(character: CharacterData, trial: ComboTrial) -> bool:
	_build_world(character)
	await wait_frames(30)
	var origin := TrialLibrary.PRACTICE_ORIGIN
	_player.reset_for_practice(origin, 1, trial.start_gauge)
	_dummy.reset_for_practice(origin + Vector2(trial.dummy_distance, 0.0), -1, 0.0)
	_tracker = TrialTracker.new()
	_tracker.setup(trial)
	_fail_reason = ""
	_tracker.failed.connect(func(reason: String) -> void: _fail_reason = reason)
	_dash_frames = 0
	_cooldown = 0
	await wait_frames(5)
	for frame in MAX_SOLVE_FRAMES:
		await wait_frames(1)
		_tracker.tick()
		_last_dummy_x = _dummy.global_position.x - _player.global_position.x
		if _tracker.finished:
			break
		_act(character, trial)
	var success := _tracker.finished and _tracker.index >= trial.steps.size()
	_teardown_world()
	return success


## One frame of the player's play for the step that is next.
func _act(character: CharacterData, trial: ComboTrial) -> void:
	_input.held_move = Vector2.ZERO
	if _cooldown > 0:
		_cooldown -= 1
		return
	var step := _tracker.expected()
	var state := _player.get_state_name()
	var moves := character.moveset
	var previous := trial.steps[_tracker.index - 1] if _tracker.index > 0 else ""
	if step == ComboTrial.TOKEN_DASH:
		if state == &"Idle":
			_input.tap_dash(1)
			_cooldown = 3
	elif step == ComboTrial.TOKEN_GAUGE_CANCEL:
		if _player.can_gauge_cancel():
			_input.tap_charge()
			_cooldown = 3
	elif step == moves.ground_neutral.display_name and previous != moves.ground_neutral.display_name:
		if state == &"Idle":
			_input.tap_attack()
			_cooldown = 3
	elif step == moves.ground_forward.display_name:
		if state == &"Dash":
			_dash_frames += 1
			if _dash_frames >= GuardRules.DASH_ATTACK_FRAME + 1:
				_input.held_move = Vector2(1.0, 0.0)
				_input.tap_attack()
				_cooldown = 3
		elif state == &"Idle":
			_input.held_move = Vector2(1.0, 0.0)
			_input.tap_attack()
			_cooldown = 3
	elif step == moves.ground_neutral.next_in_chain.display_name or step == moves.ground_neutral.next_in_chain.next_in_chain.display_name:
		if _player.hit_connected and state == &"Attack" and _player.current_attack_name() == previous:
			_input.tap_attack()
			_cooldown = 3
		elif state == &"Idle" and previous == moves.ground_neutral.display_name:
			_input.tap_attack() # the chain was missed: nothing to do but start again
			_cooldown = 3
	else:
		# a skill: cancel into it while the hit is being confirmed
		var kit := character.specials
		var skill := kit.forward if kit.forward != null and kit.forward.display_name == step else kit.neutral
		if _player.hit_confirm_left > 0:
			_input.held_move = Vector2(1.0, 0.0) if skill == kit.forward else Vector2.ZERO
			_input.tap_special()
			_cooldown = 3


func test_every_exercise_can_be_completed() -> void:
	for entry in _library():
		var character: CharacterData = entry[0]
		for trial: ComboTrial in entry[1]:
			var done: bool = await _solve(character, trial)
			check(done, "%s / %s can be completed (%s, dummy x=%d)" % [character.display_name, trial.title, _fail_reason, int(_last_dummy_x)])


# --- The practice scene itself ----------------------------------------------------------

const TRIAL_SCENE: PackedScene = preload("res://scenes/match/trial_match.tscn")


func _practice_fighters(scene: Node) -> Array[Fighter]:
	var found: Array[Fighter] = []
	for node in scene.get_children():
		if node is Fighter:
			found.append(node)
	return found


func test_the_practice_scene_stands_the_fighters_on_the_floor() -> void:
	ScreenRouter.enabled = false
	MatchConfig.p1_index = 0
	MatchConfig.trial_index = 0
	var scene := TRIAL_SCENE.instantiate()
	tree.root.add_child(scene)
	await wait_frames(60)
	var fighters := _practice_fighters(scene)
	check_eq(fighters.size(), 2, "the player and the dummy")
	for fighter in fighters:
		check(fighter.is_on_floor(), "player %d stands on the floor" % fighter.player_id)
	scene.free()
	ScreenRouter.enabled = true



func test_the_practice_scene_follows_the_exercise_and_resets() -> void:
	ScreenRouter.enabled = false
	MatchConfig.p1_index = 0
	MatchConfig.trial_index = 0
	var before := GameSettings.trials_done.duplicate()
	GameSettings.trials_done = PackedStringArray()
	var scene := TRIAL_SCENE.instantiate()
	tree.root.add_child(scene)
	await wait_frames(40)
	var player: Fighter = _practice_fighters(scene)[0]
	var input := ScriptedInput.new()
	player.set_input_source(input)
	# a wrong first move (the up attack instead of the jab) fails the exercise and resets it
	input.held_move = Vector2(0.0, -1.0)
	input.tap_attack()
	await wait_frames(30)
	input.held_move = Vector2.ZERO
	check(scene.tracker.finished or scene.tracker.index == 0, "a wrong move does not progress")
	var banner: String = scene.get_node("TrialHud").banner_text()
	check(banner.begins_with("RETRY") or banner == "", "the HUD says RETRY (or nothing yet)")
	await wait_frames(TrialTracker.TIMEOUT_FRAMES + 120)
	check_eq(scene.tracker.index, 0, "back at the first step after the reset")
	check(not scene.tracker.finished, "ready to try again")
	check_eq(scene.get_node("TrialHud").banner_text(), "", "the banner is gone")
	scene.free()
	GameSettings.trials_done = before
	ScreenRouter.enabled = true
