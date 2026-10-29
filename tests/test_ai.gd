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


func test_cpu_charges_reiatsu_when_the_opponent_is_far_away() -> void:
	_build_world(SWORDSMAN, Vector2(-140.0, 50.0), 150.0, 3)
	await wait_frames(240)
	# Charging all the way up ends in a Bankai, which spends the meter again.
	var charged := _cpu.reiatsu > 10.0 or _cpu.is_bankai()
	check(charged, "the CPU charged while safe (%d Reiatsu)" % int(_cpu.reiatsu))
	_teardown_world()


func test_cpu_stops_charging_when_the_opponent_closes_in() -> void:
	_build_world(SWORDSMAN, Vector2(-140.0, 50.0), 150.0, 3)
	await wait_frames(60)
	_dummy.respawn_at(Vector2(-110.0, 50.0))
	_dummy.hurtbox.set_active(true)
	await wait_frames(10)
	check(_cpu.get_state_name() != &"Charge", "not charging with the opponent next to it")
	_teardown_world()


func test_cpu_walks_up_to_the_opponent() -> void:
	_build_world(SWORDSMAN, Vector2(-130.0, 50.0), 0.0, 3)
	await wait_frames(30)
	var start_gap := absf(_dummy.global_position.x - _cpu.global_position.x)
	await wait_frames(90)
	var gap := absf(_dummy.global_position.x - _cpu.global_position.x)
	var engaged := gap < start_gap - 25.0 or _dummy.percent > 0.0
	check(engaged, "the CPU closed in or attacked (gap %d to %d)" % [int(start_gap), int(gap)])
	_teardown_world()


func test_hard_cpu_damages_a_standing_opponent() -> void:
	_build_world(SWORDSMAN, Vector2(-60.0, 50.0), 20.0, 3)
	await wait_frames(300)
	check(_dummy.percent > 0.0, "the CPU landed a hit (dummy at %d percent)" % int(_dummy.percent))
	_teardown_world()


func test_cpu_with_ranged_kit_also_attacks() -> void:
	_build_world(ARCHER, Vector2(-130.0, 50.0), 40.0, 3)
	await wait_frames(420)
	check(_dummy.percent > 0.0, "the archer CPU hurt the dummy (%d percent)" % int(_dummy.percent))
	_teardown_world()


func test_cpu_recovers_to_the_stage_after_being_thrown_off() -> void:
	_build_world(SWORDSMAN, Vector2(200.0, 10.0), -60.0, 3)
	_cpu.velocity = Vector2(60.0, -50.0)
	await wait_frames(300)
	var on_stage := absf(_cpu.global_position.x) < 165.0 and _cpu.global_position.y < 70.0
	check(on_stage, "back on the stage at (%d, %d)" % [int(_cpu.global_position.x), int(_cpu.global_position.y)])
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
