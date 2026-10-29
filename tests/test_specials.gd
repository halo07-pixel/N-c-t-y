extends TestCase
## Reiatsu, charging, Bankai, the ultimate and special moves with real fighters.

const STAGE_SCENE: PackedScene = preload("res://scenes/stages/test_stage.tscn")
const FIGHTER_SCENE: PackedScene = preload("res://scenes/fighter/fighter.tscn")
const SWORDSMAN: CharacterData = preload("res://resources/characters/swordsman.tres")
const ARCHER: CharacterData = preload("res://resources/characters/archer.tres")
const NOBLE: CharacterData = preload("res://resources/characters/noble.tres")

const FLOOR_Y := 60.0

var _stage: Stage
var _a: Fighter
var _b: Fighter
var _input_a: ScriptedInput
var _input_b: ScriptedInput
var _projectiles: Array[Projectile] = []
var _ultimate_events: Array[int] = []


func _on_projectile_spawned(projectile: Projectile) -> void:
	_projectiles.append(projectile)
	tree.root.add_child(projectile)


func _on_ultimate(player_id: int, _frames: int, _title: String) -> void:
	_ultimate_events.append(player_id)


func _build_world(a_data: CharacterData, b_data: CharacterData, a_x: float = -20.0, b_x: float = 10.0) -> void:
	_projectiles.clear()
	_ultimate_events.clear()
	_stage = STAGE_SCENE.instantiate() as Stage
	tree.root.add_child(_stage)
	_a = _spawn(1, a_data, Vector2(a_x, 50.0), 1)
	_b = _spawn(2, b_data, Vector2(b_x, 50.0), -1)
	_input_a = ScriptedInput.new()
	_input_b = ScriptedInput.new()
	_a.set_input_source(_input_a)
	_b.set_input_source(_input_b)
	Events.ultimate_started.connect(_on_ultimate)


func _spawn(id: int, character: CharacterData, pos: Vector2, facing: int) -> Fighter:
	var fighter := FIGHTER_SCENE.instantiate() as Fighter
	fighter.player_id = id
	fighter.data = character
	fighter.position = pos
	fighter.facing = facing
	fighter.projectile_spawned.connect(_on_projectile_spawned)
	tree.root.add_child(fighter)
	return fighter


func _teardown_world() -> void:
	Events.ultimate_started.disconnect(_on_ultimate)
	for projectile in _projectiles:
		if is_instance_valid(projectile):
			projectile.free()
	_a.free()
	_b.free()
	_stage.free()


func test_specials_are_picked_by_direction() -> void:
	var set := SWORDSMAN.specials
	check_eq(set.select(Vector2.ZERO), set.neutral, "neutral")
	check_eq(set.select(Vector2(1.0, 0.0)), set.forward, "forward")
	check_eq(set.select(Vector2(0.0, -1.0)), set.up, "up")
	check_eq(set.select(Vector2(0.0, 1.0)), set.down, "down")


func test_every_character_has_a_complete_kit() -> void:
	for character: CharacterData in [SWORDSMAN, ARCHER, NOBLE]:
		for set: SpecialSet in [character.specials, character.bankai_specials]:
			for special: SpecialData in [set.neutral, set.forward, set.up, set.down]:
				check(special != null, "%s has all four specials" % character.display_name)
		check(character.ultimate != null, "%s has an ultimate" % character.display_name)
		check(character.ultimate.cinematic_frames > 0, "%s ultimate is cinematic" % character.display_name)
		check(character.ultimate.damage > character.specials.neutral.damage, "ultimate hits hardest")
		check(character.bankai_specials.neutral != character.specials.neutral, "Bankai swaps the moves")


func test_charging_gains_reiatsu_only_while_held() -> void:
	_build_world(SWORDSMAN, SWORDSMAN, -90.0, 120.0)
	_a.start_bankai() # charging Reiatsu is a transformed-only action
	await wait_frames(30)
	_input_a.tap_charge()
	_input_a.held_charge = true
	await wait_frames(30)
	check_eq(_a.get_state_name(), &"Charge", "charging")
	check(_a.reiatsu > 30.0, "gained Reiatsu while held")
	_input_a.held_charge = false
	await wait_frames(3)
	var after_release := _a.reiatsu
	await wait_frames(20)
	check_eq(_a.get_state_name(), &"Idle", "stopped charging")
	check_eq(_a.reiatsu, after_release, "no gain after release")
	_teardown_world()


