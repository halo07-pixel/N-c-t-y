extends TestCase
## Charged specials, follow-ups and Reiatsu costs, using Ichigo's kit.

const STAGE_SCENE: PackedScene = preload("res://scenes/stages/test_stage.tscn")
const FIGHTER_SCENE: PackedScene = preload("res://scenes/fighter/fighter.tscn")
const SWORDSMAN: CharacterData = preload("res://resources/characters/swordsman.tres")
const ARCHER: CharacterData = preload("res://resources/characters/archer.tres")

var _stage: Stage
var _a: Fighter
var _b: Fighter
var _input: ScriptedInput
var _shots: Array[Projectile] = []


func _build(character: CharacterData = SWORDSMAN) -> void:
	_shots.clear()
	_stage = STAGE_SCENE.instantiate() as Stage
	tree.root.add_child(_stage)
	_a = _spawn(1, Vector2(-100.0, 50.0), 1, character)
	_b = _spawn(2, Vector2(140.0, 50.0), -1)
	_input = ScriptedInput.new()
	_a.set_input_source(_input)
	_b.set_input_source(ScriptedInput.new())


func _spawn(id: int, pos: Vector2, facing: int, character: CharacterData = SWORDSMAN) -> Fighter:
	var fighter := FIGHTER_SCENE.instantiate() as Fighter
	fighter.player_id = id
	fighter.data = character
	fighter.position = pos
	fighter.facing = facing
	fighter.projectile_spawned.connect(func(p: Projectile) -> void:
		_shots.append(p)
		tree.root.add_child(p))
	tree.root.add_child(fighter)
	return fighter


func _teardown() -> void:
	for shot in _shots:
		if is_instance_valid(shot):
			shot.free()
	_a.free()
	_b.free()
	_stage.free()


func test_charge_scales_grow_with_the_charge_and_pierce_only_when_full() -> void:
	var getsuga := SWORDSMAN.specials.neutral
	var none := getsuga.charge_scales(0.0)
	var half := getsuga.charge_scales(0.5)
	var full := getsuga.charge_scales(1.0)
	check_near(none["damage"], 1.0, 0.001, "no charge, normal damage")
	check(half["damage"] > none["damage"] and full["damage"] > half["damage"], "damage grows with the charge")
	check(full["size"] > half["size"] and full["speed"] > half["speed"], "size and speed grow too")
	check(not half["pierce"] and full["pierce"], "only a full charge pierces")


func test_a_charge_past_the_free_share_needs_the_reiatsu() -> void:
	var getsuga := SWORDSMAN.specials.neutral
	check_near(getsuga.max_charge_share(false), SpecialData.FREE_CHARGE_SHARE, 0.001, "capped when it cannot pay")
	check_near(getsuga.max_charge_share(true), 1.0, 0.001, "full when it can")


func test_holding_special_charges_and_releasing_fires() -> void:
	_build()
	await wait_frames(30)
	_input.held_special = true
	_input.tap_special()
	await wait_frames(25)
	check(_a.special_charge > 0.2, "charging (%.2f)" % _a.special_charge)
	check(_shots.is_empty(), "nothing is fired while holding")
	_input.held_special = false
	await wait_frames(6)
	check_eq(_shots.size(), 1, "released: the wave flies")
	check(_shots[0]._size.x > SWORDSMAN.specials.neutral.projectiles[0].size.x, "a charged wave is bigger")
	check_eq(_a.special_charge, 0.0, "the charge is spent")
	_teardown()


func test_a_quick_tap_fires_a_normal_wave() -> void:
	_build()
	await wait_frames(30)
	_input.tap_special()
	await wait_frames(20)
	check_eq(_shots.size(), 1, "one wave")
	check_near(_shots[0]._size.x, SWORDSMAN.specials.neutral.projectiles[0].size.x, 0.01, "of normal size")
	_teardown()


