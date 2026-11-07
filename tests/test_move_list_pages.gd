extends TestCase
## The F3 move list: two pages per fighter and a plain sentence for every skill, follow-ups included.

const ROSTER := ["swordsman", "archer", "noble", "lieutenant", "ice", "brute"]


func _character(name: String) -> CharacterData:
	return load("res://resources/characters/%s.tres" % name) as CharacterData


func test_every_skill_and_follow_up_has_a_sentence() -> void:
	for name in ROSTER:
		var kit := _character(name).specials
		for skill: SpecialData in [kit.neutral, kit.forward, kit.up, kit.down]:
			check(SkillGuide.text_for(skill) != "", "%s: %s is explained" % [name, skill.display_name])
			if skill.follow_up != null:
				check(SkillGuide.text_for(skill.follow_up) != "", "%s: %s is explained" % [name, skill.follow_up.display_name])
			if skill.counter_move != null:
				check(SkillGuide.trigger_for(skill) == "", "a counter is not a follow-up")


func test_two_pages_and_the_follow_up_is_listed_under_its_skill() -> void:
	for name in ROSTER:
		var pages := MoveListOverlay.pages_for(_character(name), 1)
		check_eq(pages.size(), 2, "%s: two pages" % name)
		var names: Array = []
		for entry: Dictionary in pages[0]:
			if entry["kind"] == "skill":
				names.append(entry["name"])
		var kit := _character(name).specials
		var first: SpecialData = kit.neutral
		check(names.size() >= 5, "%s: skills and second presses are listed (%d)" % [name, names.size()])
		check(str(names[0]).begins_with(first.display_name), "%s: the neutral skill comes first" % name)


func test_the_numbers_come_from_the_data() -> void:
	var noble := _character("noble").specials
	var bind := noble.forward.follow_up
	check(SkillGuide.text_for(bind).contains("%.1fs" % (float(bind.bind_frames) / 60.0)), "the bind time is read from the skill")
	var brute := _character("brute").specials.down.follow_up
	check(SkillGuide.text_for(brute).contains("%.2f" % brute.release_taken), "the damage taken in a release is shown")


func test_paging_wraps_around() -> void:
	var overlay := MoveListOverlay.new()
	overlay.add_child(Control.new())
	check_eq(MoveListOverlay.PAGE_NAMES.size(), 2, "two pages")
	overlay.free()
