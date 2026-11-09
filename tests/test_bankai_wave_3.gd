extends TestCase
## Bankai wave 3: Renji's tail echo and Kenpachi's fury.

const STAGE_SCENE: PackedScene = preload("res://scenes/stages/test_stage.tscn")
const FIGHTER_SCENE: PackedScene = preload("res://scenes/fighter/fighter.tscn")
const RENJI: CharacterData = preload("res://resources/characters/lieutenant.tres")
const KENPACHI: CharacterData = preload("res://resources/characters/brute.tres")
const BYAKUYA: CharacterData = preload("res://resources/characters/noble.tres")

var _stage: Stage
var _a: Fighter
var _b: Fighter


func _fighter(id: int, character: CharacterData, pos: Vector2, facing: int) -> Fighter:
	var fighter := FIGHTER_SCENE.instantiate() as Fighter
	fighter.player_id = id
	fighter.data = character
	fighter.position = pos
	fighter.facing = facing
	tree.root.add_child(fighter)
	fighter.set_input_source(ScriptedInput.new())
	return fighter


func _build(character: CharacterData, gap: float) -> void:
	_stage = STAGE_SCENE.instantiate() as Stage
	tree.root.add_child(_stage)
	_a = _fighter(1, character, Vector2(-60.0, 50.0), 1)
	_b = _fighter(2, BYAKUYA, Vector2(-60.0 + gap, 50.0), -1)


func _teardown() -> void:
	_a.free()
	_b.free()
	_stage.free()


func _hit(damage: float) -> HitInfo:
	var info := HitInfo.new()
	info.damage = damage
	info.attacker_id = 2
	info.direction = Vector2.RIGHT
	info.base_knockback = 100.0
	return info


func test_a_landed_hit_schedules_the_tail_echo_in_the_form_only() -> void:
	_build(RENJI, 60.0)
	_a._register_landed_hit(10.0)
	check_eq(_a.echo_frames, 0, "nothing outside the form")
	_a.start_bankai()
	_a._register_landed_hit(10.0)
	check_eq(_a.echo_frames, BankaiTraits.ECHO_DELAY, "the tail is on its way")
	check_near(_a.echo_damage, 10.0 * BankaiTraits.ECHO_SHARE, 0.001, "with a share of the damage")
	_teardown()


func test_the_tail_strikes_a_nearby_enemy_and_misses_a_far_one() -> void:
	_build(RENJI, 60.0)
	_a.start_bankai()
	_a._register_landed_hit(10.0)
	var before := _b.percent
	await wait_frames(BankaiTraits.ECHO_DELAY + 4)
	check(_b.percent > before, "the echo cut the near enemy")
	_teardown()
	_build(RENJI, 400.0)
	_a.start_bankai()
	_a._register_landed_hit(10.0)
	await wait_frames(BankaiTraits.ECHO_DELAY + 4)
	check_eq(_b.percent, 0.0, "a far enemy is out of the tail's reach")
	_teardown()


func test_kenpachis_fury_grows_with_hits_taken_and_caps() -> void:
	_build(KENPACHI, 60.0)
	check_eq(_a.zeal_scale(), 1.0, "calm at the start")
	_a.start_bankai()
	var base := _a.zeal_scale()
	for i in 10:
		_a._on_hit_received(_hit(1.0))
	check_eq(_a.fury_stacks, BankaiTraits.FURY_MAX, "fury is capped")
	check(_a.zeal_scale() > base + BankaiTraits.FURY_STEP * 5.0, "his hits grow stronger")
	_teardown()


func test_zeal_climbs_further_in_the_form() -> void:
	_build(KENPACHI, 60.0)
	_a.set_percent(100.0)
	var plain := _a.zeal_scale()
	_a.start_bankai()
	check(_a.zeal_scale() > plain, "more zeal for the same percent")
	_teardown()


func test_kenpachis_form_burns_slower_than_others() -> void:
	_build(KENPACHI, 60.0)
	_a.start_bankai()
	var before := _a.bankai_frames_left
	_a._on_hit_received(_hit(10.0))
	var lost := before - _a.bankai_frames_left
	check(lost <= int(round(BankaiRules.drain_for(10.0) * BankaiTraits.ZEAL_DRAIN_SCALE)) + 1, "half the drain")
	_teardown()


func test_the_form_ending_drops_the_fury() -> void:
	_build(KENPACHI, 60.0)
	_a.start_bankai()
	_a._on_hit_received(_hit(5.0))
	_a.end_bankai()
	check_eq(_a.fury_stacks, 0, "calm again")
	_teardown()


func _chain_moves(set: SpecialSet) -> Dictionary:
	var found := {}
	for slot in [set.neutral, set.forward, set.up, set.down]:
		var move: SpecialData = slot
		while move != null:
			found[move.display_name.trim_suffix(" +")] = move
			move = move.follow_up
	return found


func test_renjis_bankai_slam_reaches_further_and_the_whirl_lasts_longer() -> void:
	var normal := _chain_moves(RENJI.specials)
	var form := _chain_moves(RENJI.bankai_specials)
	check(form["Zabimaru Slam"].hitbox_size.x > normal["Zabimaru Slam"].hitbox_size.x, "the slam reaches further")
	check(form["Zabimaru Whirl"].spin_frames > normal["Zabimaru Whirl"].spin_frames, "the whirl spins longer")


const YHWACH: CharacterData = preload("res://resources/characters/emperor.tres")


func test_yhwach_remembers_damage_taken_in_the_form_and_returns_it_once() -> void:
	_build(YHWACH, 60.0)
	_a._on_hit_received(_hit(5.0)) # outside the form: forgotten
	check_eq(_a.memory_damage, 0.0, "nothing is remembered outside the form")
	_a.start_bankai()
	_a._on_hit_received(_hit(8.0))
	_a._on_hit_received(_hit(30.0))
	check_near(_a.memory_damage, BankaiTraits.MEMORY_CAP, 0.001, "the memory has a cap")
	_a.global_position = Vector2(-60.0, 50.0) # the hits threw him back; he is next to the enemy again
	_a.velocity = Vector2.ZERO
	_a.hitlag_left = 0
	_a._register_landed_hit(6.0)
	check_eq(_a.memory_damage, 0.0, "the next hit spends it")
	check_near(_a.echo_damage, BankaiTraits.MEMORY_CAP * BankaiTraits.MEMORY_SHARE, 0.001, "and gives most of it back")
	var before := _b.percent
	await wait_frames(BankaiTraits.ECHO_DELAY + 30)
	check(_b.percent > before, "the echo hit the nearby enemy")
	_a._register_landed_hit(6.0)
	check_eq(_a.echo_damage, BankaiTraits.MEMORY_CAP * BankaiTraits.MEMORY_SHARE, "nothing more to give back")
	_teardown()
