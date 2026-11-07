extends TestCase
## Polish: a wall of ice that breaks, a snow veil that slows attacks too, and Renji's pull-then-slam.

const STAGE_SCENE: PackedScene = preload("res://scenes/stages/test_stage.tscn")
const FIGHTER_SCENE: PackedScene = preload("res://scenes/fighter/fighter.tscn")
const RUKIA: CharacterData = preload("res://resources/characters/ice.tres")
const RENJI: CharacterData = preload("res://resources/characters/lieutenant.tres")
const BYAKUYA: CharacterData = preload("res://resources/characters/noble.tres")

var _shots: Array[Projectile] = []


func _on_shot(projectile: Projectile) -> void:
	_shots.append(projectile)
	tree.root.add_child(projectile)


func _duel(character: CharacterData, other: CharacterData, gap: float) -> Array:
	var stage := STAGE_SCENE.instantiate() as Stage
	tree.root.add_child(stage)
	var a := FIGHTER_SCENE.instantiate() as Fighter
	a.player_id = 1
	a.data = character
	a.position = Vector2(0.0, 50.0)
	tree.root.add_child(a)
	var b := FIGHTER_SCENE.instantiate() as Fighter
	b.player_id = 2
	b.data = other
	b.position = Vector2(gap, 50.0)
	b.facing = -1
	tree.root.add_child(b)
	var input_a := ScriptedInput.new()
	a.set_input_source(input_a)
	var input_b := ScriptedInput.new()
	b.set_input_source(input_b)
	_shots.clear()
	a.projectile_spawned.connect(_on_shot)
	return [stage, a, b, input_a, input_b]


func _free(rig: Array) -> void:
	for n in [rig[1], rig[2], rig[0]]:
		n.free()


func test_the_wall_has_health_and_breaks() -> void:
	for set: SpecialSet in [RUKIA.specials, RUKIA.bankai_specials]:
		check(set.forward.follow_up.projectiles[0].wall_health > 0.0, "the ice wall can break")
	var rig := _duel(RUKIA, BYAKUYA, 200.0)
	var a: Fighter = rig[1]
	await wait_frames(20)
	var wall := RUKIA.specials.forward.follow_up
	a.spawn_projectile(wall.projectiles[0], wall, 0.0)
	await wait_frames(2)
	var shot := _shots[0]
	check(is_instance_valid(shot), "the wall stands")
	shot._wear(RUKIA.specials.forward.follow_up.projectiles[0].wall_health + 1.0)
	await wait_frames(3)
	check(not is_instance_valid(shot) or shot.is_queued_for_deletion(), "it breaks when worn out")
	_free(rig)


func test_a_swing_wears_the_wall_once() -> void:
	var rig := _duel(RUKIA, RENJI, 90.0)
	var a: Fighter = rig[1]
	var b: Fighter = rig[2]
	await wait_frames(20)
	var wall := RUKIA.specials.forward.follow_up
	a.spawn_projectile(wall.projectiles[0], wall, 0.0)
	await wait_frames(2)
	var shot := _shots[0]
	var before: float = shot._wall_health
	shot.global_position = b.global_position + Vector2(-20.0, -16.0)
	b.hitbox.activate(RENJI.moveset.ground_neutral, -1)
	await wait_frames(3)
	var after: float = shot._wall_health
	check(after < before, "a swing that reaches the wall wears it (%.1f -> %.1f)" % [before, after])
	await wait_frames(3)
	check_near(shot._wall_health, after, 0.01, "the same swing does not wear it twice")
	_free(rig)


func test_a_slowed_fighter_attacks_more_slowly() -> void:
	var rig := _duel(RUKIA, BYAKUYA, 200.0)
	var a: Fighter = rig[1]
	var b: Fighter = rig[2]
	var skipped := 0
	b.slow_down(0.5)
	for i in 30:
		b.slowed_frames = 3
		if b.slow_skips_frame():
			skipped += 1
	check(skipped >= 12 and skipped <= 18, "about half the frames are held back (%d/30)" % skipped)
	b.slowed_frames = 0
	check(not b.slow_skips_frame(), "no slowing once the veil is gone")
	check(a != null, "ok")
	_free(rig)


func test_renji_pull_leads_into_a_slam() -> void:
	for set: SpecialSet in [RENJI.specials, RENJI.bankai_specials]:
		var pull := set.neutral.follow_up
		check(pull.follow_up != null, "the pull has a slam after it")
		check(pull.follow_up.angle_degrees < 0.0 and pull.follow_up.hitbox_size.x > 0.0, "a downward melee strike")
	var pages := MoveListOverlay.pages_for(RENJI, 1)
	var found := false
	for entry: Dictionary in pages[0]:
		found = found or str(entry.get("name", "")).begins_with("Zabimaru Slam")
	check(found, "F3 lists the third press")
