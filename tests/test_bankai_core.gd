extends TestCase
## The price of a Bankai: hits taken burn the form, an ended form leaves the fighter exhausted,
## one ultimate per form, and the stage shows the field while it lasts.

const STAGE_SCENE: PackedScene = preload("res://scenes/stages/test_stage.tscn")
const FIGHTER_SCENE: PackedScene = preload("res://scenes/fighter/fighter.tscn")
const ICHIGO: CharacterData = preload("res://resources/characters/swordsman.tres")

var _stage: Stage
var _a: Fighter


func _build() -> void:
	_stage = STAGE_SCENE.instantiate() as Stage
	tree.root.add_child(_stage)
	_a = FIGHTER_SCENE.instantiate() as Fighter
	_a.player_id = 1
	_a.data = ICHIGO
	_a.position = Vector2(0.0, 50.0)
	tree.root.add_child(_a)
	_a.set_input_source(ScriptedInput.new())


func _teardown() -> void:
	_a.free()
	_stage.free()


func _hit(damage: float) -> HitInfo:
	var info := HitInfo.new()
	info.damage = damage
	info.attacker_id = 2
	info.direction = Vector2.RIGHT
	info.base_knockback = 100.0
	return info


func test_a_hit_burns_frames_of_the_form_and_never_more_than_the_cap() -> void:
	check_eq(BankaiRules.drain_for(5.0), 20, "5% costs a third of a second")
	check_eq(BankaiRules.drain_for(80.0), BankaiRules.DRAIN_MAX_PER_HIT, "one hit never costs more than the cap")


func test_taking_a_hit_in_the_form_shortens_it() -> void:
	_build()
	_a.start_bankai()
	var before := _a.bankai_frames_left
	_a._on_hit_received(_hit(10.0))
	check(_a.bankai_frames_left <= before - BankaiRules.drain_for(10.0), "the form lost time")
	check(_a.is_bankai(), "but it is still on")
	_teardown()


func test_enough_hits_end_the_form_and_leave_the_fighter_exhausted() -> void:
	_build()
	_a.start_bankai()
	_a.bankai_frames_left = 30
	_a._on_hit_received(_hit(20.0))
	check(not _a.is_bankai(), "the form burnt out")
	check_eq(_a.exhausted_frames, BankaiRules.EXHAUST_FRAMES, "exhausted")
	check_near(_a.speed_scale, BankaiRules.EXHAUST_SPEED, 0.001, "and slower")
	check(not _a.can_bankai(), "no new Bankai while exhausted")
	_teardown()


func test_exhaustion_wears_off() -> void:
	_build()
	_a.start_bankai()
	_a.end_bankai(true)
	_a.exhausted_frames = 3
	await wait_frames(6)
	check_eq(_a.exhausted_frames, 0, "it ran out")
	check_near(_a.speed_scale, 1.0, 0.001, "speed is back")
	_teardown()


func test_a_knock_out_does_not_exhaust() -> void:
	_build()
	_a.start_bankai()
	_a.enter_ko()
	check_eq(_a.exhausted_frames, 0, "a fresh stock starts rested")
	check_near(_a.speed_scale, 1.0, 0.001, "at normal speed")
	_teardown()


func test_one_ultimate_per_transformation() -> void:
	_build()
	_a.start_bankai()
	_a.set_reiatsu(Reiatsu.MAX)
	check(_a.can_ultimate(), "the first is ready")
	_a.charge_press_state()
	_a.set_reiatsu(Reiatsu.MAX)
	check(not _a.can_ultimate(), "the second waits for a new form")
	_a.end_bankai()
	_a.start_bankai()
	_a.set_reiatsu(Reiatsu.MAX)
	check(_a.can_ultimate(), "a new transformation brings it back")
	_teardown()


func test_the_stage_shows_a_field_while_the_form_lasts() -> void:
	_build()
	var field := _stage.get_node("BankaiField") as BankaiField
	check(not field.is_showing(), "nothing before the form")
	_a.start_bankai()
	await wait_frames(20)
	check(field.level_of(1) > 0.0, "the field fades in")
	_a.end_bankai()
	await wait_frames(120)
	check_near(field.level_of(1), 0.0, 0.001, "and out again")
	_teardown()
