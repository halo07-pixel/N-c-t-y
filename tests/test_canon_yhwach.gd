extends TestCase
## Yhwach's kit uses the series' Quincy terms: Hirenkyaku, Blut, reishi arrows, the Almighty, Auswählen.

const YHWACH: CharacterData = preload("res://resources/characters/emperor.tres")


func test_canon_names() -> void:
	var kit := YHWACH.specials
	check_eq(kit.alt_neutral.display_name, "Reishi Arrow", "arrows of reishi")
	check_eq(kit.alt_forward.display_name, "Hirenkyaku Strike", "the Quincy step")
	check_eq(kit.alt_down.display_name, "Reishi Pillar", "pillar")
	check_eq(kit.down.display_name, "Foresight", "the Almighty sees the future")
	check_eq(kit.down.counter_move.display_name, "The Almighty", "the rewritten outcome")
	check_eq(YHWACH.ultimate.display_name, "Auswählen", "the pillar of light")


func test_pillars_are_light_not_shadow() -> void:
	var pillar := YHWACH.specials.alt_down.projectiles[0]
	check(pillar.color.r > 0.9 and pillar.color.g > 0.85, "pale gold light")
	for blast: ProjectileData in YHWACH.ultimate.projectiles:
		check(blast.color.g > 0.85, "Auswählen is light")


func test_bankai_names_follow() -> void:
	check_eq(YHWACH.bankai_specials.neutral.display_name, "Reishi Absorption +", "same skill, stronger")
