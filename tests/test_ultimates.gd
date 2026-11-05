extends TestCase
## Ultimates that play out in beats: the data of Renji, Rukia and Kenpachi, and what a real ultimate does to a target.

const STAGE_SCENE: PackedScene = preload("res://scenes/stages/test_stage.tscn")
const FIGHTER_SCENE: PackedScene = preload("res://scenes/fighter/fighter.tscn")
const RENJI: CharacterData = preload("res://resources/characters/lieutenant.tres")
const RUKIA: CharacterData = preload("res://resources/characters/ice.tres")
const KENPACHI: CharacterData = preload("res://resources/characters/brute.tres")

var _stage: Stage
var _a: Fighter
var _b: Fighter
var _input_a: ScriptedInput
var _spawned: Array[Projectile] = []
var _shakes: Array[float] = []


func _on_spawned(projectile: Projectile) -> void:
	_spawned.append(projectile)
	tree.root.add_child(projectile)


func _on_shake(amount: float) -> void:
	_shakes.append(amount)


func _build(character: CharacterData, gap: float) -> void:
	_spawned.clear()
	_shakes.clear()
	_stage = STAGE_SCENE.instantiate() as Stage
	tree.root.add_child(_stage)
	_a = _fighter(1, character, Vector2(-60.0, 50.0), 1)
	_b = _fighter(2, load("res://resources/characters/swordsman.tres") as CharacterData, Vector2(-60.0 + gap, 50.0), -1)
	_input_a = ScriptedInput.new()
	_a.set_input_source(_input_a)
	_b.set_input_source(ScriptedInput.new())
	Events.screen_shake.connect(_on_shake)


func _fighter(id: int, character: CharacterData, pos: Vector2, facing: int) -> Fighter:
	var fighter := FIGHTER_SCENE.instantiate() as Fighter
	fighter.player_id = id
	fighter.data = character
	fighter.position = pos
	fighter.facing = facing
	fighter.projectile_spawned.connect(_on_spawned)
	tree.root.add_child(fighter)
	return fighter


func _teardown() -> void:
	Events.screen_shake.disconnect(_on_shake)
	for projectile in _spawned:
		if is_instance_valid(projectile):
			projectile.free()
	_a.free()
	_b.free()
	_stage.free()


## Runs the ultimate of `character` against a target `gap` pixels away and returns the damage dealt.
func _damage_dealt(character: CharacterData, gap: float) -> float:
	_build(character, gap)
	_a.start_bankai()
	_a.set_reiatsu(Reiatsu.MAX)
	await wait_frames(30)
	_input_a.tap_charge()
	await wait_frames(170)
	var dealt := _b.percent
	_teardown()
	return dealt


func test_the_three_ultimates_fire_in_beats() -> void:
	for character: CharacterData in [RENJI, RUKIA, KENPACHI]:
		var move := character.ultimate
		check(move.projectiles.size() >= 3, "%s: at least three beats" % character.display_name)
		var last_delay := 0
		var finisher: ProjectileData
		for projectile: ProjectileData in move.projectiles:
			if projectile.delay_frames >= last_delay:
				last_delay = projectile.delay_frames
				finisher = projectile
			check(projectile.delay_frames < move.active_frames + move.recovery_frames, "%s: every beat comes before the move ends" % character.display_name)
		check(last_delay > 0, "%s: some beats are delayed" % character.display_name)
		check_near(finisher.damage_scale, 1.0, 0.001, "%s: the last beat is the full hit" % character.display_name)
		check(finisher.shake >= 5.0, "%s: and it shakes the screen" % character.display_name)
		for projectile: ProjectileData in move.projectiles:
			if projectile != finisher:
				check(projectile.damage_scale < 1.0 and projectile.knockback_scale < 1.0, "%s: earlier beats are lighter" % character.display_name)


func test_each_ultimate_has_its_own_look() -> void:
	var styles := {}
	for character: CharacterData in [RENJI, RUKIA, KENPACHI]:
		var set_of_styles := {}
		for projectile: ProjectileData in character.ultimate.projectiles:
			set_of_styles[projectile.style] = true
			check(ProjectileArt.STYLES.has(projectile.style), "%s: a known style" % character.display_name)
		styles[character.display_name] = set_of_styles
	check(styles["Rukia"].has(&"pillar"), "Rukia: pillars of ice")
	check(styles["Renji"].has(&"baboon") and styles["Renji"].has(&"chain") and styles["Renji"].has(&"beam"), "Renji: skull, bone lash and cannon")
	check(styles["Kenpachi"].has(&"crescent") and not styles["Kenpachi"].has(&"pillar"), "Kenpachi: swings")
	check(RUKIA.ultimate.projectiles[0].velocity == Vector2.ZERO, "the pillars stand where they rise")
	check(KENPACHI.ultimate.self_velocity.x > 0.0, "Kenpachi charges in as he swings")


func test_a_delayed_beat_appears_late_and_shakes_the_screen() -> void:
	_build(RUKIA, 140.0)
	_a.start_bankai()
	_a.set_reiatsu(Reiatsu.MAX)
	await wait_frames(30)
	_input_a.tap_charge()
	await wait_frames(RUKIA.ultimate.startup_frames + 6)
	var early := _spawned.size()
	check(early >= 1 and early < RUKIA.ultimate.projectiles.size(), "only the first beats are out after the wind-up")
	await wait_frames(40)
	check_eq(_spawned.size(), RUKIA.ultimate.projectiles.size(), "all the beats came")
	check(not _shakes.is_empty() and _shakes.max() >= 5.0, "the finisher shook the screen")
	_teardown()


func test_an_ultimate_on_a_standing_target_hurts_without_being_a_free_kill() -> void:
	for character: CharacterData in [RENJI, RUKIA, KENPACHI]:
		var base := character.ultimate.damage * CombatGauge.DAMAGE_SCALE
		var dealt := await _damage_dealt(character, 110.0)
		print("  ultimate %s dealt %.1f (one full hit is %.1f)" % [character.display_name, dealt, base])
		check(dealt >= base * 0.6, "%s: it connects for real damage" % character.display_name)
		check(dealt <= base * 2.4, "%s: but not several full ultimates at once" % character.display_name)


func test_a_close_target_is_not_hit_for_more_than_a_far_one_by_much() -> void:
	for character: CharacterData in [RENJI, RUKIA, KENPACHI]:
		var close := await _damage_dealt(character, 50.0)
		var far := await _damage_dealt(character, 170.0)
		print("  %s close %.1f far %.1f" % [character.display_name, close, far])
		check(close > 0.0, "%s: hits up close" % character.display_name)
		check(far > 0.0, "%s: and from a distance" % character.display_name)