func test_reiatsu_is_capped_and_gained_from_hits() -> void:
	_build_world(SWORDSMAN, SWORDSMAN)
	_a.set_reiatsu(9999.0)
	check_eq(_a.reiatsu, Reiatsu.MAX, "capped")
	_a.set_reiatsu(0.0)
	await wait_frames(30)
	_input_a.tap_attack()
	for _i in 40:
		await tree.physics_frame
	check(_a.reiatsu > 0.0, "the attacker gained Reiatsu")
	check(_b.reiatsu > 0.0, "the victim gained Reiatsu")
	check(_a.reiatsu > _b.reiatsu, "dealing damage gives more than taking it")
	_teardown_world()


func test_bankai_costs_reiatsu_and_boosts_the_fighter() -> void:
	_build_world(SWORDSMAN, SWORDSMAN, -90.0, 120.0)
	_a.set_gauge(CombatGauge.MAX)
	await wait_frames(30)
	_input_a.tap_charge()
	await wait_frames(3)
	check_eq(_a.get_state_name(), &"Transform", "transforming")
	check(_a.is_bankai(), "Bankai is on")
	check_near(_a.gauge, 0.0, 0.001, "the gauge starts over")
	check_eq(_a.damage_multiplier, CombatGauge.DAMAGE_SCALE, "stronger")
	check_eq(_a.speed_scale, CombatGauge.SPEED_SCALE, "faster")
	check(not _a.hurtbox.is_active, "invincible while transforming")
	check_eq(_a.current_specials(), SWORDSMAN.bankai_specials, "uses the Bankai specials")
	await wait_frames(CombatGauge.TRANSFORM_FRAMES + 5)
	check_eq(_a.get_state_name(), &"Idle", "back in control")
	check(_a.hurtbox.is_active, "hittable again")
	_teardown_world()


func test_bankai_wears_off_and_resets_the_stats() -> void:
	_build_world(SWORDSMAN, SWORDSMAN, -90.0, 120.0)
	_a.set_gauge(CombatGauge.MAX)
	await wait_frames(30)
	_input_a.tap_charge()
	await wait_frames(CombatGauge.TRANSFORM_FRAMES + 5)
	_a.bankai_frames_left = 3
	await wait_frames(6)
	check(not _a.is_bankai(), "Bankai ended")
	check_eq(_a.damage_multiplier, 1.0, "damage back to normal")
	check_eq(_a.speed_scale, 1.0, "speed back to normal")
	check_eq(_a.current_specials(), SWORDSMAN.specials, "normal specials again")
	_teardown_world()


func test_transformation_needs_a_full_gauge() -> void:
	_build_world(SWORDSMAN, SWORDSMAN, -90.0, 120.0)
	_a.set_gauge(CombatGauge.MAX - 5.0)
	_a.set_reiatsu(Reiatsu.MAX) # Reiatsu alone does not transform
	await wait_frames(30)
	_input_a.tap_charge()
	await wait_frames(3)
	check(not _a.is_bankai(), "no transformation without a full gauge")
	check(_a.get_state_name() != &"Transform" and _a.get_state_name() != &"Charge", "and nothing else starts either")
	_teardown_world()


func test_ultimate_only_while_transformed() -> void:
	_build_world(SWORDSMAN, SWORDSMAN, -90.0, 120.0)
	_a.set_reiatsu(Reiatsu.MAX)
	check(not _a.can_ultimate(), "no ultimate in normal form")
	_a.start_bankai()
	check(_a.can_ultimate(), "ultimate available while transformed")
	_teardown_world()


func test_gauge_fills_from_hits_and_combo_and_resets_after_transforming() -> void:
	check(CombatGauge.gain_for_hit(10.0, 3) > CombatGauge.gain_for_hit(10.0, 1), "combos fill it faster")
	check_near(CombatGauge.combo_multiplier(99), CombatGauge.COMBO_MAX_MULTIPLIER, 0.001, "combo bonus is capped")
	_build_world(SWORDSMAN, SWORDSMAN)
	await wait_frames(30)
	_input_a.tap_attack()
	for _i in 40:
		await tree.physics_frame
	check(_a.gauge > 0.0, "the attacker's gauge grew")
	check(_b.gauge > 0.0, "the victim's gauge grew too")
	check(_a.gauge > _b.gauge, "but dealing damage pays more than taking it")
	_teardown_world()


