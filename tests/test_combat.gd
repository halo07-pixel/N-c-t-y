extends TestCase
## Real fighters, real hitboxes and hurtboxes, scripted input.

const STAGE_SCENE: PackedScene = preload("res://scenes/stages/test_stage.tscn")
const FIGHTER_SCENE: PackedScene = preload("res://scenes/fighter/fighter.tscn")
const CHARACTER_A: CharacterData = preload("res://resources/characters/swordsman.tres")
const CHARACTER_B: CharacterData = preload("res://resources/characters/swordsman.tres")
const MOVESET: MoveSet = preload("res://resources/movesets/swordsman_moveset.tres")

const MAX_WAIT_FRAMES := 60

var _stage: Stage
var _a: Fighter
var _b: Fighter
var _input_a: ScriptedInput
var _input_b: ScriptedInput


## A stands at a_x facing a_facing, B at b_x; both start just above the floor.
func _build_world(a_x: float, b_x: float, a_facing: int = 1) -> void:
	_stage = STAGE_SCENE.instantiate() as Stage
	tree.root.add_child(_stage)
	_a = _spawn(1, CHARACTER_A, Vector2(a_x, 50.0), a_facing)
	_b = _spawn(2, CHARACTER_B, Vector2(b_x, 50.0), -a_facing)
	_input_a = ScriptedInput.new()
	_input_b = ScriptedInput.new()
	_a.set_input_source(_input_a)
	_b.set_input_source(_input_b)


func _spawn(id: int, character: CharacterData, pos: Vector2, facing: int) -> Fighter:
	var fighter := FIGHTER_SCENE.instantiate() as Fighter
	fighter.player_id = id
	fighter.data = character
	fighter.position = pos
	fighter.facing = facing
	tree.root.add_child(fighter)
	return fighter


func _teardown_world() -> void:
	_a.free()
	_b.free()
	_stage.free()


## Waits until B is launched. Returns false if that takes too long.
func _wait_for_b_hit() -> bool:
	for _i in MAX_WAIT_FRAMES:
		await tree.physics_frame
		if _b.get_state_name() == &"Hitstun":
			return true
	return false


func test_jab_damages_and_launches_the_target() -> void:
	_build_world(-20.0, 10.0)
	await wait_frames(30)
	_input_a.tap_attack()
	var landed: bool = await _wait_for_b_hit()
	check(landed, "the jab connected")
	check_eq(_b.percent, MOVESET.ground_neutral.damage, "B took the jab's damage")
	check_eq(_a.percent, 0.0, "A took nothing")
	check(_b.velocity.x > 0.0, "B was launched away from A")
	check(_b.velocity.y < 0.0, "B was launched upward")
	_teardown_world()


func test_launch_speed_matches_the_knockback_formula() -> void:
	_build_world(-20.0, 10.0)
	await wait_frames(30)
	_input_a.tap_attack()
	await _wait_for_b_hit()
	var move := MOVESET.ground_neutral
	var expected := Knockback.magnitude(
		move.base_knockback, move.knockback_growth, move.damage, CHARACTER_B.weight
	)
	check_near(_b.velocity.length(), expected, 0.5, "launch speed")
	_teardown_world()


func test_one_swing_hits_only_once() -> void:
	_build_world(-20.0, 10.0)
	await wait_frames(30)
	_input_a.tap_attack()
	await _wait_for_b_hit()
	await wait_frames(25)
	check_eq(_b.percent, MOVESET.ground_neutral.damage, "damage counted once")
	_teardown_world()


func test_an_attack_never_hits_its_own_fighter() -> void:
	_build_world(-20.0, 120.0)
	await wait_frames(30)
	_input_a.tap_attack()
	await wait_frames(40)
	check_eq(_a.percent, 0.0, "no self damage")
	check_eq(_b.percent, 0.0, "B was out of reach")
	check(_a.get_state_name() != &"Hitstun", "A was not stunned")
	_teardown_world()


func test_attacks_hit_to_the_left_when_facing_left() -> void:
	_build_world(10.0, -20.0, -1)
	await wait_frames(30)
	_input_a.tap_attack()
	var landed: bool = await _wait_for_b_hit()
	check(landed, "the jab connected")
	check(_b.velocity.x < 0.0, "B was launched to the left")
	_teardown_world()


func test_higher_percent_launches_harder() -> void:
	_build_world(-20.0, 10.0)
	await wait_frames(30)
	_input_a.tap_attack()
	await _wait_for_b_hit()
	var low_speed := _b.velocity.length()
	_teardown_world()

	_build_world(-20.0, 10.0)
	await wait_frames(30)
	_b.set_percent(150.0)
	_input_a.tap_attack()
	await _wait_for_b_hit()
	var move := MOVESET.ground_neutral
	var expected := Knockback.magnitude(
		move.base_knockback, move.knockback_growth, 150.0 + move.damage, CHARACTER_B.weight
	)
	check(_b.velocity.length() > low_speed + 20.0, "a damaged fighter flies farther")
	check_near(_b.velocity.length(), expected, 0.5, "matches the formula at 154 percent")
	_teardown_world()


