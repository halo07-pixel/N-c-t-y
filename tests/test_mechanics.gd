extends TestCase
## Signature mechanics: Hollow points, Heartless bounce, petal zone, Reiatsu steal.

const STAGE_SCENE: PackedScene = preload("res://scenes/stages/test_stage.tscn")
const FIGHTER_SCENE: PackedScene = preload("res://scenes/fighter/fighter.tscn")

var _stage: Stage
var _a: Fighter
var _b: Fighter
var _events: Array = []


func _on_mechanic(player_id: int, kind: StringName, _spot: Vector2) -> void:
	_events.append([player_id, kind])


func _build(character_a: String, character_b: String = "swordsman") -> void:
	_events.clear()
	_stage = STAGE_SCENE.instantiate() as Stage
	tree.root.add_child(_stage)
	_a = _spawn(1, character_a, Vector2(-30.0, 50.0), 1)
	_b = _spawn(2, character_b, Vector2(30.0, 50.0), -1)
	_a.set_input_source(ScriptedInput.new())
	_b.set_input_source(ScriptedInput.new())
	Events.mechanic_triggered.connect(_on_mechanic)


func _spawn(id: int, character: String, pos: Vector2, facing: int) -> Fighter:
	var fighter := FIGHTER_SCENE.instantiate() as Fighter
	fighter.player_id = id
	fighter.data = load("res://resources/characters/%s.tres" % character)
	fighter.position = pos
	fighter.facing = facing
	tree.root.add_child(fighter)
	return fighter


func _teardown() -> void:
	Events.mechanic_triggered.disconnect(_on_mechanic)
	_a.free()
	_b.free()
	_stage.free()


func _hit(damage: float = 5.0) -> HitInfo:
	var info := HitInfo.new()
	info.attacker_id = 1
	info.damage = damage
	info.base_knockback = 200.0
	info.direction = Vector2.RIGHT
	return info


func test_every_character_has_a_mechanic() -> void:
	for name in ["swordsman", "archer", "noble", "emperor"]:
		var data := load("res://resources/characters/%s.tres" % name) as CharacterData
		check(data.mechanic != &"", "%s has a signature mechanic" % name)


func test_hollow_points_boost_the_next_special() -> void:
	_build("swordsman")
	await wait_frames(20)
	for i in 3:
		_a._on_hit_landed(_hit())
	check(_a.empowered, "three hits in a row charge the Hollow boost")
	check_eq(_events.size(), 1, "and it is announced")
	var special := _a.data.specials.neutral
	_a.begin_special_use(special, false)
	check_near(_a.empower_scale, Fighter.HOLLOW_SCALE, 0.001, "the next special hits 25% harder")
	check(not _a.empowered, "the boost is used up")
	_teardown()


func test_two_hits_are_not_enough_for_hollow() -> void:
	_build("swordsman")
	await wait_frames(20)
	for i in 2:
		_a._on_hit_landed(_hit())
	check(not _a.empowered, "two hits do not charge it")
	_teardown()


func test_third_arrow_bounces() -> void:
	_build("archer")
	await wait_frames(20)
	var first := _hit()
	var second := _hit()
	var third := _hit()
	_a._on_projectile_hit(first)
	_a._on_projectile_hit(second)
	check(first.direction == Vector2.RIGHT and second.direction == Vector2.RIGHT, "the first two arrows are plain")
	_a._on_projectile_hit(third)
	check(third.direction.y < -0.9, "the third pops the target up")
	check(third.base_knockback > 200.0, "and harder")
	check(_events.size() == 1 and _events[0][1] == &"heartless", "announced as Heartless")
	_teardown()


func test_the_arrow_streak_expires() -> void:
	_build("archer")
	await wait_frames(20)
	_a._on_projectile_hit(_hit())
	_a._on_projectile_hit(_hit())
	await wait_frames(Fighter.HEARTLESS_WINDOW + 5)
	var late := _hit()
	_a._on_projectile_hit(late)
	check(late.direction == Vector2.RIGHT, "a late arrow starts a new streak")
	_teardown()


func _petal(at: Vector2) -> Projectile:
	var data := ProjectileData.new()
	data.commandable = true
	data.lifetime_frames = 200
	data.velocity = Vector2.ZERO
	data.size = Vector2(8.0, 8.0)
	var projectile := Projectile.new()
	projectile.launch(data, _a.data.moveset.ground_neutral, 1, 1, 1.0, at)
	tree.root.add_child(projectile)
	return projectile


func test_petal_zone_speeds_up_byakuya_and_keeps_petals() -> void:
	_build("noble")
	await wait_frames(20)
	var near := _petal(_a.global_position + Vector2(20.0, -14.0))
	await wait_frames(4)
	check(_a.in_petal_zone, "near his petals Byakuya is in the zone")
	var before := near._frames_left
	await wait_frames(20)
	check(before - near._frames_left < 20, "petals fade slower near him")
	_a.apply_horizontal(0.1, 1.0, 100.0, 10000.0, 0.0)
	check_near(_a.velocity.x, 100.0 * Fighter.PETAL_RUN_SCALE, 0.01, "and he runs faster")
	near.free()
	await wait_frames(3)
	check(not _a.in_petal_zone, "no petals, no zone")
	var far := _petal(_a.global_position + Vector2(300.0, -14.0))
	await wait_frames(4)
	check(not _a.in_petal_zone, "far-away petals do not count")
	far.free()
	_teardown()


func test_counter_steals_a_reiatsu_block() -> void:
	_build("emperor", "swordsman")
	await wait_frames(20)
	_b.set_reiatsu(150.0)
	_a.set_reiatsu(0.0)
	var down := _a.data.specials.down
	_a.set_counter(down)
	var info := _hit()
	info.attacker_id = 2
	_a._counter_hit(info)
	check_near(_b.reiatsu, 50.0, 0.01, "the attacker loses a block")
	check_near(_a.reiatsu, 100.0, 0.01, "Yhwach takes it")
	_teardown()


func test_counter_steals_nothing_from_an_empty_attacker() -> void:
	_build("emperor", "swordsman")
	await wait_frames(20)
	_b.set_reiatsu(40.0)
	_a.set_reiatsu(0.0)
	_a.set_counter(_a.data.specials.down)
	var info := _hit()
	info.attacker_id = 2
	_a._counter_hit(info)
	check_near(_b.reiatsu, 40.0, 0.01, "less than a block cannot be taken")
	check_near(_a.reiatsu, 0.0, 0.01, "nothing gained")
	_teardown()
