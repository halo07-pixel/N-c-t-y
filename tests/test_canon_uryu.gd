extends TestCase
## Uryu's kit follows the series: Heilig Pfeil, Path Control, Hirenkyaku, Negation of Attacks, Licht Regen.

const STAGE_SCENE: PackedScene = preload("res://scenes/stages/test_stage.tscn")
const FIGHTER_SCENE: PackedScene = preload("res://scenes/fighter/fighter.tscn")
const URYU: CharacterData = preload("res://resources/characters/archer.tres")


func test_canon_names() -> void:
	var kit := URYU.specials
	check_eq(kit.neutral.display_name, "Heilig Pfeil", "the Quincy arrow")
	check_eq(kit.forward.display_name, "Path Control", "curving volley of three")
	check_eq(kit.alt_neutral.display_name, "Negation Arrow", "an arrow that cancels attacks")
	check_eq(kit.alt_forward.display_name, "Hirenkyaku Shot", "fast movement")
	check_eq(kit.alt_up.display_name, "Licht Regen", "light rain from above")


func test_negation_arrow_cancels_projectiles() -> void:
	check(URYU.specials.alt_neutral.projectiles[0].absorbs, "it destroys the shots it meets")
	check(URYU.specials.alt_neutral.projectiles[0].pierce, "and keeps flying")


func test_licht_regen_falls_on_one_spot() -> void:
	var rain := URYU.specials.alt_up
	check(rain.projectiles.size() >= 5, "a volley of arrows")
	var column := rain.projectiles[0].offset.x
	for arrow: ProjectileData in rain.projectiles:
		check_near(arrow.offset.x, column, 0.01, "all aimed at the same spot")
		check(arrow.velocity.x == 0.0 and arrow.velocity.y > 0.0, "straight down from above")
	check(rain.gather, "reishi is gathered first")
	check(rain.startup_frames >= 12, "the wind-up is readable")


func test_the_negation_arrow_destroys_an_enemy_shot() -> void:
	var absorber := Projectile.new()
	absorber.launch(URYU.specials.alt_neutral.projectiles[0], URYU.specials.alt_neutral, 1, 1, 1.0, Vector2(0.0, -40.0))
	tree.root.add_child(absorber)
	var enemy := Projectile.new()
	enemy.launch(URYU.specials.neutral.projectiles[0], URYU.specials.neutral, 2, -1, 1.0, Vector2(34.0, -38.0))
	tree.root.add_child(enemy)
	await wait_frames(3)
	check(not is_instance_valid(enemy) or enemy.is_queued_for_deletion(), "the enemy shot is gone")
	if is_instance_valid(absorber):
		absorber.free()
	if is_instance_valid(enemy):
		enemy.free()


func test_reishi_gathers_during_the_wind_up_only() -> void:
	var stage := STAGE_SCENE.instantiate() as Stage
	tree.root.add_child(stage)
	var fighter := FIGHTER_SCENE.instantiate() as Fighter
	fighter.player_id = 1
	fighter.data = URYU
	fighter.position = Vector2(0.0, 50.0)
	tree.root.add_child(fighter)
	var input := ScriptedInput.new()
	fighter.set_input_source(input)
	await wait_frames(30)
	input.held_move = Vector2(0.0, -1.0)
	input.tap_special2()
	await wait_frames(6)
	check(fighter.gathering, "motes gather during the wind-up")
	await wait_frames(URYU.specials.alt_up.startup_frames + 4)
	check(not fighter.gathering, "and stop once the arrows are loosed")
	fighter.free()
	stage.free()