func test_a_full_charge_costs_a_block_and_pierces() -> void:
	_build()
	_a.set_reiatsu(150.0)
	await wait_frames(30)
	_input.held_special = true
	_input.tap_special()
	await wait_frames(SWORDSMAN.specials.neutral.charge_max_frames + 20)
	_input.held_special = false
	await wait_frames(8)
	check(_shots.size() >= 1 and _shots[0]._pierce, "the full charge pierces")
	check(_a.reiatsu < 80.0, "and one block was paid (%d left)" % int(_a.reiatsu))
	_teardown()


func test_without_reiatsu_the_charge_stops_at_the_free_share() -> void:
	_build()
	_a.set_reiatsu(0.0)
	await wait_frames(30)
	_input.held_special = true
	_input.tap_special()
	await wait_frames(SWORDSMAN.specials.neutral.charge_max_frames + 25)
	check(_shots.size() >= 1, "it fires by itself when it cannot charge further")
	check(not _shots[0]._pierce, "without piercing")
	_input.held_special = false
	_teardown()


func test_the_follow_up_slashes_back_and_costs_reiatsu() -> void:
	_build()
	_a.set_reiatsu(100.0)
	await wait_frames(30)
	_input.held_move = Vector2(1.0, 0.0)
	_input.tap_special()
	await wait_frames(9)
	_input.held_move = Vector2.ZERO
	check_eq(_a.facing, 1, "dashing forward")
	_input.tap_special()
	await wait_frames(2)
	check_eq(_a.get_state_name(), &"Attack", "still attacking")
	check_eq(_a.facing, -1, "turned around for the return slash")
	check(_a.reiatsu < 60.0, "half a block was paid (%d left)" % int(_a.reiatsu))
	_teardown()


func test_no_follow_up_without_reiatsu() -> void:
	_build()
	_a.set_reiatsu(0.0)
	await wait_frames(30)
	_input.held_move = Vector2(1.0, 0.0)
	_input.tap_special()
	await wait_frames(9)
	_input.held_move = Vector2.ZERO
	_input.tap_special()
	await wait_frames(2)
	check_eq(_a.facing, 1, "no turn around: it could not be paid")
	_teardown()


func test_ichigos_kit_has_the_new_pieces_and_the_form_makes_them_free() -> void:
	for set: SpecialSet in [SWORDSMAN.specials, SWORDSMAN.bankai_specials]:
		check(set.neutral.is_chargeable(), "Getsuga can be charged")
		check(set.forward.follow_up != null and set.forward.follow_up.flip_facing, "Dash Slash has a return slash")
		check(set.up.follow_up != null, "Rising Cut has a dive")
		check(not set.down.projectiles.is_empty(), "Ground Slam sends a shockwave")
	check(SWORDSMAN.specials.neutral.charge_cost > 0.0 and SWORDSMAN.specials.forward.follow_up_cost > 0.0, "costs Reiatsu normally")
	check_eq(SWORDSMAN.bankai_specials.neutral.charge_cost, 0.0, "free in the form")
	check_eq(SWORDSMAN.bankai_specials.forward.follow_up_cost, 0.0, "follow-ups are free in the form")
	check(SWORDSMAN.bankai_specials.neutral.projectiles.size() == 2, "the form fires two waves")



# --- Uryu --------------------------------------------------------------------------

func _build_archer() -> void:
	_build(ARCHER)


