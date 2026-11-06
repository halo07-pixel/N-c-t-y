extends TestCase
## Ichigo and Uryu each have skills no one else has: a cross-shaped Getsuga and a counter stance,
## thrown blades that can be called home, and a held stream of arrows.

const STAGE_SCENE: PackedScene = preload("res://scenes/stages/test_stage.tscn")
const FIGHTER_SCENE: PackedScene = preload("res://scenes/fighter/fighter.tscn")
const ICHIGO: CharacterData = preload("res://resources/characters/swordsman.tres")
const URYU: CharacterData = preload("res://resources/characters/archer.tres")


func _sets(character: CharacterData) -> Array:
	return [character.specials, character.bankai_specials]


func test_ichigo_has_a_cross_getsuga_and_a_counter_stance() -> void:
	for set: SpecialSet in _sets(ICHIGO):
		var cross := set.neutral.follow_up
		check(cross != null and cross.projectiles.size() == 2, "Jūjishō fires two waves")
		check(cross.projectiles[0].size.x > cross.projectiles[0].size.y, "one lies flat")
		check(cross.projectiles[1].size.y > cross.projectiles[1].size.x, "one stands tall")
		check(set.down.counter_move != null and set.down.counter_move.damage > 0.0, "Tensa answers a hit")
		check(set.down.damage == 0.0, "the stance itself deals nothing")


func test_uryu_has_planted_blades_and_a_stream() -> void:
	for set: SpecialSet in _sets(URYU):
		var planted := set.forward
		check_eq(planted.projectiles.size(), 3, "three Seele Schneider")
		for blade: ProjectileData in planted.projectiles:
			check(blade.commandable and blade.velocity == Vector2.ZERO, "a blade stays where it was planted")
		check(planted.follow_up != null and planted.follow_up.command_recall, "the second press calls them home")
		var stream := set.neutral.follow_up
		check(stream != null and stream.is_stream() and stream.stream_max_shots > 1, "Ginrei Kojaku can be held")


var _shots: Array[Projectile] = []


func _on_shot(projectile: Projectile) -> void:
	_shots.append(projectile)
	tree.root.add_child(projectile)


func _live() -> Array[Projectile]:
	var live: Array[Projectile] = []
	for shot in _shots:
		if is_instance_valid(shot) and not shot.is_queued_for_deletion():
			live.append(shot)
	return live


func _stage_with(character: CharacterData) -> Array:
	var stage := STAGE_SCENE.instantiate() as Stage
	tree.root.add_child(stage)
	var fighter := FIGHTER_SCENE.instantiate() as Fighter
	fighter.player_id = 1
	fighter.data = character
	fighter.position = Vector2(0.0, 50.0)
	tree.root.add_child(fighter)
	var input := ScriptedInput.new()
	fighter.set_input_source(input)
	_shots.clear()
	fighter.projectile_spawned.connect(_on_shot)
	return [stage, fighter, input]


func _arrows(_owner_id: int) -> int:
	return _live().size()


func test_holding_special_keeps_the_stream_going() -> void:
	var rig := _stage_with(URYU)
	var fighter: Fighter = rig[1]
	var input: ScriptedInput = rig[2]
	fighter.reiatsu = 100.0
	await wait_frames(30)
	input.tap_special()
	await wait_frames(14)
	input.tap_special()
	input.held_special = true
	await wait_frames(60)
	var held := _arrows(1)
	input.held_special = false
	check(held >= 4, "holding fires several arrows (%d)" % held)
	await wait_frames(120)
	fighter.free()
	rig[0].free()


func test_tapping_the_follow_up_fires_only_one_arrow() -> void:
	var rig := _stage_with(URYU)
	var fighter: Fighter = rig[1]
	var input: ScriptedInput = rig[2]
	fighter.reiatsu = 100.0
	await wait_frames(30)
	input.tap_special()
	await wait_frames(14)
	input.tap_special()
	await wait_frames(30)
	check(_arrows(1) <= 3, "a tap is not a stream (%d)" % _arrows(1))
	fighter.free()
	rig[0].free()


func test_blades_wait_in_the_air_and_come_home() -> void:
	var rig := _stage_with(URYU)
	var fighter: Fighter = rig[1]
	var input: ScriptedInput = rig[2]
	await wait_frames(30)
	input.held_move = Vector2.RIGHT
	input.tap_special()
	await wait_frames(14)
	input.held_move = Vector2.ZERO
	var before: Array[float] = []
	for shot in _live():
		before.append(shot.global_position.x)
	check_eq(before.size(), 3, "three blades planted")
	await wait_frames(4)
	var still := true
	var i := 0
	for shot in _live():
		still = still and absf(shot.global_position.x - before[i]) < 1.0
		i += 1
	check(still, "they do not move on their own")
	input.tap_special()
	await wait_frames(24)
	var moved := false
	for shot in _live():
		moved = moved or absf(shot.global_position.x - fighter.global_position.x) < absf(before[0] - fighter.global_position.x)
	check(moved, "the blades fly back toward Uryu")
	fighter.free()
	rig[0].free()
