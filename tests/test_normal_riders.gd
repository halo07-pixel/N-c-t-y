extends TestCase
## Riders of normal attacks: Ichigo's rhythm, Byakuya's cut marks, Uryu's recoil. They live on the
## attack key and its string, so none of them touches what the skills do (charge, second press, traps).

const STAGE_SCENE: PackedScene = preload("res://scenes/stages/test_stage.tscn")
const FIGHTER_SCENE: PackedScene = preload("res://scenes/fighter/fighter.tscn")
const ICHIGO: CharacterData = preload("res://resources/characters/swordsman.tres")
const URYU: CharacterData = preload("res://resources/characters/archer.tres")
const BYAKUYA: CharacterData = preload("res://resources/characters/noble.tres")

var _stage: Stage
var _a: Fighter
var _b: Fighter
var _input: ScriptedInput
var _rhythm_events: int = 0
var _hits: Array[float] = []


func _on_mechanic(_id: int, kind: StringName, _spot: Vector2) -> void:
	if kind == &"rhythm":
		_rhythm_events += 1


func _on_hit(_attacker: int, _victim: int, damage: float) -> void:
	_hits.append(damage)


func _build(character: CharacterData, gap: float) -> void:
	_rhythm_events = 0
	_hits.clear()
	_stage = STAGE_SCENE.instantiate() as Stage
	tree.root.add_child(_stage)
	_a = _fighter(1, character, Vector2(-60.0, 50.0), 1)
	_b = _fighter(2, character, Vector2(-60.0 + gap, 50.0), -1)
	_input = ScriptedInput.new()
	_a.set_input_source(_input)
	_b.set_input_source(ScriptedInput.new())
	Events.mechanic_triggered.connect(_on_mechanic)
	Events.fighter_hit.connect(_on_hit)


func _fighter(id: int, character: CharacterData, pos: Vector2, facing: int) -> Fighter:
	var fighter := FIGHTER_SCENE.instantiate() as Fighter
	fighter.player_id = id
	fighter.data = character
	fighter.position = pos
	fighter.facing = facing
	tree.root.add_child(fighter)
	return fighter


func _teardown() -> void:
	Events.mechanic_triggered.disconnect(_on_mechanic)
	Events.fighter_hit.disconnect(_on_hit)
	_a.free()
	_b.free()
	_stage.free()


## Ichigo jabs, then presses attack again `delay` frames later. Returns whether the link was perfect.
func _link_after(delay: int, gap: float = 30.0) -> bool:
	_build(ICHIGO, gap)
	await wait_frames(20)
	_input.tap_attack()
	await wait_frames(delay)
	_input.tap_attack()
	await wait_frames(40)
	var perfect := _rhythm_events > 0
	_teardown()
	return perfect


func test_the_perfect_window_is_a_few_frames_around_the_end_of_the_hit() -> void:
	check(NormalRiders.is_perfect(5, 5), "right as the hit ends")
	check(NormalRiders.is_perfect(5 + NormalRiders.PERFECT_LATE, 5), "a little late")
	check(not NormalRiders.is_perfect(4, 5), "mashing during the swing is too early")
	check(not NormalRiders.is_perfect(5 + NormalRiders.PERFECT_LATE + 1, 5), "waiting is too late")


func test_ichigo_links_on_time_only() -> void:
	var results := []
	for delay in range(0, 40):
		results.append(await _link_after(delay))
	print("  rhythm by press delay: ", results)
	check(results.has(true), "some timing links perfectly")
	check(results.has(false), "and some does not")
	var first := results.find(true)
	var last := results.rfind(true)
	check(not results[results.size() - 1], "waiting too long is not perfect")
	check(not results[first - 1], "mashing just before is not perfect")
	for i in range(first, last + 1):
		check(results[i], "the window has no holes (delay %d)" % i)


func test_a_perfect_link_hits_harder_and_pays_reiatsu() -> void:
	var results := []
	for delay in range(0, 40):
		results.append(await _link_after(delay))
	var good := results.find(true)
	var bad := good - 1
	_build(ICHIGO, 30.0)
	await wait_frames(20)
	_input.tap_attack()
	await wait_frames(good)
	var reiatsu_before := _a.reiatsu
	_input.tap_attack()
	await wait_frames(40)
	var perfect_hits := _hits.duplicate()
	var perfect_reiatsu := _a.reiatsu
	_teardown()
	_build(ICHIGO, 30.0)
	await wait_frames(20)
	_input.tap_attack()
	await wait_frames(bad)
	_input.tap_attack()
	await wait_frames(40)
	var plain_hits := _hits.duplicate()
	_teardown()
	check(perfect_hits.size() >= 2 and plain_hits.size() >= 2, "both strings connect twice")
	if perfect_hits.size() >= 2 and plain_hits.size() >= 2:
		check(perfect_hits[1] > plain_hits[1] * 1.1, "the on-time second hit is stronger")
	check(perfect_reiatsu > reiatsu_before, "and pays back Reiatsu")