func test_urys_kit_has_charge_sky_shot_and_traps_and_the_form_makes_them_free() -> void:
	for set: SpecialSet in [ARCHER.specials, ARCHER.bankai_specials]:
		check(set.neutral.is_chargeable() and set.neutral.charge_pierce, "the arrow can be charged to pierce")
		check(set.up.follow_up != null and not set.up.follow_up.projectiles.is_empty(), "Sky Step has a Sky Shot")
		check(set.down.projectiles[0].trap and set.down.projectiles[0].velocity == Vector2.ZERO, "Sprenger is a stationary trap")
		check(set.down.limit_active == 2, "two traps at most")
	check(ARCHER.specials.neutral.charge_cost > 0.0 and ARCHER.specials.up.follow_up_cost > 0.0, "costs Reiatsu normally")
	check_eq(ARCHER.bankai_specials.neutral.charge_cost, 0.0, "charging is free in the form")
	check_eq(ARCHER.bankai_specials.up.follow_up_cost, 0.0, "Sky Shot is free in the form")
	check_eq(ARCHER.bankai_specials.down.repeat_cost, 0.0, "extra traps are free in the form")
	check_eq(ARCHER.bankai_specials.neutral.projectiles.size(), 3, "the form fires a fan of three arrows")


func test_sprenger_lays_a_trap_that_stays_put() -> void:
	_build_archer()
	await wait_frames(30)
	_input.held_move = Vector2(0.0, 1.0)
	_input.tap_special()
	await wait_frames(20)
	_input.held_move = Vector2.ZERO
	check_eq(_a.live_traps().size(), 1, "one trap is down")
	var where := _shots[0].position
	await wait_frames(30)
	check_near(_shots[0].position.x, where.x, 0.01, "it does not move")
	_teardown()


func test_a_trap_explodes_on_the_enemy() -> void:
	_build_archer()
	_b.global_position = Vector2(-100.0 + 46.0, 50.0)
	await wait_frames(30)
	_input.held_move = Vector2(0.0, 1.0)
	_input.tap_special()
	await wait_frames(25)
	_input.held_move = Vector2.ZERO
	check(_b.percent > 0.0 or _a.live_traps().is_empty(), "the trap went off on the enemy")
	_teardown()


func test_a_second_trap_costs_reiatsu_and_the_limit_replaces_the_oldest() -> void:
	_build_archer()
	_a.set_reiatsu(100.0)
	await wait_frames(30)
	_input.held_move = Vector2(0.0, 1.0)
	for i in 3:
		_input.tap_special()
		await wait_frames(40)
		if i == 0:
			check(_a.reiatsu > 90.0, "the first trap is free")
		if i == 1:
			check(_a.reiatsu < 80.0, "the second one is paid (%d left)" % int(_a.reiatsu))
	await wait_frames(2)
	check_eq(_a.live_traps().size(), 2, "never more than two live traps")
	_teardown()


func test_without_reiatsu_a_new_trap_replaces_the_old_one() -> void:
	_build_archer()
	_a.set_reiatsu(0.0)
	await wait_frames(30)
	_input.held_move = Vector2(0.0, 1.0)
	_input.tap_special()
	await wait_frames(40)
	_input.tap_special()
	await wait_frames(40)
	check_eq(_a.live_traps().size(), 1, "the first trap was replaced")
	_teardown()


func test_sky_shot_follows_sky_step_and_fires_down() -> void:
	_build_archer()
	_a.set_reiatsu(100.0)
	await wait_frames(30)
	_input.held_move = Vector2(0.0, -1.0)
	_input.tap_special()
	await wait_frames(10)
	_input.held_move = Vector2.ZERO
	_input.tap_special()
	await wait_frames(12)
	check(_a.reiatsu < 70.0, "half a block was paid (%d left)" % int(_a.reiatsu))
	check_eq(_shots.size(), 1, "one arrow")
	check(_shots[0]._velocity.y > 0.0, "flying downward")
	_teardown()


func test_the_cpu_lays_traps_only_up_to_the_limit() -> void:
	_build_archer()
	var ai := AIInput.new()
	_a.set_input_source(ai)
	ai.bind(_a, _b, 3, 7)
	var placed := 0
	for i in 600:
		await wait_frames(1)
		placed = maxi(placed, _a.live_traps().size())
	check(placed <= 2, "the limit holds for the CPU (%d)" % placed)
	_teardown()
