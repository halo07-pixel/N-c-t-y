extends TestCase
## Physics-level checks: real stage, real fighter, scripted input.

const STAGE_SCENE: PackedScene = preload("res://scenes/stages/test_stage.tscn")
const FIGHTER_SCENE: PackedScene = preload("res://scenes/fighter/fighter.tscn")
const CHARACTER: CharacterData = preload("res://resources/characters/placeholder_a.tres")

const MAIN_FLOOR_Y := 60.0
const LEFT_SOFT_PLATFORM_Y := 18.0

var _stage: Stage
var _fighter: Fighter
var _input: ScriptedInput


func _build_world(spawn: Vector2) -> void:
	_stage = STAGE_SCENE.instantiate() as Stage
	tree.root.add_child(_stage)
	_fighter = FIGHTER_SCENE.instantiate() as Fighter
	_fighter.data = CHARACTER
	_fighter.position = spawn
	tree.root.add_child(_fighter)
	_input = ScriptedInput.new()
	_fighter.set_input_source(_input)


func _teardown_world() -> void:
	_fighter.free()
	_stage.free()


func test_fighter_falls_onto_the_floor_and_idles() -> void:
	_build_world(Vector2(-70.0, 40.0))
	await wait_frames(40)
	check(_fighter.is_on_floor(), "standing on the floor")
	check_eq(_fighter.get_state_name(), &"Idle", "state is Idle")
	check_near(_fighter.position.y, MAIN_FLOOR_Y, 1.0, "feet rest on the main platform")
	_teardown_world()


func test_holding_right_runs_and_releasing_stops() -> void:
	_build_world(Vector2(-70.0, 40.0))
	await wait_frames(30)
	var start_x := _fighter.position.x
	_input.held_move = Vector2(1.0, 0.0)
	await wait_frames(30)
	check(_fighter.position.x > start_x + 30.0, "moved right")
	check_eq(_fighter.get_state_name(), &"Run", "state is Run")
	check_eq(_fighter.facing, 1, "faces right")
	_input.held_move = Vector2.ZERO
	await wait_frames(30)
	check_eq(_fighter.get_state_name(), &"Idle", "back to Idle")
	check_near(_fighter.velocity.x, 0.0, 0.01, "stopped")
	_teardown_world()


func test_facing_follows_the_direction_pressed() -> void:
	_build_world(Vector2(0.0, 40.0))
	await wait_frames(30)
	_input.held_move = Vector2(-1.0, 0.0)
	await wait_frames(5)
	check_eq(_fighter.facing, -1, "faces left")
	_teardown_world()


func test_jump_rises_then_lands_and_refills_the_air_jump() -> void:
	_build_world(Vector2(-70.0, 40.0))
	await wait_frames(30)
	_input.tap_up()
	await wait_frames(6)
	check(_fighter.position.y < MAIN_FLOOR_Y - 5.0, "left the ground")
	check_eq(_fighter.get_state_name(), &"Jump", "state is Jump while rising")
	await wait_frames(120)
	check(_fighter.is_on_floor(), "landed")
	check_eq(_fighter.get_state_name(), &"Idle", "state is Idle after landing")
	check_eq(_fighter.air_jumps_left, CHARACTER.max_air_jumps, "air jump refilled on landing")
	_teardown_world()


func test_single_jump_height_matches_the_physics() -> void:
	_build_world(Vector2(-70.0, 40.0))
	await wait_frames(30)
	var lowest_y := _fighter.position.y
	_input.tap_up()
	for _i in 60:
		await tree.physics_frame
		lowest_y = minf(lowest_y, _fighter.position.y)
	var expected := (CHARACTER.jump_velocity * CHARACTER.jump_velocity) / (2.0 * CHARACTER.gravity)
	check_near(MAIN_FLOOR_Y - lowest_y, expected, 6.0, "apex height")
	_teardown_world()


func test_only_one_air_jump_is_allowed() -> void:
	_build_world(Vector2(-70.0, 40.0))
	await wait_frames(30)
	_input.tap_up()
	await wait_frames(10)
	_input.tap_up()
	await wait_frames(2)
	check_eq(_fighter.air_jumps_left, 0, "air jump used")
	check(_fighter.velocity.y < 0.0, "rising again after the air jump")
	await wait_frames(30)
	var speed_before := _fighter.velocity.y
	_input.tap_up()
	await wait_frames(1)
	check(_fighter.velocity.y >= speed_before, "a third jump press does nothing")
	_teardown_world()


func test_down_while_falling_triggers_a_fast_fall() -> void:
	_build_world(Vector2(135.0, -150.0))
	await wait_frames(10)
	_input.tap_down()
	await wait_frames(30)
	check(_fighter.is_fast_falling, "fast fall is latched")
	check(_fighter.velocity.y > CHARACTER.max_fall_speed + 20.0, "falls faster than normal")
	await wait_frames(120)
	check(_fighter.is_on_floor(), "lands eventually")
	check(not _fighter.is_fast_falling, "fast fall resets on landing")
	_teardown_world()


func test_down_drops_through_a_soft_platform() -> void:
	_build_world(Vector2(-90.0, 10.0))
	await wait_frames(30)
	check(_fighter.is_on_floor(), "standing on the soft platform")
	check_near(_fighter.position.y, LEFT_SOFT_PLATFORM_Y, 1.5, "feet on the soft platform")
	_input.tap_down()
	await wait_frames(25)
	check(_fighter.position.y > LEFT_SOFT_PLATFORM_Y + 10.0, "passed below the platform")
	await wait_frames(90)
	check(_fighter.is_on_floor(), "landed on the main platform")
	check_near(_fighter.position.y, MAIN_FLOOR_Y, 1.0, "feet on the main platform")
	check_eq(_fighter.get_state_name(), &"Idle", "idle again")
	_teardown_world()


func test_soft_platform_blocks_from_above_and_lets_through_from_below() -> void:
	_build_world(Vector2(-90.0, 60.0))
	await wait_frames(20)
	_input.tap_up()
	await wait_frames(40)
	check_near(_fighter.position.y, LEFT_SOFT_PLATFORM_Y, 1.5, "jumped up onto the platform")
	_teardown_world()


func test_down_does_nothing_on_the_main_platform() -> void:
	_build_world(Vector2(-70.0, 40.0))
	await wait_frames(30)
	_input.tap_down()
	await wait_frames(30)
	check_near(_fighter.position.y, MAIN_FLOOR_Y, 1.0, "still on the main platform")
	check_eq(_fighter.get_state_name(), &"Idle", "still Idle")
	_teardown_world()


func test_respawn_resets_motion_and_position() -> void:
	_build_world(Vector2(0.0, 40.0))
	await wait_frames(30)
	_fighter.velocity = Vector2(300.0, -300.0)
	_fighter.respawn_at(_stage.get_spawn_position(1))
	check_eq(_fighter.velocity, Vector2.ZERO, "velocity cleared")
	check_eq(_fighter.global_position, _stage.get_spawn_position(1), "moved to the spawn")
	check_eq(_fighter.air_jumps_left, CHARACTER.max_air_jumps, "jumps refilled")
	_teardown_world()