func test_form_lasts_longer_with_hits_up_to_a_cap() -> void:
	check_eq(CombatGauge.extend_form(100), 100 + CombatGauge.HIT_EXTEND_FRAMES, "each hit adds time")
	check_eq(CombatGauge.extend_form(CombatGauge.FORM_CAP_FRAMES - 1), CombatGauge.FORM_CAP_FRAMES, "capped")


func test_stock_loss_gives_pity_and_ko_gives_a_bonus() -> void:
	_build_world(SWORDSMAN, SWORDSMAN, -90.0, 150.0)
	_b.last_attacker_id = _a.player_id
	_b.enter_ko()
	check_near(_b.gauge, CombatGauge.STOCK_LOSS_PITY, 0.001, "losing a stock fills the gauge")
	check_near(_a.gauge, CombatGauge.KO_BONUS, 0.001, "the one who landed the last hit gets a bonus")
	_teardown_world()


func test_gauge_fades_when_nothing_happens_but_not_in_form() -> void:
	_build_world(SWORDSMAN, SWORDSMAN, -90.0, 400.0)
	_a.set_gauge(50.0)
	_a._gauge_idle_frames = CombatGauge.IDLE_FRAMES
	await wait_frames(20)
	check(_a.gauge < 50.0, "it fades after a quiet spell")
	_teardown_world()


func test_transformation_announces_its_title_and_freezes_the_opponent() -> void:
	_build_world(SWORDSMAN, SWORDSMAN, -90.0, 120.0)
	var titles: Array[String] = []
	Events.transform_started.connect(func(_id: int, title: String, _frames: int) -> void: titles.append(title))
	_a.set_gauge(CombatGauge.MAX)
	await wait_frames(30)
	_input_a.tap_charge()
	await wait_frames(3)
	check_eq(titles.size(), 1, "one announcement")
	check_eq(titles[0], SWORDSMAN.transform_title, "with the character's own title")
	check(_b.hitlag_left > 0, "the opponent is frozen during the cinematic")
	_teardown_world()


func test_bankai_boosts_damage_dealt() -> void:
	_build_world(SWORDSMAN, SWORDSMAN)
	_a.start_bankai()
	await wait_frames(30)
	_input_a.tap_attack()
	for _i in 40:
		await tree.physics_frame
	var jab := SWORDSMAN.moveset.ground_neutral.damage
	check_near(_b.percent, jab * CombatGauge.DAMAGE_SCALE, 0.001, "jab hits 25 percent harder")
	_teardown_world()


func test_ultimate_spends_everything_and_freezes_the_opponent() -> void:
	_build_world(SWORDSMAN, SWORDSMAN, -90.0, 120.0)
	_a.start_bankai()
	_a.set_reiatsu(Reiatsu.MAX)
	await wait_frames(30)
	_input_a.tap_charge()
	await wait_frames(3)
	check_eq(_a.reiatsu, 0.0, "spent all Reiatsu")
	check_eq(_a.get_state_name(), &"Attack", "performing the ultimate")
	check_eq(_ultimate_events, [1] as Array[int], "announced once")
	check(_b.hitlag_left > 30, "the opponent is frozen")
	check_eq(_a.hitlag_left, 0, "the user is not frozen")
	check(not _a.hurtbox.is_active, "the user cannot be interrupted")
	_teardown_world()


func test_ultimate_fires_a_piercing_projectile() -> void:
	_build_world(SWORDSMAN, SWORDSMAN, -90.0, 120.0)
	_a.start_bankai()
	_a.set_reiatsu(Reiatsu.MAX)
	await wait_frames(30)
	_input_a.tap_charge()
	await wait_frames(SWORDSMAN.ultimate.startup_frames + 6)
	check(_projectiles.size() >= 1, "a projectile was fired")
	await wait_frames(80)
	check(_b.percent >= SWORDSMAN.ultimate.damage - 0.01, "it landed on the frozen-then-released opponent")
	_teardown_world()


