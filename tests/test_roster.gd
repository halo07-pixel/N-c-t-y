extends TestCase

const MATCH_CONFIG_SCRIPT := preload("res://scripts/autoload/match_config.gd")


func test_every_roster_entry_loads_as_a_complete_character() -> void:
	for path in MATCH_CONFIG_SCRIPT.ROSTER_PATHS:
		var character := load(path) as CharacterData
		check(character != null, "%s loads" % path)
		if character == null:
			continue
		check(character.display_name != "", "%s has a name" % path)
		check(character.moveset != null and character.specials != null, "%s has moves" % path)
		check(character.weight > 0.0 and character.run_speed > 0.0, "%s has stats" % path)


func test_characters_play_differently() -> void:
	var swordsman := load("res://resources/characters/swordsman.tres") as CharacterData
	var archer := load("res://resources/characters/archer.tres") as CharacterData
	var noble := load("res://resources/characters/noble.tres") as CharacterData
	check(noble.run_speed > swordsman.run_speed and swordsman.run_speed > archer.run_speed, "speed differs")
	check(archer.weight < swordsman.weight, "the archer is lighter")
	check(archer.specials.neutral.projectiles.size() > 0, "the archer shoots")
	check(noble.specials.forward.teleport.x > 0.0, "the noble teleports")
	check(swordsman.specials.up.self_velocity.y < 0.0, "the swordsman has a rising recovery")
	check(archer.weapon_style == &"bow", "the archer draws a bow")


func test_config_cycles_characters_and_cpu_level() -> void:
	var config = MATCH_CONFIG_SCRIPT.new()
	check_eq(config.p1_index, 0, "starts on the first character")
	config.cycle_character(1)
	check_eq(config.p1_index, 1, "next character")
	for _i in config.roster_size():
		config.cycle_character(2)
	check_eq(config.p2_index, 1, "wraps around the roster")
	check_eq(config.cpu_level, 0, "CPU is off by default")
	for _i in 3:
		config.cycle_cpu()
	check_eq(config.cpu_level, 3, "cycles up to level 3")
	config.cycle_cpu()
	check_eq(config.cpu_level, 0, "and back to off")
	check(config.describe().contains("P1"), "has a description")
	config.free()
