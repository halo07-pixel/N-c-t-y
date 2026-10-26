extends TestCase

const MOVESET: MoveSet = preload("res://resources/movesets/default_moveset.tres")


func test_direction_kind_maps_input_to_four_directions() -> void:
	check_eq(MoveSet.direction_kind(Vector2.ZERO), &"neutral", "no direction")
	check_eq(MoveSet.direction_kind(Vector2(1.0, 0.0)), &"forward", "right")
	check_eq(MoveSet.direction_kind(Vector2(-1.0, 0.0)), &"forward", "left")
	check_eq(MoveSet.direction_kind(Vector2(0.0, -1.0)), &"up", "up")
	check_eq(MoveSet.direction_kind(Vector2(0.0, 1.0)), &"down", "down")
	check_eq(MoveSet.direction_kind(Vector2(1.0, -1.0)), &"up", "vertical wins over horizontal")
	check_eq(MoveSet.direction_kind(Vector2(0.3, 0.2)), &"neutral", "small stick is neutral")


func test_select_picks_ground_and_air_moves() -> void:
	check_eq(MOVESET.select(false, Vector2.ZERO), MOVESET.ground_neutral, "ground neutral")
	check_eq(MOVESET.select(false, Vector2(1.0, 0.0)), MOVESET.ground_forward, "ground forward")
	check_eq(MOVESET.select(false, Vector2(0.0, -1.0)), MOVESET.ground_up, "ground up")
	check_eq(MOVESET.select(false, Vector2(0.0, 1.0)), MOVESET.ground_down, "ground down")
	check_eq(MOVESET.select(true, Vector2.ZERO), MOVESET.air_neutral, "air neutral")
	check_eq(MOVESET.select(true, Vector2(-1.0, 0.0)), MOVESET.air_forward, "air forward")
	check_eq(MOVESET.select(true, Vector2(0.0, -1.0)), MOVESET.air_up, "air up")
	check_eq(MOVESET.select(true, Vector2(0.0, 1.0)), MOVESET.air_down, "air down")


func test_every_move_is_filled_in_and_sane() -> void:
	var moves := [
		MOVESET.ground_neutral, MOVESET.ground_forward, MOVESET.ground_up, MOVESET.ground_down,
		MOVESET.air_neutral, MOVESET.air_forward, MOVESET.air_up, MOVESET.air_down,
	]
	for move: MoveData in moves:
		check(move != null, "move exists")
		if move == null:
			continue
		check(move.damage > 0.0, "%s deals damage" % move.display_name)
		check(move.startup_frames > 0 and move.active_frames > 0, "%s has frames" % move.display_name)
		check(move.hitbox_size.x > 0.0 and move.hitbox_size.y > 0.0, "%s has a hitbox" % move.display_name)
		check_eq(move.total_frames(), move.startup_frames + move.active_frames + move.recovery_frames, "total frames")


func test_strong_moves_hit_harder_than_the_jab() -> void:
	check(MOVESET.ground_forward.damage > MOVESET.ground_neutral.damage, "forward beats jab")
	check(MOVESET.ground_forward.knockback_growth > MOVESET.ground_neutral.knockback_growth, "forward scales more")
	check(MOVESET.air_down.angle_degrees < 0.0, "the air down attack is a spike")
