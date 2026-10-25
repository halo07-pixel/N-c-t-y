extends TestCase

const VIEW := Vector2(480.0, 270.0)
const MARGIN := Vector2(90.0, 60.0)


func test_empty_target_list_falls_back_to_minimum_zoom() -> void:
	var framing := FightCamera.compute_framing(PackedVector2Array(), VIEW, MARGIN, 0.6, 1.4)
	check_eq(framing["center"], Vector2.ZERO, "centered on the origin")
	check_near(framing["zoom"], 0.6, 0.0001, "minimum zoom")


func test_center_is_midpoint_between_two_fighters() -> void:
	var points := PackedVector2Array([Vector2(-100.0, 0.0), Vector2(60.0, 40.0)])
	var framing := FightCamera.compute_framing(points, VIEW, MARGIN, 0.6, 1.4)
	check_eq(framing["center"], Vector2(-20.0, 20.0), "midpoint")


func test_zoom_shrinks_as_fighters_move_apart() -> void:
	var near_points := PackedVector2Array([Vector2(-20.0, 0.0), Vector2(20.0, 0.0)])
	var far_points := PackedVector2Array([Vector2(-250.0, 0.0), Vector2(250.0, 0.0)])
	var near_framing := FightCamera.compute_framing(near_points, VIEW, MARGIN, 0.6, 1.4)
	var far_framing := FightCamera.compute_framing(far_points, VIEW, MARGIN, 0.6, 1.4)
	check(far_framing["zoom"] < near_framing["zoom"], "far apart is more zoomed out")


func test_zoom_never_leaves_its_limits() -> void:
	var very_far := PackedVector2Array([Vector2(-2000.0, 0.0), Vector2(2000.0, 0.0)])
	var identical := PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
	check_near(
		FightCamera.compute_framing(very_far, VIEW, MARGIN, 0.6, 1.4)["zoom"], 0.6, 0.0001,
		"clamped to the minimum"
	)
	check_near(
		FightCamera.compute_framing(identical, VIEW, MARGIN, 0.6, 1.4)["zoom"], 1.4, 0.0001,
		"clamped to the maximum"
	)


func test_center_is_pulled_inside_the_bounds() -> void:
	var bounds := Rect2(-420.0, -300.0, 840.0, 600.0)
	var clamped := FightCamera.clamp_center(Vector2(1000.0, -1000.0), 1.0, VIEW, bounds)
	check_near(clamped.x, 420.0 - 240.0, 0.0001, "right edge limits the center")
	check_near(clamped.y, -300.0 + 135.0, 0.0001, "top edge limits the center")


func test_view_larger_than_bounds_centers_on_the_bounds() -> void:
	var small_bounds := Rect2(-100.0, -50.0, 200.0, 100.0)
	var clamped := FightCamera.clamp_center(Vector2(300.0, 300.0), 1.0, VIEW, small_bounds)
	check_eq(clamped, Vector2.ZERO, "centered when the bounds are smaller than the view")
