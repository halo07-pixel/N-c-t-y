extends TestCase
## The Arcade run: ladder order, boss, win/loss flow and the screens that use it.

const SELECT_SCENE: PackedScene = preload("res://scenes/ui/character_select.tscn")
const MAIN_MENU_SCENE: PackedScene = preload("res://scenes/ui/main_menu.tscn")
const STORY_SCENE: PackedScene = preload("res://scenes/ui/arcade_story.tscn")

var _requested: Array[StringName] = []


func _on_screen_requested(screen: StringName) -> void:
	_requested.append(screen)


func _begin() -> void:
	_requested.clear()
	ScreenRouter.enabled = false
	Events.screen_requested.connect(_on_screen_requested)


func _end() -> void:
	Events.screen_requested.disconnect(_on_screen_requested)
	ScreenRouter.enabled = true
	ArcadeRun.quit_run()
	MatchConfig.p1_index = 0
	MatchConfig.p2_index = 1


func test_boss_is_a_complete_character() -> void:
	var boss := load(ArcadeRun.BOSS_PATH) as CharacterData
	check(boss != null, "the boss loads")
	check_eq(boss.display_name, "Yhwach", "the boss is Yhwach")
	check(boss.moveset != null and boss.specials != null and boss.ultimate != null, "the boss has moves")
	check(boss.bankai_specials != null, "the boss has a powered-up set")
	for path in MatchConfig.ROSTER_PATHS:
		check(boss.weight >= (load(path) as CharacterData).weight, "the boss is at least as heavy as the roster")
	check(not MatchConfig.ROSTER_PATHS.has(ArcadeRun.BOSS_PATH), "the boss is not selectable")


func test_ladder_has_the_other_fighters_then_a_rival_then_the_boss() -> void:
	for player in MatchConfig.roster_size():
		ArcadeRun.player_index = player
		var player_name := ArcadeRun.player_name()
		check(ArcadeRun.opponent_name(0) != player_name, "fight 1 is another fighter (player %d)" % player)
		check(ArcadeRun.opponent_name(1) != player_name, "fight 2 is another fighter (player %d)" % player)
		check(ArcadeRun.opponent_name(0) != ArcadeRun.opponent_name(1), "the first two differ (player %d)" % player)
		check_eq(ArcadeRun.opponent_name(2), player_name, "fight 3 is the rival (player %d)" % player)
		check_eq(ArcadeRun.opponent_name(3), "Yhwach", "fight 4 is the boss (player %d)" % player)
	ArcadeRun.quit_run()


func test_difficulty_rises_and_the_boss_is_the_hardest() -> void:
	for fight in ArcadeRun.FIGHT_COUNT - 1:
		check(ArcadeRun.cpu_level_for(fight) < ArcadeRun.cpu_level_for(fight + 1), "fight %d is harder" % (fight + 2))
	check_eq(ArcadeRun.cpu_level_for(3), AIInput.MAX_LEVEL, "the boss uses the top AI level")
	check(AIInput.LEVELS.has(AIInput.MAX_LEVEL), "the top AI level has settings")


func test_start_prepares_the_first_match() -> void:
	ArcadeRun.start(1)
	check(ArcadeRun.active and MatchConfig.arcade, "the run is active")
	check_eq(MatchConfig.p1_index, 1, "the player's pick is used")
	check_eq(MatchConfig.cpu_level, 1, "the first fight is level 1")
	check_eq(MatchConfig.character_for(2).display_name, ArcadeRun.opponent_name(0), "player 2 is the opponent")
	ArcadeRun.quit_run()
	check(not MatchConfig.arcade and MatchConfig.opponent_override == null, "quitting clears the override")
	check_eq(MatchConfig.cpu_level, 0, "quitting turns the CPU off")


func test_winning_advances_and_losing_repeats_the_fight() -> void:
	ArcadeRun.start(0)
	check_eq(ArcadeRun.finish_match(true), ArcadeRun.SCREEN_STORY, "a win leads to the next story")
	check_eq(ArcadeRun.fight_index, 1, "now fight 2")
	check_eq(MatchConfig.cpu_level, 2, "the CPU level rose")
	check_eq(ArcadeRun.finish_match(false), ArcadeRun.SCREEN_CONTINUE, "a loss leads to the continue screen")
	check_eq(ArcadeRun.fight_index, 1, "the fight stays the same")
	check_eq(ArcadeRun.continues_used, 1, "the continue is counted")
	ArcadeRun.finish_match(true)
	ArcadeRun.finish_match(true)
	check(ArcadeRun.is_boss_fight(), "the last fight is the boss")
	check_eq(MatchConfig.character_for(2).display_name, "Yhwach", "the boss is player 2")
	check_eq(ArcadeRun.finish_match(true), ArcadeRun.SCREEN_CLEAR, "beating the boss clears Arcade")
	ArcadeRun.quit_run()


func test_every_fight_has_story_text_with_the_names_filled_in() -> void:
	ArcadeRun.start(0)
	for fight in ArcadeRun.FIGHT_COUNT:
		var lines := ArcadeRun.intro_lines(fight)
		check(lines.size() >= 2, "fight %d has story lines" % (fight + 1))
		for line in lines:
			check(not line.contains("%s") and not line.contains("%p"), "no placeholders left: %s" % line)
	check(ArcadeRun.intro_lines(3)[1].contains("Yhwach"), "the boss intro names him")
	check(ArcadeRun.ending_lines()[1].contains("Ichigo"), "the ending names the player")
	ArcadeRun.quit_run()


func test_main_menu_arcade_turns_arcade_on_and_other_modes_turn_it_off() -> void:
	_begin()
	var menu := MAIN_MENU_SCENE.instantiate() as MainMenu
	check_eq(menu.cursor.index, 0, "Arcade is the first entry and is selectable")
	menu.handle_action(&"confirm")
	check(MatchConfig.arcade and MatchConfig.cpu_level > 0, "Arcade mode is on")
	menu.handle_action(&"down")
	menu.handle_action(&"confirm")
	check(not MatchConfig.arcade and MatchConfig.cpu_level == 0, "2-player versus turns Arcade off")
	menu.free()
	_end()


func test_arcade_character_select_starts_the_run() -> void:
	_begin()
	MatchConfig.arcade = true
	MatchConfig.cpu_level = 2
	var screen := SELECT_SCENE.instantiate() as CharacterSelect
	screen.handle_player_action(1, &"right")
	screen.handle_player_action(2, &"right")
	check_eq(MatchConfig.p2_index, 1, "player 2's keys do nothing in Arcade")
	screen.handle_player_action(1, &"confirm")
	check(ArcadeRun.active, "the run started")
	check_eq(ArcadeRun.player_index, 1, "with the fighter that was picked")
	check_eq(_requested, [ArcadeRun.SCREEN_STORY] as Array[StringName], "the story screen comes next")
	screen.free()
	_end()


func test_story_screen_heading_and_back() -> void:
	_begin()
	ArcadeRun.start(0)
	var screen := STORY_SCENE.instantiate() as ArcadeStory
	check_eq(screen.heading(), "FIGHT 1 / 4", "first heading")
	ArcadeRun.finish_match(true)
	ArcadeRun.finish_match(true)
	ArcadeRun.finish_match(true)
	check_eq(screen.heading(), "FINAL FIGHT", "boss heading")
	screen.handle_action(&"confirm")
	check_eq(_requested, [&"versus_match"] as Array[StringName], "confirm starts the fight")
	screen.handle_action(&"back")
	check(not ArcadeRun.active, "back quits Arcade")
	screen.free()
	_end()
