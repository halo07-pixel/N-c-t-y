extends TestCase
## Byakuya's kit follows the series: Senbonzakura, Flash Step, Petal Wall,
## the Bankai's Senkei and Ikka Senjinka, and Shukei: Hakuteiken.

const BYAKUYA: CharacterData = preload("res://resources/characters/noble.tres")


func test_canon_names() -> void:
	var kit := BYAKUYA.specials
	check_eq(kit.neutral.display_name, "Senbonzakura", "the shikai")
	check_eq(kit.neutral.follow_up.display_name, "Senbonzakura: Command", "controlled by thought")
	check_eq(kit.forward.display_name, "Flash Step", "Shunpo master")
	check_eq(kit.down.display_name, "Petal Wall", "a wall of blades")
	check_eq(BYAKUYA.ultimate.display_name, "Shukei: Hakuteiken", "the single white sword")


func test_the_bankai_is_made_of_blades_that_strike_together() -> void:
	var form := BYAKUYA.bankai_specials
	check_eq(form.neutral.display_name, "Senkei", "the true form")
	for blade: ProjectileData in form.neutral.projectiles:
		check_eq(blade.style, &"blade", "glowing swords, not petals")
		check(blade.commandable, "they can be commanded")
	check_eq(form.neutral.follow_up.display_name, "Ikka Senjinka", "all of them strike at once")
	check(form.neutral.follow_up.command_speed > 0.0, "by sending them flying")


func test_hakuteiken_is_one_big_piercing_white_blade() -> void:
	var ultimate := BYAKUYA.ultimate
	check_eq(ultimate.projectiles.size(), 1, "a single sword")
	var sword := ultimate.projectiles[0]
	check_eq(sword.style, &"blade", "a blade")
	check(sword.pierce and sword.size.x >= 80.0, "large and piercing")
	check(sword.color.r > 0.9 and sword.color.g > 0.85, "white")
