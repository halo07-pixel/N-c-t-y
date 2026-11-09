extends TestCase
## The smarter CPU: it reads its opponent's habits, chooses when to transform, stands where its
## Bankai works and has names for its levels.


func _observe(reader: CpuReader, state: StringName, times: int) -> void:
	for i in times:
		reader.observe(&"Idle", true)
		reader.observe(state, true)


func test_the_reader_needs_a_few_events_before_it_judges() -> void:
	var reader := CpuReader.new()
	check_eq(reader.dominant(), CpuReader.NONE, "nothing seen yet")
	_observe(reader, &"Guard", 2)
	check_eq(reader.dominant(), CpuReader.NONE, "two guards are not a habit")
	_observe(reader, &"Guard", 2)
	check_eq(reader.dominant(), CpuReader.GUARD, "four are")


func test_a_habit_has_to_make_up_most_of_what_the_opponent_does() -> void:
	var reader := CpuReader.new()
	_observe(reader, &"Guard", 3)
	_observe(reader, &"Jump", 3)
	_observe(reader, &"Dash", 3)
	check_eq(reader.dominant(), CpuReader.NONE, "an even mix is no habit")


func test_old_habits_are_forgotten() -> void:
	var reader := CpuReader.new()
	_observe(reader, &"Guard", 5)
	for i in CpuReader.WINDOW_FRAMES + 20:
		reader.observe(&"Idle", true)
	check_eq(reader.dominant(), CpuReader.NONE, "ten seconds later the memory is empty")
	check_eq(reader.count_of(CpuReader.GUARD), 0, "no guards remembered")


func test_advice_follows_the_habit() -> void:
	var guarder := CpuReader.new()
	_observe(guarder, &"Guard", 5)
	check(guarder.advice()["mixup"] > 0.0, "a guarder is grabbed")
	check(guarder.advice()["poke_scale"] < 1.0, "and poked at less")
	var jumper := CpuReader.new()
	_observe(jumper, &"Jump", 5)
	check(jumper.advice()["anti_air"] > 0.0, "a jumper is hit in the air")
	var rusher := CpuReader.new()
	_observe(rusher, &"Attack", 5)
	check(rusher.advice()["defend"] > 0.0, "a rusher is met with the guard")


func test_good_cpus_wait_for_a_moment_worth_a_bankai() -> void:
	var calm := {"distance": 120.0, "target_attacking": false, "self_percent": 10.0, "target_percent": 5.0, "waited": 0}
	check(CpuTactics.bankai_wanted(1, calm), "the easiest level transforms at once")
	check(not CpuTactics.bankai_wanted(2, calm), "a better one waits")
	var hurt := calm.duplicate()
	hurt["self_percent"] = 80.0
	check(CpuTactics.bankai_wanted(2, hurt), "when hurt it transforms")
	var ahead := calm.duplicate()
	ahead["target_percent"] = 60.0
	check(CpuTactics.bankai_wanted(2, ahead), "when ahead it transforms")
	var patient := calm.duplicate()
	patient["waited"] = 600
	check(CpuTactics.bankai_wanted(2, patient), "it never sits on a full gauge for ever")
	var attacked := hurt.duplicate()
	attacked["target_attacking"] = true
	check(not CpuTactics.bankai_wanted(2, attacked), "not in the middle of being hit")
	var close := hurt.duplicate()
	close["distance"] = 30.0
	check(not CpuTactics.bankai_wanted(1, close), "nobody transforms inside the opponent")


func test_the_ultimate_waits_until_it_hurts() -> void:
	var early := {"distance": 100.0, "target_percent": 5.0, "form_frames_left": 900}
	check(CpuTactics.ultimate_wanted(1, early), "level 1 fires it at once")
	check(not CpuTactics.ultimate_wanted(2, early), "a better CPU saves it")
	check(CpuTactics.ultimate_wanted(2, {"distance": 100.0, "target_percent": 70.0, "form_frames_left": 900}), "for a damaged target")
	check(CpuTactics.ultimate_wanted(2, {"distance": 100.0, "target_percent": 5.0, "form_frames_left": 100}), "or before the form ends")
	check(not CpuTactics.ultimate_wanted(2, {"distance": 400.0, "target_percent": 90.0, "form_frames_left": 50}), "never out of range")


func test_every_bankai_mechanic_has_a_place_to_stand() -> void:
	for mechanic in [&"petals", &"reach", &"zeal", &"heartless", &"hollow", &"frost"]:
		var spacing := CpuTactics.bankai_spacing(mechanic)
		check(spacing != Vector2.ZERO and spacing.y > spacing.x, "%s has a preferred range" % mechanic)
	check(CpuTactics.bankai_spacing(&"heartless").x > 0.0, "Uryu keeps away")
	check_eq(CpuTactics.bankai_spacing(&"petals").x, 0.0, "Byakuya's ring wants the opponent close")
	check_eq(CpuTactics.bankai_spacing(&"steal"), Vector2.ZERO, "no opinion for the rest")


func test_the_levels_have_names_and_get_harder() -> void:
	for level in [1, 2, 3, 4]:
		check(MatchConfig.cpu_level_name(level) != "", "level %d is named" % level)
	for level in [1, 2, 3]:
		check(AIInput.LEVELS[level + 1]["reaction"] <= AIInput.LEVELS[level]["reaction"], "level %d reacts no slower" % (level + 1))
		check(AIInput.LEVELS[level + 1]["guard"] >= AIInput.LEVELS[level]["guard"], "and defends no less")
	check_eq(MatchConfig.CPU_MAX_LEVEL, 3, "menus offer three levels")
