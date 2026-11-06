extends TestCase
## The streak of a swing and the weight of a hit: pure visuals that follow the hitbox, never change it.

const STAGE_SCENE: PackedScene = preload("res://scenes/stages/test_stage.tscn")
const FIGHTER_SCENE: PackedScene = preload("res://scenes/fighter/fighter.tscn")

var _swings: Array = []


func _on_swing(attacker: int, center: Vector2, size: Vector2, facing: int) -> void:
	_swings.append([attacker, center, size, facing])


func test_the_arc_sweeps_forward_and_mirrors_with_the_facing() -> void:
	var size := Vector2(40.0, 16.0)
	var right := SwingTrail.arc_points(size, 1, 1.0)
	var left := SwingTrail.arc_points(size, -1, 1.0)
	check_eq(right.size(), SwingTrail.ARC_STEPS + 1, "a smooth arc")
	for i in right.size():
		check_near(right[i].x, -left[i].x, 0.001, "mirrored (point %d)" % i)
		check_near(right[i].y, left[i].y, 0.001, "same height")
	check(right[right.size() - 1].x > right[0].x, "it sweeps forward")
	var early := SwingTrail.arc_points(size, 1, 0.2)
	check(early[early.size() - 1].x < right[right.size() - 1].x, "and grows as it goes")


func test_a_lash_reaches_further_than_a_slash() -> void:
	check(SwingTrail.stretch_for(&"lash") > SwingTrail.stretch_for(&"slash"), "the whip trails long")
	var long_arc := SwingTrail.arc_points(Vector2(40.0, 16.0), 1, 1.0, SwingTrail.stretch_for(&"lash"))
	var short_arc := SwingTrail.arc_points(Vector2(40.0, 16.0), 1, 1.0, SwingTrail.stretch_for(&"slash"))
	check(long_arc[long_arc.size() - 1].x > short_arc[short_arc.size() - 1].x, "in the points too")


func test_every_style_draws_and_frees_itself() -> void:
	for style: StringName in [&"slash", &"shards", &"petals", &"lash", &"frost", &"quake", &"ink"]:
		var trail := SwingTrail.new()
		trail.style = style
		tree.root.add_child(trail)
		await wait_frames(4)
		check(is_instance_valid(trail), "%s draws" % style)
		await wait_frames(20)
		check(not is_instance_valid(trail), "%s frees itself" % style)


func test_a_hitbox_announces_its_swing_only_when_it_has_a_box() -> void:
	_swings.clear()
	Events.attack_swing.connect(_on_swing)
	var stage := STAGE_SCENE.instantiate() as Stage
	tree.root.add_child(stage)
	var fighter := FIGHTER_SCENE.instantiate() as Fighter
	fighter.player_id = 1
	fighter.data = load("res://resources/characters/swordsman.tres") as CharacterData
	fighter.position = Vector2(-60.0, 50.0)
	tree.root.add_child(fighter)
	var input := ScriptedInput.new()
	fighter.set_input_source(input)
	await wait_frames(20)
	input.tap_attack()
	await wait_frames(12)
	check(_swings.size() >= 1, "a swing was announced")
	if not _swings.is_empty():
		check_eq(_swings[0][0], 1, "by the fighter that swung")
		check(_swings[0][1].x > -60.0, "in front of it")
		check(_swings[0][2].x > 0.0, "with the size of the hitbox")
	var empty := MoveData.new()
	empty.hitbox_size = Vector2.ZERO
	var before := _swings.size()
	fighter.hitbox.activate(empty, 1)
	check_eq(_swings.size(), before, "a move without a box leaves no streak")
	Events.attack_swing.disconnect(_on_swing)
	fighter.free()
	stage.free()


func test_swings_spawn_a_trail_only_when_effects_are_on() -> void:
	var before := GameSettings.screen_effects
	var fx := CombatFx.new()
	tree.root.add_child(fx)
	GameSettings.screen_effects = true
	Events.attack_swing.emit(1, Vector2.ZERO, Vector2(30.0, 16.0), 1)
	check_eq(fx.get_child_count(), 1, "a streak appears")
	GameSettings.screen_effects = false
	Events.attack_swing.emit(1, Vector2.ZERO, Vector2(30.0, 16.0), 1)
	check_eq(fx.get_child_count(), 1, "nothing with effects off")
	fx.queue_free()
	GameSettings.screen_effects = before


func test_heavy_characters_shake_the_screen_on_solid_hits_and_light_ones_do_not() -> void:
	var brute := (load("res://resources/characters/brute.tres") as CharacterData).fx_profile
	var archer := (load("res://resources/characters/archer.tres") as CharacterData).fx_profile
	check(CombatFx.hit_shake(13.0, brute.spark_scale) > 1.0, "Kenpachi's cleave shakes")
	check_eq(CombatFx.hit_shake(13.0, archer.spark_scale), 0.0, "Uryu's hit does not")
	check(CombatFx.hit_shake(13.0, brute.spark_scale) > CombatFx.hit_shake(5.0, brute.spark_scale), "and harder hits shake more")
