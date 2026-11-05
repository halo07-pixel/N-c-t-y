extends TestCase
## Rukia's kit: Sode no Shirayuki's three dances, Hakka no Togame, and the frost that builds up on
## whoever she hits.

const RUKIA: CharacterData = preload("res://resources/characters/ice.tres")
const FIGHTER_SCENE: PackedScene = preload("res://scenes/fighter/fighter.tscn")


func test_canon_names() -> void:
	check_eq(RUKIA.display_name, "Rukia", "the fighter")
	check_eq(RUKIA.specials.neutral.display_name, "Tsugi no Mai: Hakuren", "the second dance")
	check_eq(RUKIA.specials.down.display_name, "Some no Mai: Tsukishiro", "the first dance")
	check_eq(RUKIA.ultimate.display_name, "San no Mai: Shirafune", "the third dance")
	check_eq(RUKIA.transform_title, "BANKAI: HAKKA NO TOGAME", "the bankai")


func test_her_kit_has_a_way_in_a_way_back_and_a_jab_string() -> void:
	var roles := {}
	for skill: SpecialData in [RUKIA.specials.neutral, RUKIA.specials.forward, RUKIA.specials.up, RUKIA.specials.down]:
		roles[skill.role] = true
	check(roles.has("zone") and roles.has("rush"), "pokes from afar and closes the gap")
	check(roles.has("recover"), "can get back to the stage")
	check(RUKIA.moveset.ground_neutral.next_in_chain.next_in_chain != null, "the jab becomes a three-hit string")


func test_her_skills_are_interactive_like_the_first_three() -> void:
	for set: SpecialSet in [RUKIA.specials, RUKIA.bankai_specials]:
		check(set.neutral.is_chargeable() and set.neutral.charge_pierce, "hold the skill key to widen the ice stream; a full charge pierces")
		check(set.forward.follow_up != null and set.forward.follow_up.flip_facing, "the step has a second press that dances back through the target")
		check(set.down.projectiles[0].trap and set.down.limit_active > 1, "Tsukishiro is a rune trap she can lay more than one of")


func test_her_bankai_is_white_and_not_another_fighters_look() -> void:
	check_eq(RUKIA.rig.form_style, &"white_frost", "Hakka no Togame is a white frost form")
	for path in ["swordsman", "archer", "noble", "lieutenant"]:
		var other := load("res://resources/characters/%s.tres" % path) as CharacterData
		check(other.rig.form_style != RUKIA.rig.form_style, "not %s's form" % other.display_name)
	check(RUKIA.rig.form_look != null, "she changes into an all-white look")
	check(RUKIA.rig.form_look.cloth.get_luminance() > 0.9 and RUKIA.rig.form_look.hair.get_luminance() > 0.9, "white clothes and white hair")
	check(RUKIA.rig.hair.get_luminance() < 0.3, "her normal hair is dark")


func test_the_body_wears_the_form_look_only_while_transformed() -> void:
	var body := BodyFactory.create(RUKIA, 1)
	tree.root.add_child(body)
	body.set_bankai(true)
	check(body._look == RUKIA.rig.form_look, "transformed: the white look")
	body.set_bankai(false)
	check(body._look == RUKIA.rig, "back to the normal look")
	body.free()


func test_she_is_the_lightest_and_fastest_fighter() -> void:
	for path in ["swordsman", "archer", "noble", "lieutenant"]:
		var other := load("res://resources/characters/%s.tres" % path) as CharacterData
		check(RUKIA.weight < other.weight, "lighter than %s" % other.display_name)
		check(RUKIA.run_speed >= other.run_speed, "at least as fast as %s" % other.display_name)


func _victim_and_rukia() -> Array:
	var rukia := FIGHTER_SCENE.instantiate() as Fighter
	rukia.player_id = 1
	rukia.data = RUKIA
	tree.root.add_child(rukia)
	var victim := FIGHTER_SCENE.instantiate() as Fighter
	victim.player_id = 2
	victim.data = RUKIA
	tree.root.add_child(victim)
	return [rukia, victim]


func _strike(victim: Fighter, attacker_id: int) -> void:
	var info := HitInfo.new()
	info.attacker_id = attacker_id
	info.damage = 4.0
	info.base_knockback = 100.0
	victim.hurtbox.receive_hit(info)


func test_the_third_hit_freezes_the_target_and_the_stacks_reset() -> void:
	var pair := _victim_and_rukia()
	var victim: Fighter = pair[1]
	_strike(victim, 1)
	check_eq(victim.chill_stacks, 1, "one chill")
	_strike(victim, 1)
	check_eq(victim.chill_stacks, 2, "two chills")
	var plain_lag := victim.hitlag_left
	_strike(victim, 1)
	check_eq(victim.chill_stacks, 0, "the third hit spends the stacks")
	check(victim.hitlag_left >= Fighter.FREEZE_FRAMES, "and freezes the target (%d > %d)" % [victim.hitlag_left, plain_lag])
	pair[0].free()
	victim.free()


func test_only_rukias_hits_chill() -> void:
	var pair := _victim_and_rukia()
	var victim: Fighter = pair[1]
	victim.data = preload("res://resources/characters/swordsman.tres")
	pair[0].data = preload("res://resources/characters/swordsman.tres")
	_strike(victim, 1)
	check_eq(victim.chill_stacks, 0, "other fighters' hits do not chill")
	pair[0].free()
	victim.free()
