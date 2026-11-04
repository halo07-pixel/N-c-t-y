extends TestCase
## The skill strip data and the move list.

const STAGE_SCENE: PackedScene = preload("res://scenes/stages/test_stage.tscn")
const FIGHTER_SCENE: PackedScene = preload("res://scenes/fighter/fighter.tscn")
const ROSTER: Array[String] = ["swordsman", "archer", "noble", "lieutenant", "emperor"]


func _fighter(character: String) -> Fighter:
	var fighter := FIGHTER_SCENE.instantiate() as Fighter
	fighter.player_id = 1
	fighter.data = load("res://resources/characters/%s.tres" % character)
	fighter.position = Vector2(0.0, 50.0)
	tree.root.add_child(fighter)
	return fighter


func test_skill_info_has_four_slots() -> void:
	var fighter := _fighter("archer")
	var info := fighter.skill_hud_info()
	check_eq(info.size(), 4, "one slot per direction")
	check(info[0]["fraction"] == 0.0 and info[0]["seconds"] == 0.0, "nothing cooling at the start")
	fighter.free()


func test_a_used_skill_shows_its_seconds() -> void:
	var fighter := _fighter("archer")
	var special := fighter.data.specials.forward
	fighter.begin_special_use(special, false)
	var info := fighter.skill_hud_info()
	check(info[1]["fraction"] > 0.9, "the forward slot is cooling")
	check_near(info[1]["seconds"], float(special.cooldown_frames) / 60.0, 0.05, "with the seconds left")
	check(info[0]["fraction"] == 0.0, "the others are ready")
	fighter.free()


func test_the_counter_slot_reports_its_reiatsu_cost() -> void:
	var fighter := _fighter("emperor")
	var info := fighter.skill_hud_info()
	check(info[3]["cost"] > 0.0, "Yhwach's down skill costs Reiatsu")
	check_eq(info[0]["cost"], 0.0, "his neutral skill is free")
	fighter.free()


func test_the_hud_is_told_about_changes() -> void:
	var fighter := _fighter("swordsman")
	var seen: Array = []
	var listener := func(id: int, info: Array) -> void:
		if id == 1:
			seen.append(info.size())
	Events.fighter_skills_changed.connect(listener)
	fighter.reset_cooldowns()
	Events.fighter_skills_changed.disconnect(listener)
	check(not seen.is_empty() and seen[0] == 4, "the HUD receives four entries")
	fighter.free()


func test_key_labels() -> void:
	check_eq(MatchHud.skill_key_label(1, &"special"), "K", "player 1 Special is K")
	check(MatchHud.skill_key_label(2, &"special").begins_with("N"), "player 2 uses the numpad")


func test_move_list_names_every_skill() -> void:
	for name in ROSTER:
		var data := load("res://resources/characters/%s.tres" % name) as CharacterData
		var text := "\n".join(MoveListOverlay.lines_for(data, 1))
		check(text.contains(data.display_name.to_upper()), "%s: the name" % name)
		check(text.contains(data.moveset.throw_move.display_name), "%s: the throw" % name)
		check(text.contains(data.moveset.ground_neutral.next_in_chain.display_name), "%s: the combo" % name)
		for skill: SpecialData in [data.specials.neutral, data.specials.forward, data.specials.up, data.specials.down]:
			check(text.contains(skill.display_name), "%s: %s is listed" % [name, skill.display_name])
		check(text.contains(data.ultimate.display_name), "%s: the ultimate" % name)
