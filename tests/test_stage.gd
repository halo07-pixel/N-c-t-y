extends TestCase

const STAGE_SCENE: PackedScene = preload("res://scenes/stages/test_stage.tscn")


func test_blast_zone_contains_the_center_and_rejects_far_points() -> void:
	var stage := STAGE_SCENE.instantiate() as Stage
	tree.root.add_child(stage)
	check(stage.is_inside_blast_zone(Vector2.ZERO), "origin is inside")
	check(not stage.is_inside_blast_zone(Vector2(2000.0, 0.0)), "far right is outside")
	check(not stage.is_inside_blast_zone(Vector2(0.0, -400.0)), "far above is outside")
	check(not stage.is_inside_blast_zone(Vector2(0.0, 400.0)), "far below is outside")
	stage.free()


func test_respawn_points_are_inside_the_stage_and_apart() -> void:
	var stage := STAGE_SCENE.instantiate() as Stage
	tree.root.add_child(stage)
	var first := stage.get_respawn_position(1)
	var second := stage.get_respawn_position(2)
	check(first.x < second.x, "player 1 respawns on the left")
	check(stage.is_inside_blast_zone(first) and stage.is_inside_blast_zone(second), "inside")
	check(first.y < stage.get_spawn_position(1).y, "respawn is above the spawn point")
	stage.free()


func test_both_players_have_distinct_spawn_points() -> void:
	var stage := STAGE_SCENE.instantiate() as Stage
	tree.root.add_child(stage)
	var first := stage.get_spawn_position(1)
	var second := stage.get_spawn_position(2)
	check(first != second, "spawn points differ")
	check(first.x < second.x, "player 1 spawns on the left")
	check(stage.is_inside_blast_zone(first), "spawn 1 is inside the blast zone")
	check(stage.is_inside_blast_zone(second), "spawn 2 is inside the blast zone")
	stage.free()
