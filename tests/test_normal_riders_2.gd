extends TestCase
## Riders of normal attacks, second batch: Rukia's flurry thrusts, Kenpachi's armor, Renji's pulling links.

const STAGE_SCENE: PackedScene = preload("res://scenes/stages/test_stage.tscn")
const FIGHTER_SCENE: PackedScene = preload("res://scenes/fighter/fighter.tscn")
const RENJI: CharacterData = preload("res://resources/characters/lieutenant.tres")
const RUKIA: CharacterData = preload("res://resources/characters/ice.tres")
const KENPACHI: CharacterData = preload("res://resources/characters/brute.tres")

var _stage: Stage
var _a: Fighter
var _b: Fighter
var _input: ScriptedInput
var _hits: Array[float] = []


func _on_hit(_attacker: int, _victim: int, damage: float) -> void:
	_hits.append(damage)


func _build(character: CharacterData, gap: float) -> void:
	_hits.clear()
	_stage = STAGE_SCENE.instantiate() as Stage
	tree.root.add_child(_stage)
	_a = _fighter(1, character, Vector2(-60.0, 50.0), 1)
	_b = _fighter(2, character, Vector2(-60.0 + gap, 50.0), -1)
	_input = ScriptedInput.new()
	_a.set_input_source(_input)
	_b.set_input_source(ScriptedInput.new())
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
	Events.fighter_hit.disconnect(_on_hit)
	_a.free()
	_b.free()
	_stage.free()


func _blow(damage: float) -> HitInfo:
	var info := HitInfo.new()
	info.attacker_id = 2
	info.damage = damage
	info.base_knockback = 200.0
	info.knockback_growth = 100.0
	info.direction = Vector2.LEFT
	return info


func test_a_flurry_strikes_on_the_beats_inside_the_active_frames() -> void:
	var jab := RUKIA.moveset.ground_neutral
	check_eq(jab.repeat_hits, 2, "Rukia's jab is two thrusts")
	check(not NormalRiders.is_flurry_frame(jab, jab.startup_frames), "the first thrust is the normal one")
	check(NormalRiders.is_flurry_frame(jab, jab.startup_frames + jab.repeat_gap_frames), "the second comes one gap later")
	check(not NormalRiders.is_flurry_frame(jab, jab.startup_frames + 2 * jab.repeat_gap_frames), "and there is no third")
	check(not NormalRiders.is_flurry_frame(RENJI.moveset.ground_neutral, 6), "other fighters' jabs are single")


func test_rukias_jab_hits_twice_for_about_one_normal_jab() -> void:
	_build(RUKIA, 26.0)
	await wait_frames(20)
	_input.tap_attack()
	await wait_frames(40)
	var count := _hits.size()
	var total := 0.0
	for damage in _hits:
		total += damage
	print("  Rukia jab: %d hits, %.1f damage" % [count, total])
	check_eq(count, 2, "two thrusts land")
	check(total <= 7.0 and total >= 3.5, "for about what one jab did")
	_teardown()


func test_armor_takes_a_light_hit_without_stopping_the_swing() -> void:
	_build(KENPACHI, 60.0)
	_a.facing = 1
	await wait_frames(20)
	_input.held_move = Vector2(1.0, 0.0)
	_input.tap_attack()
	await wait_frames(4)
	check_eq(_a.get_state_name(), &"Attack", "he is mid-swing")
	check(_a.armored, "and the swing has armor")
	var reiatsu := _a.reiatsu
	_a.hurtbox.receive_hit(_blow(8.0))
	await wait_frames(1)
	check_eq(_a.get_state_name(), &"Attack", "a light hit does not stop it")
	check_near(_a.percent, 8.0, 0.01, "but it still hurts")
	check(_a.reiatsu > reiatsu + 8.0, "and pays Reiatsu")
	check(_a.velocity.length() < 60.0, "he is not launched")
	_a.hurtbox.receive_hit(_blow(20.0))
	await wait_frames(1)
	check_eq(_a.get_state_name(), &"Hitstun", "a heavy hit breaks through")
	_teardown()


func test_a_swing_without_armor_is_stopped_by_a_light_hit() -> void:
	_build(KENPACHI, 60.0)
	await wait_frames(20)
	_input.tap_attack() # the heavy swing (neutral) has no armor
	await wait_frames(3)
	check(not _a.armored, "no armor")
	_a.hurtbox.receive_hit(_blow(8.0))
	await wait_frames(1)
	check_eq(_a.get_state_name(), &"Hitstun", "the swing is stopped")
	_teardown()


func test_armor_ends_with_the_swing() -> void:
	_build(KENPACHI, 60.0)
	await wait_frames(20)
	_input.held_move = Vector2(1.0, 0.0)
	_input.tap_attack()
	await wait_frames(70)
	check(not _a.armored, "armor is gone once the move is over")
	_teardown()


func test_renjis_first_links_pull_the_target_back_and_the_finisher_launches_it_away() -> void:
	var set := RENJI.moveset
	var first := set.ground_neutral
	var second := first.next_in_chain
	var finisher := second.next_in_chain
	check(first.angle_degrees > 90.0 and second.angle_degrees > 90.0, "the first links launch back toward him")
	check(finisher.angle_degrees < 90.0, "the finisher launches away")
	check(Knockback.direction(first.angle_degrees, 1).x < 0.0, "toward the attacker when facing right")


func test_riders_stay_with_the_normal_attacks() -> void:
	for character: CharacterData in [RENJI, RUKIA, KENPACHI]:
		for set_of_skills: SpecialSet in [character.specials, character.bankai_specials]:
			for property in set_of_skills.get_property_list():
				var value: Variant = set_of_skills.get(property.name)
				if value is SpecialData:
					var skill := value as SpecialData
					check(skill.repeat_hits <= 1 and not skill.armor, "%s: %s has no normal-attack rider" % [character.display_name, skill.display_name])
		check(character.ultimate.repeat_hits <= 1 and not character.ultimate.armor, "%s: nor the ultimate" % character.display_name)
	check(KENPACHI.moveset.ground_forward.armor and not RUKIA.moveset.ground_forward.armor, "armor is Kenpachi's")
	check(RUKIA.moveset.ground_neutral.repeat_hits > 1 and KENPACHI.moveset.ground_neutral.repeat_hits <= 1, "the flurry is Rukia's")
