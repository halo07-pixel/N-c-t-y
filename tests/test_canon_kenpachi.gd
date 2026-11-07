extends TestCase
## Kenpachi's kit: the heaviest fighter, no finesse, and a zeal that grows with the beating he takes.

const KENPACHI: CharacterData = preload("res://resources/characters/brute.tres")
const FIGHTER_SCENE: PackedScene = preload("res://scenes/fighter/fighter.tscn")


func test_his_skills_are_interactive_like_the_first_three() -> void:
	for set: SpecialSet in [KENPACHI.specials, KENPACHI.bankai_specials]:
		check(set.neutral.is_chargeable() and set.neutral.charge_pierce, "hold the skill key to charge the slash; a full charge pierces")
		check(set.forward.follow_up != null, "the cleave has a second press (an overhead chop)")
		check(set.down.follow_up != null and set.down.follow_up.release_frames > 0, "the smash has a second press that tears off the eyepatch")


func test_the_eyepatch_comes_off_when_unleashed() -> void:
	check(KENPACHI.rig.eyepatch and KENPACHI.rig.hair_bells, "he wears the eyepatch and the bells")
	check_eq(KENPACHI.rig.form_style, &"unleashed", "the form is the unleashed release")
	check(KENPACHI.rig.form_look != null and not KENPACHI.rig.form_look.eyepatch, "the patch is gone in the form")
	var body := BodyFactory.create(KENPACHI, 1)
	tree.root.add_child(body)
	body.set_bankai(true)
	check(not body._head.rig.eyepatch, "the body's head draws no patch while unleashed")
	body.set_bankai(false)
	check(body._head.rig.eyepatch, "and the patch is back afterwards")
	body.free()


func test_canon_names() -> void:
	check_eq(KENPACHI.display_name, "Kenpachi", "the fighter")
	check_eq(KENPACHI.ultimate.display_name, "Nozarashi: Final Cleave", "his sword")
	check_eq(KENPACHI.specials.down.display_name, "Ground Smash", "a heavy blow")


func test_he_is_the_heaviest_and_slowest_on_foot_and_hits_hardest() -> void:
	for path in ["swordsman", "archer", "noble", "lieutenant", "ice"]:
		var other := load("res://resources/characters/%s.tres" % path) as CharacterData
		check(KENPACHI.weight > other.weight, "heavier than %s" % other.display_name)
		check(KENPACHI.run_speed <= other.run_speed, "no faster than %s" % other.display_name)
		check(KENPACHI.moveset.ground_forward.damage >= other.moveset.ground_forward.damage, "hits at least as hard as %s" % other.display_name)


func test_his_kit_has_a_way_in_a_way_back_and_a_heavy_blow() -> void:
	var roles := {}
	for skill: SpecialData in [KENPACHI.specials.neutral, KENPACHI.specials.forward, KENPACHI.specials.up, KENPACHI.specials.down]:
		roles[skill.role] = true
	check(roles.has("zone") and roles.has("rush") and roles.has("recover") and roles.has("heavy"), "poke, rush, recover and heavy")
	check(KENPACHI.moveset.ground_neutral.next_in_chain.next_in_chain != null, "the jab becomes a three-hit string")


func _kenpachi() -> Fighter:
	var fighter := FIGHTER_SCENE.instantiate() as Fighter
	fighter.player_id = 1
	fighter.data = KENPACHI
	tree.root.add_child(fighter)
	return fighter


func test_zeal_grows_with_the_damage_he_has_taken() -> void:
	var fighter := _kenpachi()
	check_near(fighter.zeal_scale(), 1.0, 0.001, "fresh, no bonus")
	fighter.percent = 50.0
	check_near(fighter.zeal_scale(), 1.175, 0.001, "half way")
	fighter.percent = 100.0
	check_near(fighter.zeal_scale(), 1.35, 0.001, "at 100% a third more damage")
	fighter.percent = 300.0
	check_near(fighter.zeal_scale(), 1.35, 0.001, "capped")
	fighter.free()


func test_zeal_empowers_melee_hits_but_not_throws() -> void:
	var fighter := _kenpachi()
	fighter.percent = 100.0
	var hit := HitInfo.new()
	hit.damage = 10.0
	fighter._on_hit_landed(hit)
	check_near(hit.damage, 13.5, 0.01, "a melee hit is empowered")
	var grab := HitInfo.new()
	grab.damage = 10.0
	grab.is_throw = true
	fighter._on_hit_landed(grab)
	check_near(grab.damage, 10.0, 0.01, "a throw is not")
	fighter.free()
