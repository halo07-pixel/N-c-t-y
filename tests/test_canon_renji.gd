extends TestCase
## Renji's kit: Zabimaru's long reach, a lashing blade, Soo Zabimaru and the Hikotsu Taiho.

const RENJI: CharacterData = preload("res://resources/characters/lieutenant.tres")


func test_canon_names() -> void:
	check_eq(RENJI.display_name, "Renji", "the fighter")
	check_eq(RENJI.specials.neutral.display_name, "Hihio Zabimaru", "the shikai's roar")
	check_eq(RENJI.bankai_specials.neutral.display_name, "Hikotsu Taiho", "the bankai's cannon")
	check_eq(RENJI.transform_title, "BANKAI: SOO ZABIMARU", "the bankai")


func test_his_blade_reaches_further_than_everyone_elses() -> void:
	var renji_reach := RENJI.rig.weapon_length
	for path in ["swordsman", "archer", "noble"]:
		var other := load("res://resources/characters/%s.tres" % path) as CharacterData
		check(renji_reach > other.rig.weapon_length, "longer than %s's weapon" % other.display_name)


func test_his_kit_has_a_way_in_a_way_back_and_a_jab_string() -> void:
	var roles := {}
	for skill: SpecialData in [RENJI.specials.neutral, RENJI.specials.forward, RENJI.specials.up, RENJI.specials.down]:
		roles[skill.role] = true
	check(roles.has("zone") and roles.has("rush"), "pokes from afar and closes the gap")
	check(roles.has("recover"), "can get back to the stage")
	var jab := RENJI.moveset.ground_neutral
	check(jab.next_in_chain != null and jab.next_in_chain.next_in_chain != null, "the jab becomes a three-hit string")


func test_the_roar_is_a_fast_long_blade_and_the_cannon_pierces() -> void:
	var roar := RENJI.specials.neutral.projectiles[0]
	check(roar.velocity.x >= 450.0 and roar.lifetime_frames <= 20, "a fast, short-lived extension of the blade")
	check(RENJI.bankai_specials.neutral.projectiles[0].pierce, "the bankai's version pierces")
	check(RENJI.ultimate.projectiles[0].pierce and RENJI.ultimate.cinematic_frames > 0, "the ultimate is a cinematic piercing blast")


func test_his_signature_is_the_tip_strike() -> void:
	check_eq(RENJI.mechanic, &"reach", "Renji's mechanic is spacing with the blade tip")


func test_a_hit_on_the_blade_tip_hits_harder_than_one_up_close() -> void:
	var fighter := (preload("res://scenes/fighter/fighter.tscn").instantiate()) as Fighter
	fighter.data = RENJI
	tree.root.add_child(fighter)
	var near := HitInfo.new()
	near.reach_fraction = 0.3
	var tip := HitInfo.new()
	tip.reach_fraction = 0.9
	check(not fighter.is_tip_hit(near), "close to the fighter is no tip hit")
	check(fighter.is_tip_hit(tip), "far along the blade is a tip hit")
	tip.is_throw = true
	check(not fighter.is_tip_hit(tip), "a throw never counts")
	var hit := HitInfo.new()
	hit.reach_fraction = 0.9
	hit.damage = 10.0
	hit.base_knockback = 200.0
	fighter._on_hit_landed(hit)
	check_near(hit.damage, 12.0, 0.01, "tip hits deal 20% more damage")
	check_near(hit.base_knockback, 230.0, 0.01, "and knock back 15% further")
	var close := HitInfo.new()
	close.reach_fraction = 0.2
	close.damage = 10.0
	fighter._on_hit_landed(close)
	check_near(close.damage, 10.0, 0.01, "a close hit is unchanged")
	fighter.free()


func test_hitbox_reports_how_far_along_the_blade_the_target_is() -> void:
	var fighter := (preload("res://scenes/fighter/fighter.tscn").instantiate()) as Fighter
	fighter.data = RENJI
	tree.root.add_child(fighter)
	var hitbox := fighter.hitbox
	var move: MoveData = RENJI.moveset.ground_forward
	hitbox.activate(move, 1)
	var edge := move.hitbox_offset.x + move.hitbox_size.x * 0.5
	check_near(hitbox.reach_fraction_of(hitbox.global_position + Vector2(edge, 0.0)), 1.0, 0.01, "the far edge is 1")
	check_near(hitbox.reach_fraction_of(hitbox.global_position), 0.0, 0.01, "the fighter is 0")
	fighter.free()
