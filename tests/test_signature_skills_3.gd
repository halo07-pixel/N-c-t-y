extends TestCase
## Rukia builds terrain (a wall of ice, a snow veil that slows); Kenpachi trades defence for power.

const STAGE_SCENE: PackedScene = preload("res://scenes/stages/test_stage.tscn")
const FIGHTER_SCENE: PackedScene = preload("res://scenes/fighter/fighter.tscn")
const RUKIA: CharacterData = preload("res://resources/characters/ice.tres")
const KENPACHI: CharacterData = preload("res://resources/characters/brute.tres")
const BYAKUYA: CharacterData = preload("res://resources/characters/noble.tres")


func test_kit_data() -> void:
	for set: SpecialSet in [RUKIA.specials, RUKIA.bankai_specials]:
		var wall := set.forward.follow_up.projectiles[0]
		check(wall.solid and wall.absorbs and wall.velocity == Vector2.ZERO, "a standing wall that eats shots")
		var veil := set.up.follow_up.projectiles[0]
		check(veil.slow_scale < 1.0 and veil.size.x >= 100.0, "a wide veil that slows")
	for set: SpecialSet in [KENPACHI.specials, KENPACHI.bankai_specials]:
		var release := set.down.follow_up
		check(release.release_frames > 0 and release.release_dealt > 1.0 and release.release_taken > 1.0, "power for risk")
		check(set.forward.follow_up.armor, "the rush is armoured")


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
	for old in _shots:
		if is_instance_valid(old):
			old.free()
	_shots.clear()
	a.projectile_spawned.connect(_on_shot)
	return [stage, a, b, input_a, input_b]


func _free(rig: Array) -> void:
	for n in [rig[1], rig[2], rig[0]]:
		n.free()


func test_the_ice_wall_stops_a_walker() -> void:
	var rig := _duel(RUKIA, BYAKUYA, 140.0)
	var a: Fighter = rig[1]
	var b: Fighter = rig[2]
	var input_a: ScriptedInput = rig[3]
	var input_b: ScriptedInput = rig[4]
	a.reiatsu = 100.0
	await wait_frames(30)
	input_a.held_move = Vector2.RIGHT
	input_a.tap_special() # Snow Step
	await wait_frames(8)
	input_a.held_move = Vector2.ZERO
	input_a.tap_special() # the wall
	await wait_frames(40)
	var wall_x := NAN
	for shot in _shots:
		if is_instance_valid(shot) and shot.get_child_count() > 0:
			wall_x = shot.global_position.x
	check(not is_nan(wall_x), "a wall stands")
	b.global_position = Vector2(wall_x + 60.0, 50.0)
	input_b.held_move = Vector2.LEFT
	await wait_frames(60)
	check(b.global_position.x > wall_x, "the walker could not pass (%.0f vs %.0f)" % [b.global_position.x, wall_x])
	_free(rig)


func test_the_snow_veil_slows_enemies_but_not_its_owner() -> void:
	var rig := _duel(RUKIA, BYAKUYA, 56.0)
	var a: Fighter = rig[1]
	var b: Fighter = rig[2]
	var input_b: ScriptedInput = rig[4]
	await wait_frames(30)
	input_b.held_move = Vector2.LEFT
	var start := b.global_position.x
	await wait_frames(15)
	var free_run := start - b.global_position.x
	input_b.held_move = Vector2.ZERO
	await wait_frames(30)
	b.global_position = Vector2(start, a.global_position.y)
	b.velocity = Vector2.ZERO
	var veil := RUKIA.specials.up.follow_up
	a.spawn_projectile(veil.projectiles[0], veil, 0.0)
	await wait_frames(2)
	check(b.slowed_frames > 0, "the enemy in the veil is slowed")
	check_eq(a.slowed_frames, 0, "its owner is not")
	input_b.held_move = Vector2.LEFT
	await wait_frames(15)
	var veil_run := start - b.global_position.x
	check(veil_run < free_run * 0.9, "the enemy covers less ground (%.0f vs %.0f)" % [veil_run, free_run])
	_free(rig)


func test_the_release_trades_defence_for_power() -> void:
	var rig := _duel(KENPACHI, BYAKUYA, 200.0)
	var a: Fighter = rig[1]
	check_eq(a.outgoing_multiplier(), 1.0, "normal damage before")
	a.begin_release(KENPACHI.specials.down.follow_up)
	check(a.outgoing_multiplier() > 1.2, "hits harder")
	check(a.release_taken > 1.0, "and is hurt more")
	await wait_frames(a.release_frames + 5)
	check_eq(a.outgoing_multiplier(), 1.0, "back to normal after")
	_free(rig)


func test_the_release_makes_him_faster() -> void:
	var rig := _duel(KENPACHI, BYAKUYA, 200.0)
	var a: Fighter = rig[1]
	var input_a: ScriptedInput = rig[3]
	await wait_frames(30)
	input_a.held_move = Vector2.RIGHT
	var start := a.global_position.x
	await wait_frames(30)
	var plain := a.global_position.x - start
	input_a.held_move = Vector2.ZERO
	await wait_frames(30)
	a.begin_release(KENPACHI.specials.down.follow_up)
	var from := a.global_position.x
	input_a.held_move = Vector2.RIGHT
	await wait_frames(30)
	var released := a.global_position.x - from
	check(released > plain * 1.05, "faster in a release (%.0f vs %.0f)" % [released, plain])
	_free(rig)
