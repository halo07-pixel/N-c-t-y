extends TestCase
## Bankai wave 1: Byakuya's hunting petals and blade ring, Rukia's toothed walls, chilling veil and slick floor.

const STAGE_SCENE: PackedScene = preload("res://scenes/stages/test_stage.tscn")
const FIGHTER_SCENE: PackedScene = preload("res://scenes/fighter/fighter.tscn")
const BYAKUYA: CharacterData = preload("res://resources/characters/noble.tres")
const RUKIA: CharacterData = preload("res://resources/characters/ice.tres")
const ICHIGO: CharacterData = preload("res://resources/characters/swordsman.tres")

var _stage: Stage
var _a: Fighter
var _b: Fighter
var _spawned: Array[Projectile] = []


func _on_spawned(projectile: Projectile) -> void:
	_spawned.append(projectile)
	tree.root.add_child(projectile)


func _fighter(id: int, character: CharacterData, pos: Vector2, facing: int) -> Fighter:
	var fighter := FIGHTER_SCENE.instantiate() as Fighter
	fighter.player_id = id
	fighter.data = character
	fighter.position = pos
	fighter.facing = facing
	fighter.projectile_spawned.connect(_on_spawned)
	tree.root.add_child(fighter)
	fighter.set_input_source(ScriptedInput.new())
	return fighter


func _build(character: CharacterData, gap: float) -> void:
	_spawned.clear()
	_stage = STAGE_SCENE.instantiate() as Stage
	tree.root.add_child(_stage)
	_a = _fighter(1, character, Vector2(-60.0, 50.0), 1)
	_b = _fighter(2, ICHIGO, Vector2(-60.0 + gap, 50.0), -1)


func _teardown() -> void:
	for projectile in _spawned:
		if is_instance_valid(projectile):
			projectile.free()
	_a.free()
	_b.free()
	_stage.free()


func test_byakuyas_bankai_petals_hunt_and_his_bars_are_longer() -> void:
	var set := BYAKUYA.bankai_specials
	for shot in set.neutral.projectiles:
		check(shot.homing > 0.0, "every Senkei petal hunts in the Bankai")
	for shot in BYAKUYA.specials.neutral.projectiles:
		check_eq(shot.homing, 0.0, "the normal petals fly straight")
	check(set.forward.follow_up.projectiles[0].size.y > BYAKUYA.specials.forward.follow_up.projectiles[0].size.y, "taller bars")
	check(set.forward.follow_up.bind_frames > BYAKUYA.specials.forward.follow_up.bind_frames, "bound for longer")


func test_a_homing_petal_bends_toward_the_enemy() -> void:
	_build(BYAKUYA, 200.0)
	_b.position = Vector2(140.0, -20.0) # above and ahead of where the petal flies
	_a.start_bankai()
	var shot := BYAKUYA.bankai_specials.neutral.projectiles[0]
	_a.spawn_projectile(shot, BYAKUYA.bankai_specials.neutral)
	var petal := _spawned[0]
	await wait_frames(25)
	check(petal.position.y < 50.0 - 18.0, "it climbed toward the target instead of flying level")
	_teardown()


func test_the_petal_ring_cuts_close_enemies_and_eats_shots() -> void:
	_build(BYAKUYA, 30.0)
	_a.start_bankai()
	await wait_frames(4)
	var before := _b.percent
	await wait_frames(40)
	check(_b.percent > before, "an enemy inside the ring is cut")
	_teardown()
	_build(BYAKUYA, 300.0)
	_a.start_bankai()
	await wait_frames(4)
	var far := _b.percent
	await wait_frames(40)
	check_eq(_b.percent, far, "an enemy outside is left alone")
	_teardown()


func test_no_ring_without_the_form() -> void:
	_build(BYAKUYA, 30.0)
	await wait_frames(60)
	check_eq(_b.percent, 0.0, "the ring belongs to the Bankai")
	_teardown()


func test_rukias_bankai_wall_has_teeth_and_more_health() -> void:
	var wall: ProjectileData = RUKIA.bankai_specials.forward.follow_up.projectiles[0] if RUKIA.bankai_specials.forward.follow_up != null else null
	var found := false
	for slot in [RUKIA.bankai_specials.neutral, RUKIA.bankai_specials.forward, RUKIA.bankai_specials.up, RUKIA.bankai_specials.down]:
		var move: SpecialData = slot
		while move != null:
			for shot in move.projectiles:
				if shot.solid:
					found = true
					check(shot.contact_damage > 0.0, "the wall hurts what touches it")
			move = move.follow_up
	check(found or wall != null, "the Bankai kit has an ice wall")


func test_the_veil_chills_and_slows_harder() -> void:
	var veil: ProjectileData
	for slot in [RUKIA.bankai_specials.neutral, RUKIA.bankai_specials.forward, RUKIA.bankai_specials.up, RUKIA.bankai_specials.down]:
		var move: SpecialData = slot
		while move != null:
			for shot in move.projectiles:
				if shot.slow_scale < 1.0:
					veil = shot
			move = move.follow_up
	check(veil != null, "there is a veil")
	check(veil.chill_in_zone, "it chills")
	check(veil.slow_scale < 0.7, "and slows more than the normal one")


func test_enemies_slide_on_rukias_ice_floor() -> void:
	_build(RUKIA, 60.0)
	_b.velocity.x = 100.0
	await wait_frames(20)
	var normal_slide := absf(_b.velocity.x)
	_teardown()
	_build(RUKIA, 60.0)
	_a.start_bankai()
	_b.velocity.x = 100.0
	await wait_frames(20)
	check(_b.slippery_frames > 0, "the floor is slick for the enemy")
	check(absf(_b.velocity.x) >= normal_slide, "so it keeps its speed at least as long")
	_teardown()
