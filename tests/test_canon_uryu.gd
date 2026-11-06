extends TestCase
## Uryu's kit follows the series: Heilig Pfeil, Seele Schneider, Reishi Platform, Reishi Mine.

const STAGE_SCENE: PackedScene = preload("res://scenes/stages/test_stage.tscn")
const FIGHTER_SCENE: PackedScene = preload("res://scenes/fighter/fighter.tscn")
const URYU: CharacterData = preload("res://resources/characters/archer.tres")


func test_canon_names() -> void:
	var kit := URYU.specials
	check_eq(kit.neutral.display_name, "Heilig Pfeil", "the Quincy arrow")
	check_eq(kit.forward.display_name, "Seele Schneider", "blades planted in the floor")
	check_eq(kit.up.display_name, "Reishi Platform", "a platform of reishi")
	check_eq(kit.down.display_name, "Reishi Mine", "a trap of reishi")


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
	input.tap_special()
	await wait_frames(4)
	check(fighter.gathering, "motes gather during the wind-up")
	await wait_frames(URYU.specials.neutral.startup_frames + 4)
	check(not fighter.gathering, "and stop once the arrow is loosed")
	fighter.free()
	stage.free()