func test_cut_marks_come_from_the_far_part_of_the_blade_and_burst_later() -> void:
	_build(BYAKUYA, 26.0)
	await wait_frames(20)
	_input.tap_attack()
	await wait_frames(14)
	check_eq(_b.cut_marks, 1, "a hit at the tip leaves a mark")
	var after_hit := _b.percent
	await wait_frames(NormalRiders.CUT_FRAMES + 10)
	check_eq(_b.cut_marks, 0, "the mark has burst")
	check_near(_b.percent - after_hit, NormalRiders.burst_damage(1), 0.01, "for its share of damage")
	_teardown()
	_build(BYAKUYA, 10.0)
	await wait_frames(20)
	_input.tap_attack()
	await wait_frames(14)
	check(_b.percent > 0.0, "a close hit still lands")
	check_eq(_b.cut_marks, 0, "but leaves no mark")
	_teardown()


func test_a_ko_clears_the_marks() -> void:
	_build(BYAKUYA, 40.0)
	_b.cut_marks = 3
	_b.clear_riders()
	check_eq(_b.cut_marks, 0, "cleared")
	_teardown()


func test_a_hit_throws_uryu_back_and_a_second_throws_him_further() -> void:
	_build(URYU, 26.0)
	await wait_frames(20)
	_input.tap_attack()
	var first := 0.0
	for _i in 30:
		await wait_frames(1)
		if _a.hit_connected:
			first = _a.velocity.x
			break
	check(first < 0.0, "the first hit pushes him back, away from the target")
	_teardown()
	var recoil := NormalRiders.recoil_velocity(URYU.moveset.ground_neutral, 1, false)
	var stacked := NormalRiders.recoil_velocity(URYU.moveset.ground_neutral, 1, true)
	check(stacked.x < recoil.x and recoil.x < 0.0, "a second hit throws him further")
	var kick := NormalRiders.recoil_velocity(URYU.moveset.air_forward, -1, false)
	check(kick.x > 0.0 and kick.y < 0.0, "facing left it throws him right, and an air hit kicks him up")


func test_riders_belong_to_normal_attacks_not_skills() -> void:
	for character: CharacterData in [ICHIGO, URYU, BYAKUYA]:
		for set_of_skills: SpecialSet in [character.specials, character.bankai_specials]:
			for property in set_of_skills.get_property_list():
				var value: Variant = set_of_skills.get(property.name)
				if value is SpecialData:
					var skill := value as SpecialData
					check(skill.rhythm_bonus == 0.0 and skill.cut_marks == 0 and skill.recoil_speed == 0.0, "%s: %s carries no rider" % [character.display_name, skill.display_name])
		check(character.ultimate.rhythm_bonus == 0.0 and character.ultimate.cut_marks == 0 and character.ultimate.recoil_speed == 0.0, "%s: nor the ultimate" % character.display_name)


func test_each_style_has_its_own_rider_and_only_its_own() -> void:
	check(ICHIGO.moveset.ground_neutral.rhythm_bonus > 0.0 and ICHIGO.moveset.ground_neutral.cut_marks == 0 and ICHIGO.moveset.ground_neutral.recoil_speed == 0.0, "Ichigo: rhythm only")
	check(BYAKUYA.moveset.ground_neutral.cut_marks > 0 and BYAKUYA.moveset.ground_neutral.rhythm_bonus == 0.0 and BYAKUYA.moveset.ground_neutral.recoil_speed == 0.0, "Byakuya: cut only")
	check(URYU.moveset.ground_neutral.recoil_speed > 0.0 and URYU.moveset.ground_neutral.rhythm_bonus == 0.0 and URYU.moveset.ground_neutral.cut_marks == 0, "Uryu: recoil only")
	check(ICHIGO.moveset.ground_neutral.lunge_speed > 0.0 and ICHIGO.moveset.ground_neutral.next_in_chain.lunge_speed > 0.0, "Ichigo steps into every slash")
