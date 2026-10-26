extends TestCase


func test_knockback_at_zero_percent_is_the_base_value() -> void:
	check_near(Knockback.magnitude(200.0, 150.0, 0.0, 100.0), 200.0, 0.001, "base only")


func test_knockback_grows_with_percent() -> void:
	check_near(Knockback.magnitude(200.0, 150.0, 100.0, 100.0), 350.0, 0.001, "100 percent")
	check(
		Knockback.magnitude(200.0, 150.0, 200.0, 100.0)
		> Knockback.magnitude(200.0, 150.0, 100.0, 100.0),
		"200 percent flies farther than 100"
	)


func test_heavier_fighters_are_launched_less() -> void:
	var light := Knockback.magnitude(200.0, 150.0, 50.0, 80.0)
	var normal := Knockback.magnitude(200.0, 150.0, 50.0, 100.0)
	var heavy := Knockback.magnitude(200.0, 150.0, 50.0, 140.0)
	check(light > normal and normal > heavy, "lighter flies farther")
	check_near(Knockback.magnitude(200.0, 150.0, 0.0, 200.0), 100.0, 0.001, "double weight halves it")


func test_hitstun_scales_with_launch_speed_and_has_a_floor() -> void:
	check_eq(Knockback.hitstun_frames(240.0), 20, "240 speed")
	check_eq(Knockback.hitstun_frames(600.0), 50, "600 speed")
	check_eq(Knockback.hitstun_frames(12.0), Knockback.MIN_HITSTUN_FRAMES, "tiny hits still stun")


func test_hitlag_scales_with_damage_within_limits() -> void:
	check_eq(Knockback.hitlag_frames(0.0), Knockback.MIN_HITLAG_FRAMES, "no damage")
	check_eq(Knockback.hitlag_frames(4.0), 4, "jab")
	check_eq(Knockback.hitlag_frames(100.0), Knockback.MAX_HITLAG_FRAMES, "capped")


func test_launch_direction_follows_angle_and_facing() -> void:
	var right := Knockback.direction(0.0, 1)
	check_near(right.x, 1.0, 0.001, "angle 0 facing right goes right")
	check_near(right.y, 0.0, 0.001, "angle 0 is level")
	var up := Knockback.direction(90.0, 1)
	check_near(up.y, -1.0, 0.001, "angle 90 goes up")
	var left_up := Knockback.direction(45.0, -1)
	check(left_up.x < 0.0 and left_up.y < 0.0, "facing left mirrors the angle")
	var spike := Knockback.direction(-70.0, 1)
	check(spike.y > 0.5, "negative angle points downward")
	check_near(Knockback.direction(38.0, 1).length(), 1.0, 0.001, "always a unit vector")
