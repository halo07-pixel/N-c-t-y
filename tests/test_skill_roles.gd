extends TestCase
## Every skill has one clear role, and its cooldown and damage fit that role.

const CHARACTERS: Array[CharacterData] = [
	preload("res://resources/characters/swordsman.tres"),
	preload("res://resources/characters/archer.tres"),
	preload("res://resources/characters/noble.tres"),
	preload("res://resources/characters/lieutenant.tres"),
	preload("res://resources/characters/ice.tres"),
	preload("res://resources/characters/emperor.tres"),
]


static func _slots(kit: SpecialSet) -> Array[SpecialData]:
	return [kit.neutral, kit.forward, kit.up, kit.down]


func test_every_skill_has_a_role_inside_its_cooldown_band() -> void:
	for character in CHARACTERS:
		for skill in _slots(character.specials):
			check(skill.role != "", "%s / %s has a role" % [character.display_name, skill.display_name])
			var band: Vector2i = SpecialData.ROLE_COOLDOWNS.get(skill.role, Vector2i(0, 9999))
			check(skill.cooldown_frames >= band.x and skill.cooldown_frames <= band.y, "%s / %s (%s) cooldown %d fits %s" % [character.display_name, skill.display_name, skill.role, skill.cooldown_frames, band])


func test_heavy_skills_hit_hard() -> void:
	for character in CHARACTERS:
		for skill in _slots(character.specials):
			if skill.role == "heavy":
				check(skill.damage >= SpecialData.HEAVY_MIN_DAMAGE, "%s / %s is heavy" % [character.display_name, skill.display_name])


func test_each_character_has_a_way_in_and_a_way_back() -> void:
	for character in CHARACTERS:
		var roles := {}
		for skill in _slots(character.specials):
			roles[skill.role] = true
		check(roles.has("zone") or roles.has("rush"), "%s can poke or close the gap" % character.display_name)
		check(roles.has("recover"), "%s can get back to the stage" % character.display_name)


func test_move_list_shows_the_role() -> void:
	var lines := MoveListOverlay.lines_for(CHARACTERS[0], 1)
	var text := "\n".join(lines)
	check(text.contains("[ZONE]") and text.contains("[DEFEND]"), "tags appear in the F3 list")
