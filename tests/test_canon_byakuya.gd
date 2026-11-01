extends TestCase
## Byakuya's kit follows the series: Senbonzakura, Hadō 31 Shakkahō, Hadō 4 Byakurai, Gōkei,
## the Bankai's Senkei and Ikka Senjinka, and Shukei: Hakuteiken.

const BYAKUYA: CharacterData = preload("res://resources/characters/noble.tres")


func test_canon_names() -> void:
	var kit := BYAKUYA.specials
	check_eq(kit.neutral.display_name, "Senbonzakura", "the shikai")
	check_eq(kit.neutral.follow_up.display_name, "Senbonzakura: Command", "controlled by thought")
	check_eq(kit.alt_neutral.display_name, "Hadō 31: Shakkahō", "the red fire")
	check_eq(kit.alt_forward.display_name, "Hadō 4: Byakurai", "the lightning")
	check_eq(kit.alt_down.display_name, "Gōkei", "blades closing in")
	check_eq(BYAKUYA.ultimate.display_name, "Shukei: Hakuteiken", "the single white sword")


func test_shakkaho_is_red_and_byakurai_is_a_white_bolt() -> void:
	var fire := BYAKUYA.specials.alt_neutral.projectiles[0]
	check(fire.color.r > 0.9 and fire.color.g < 0.35 and fire.color.b < 0.3, "a ball of red energy")
	var bolt := BYAKUYA.specials.alt_forward.projectiles[0]
	check_eq(bolt.style, &"bolt", "drawn as lightning")
	check(bolt.color.r > 0.8 and bolt.color.g > 0.85 and bolt.color.b > 0.9, "white")
	check(bolt.pierce or bolt.velocity.x > 400.0, "fast")


func test_gokei_swirls_and_still_stops_shots() -> void:
	var field := BYAKUYA.specials.alt_down.projectiles[0]
	check_eq(field.style, &"swirl", "blades circling and closing in")
	check(field.absorbs, "it still stops projectiles")


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