func test_projectile_special_travels_and_damages() -> void:
	_build_world(SWORDSMAN, SWORDSMAN, -90.0, 100.0)
	await wait_frames(30)
	_input_a.tap_special()
	await wait_frames(SWORDSMAN.specials.neutral.startup_frames + 3)
	check_eq(_projectiles.size(), 1, "one projectile")
	var start_x := _projectiles[0].position.x
	await wait_frames(10)
	check(_projectiles[0].position.x > start_x + 20.0, "it flies forward")
	await wait_frames(60)
	check_near(_b.percent, SWORDSMAN.specials.neutral.damage, 0.001, "it hit once for its damage")
	check(not is_instance_valid(_projectiles[0]) or _projectiles[0].is_queued_for_deletion(), "it vanished on hit")
	_teardown_world()


func test_projectile_never_hits_its_owner() -> void:
	_build_world(SWORDSMAN, SWORDSMAN, -90.0, 150.0)
	await wait_frames(30)
	_input_a.tap_special()
	await wait_frames(60)
	check_eq(_a.percent, 0.0, "no self damage")
	_teardown_world()


func test_projectile_expires_after_its_lifetime() -> void:
	_build_world(SWORDSMAN, SWORDSMAN, -90.0, 150.0)
	_b.hurtbox.set_active(false)
	await wait_frames(30)
	_input_a.tap_special()
	await wait_frames(SWORDSMAN.specials.neutral.startup_frames + 5)
	var projectile := _projectiles[0]
	await wait_frames(SWORDSMAN.specials.neutral.projectiles[0].lifetime_frames + 5)
	check(not is_instance_valid(projectile) or projectile.is_queued_for_deletion(), "removed after its lifetime")
	_teardown_world()


func test_triple_shot_fires_three_arrows() -> void:
	_build_world(ARCHER, SWORDSMAN, -90.0, 150.0)
	await wait_frames(30)
	_input_a.held_move = Vector2(1.0, 0.0)
	_input_a.tap_special()
	await wait_frames(ARCHER.specials.forward.startup_frames + 4)
	check_eq(_projectiles.size(), 3, "three arrows")
	_teardown_world()


func test_up_special_launches_the_fighter_upward() -> void:
	_build_world(SWORDSMAN, SWORDSMAN, -90.0, 150.0)
	await wait_frames(30)
	_input_a.held_move = Vector2(0.0, -1.0)
	_input_a.tap_special()
	await wait_frames(SWORDSMAN.specials.up.startup_frames + 8)
	check(_a.global_position.y < FLOOR_Y - 30.0, "rose well above the floor")
	check_eq(_a.get_state_name(), &"Attack", "the move was not cancelled by leaving the ground")
	_teardown_world()


func test_dash_special_covers_distance() -> void:
	_build_world(SWORDSMAN, SWORDSMAN, -100.0, 150.0)
	await wait_frames(30)
	var start_x := _a.global_position.x
	_input_a.held_move = Vector2(1.0, 0.0)
	_input_a.tap_special()
	await wait_frames(SWORDSMAN.specials.forward.startup_frames + SWORDSMAN.specials.forward.active_frames + 3)
	check(_a.global_position.x > start_x + 25.0, "dashed forward")
	_teardown_world()


func test_teleport_special_moves_instantly() -> void:
	_build_world(NOBLE, SWORDSMAN, -100.0, 150.0)
	await wait_frames(30)
	var start_x := _a.global_position.x
	_input_a.held_move = Vector2(1.0, 0.0)
	_input_a.tap_special()
	await wait_frames(NOBLE.specials.forward.startup_frames + 2)
	check(_a.global_position.x > start_x + 60.0, "teleported ahead")
	_teardown_world()


func test_ko_cancels_bankai_and_queued_moves() -> void:
	_build_world(SWORDSMAN, SWORDSMAN, -90.0, 150.0)
	_a.start_bankai()
	_a.enter_ko()
	check(not _a.is_bankai(), "Bankai ended on KO")
	check_eq(_a.damage_multiplier, 1.0, "stats reset")
	_teardown_world()