func test_simultaneous_hits_trade() -> void:
	_build_world(-20.0, 10.0)
	await wait_frames(30)
	_input_a.tap_attack()
	_input_b.tap_attack()
	await wait_frames(30)
	check(_a.percent > 0.0, "A was hit")
	check(_b.percent > 0.0, "B was hit")
	_teardown_world()


func test_both_fighters_freeze_briefly_on_impact() -> void:
	_build_world(-20.0, 10.0)
	await wait_frames(30)
	_input_a.tap_attack()
	await _wait_for_b_hit()
	check(_a.hitlag_left > 0, "attacker is in hitlag")
	check(_b.hitlag_left > 0, "victim is in hitlag")
	var frozen_x := _b.position.x
	await wait_frames(1)
	check_eq(_b.position.x, frozen_x, "victim does not move during hitlag")
	await wait_frames(Knockback.MAX_HITLAG_FRAMES + 2)
	check(_b.position.x > frozen_x, "victim flies once the freeze ends")
	_teardown_world()


func test_hitstun_ends_and_the_fighter_recovers() -> void:
	_build_world(-20.0, 10.0)
	await wait_frames(30)
	_input_a.tap_attack()
	await _wait_for_b_hit()
	await wait_frames(120)
	check(_b.get_state_name() in [&"Idle", &"Run"], "B is back on its feet")
	_teardown_world()


func test_attack_button_picks_the_move_from_the_held_direction() -> void:
	_build_world(-90.0, 120.0)
	await wait_frames(30)
	_input_a.held_move = Vector2(1.0, 0.0)
	_input_a.tap_attack()
	await wait_frames(2)
	check_eq(_a.get_state_name(), &"Attack", "attacking")
	check(_a.hitbox.is_active == false, "still in startup, hitbox off")
	await wait_frames(MOVESET.ground_forward.startup_frames + 2)
	check(_a.hitbox.is_active, "hitbox on during the active frames")
	_teardown_world()


func test_air_attack_works_and_landing_ends_it() -> void:
	_build_world(-90.0, 120.0)
	await wait_frames(30)
	_input_a.tap_up()
	await wait_frames(8)
	_input_a.tap_attack()
	await wait_frames(2)
	check_eq(_a.get_state_name(), &"Attack", "air attack started")
	await wait_frames(160)
	check(_a.is_on_floor(), "landed")
	check_eq(_a.get_state_name(), &"Idle", "attack ended after landing")
	_teardown_world()


func test_a_hit_interrupts_the_victims_attack() -> void:
	_build_world(-20.0, 10.0)
	await wait_frames(30)
	_input_b.tap_attack()
	_input_a.tap_attack()
	await _wait_for_b_hit()
	check_eq(_b.get_state_name(), &"Hitstun", "B's attack was cut off")
	check(not _b.hitbox.is_active, "B's hitbox was switched off")
	_teardown_world()


func test_respawn_makes_a_fighter_invincible_for_a_while() -> void:
	_build_world(-20.0, 10.0)
	await wait_frames(30)
	_b.respawn_at(Vector2(10.0, 50.0))
	await wait_frames(30)
	_input_a.tap_attack()
	await wait_frames(30)
	check_eq(_b.percent, 0.0, "invincible fighters take no damage")
	await wait_frames(Fighter.RESPAWN_INVINCIBLE_FRAMES)
	check(_b.hurtbox.is_active, "invincibility wore off")
	_teardown_world()


func test_ko_hides_the_fighter_and_respawn_restores_it() -> void:
	_build_world(-20.0, 10.0)
	await wait_frames(30)
	_b.set_percent(120.0)
	_b.enter_ko()
	check(_b.is_ko(), "in the KO state")
	check(not _b.visible, "hidden")
	check(not _b.hurtbox.is_active, "cannot be hit")
	_b.respawn_at(_stage.get_respawn_position(2))
	check(_b.visible, "visible again")
	check_eq(_b.percent, 0.0, "percent reset on respawn")
	check_eq(_b.get_state_name(), &"Fall", "falls back into the stage")
	_teardown_world()


func test_percent_is_capped() -> void:
	_build_world(-20.0, 10.0)
	_b.set_percent(5000.0)
	check_eq(_b.percent, Fighter.MAX_PERCENT, "capped at 999")
	_b.set_percent(-5.0)
	check_eq(_b.percent, 0.0, "never negative")
	_teardown_world()
