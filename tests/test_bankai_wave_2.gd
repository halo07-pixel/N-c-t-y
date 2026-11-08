extends TestCase
## Bankai wave 2: Ichigo's Getsuga charge and Uryu's blade lattice.

const STAGE_SCENE: PackedScene = preload("res://scenes/stages/test_stage.tscn")
const FIGHTER_SCENE: PackedScene = preload("res://scenes/fighter/fighter.tscn")
const ICHIGO: CharacterData = preload("res://resources/characters/swordsman.tres")
const URYU: CharacterData = preload("res://resources/characters/archer.tres")
const BYAKUYA: CharacterData = preload("res://resources/characters/noble.tres")

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


func _build(character: CharacterData, enemy_x: float) -> void:
	_spawned.clear()
	_stage = STAGE_SCENE.instantiate() as Stage
	tree.root.add_child(_stage)
	_a = _fighter(1, character, Vector2(-100.0, 50.0), 1)
	_b = _fighter(2, BYAKUYA, Vector2(enemy_x, 50.0), -1)


func _teardown() -> void:
	for projectile in _spawned:
		if is_instance_valid(projectile):
			projectile.free()
	_a.free()
	_b.free()
	_stage.free()


func test_hits_in_the_form_charge_the_getsuga_up_to_the_cap() -> void:
	_build(ICHIGO, 200.0)
	_a.start_bankai()
	for i in 8:
		BankaiTraits.on_hit_landed(_a)
	check_eq(_a.getsuga_stacks, BankaiTraits.GETSUGA_MAX, "capped")
	_teardown()


func test_a_charged_getsuga_is_bigger_and_stronger_and_spends_the_charge() -> void:
	_build(ICHIGO, 200.0)
	_a.start_bankai()
	var skill: SpecialData = ICHIGO.bankai_specials.neutral
	BankaiTraits.on_special_used(_a, skill)
	check_eq(_a.getsuga_boost, 1.0, "no charge, no boost")
	_a.getsuga_stacks = 4
	BankaiTraits.on_special_used(_a, skill)
	check_near(_a.getsuga_boost, 1.0 + BankaiTraits.GETSUGA_STEP * 4.0, 0.001, "boost follows the stacks")
	check_eq(_a.getsuga_stacks, 0, "the charge is spent")
	_teardown()


func test_too_little_charge_or_a_non_projectile_skill_keeps_the_charge() -> void:
	_build(ICHIGO, 200.0)
	_a.start_bankai()
	_a.getsuga_stacks = 2
	BankaiTraits.on_special_used(_a, ICHIGO.bankai_specials.neutral)
	check_eq(_a.getsuga_stacks, 2, "below the minimum nothing is spent")
	_a.getsuga_stacks = 4
	var step := ICHIGO.bankai_specials.forward as SpecialData
	if step.projectiles.is_empty():
		BankaiTraits.on_special_used(_a, step)
		check_eq(_a.getsuga_stacks, 4, "a skill without shots keeps it")
	_teardown()


func test_a_boosted_shot_really_is_larger() -> void:
	_build(ICHIGO, 400.0)
	_a.start_bankai()
	var skill: SpecialData = ICHIGO.bankai_specials.neutral
	_a.spawn_projectile(skill.projectiles[0], skill)
	var plain := _spawned[0]._size.x
	_a.getsuga_boost = 1.5
	_a.spawn_projectile(skill.projectiles[0], skill)
	check(_spawned[1]._size.x > plain * 1.4, "the charged shot is wider")
	_teardown()


func test_the_charge_is_lost_when_the_form_ends() -> void:
	_build(ICHIGO, 200.0)
	_a.start_bankai()
	_a.getsuga_stacks = 4
	_a.end_bankai()
	check_eq(_a.getsuga_stacks, 0, "gone with the form")
	_teardown()


func test_uryus_bankai_arrows_pierce_and_blades_last_longer() -> void:
	var stream := URYU.bankai_specials.neutral.follow_up as SpecialData
	for shot in stream.projectiles:
		check(shot.pierce, "the stream arrows pierce")
	var normal_blade: ProjectileData = null
	for shot in URYU.specials.forward.projectiles:
		if shot.plant:
			normal_blade = shot
	for shot in URYU.bankai_specials.forward.projectiles:
		if shot.plant and normal_blade != null:
			check(shot.lifetime_frames > normal_blade.lifetime_frames, "blades stay planted longer")


func _plant_blade(at: Vector2) -> Projectile:
	var data := ProjectileData.new()
	data.plant = false
	data.velocity = Vector2.ZERO
	data.lifetime_frames = 600
	data.size = Vector2(5.0, 24.0)
	data.pierce = true
	var move := SpecialData.new()
	move.damage = 0.0
	var blade := Projectile.new()
	blade.launch(data, move, 1, 1, 1.0, at)
	blade._planted = true
	blade._data.plant = true
	_spawned.append(blade)
	tree.root.add_child(blade)
	return blade


func test_two_planted_blades_shock_an_enemy_between_them() -> void:
	_build(URYU, 0.0)
	_a.start_bankai()
	_plant_blade(Vector2(-60.0, 58.0))
	_plant_blade(Vector2(60.0, 58.0))
	_b.position = Vector2(0.0, 50.0)
	var before := _b.percent
	await wait_frames(45)
	check(_b.percent > before, "the lattice shocked it")
	_teardown()


func test_blades_too_far_apart_make_no_lattice() -> void:
	_build(URYU, 0.0)
	_a.start_bankai()
	_plant_blade(Vector2(-250.0, 58.0))
	_plant_blade(Vector2(250.0, 58.0))
	_b.position = Vector2(0.0, 50.0)
	await wait_frames(4)
	check_eq(BankaiTraits.lattice_pairs(_a).size(), 0, "a gap of 500 is too wide")
	_teardown()


func test_no_lattice_without_the_form() -> void:
	_build(URYU, 0.0)
	_plant_blade(Vector2(-60.0, 58.0))
	_plant_blade(Vector2(60.0, 58.0))
	_b.position = Vector2(0.0, 50.0)
	await wait_frames(45)
	check_eq(_b.percent, 0.0, "only the Bankai lights the lattice")
	_teardown()
