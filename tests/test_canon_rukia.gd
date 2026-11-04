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
