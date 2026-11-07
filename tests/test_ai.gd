extends TestCase
## The CPU opponent against a standing dummy and when thrown off the stage.

const STAGE_SCENE: PackedScene = preload("res://scenes/stages/test_stage.tscn")
const FIGHTER_SCENE: PackedScene = preload("res://scenes/fighter/fighter.tscn")
const SWORDSMAN: CharacterData = preload("res://resources/characters/swordsman.tres")
const ARCHER: CharacterData = preload("res://resources/characters/archer.tres")

var _stage: Stage
var _cpu: Fighter
var _dummy: Fighter
var _brain: AIInput


func _on_projectile_spawned(projectile: Projectile) -> void:
	tree.root.add_child(projectile)


func _build_world(cpu_data: CharacterData, cpu_pos: Vector2, dummy_x: float, level: int) -> void:
	_stage = STAGE_SCENE.instantiate() as Stage
	tree.root.add_child(_stage)
	_cpu = _spawn(1, cpu_data, cpu_pos)
	_dummy = _spawn(2, SWORDSMAN, Vector2(dummy_x, 50.0))
	_dummy.set_input_source(ScriptedInput.new())
	_brain = AIInput.new()
	_brain.bind(_cpu, _dummy, level, 12345)
	_cpu.set_input_source(_brain)


func _spawn(id: int, character: CharacterData, pos: Vector2) -> Fighter:
	var fighter := FIGHTER_SCENE.instantiate() as Fighter
	fighter.player_id = id
	fighter.data = character
	fighter.position = pos
	fighter.projectile_spawned.connect(_on_projectile_spawned)
	tree.root.add_child(fighter)
	return fighter


func _teardown_world() -> void:
	for node in tree.root.get_children():
		if node is Projectile:
			node.free()
	_cpu.free()
	_dummy.free()
	_stage.free()


func test_level_is_clamped_to_the_known_range() -> void:
	var brain := AIInput.new()
	brain.level = 2
	check(AIInput.LEVELS.has(1) and AIInput.LEVELS.has(2) and AIInput.LEVELS.has(3), "three levels exist")
	check(AIInput.LEVELS[3]["reaction"] < AIInput.LEVELS[1]["reaction"], "harder levels react faster")
	check(AIInput.LEVELS[3]["attack"] > AIInput.LEVELS[1]["attack"], "harder levels attack more")
	brain.free()


func test_cpu_recovers_to_the_stage_after_being_thrown_off() -> void:
	_build_world(SWORDSMAN, Vector2(200.0, 10.0), -60.0, 3)
	_cpu.velocity = Vector2(60.0, -50.0)
	# it started off the stage; what matters is that it got back onto it (the fight may then carry it off again)
	var on_stage := false
	for i in 30:
		await wait_frames(10)
		on_stage = on_stage or (absf(_cpu.global_position.x) < 160.0 and _cpu.global_position.y < 70.0 and _cpu.is_on_floor())
	check(on_stage, "the CPU got back onto the stage")
	_teardown_world()


func test_cpu_does_nothing_while_knocked_out_or_stunned() -> void:
	_build_world(SWORDSMAN, Vector2(-60.0, 50.0), 20.0, 3)
	await wait_frames(30)
	_cpu.enter_ko()
	var frame := _brain.get_frame()
	check_eq(frame.move, Vector2.ZERO, "no movement when knocked out")
	check(not frame.attack_just_pressed, "no attacks when knocked out")
	_teardown_world()


func test_cpu_transforms_when_its_gauge_is_full() -> void:
	_build_world(SWORDSMAN, Vector2(-120.0, 50.0), 120.0, 3)
	_cpu.set_gauge(CombatGauge.MAX)
	await wait_frames(240)
	check(_cpu.is_bankai(), "the CPU transformed")
	_teardown_world()


func test_cpu_defends_when_the_opponent_attacks_close_by() -> void:
	_build_world(SWORDSMAN, Vector2(-20.0, 50.0), 20.0, 3)
	await wait_frames(30)
	_dummy._state_machine.transition_to(&"Attack")
	var defended := 0
	for _i in 40:
		_brain._defend_cooldown = 0
		_brain._guard_frames_left = 0
		var frame := _brain.get_frame()
		if frame.guard_just_pressed:
			defended += 1
	check(defended > 5, "the CPU raised its guard against close attacks (%d of 40)" % defended)
	_teardown_world()


func test_easy_cpu_never_defends() -> void:
	_build_world(SWORDSMAN, Vector2(-20.0, 50.0), 20.0, 1)
	await wait_frames(30)
	_dummy._state_machine.transition_to(&"Attack")
	for _i in 40:
		_brain._defend_cooldown = 0
		check(not _brain.get_frame().guard_just_pressed, "level 1 does not defend")
	_teardown_world()


func test_cpu_dashes_in_from_far_away() -> void:
	_build_world(SWORDSMAN, Vector2(-120.0, 50.0), 120.0, 3)
	await wait_frames(30)
	var dashed := false
	for i in 400:
		await wait_frames(1)
		if _cpu.get_state_name() == &"Dash":
			dashed = true
			break
	check(dashed, "a level 3 CPU uses the dash to close the gap")
	_teardown_world()


func test_level_one_never_dashes() -> void:
	check_eq(AIInput.LEVELS[1]["dash"], 0.0, "the easiest CPU has no dash")


func test_cpu_presses_special_again_for_any_skill_with_a_follow_up() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for path in ["swordsman", "noble", "lieutenant", "ice", "brute"]:
		var data := load("res://resources/characters/%s.tres" % path) as CharacterData
		for skill: SpecialData in [data.specials.neutral, data.specials.forward, data.specials.up, data.specials.down]:
			var delay := AIInput.follow_up_delay(skill, rng)
			if skill.follow_up == null:
				check_eq(delay, -1, "%s: no follow-up, no second press" % skill.display_name)
			else:
				check(delay >= skill.startup_frames + 2, "%s: waits out the wind-up" % skill.display_name)
				check(delay <= skill.startup_frames + skill.follow_up_window, "%s: presses inside the window" % skill.display_name)
	check_eq(AIInput.follow_up_delay(null, rng), -1, "no skill, no press")
