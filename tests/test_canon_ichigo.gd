extends TestCase
## Ichigo's kit follows the series: Getsuga Tenshō (black with a red rim in Bankai), Getsuga Jūjishō,
## Bringer Light, Cero, Final Getsuga Tenshō.

const ICHIGO: CharacterData = preload("res://resources/characters/swordsman.tres")


func test_canon_names() -> void:
	var kit := ICHIGO.specials
	check_eq(kit.neutral.display_name, "Getsuga Tenshō", "the signature skill")
	check_eq(kit.alt_neutral.display_name, "Getsuga Jūjishō", "two Getsuga at once")
	check_eq(kit.alt_forward.display_name, "Bringer Light", "the high-speed dash")
	check_eq(kit.alt_down.display_name, "Cero", "the Hollow blast")
	check_eq(ICHIGO.ultimate.display_name, "Final Getsuga Tenshō", "the final technique")


func test_jujisho_fires_two_crescents_that_spread() -> void:
	var jujisho := ICHIGO.specials.alt_neutral
	check_eq(jujisho.projectiles.size(), 2, "two Getsuga at once")
	check(jujisho.projectiles[0].velocity.y < 0.0 and jujisho.projectiles[1].velocity.y > 0.0, "one rises, one dips: a cross")


func test_cero_is_a_piercing_red_beam() -> void:
	var cero := ICHIGO.specials.alt_down.projectiles[0]
	check_eq(cero.style, &"beam", "drawn as a beam")
	check(cero.pierce, "it goes through the target")
	check(cero.color.r > 0.8 and cero.color.g < 0.4, "red")
	check(ICHIGO.specials.alt_down.startup_frames >= 14, "it is charged before it fires")


func test_bankai_getsuga_is_black_with_a_red_rim() -> void:
	var bankai := ICHIGO.bankai_specials
	for projectile in bankai.neutral.projectiles:
		check(projectile.rim.a > 0.0 and projectile.rim.r > 0.7, "the rim is red")
		check(projectile.color.r < 0.2 and projectile.color.g < 0.2, "the body is black")
	check(bankai.alt_neutral != null and bankai.alt_neutral.projectiles[0].rim.a > 0.0, "Jūjishō turns black in the form too")
	check(ICHIGO.ultimate.projectiles[0].rim.a > 0.0, "so does the Final Getsuga Tenshō")
	check(ICHIGO.specials.neutral.projectiles[0].rim.a == 0.0, "the Shikai Getsuga is the pale blue one")


func test_a_rimmed_projectile_is_solid_not_additive() -> void:
	var projectile := Projectile.new()
	projectile.launch(ICHIGO.bankai_specials.neutral.projectiles[0], ICHIGO.bankai_specials.neutral, 1, 1, 1.0, Vector2.ZERO)
	tree.root.add_child(projectile)
	check(projectile.material == null, "a dark projectile is not added to the light")
	projectile.free()
	var pale := Projectile.new()
	pale.launch(ICHIGO.specials.neutral.projectiles[0], ICHIGO.specials.neutral, 1, 1, 1.0, Vector2.ZERO)
	tree.root.add_child(pale)
	check(pale.material is CanvasItemMaterial, "a pale one glows")
	pale.free()


func test_the_form_aura_is_black_and_red() -> void:
	var profile := ICHIGO.fx_profile
	check(profile.form_primary.a > 0.0 and profile.form_primary.r > 0.7, "the Bankai pressure is red")
