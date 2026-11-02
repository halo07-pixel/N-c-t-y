extends TestCase
## Cancels: a normal attack that hit can be cancelled into a zone/rush skill with the skill key
## within the window, and a Gauge Cancel frees the fighter mid-hit for 40 Gauge.

const STAGE_SCENE: PackedScene = preload("res://scenes/stages/test_stage.tscn")
const FIGHTER_SCENE: PackedScene = preload("res://scenes/fighter/fighter.tscn")
const SWORDSMAN: CharacterData = preload("res://resources/characters/swordsman.tres")

var _stage: Stage
var _a: Fighter
var _b: Fighter
var _input: ScriptedInput


func _build(gap: float = 20.0) -> void:
	_stage = STAGE_SCENE.instantiate() as Stage
	tree.root.add_child(_stage)
	_a = _spawn(1, Vector2(-10.0, 50.0), 1)
	_b = _spawn(2, Vector2(-10.0 + gap, 50.0), -1)
	_input = ScriptedInput.new()
	_a.set_input_source(_input)
	_b.set_input_source(ScriptedInput.new())


func _spawn(id: int, pos: Vector2, facing: int) -> Fighter:
	var fighter := FIGHTER_SCENE.instantiate() as Fighter
	fighter.player_id = id
	fighter.data = SWORDSMAN
	fighter.position = pos
	fighter.facing = facing
	tree.root.add_child(fighter)
	return fighter


func _teardown() -> void:
	_a.free()
	_b.free()
	_stage.free()


## Throws a jab and waits until it has connected (the confirm window is open, the hitlag running).
func _jab_until_hit() -> void:
	await wait_frames(30)
	_input.tap_attack()
	for i in 40:
		await wait_frames(1)
		if _a.hit_confirm_left > 0:
			return


## Waits for the hitlag of the hit to be over, then a couple of frames.
func _after_hitlag(extra: int = 2) -> void:
	for i in 40:
		if _a.hitlag_left <= 0:
			break
		await wait_frames(1)
	await wait_frames(extra)


func test_window_and_roles_are_as_designed() -> void:
	check_eq(CombatGauge.CANCEL_WINDOW_FRAMES, 12, "twelve frames")
	check_eq(CombatGauge.GAUGE_CANCEL_COST, 40.0, "forty Gauge")
	for role in ["zone", "rush", "combo", "heavy"]:
		check(CombatGauge.CANCEL_ROLES.has(role), "%s may be cancelled into" % role)
	for role in ["defend", "recover", "area"]:
		check(not CombatGauge.CANCEL_ROLES.has(role), "%s may not" % role)


func test_a_hit_jab_cancels_into_a_zone_skill() -> void:
	_build()
	await _jab_until_hit()
	check(_a.hit_confirm_left > 0, "the jab connected")
	_input.tap_special() # pressed during the hitlag: it must not be lost
	await _after_hitlag()
	check_eq(_a.current_attack_name(), SWORDSMAN.specials.neutral.display_name, "the jab became the skill")
	check(not _a.skill_ready(&"neutral"), "and its cooldown started")
	_teardown()


func test_a_whiffed_jab_cannot_be_cancelled() -> void:
	_build(200.0)
	await wait_frames(30)
	_input.tap_attack()
	await wait_frames(6)
	_input.tap_special()
	await wait_frames(2)
	check(_a.current_attack_name() != SWORDSMAN.specials.neutral.display_name, "a miss cannot cancel")
	_teardown()


func test_the_window_closes() -> void:
	_build()
	await _jab_until_hit()
	await _after_hitlag(CombatGauge.CANCEL_WINDOW_FRAMES + 2)
	check_eq(_a.hit_confirm_left, 0, "the window is closed")
	_a.input.special_just_pressed = true
	check_eq(_a.skill_cancel_target(), null, "too late to cancel")
	_teardown()


func test_defend_and_recover_skills_do_not_cancel() -> void:
	_build()
	await _jab_until_hit()
	await _after_hitlag(0)
	_a.input.special_just_pressed = true
	_a.input.move = Vector2(0.0, -1.0) # up: Rising Cut, a recovery
	check_eq(_a.skill_cancel_target(), null, "the recovery skill is not a cancel")
	_a.input.move = Vector2(0.0, 1.0) # down: Ground Slam, a defend skill
	check_eq(_a.skill_cancel_target(), null, "nor is the defend skill")
	_a.input.move = Vector2(1.0, 0.0) # forward: Shunpo Strike, a rush skill
	check(_a.skill_cancel_target() != null, "a rush skill does cancel")
	_teardown()


func test_a_skill_on_cooldown_does_not_cancel() -> void:
	_build()
	await _jab_until_hit()
	_a.skill_cooldowns[&"neutral"] = 30
	_input.tap_special()
	await _after_hitlag()
	check(_a.current_attack_name() != SWORDSMAN.specials.neutral.display_name, "cooling skills stay put")
	_teardown()


func test_gauge_cancel_frees_the_fighter_for_forty_gauge() -> void:
	_build()
	await _jab_until_hit()
	_a.set_gauge(60.0)
	_input.tap_charge()
	await _after_hitlag()
	check_near(_a.gauge, 20.0, 0.5, "40 Gauge paid")
	check(_a.get_state_name() != &"Attack", "the attack is cancelled")
	_teardown()


func test_gauge_cancel_needs_the_gauge_and_a_hit() -> void:
	_build()
	await _jab_until_hit()
	_a.set_gauge(30.0)
	check(not _a.can_gauge_cancel(), "30 Gauge is not enough")
	_a.set_gauge(80.0)
	await _after_hitlag(CombatGauge.CANCEL_WINDOW_FRAMES + 2)
	check(not _a.can_gauge_cancel(), "and not after the hit is over")
	_teardown()
	_build(200.0)
	await wait_frames(30)
	_a.set_gauge(80.0)
	_input.tap_attack()
	await wait_frames(6)
	check(not _a.can_gauge_cancel(), "a miss cannot be Gauge Cancelled")
	_teardown()
