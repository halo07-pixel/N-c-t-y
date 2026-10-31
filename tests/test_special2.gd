extends TestCase
## The second special button: its own four skills per fighter, cooldowns and the path-covering dash.

const STAGE_SCENE: PackedScene = preload("res://scenes/stages/test_stage.tscn")
const FIGHTER_SCENE: PackedScene = preload("res://scenes/fighter/fighter.tscn")
const ROSTER: Array[String] = ["swordsman", "archer", "noble", "emperor"]

var _stage: Stage
var _a: Fighter
var _b: Fighter
var _input: ScriptedInput


func _build(character: String = "swordsman", gap: float = 80.0) -> void:
	_stage = STAGE_SCENE.instantiate() as Stage
	tree.root.add_child(_stage)
	_a = _spawn(1, character, Vector2(-gap * 0.5, 50.0), 1)
	_b = _spawn(2, "swordsman", Vector2(gap * 0.5, 50.0), -1)
	_input = ScriptedInput.new()
	_a.set_input_source(_input)
	_b.set_input_source(ScriptedInput.new())


func _spawn(id: int, character: String, pos: Vector2, facing: int) -> Fighter:
	var fighter := FIGHTER_SCENE.instantiate() as Fighter
	fighter.player_id = id
	fighter.data = load("res://resources/characters/%s.tres" % character)
	fighter.position = pos
	fighter.facing = facing
	tree.root.add_child(fighter)
	return fighter


func _teardown() -> void:
	_a.free()
	_b.free()
	_stage.free()


func test_every_character_has_four_special2_skills() -> void:
	for name in ROSTER:
		var data := load("res://resources/characters/%s.tres" % name) as CharacterData
		var kit := data.specials
		var skills := [kit.alt_neutral, kit.alt_forward, kit.alt_up, kit.alt_down]
		for skill: SpecialData in skills:
			check(skill != null, "%s has all four Special 2 skills" % name)
			if skill == null:
				continue
			check(skill.alt, "%s: %s is flagged as Special 2" % [name, skill.display_name])
			check(skill.cooldown_frames > 0, "%s: %s has a cooldown" % [name, skill.display_name])
			check(String(skill.slot_key()).begins_with("alt_"), "%s: %s has its own cooldown slot" % [name, skill.display_name])


func test_special2_uses_the_alt_skill_for_the_direction() -> void:
	_build()
	await wait_frames(30)
	var kit := _a.data.specials
	check_eq(_a.current_alt(Vector2.ZERO), kit.alt_neutral, "neutral")
	check_eq(_a.current_alt(Vector2(1.0, 0.0)), kit.alt_forward, "forward")
	check_eq(_a.current_alt(Vector2(0.0, -1.0)), kit.alt_up, "up")
	check_eq(_a.current_alt(Vector2(0.0, 1.0)), kit.alt_down, "down")
	_teardown()


func test_pressing_special2_plays_the_alt_skill_and_starts_its_cooldown() -> void:
	_build()
	await wait_frames(30)
	_input.tap_special2()
	await wait_frames(2)
	check_eq(_a.current_attack_name(), _a.data.specials.alt_neutral.display_name, "the alt skill plays")
	check(not _a.skill_ready(&"alt_neutral"), "its own slot is cooling down")
	check(_a.skill_ready(&"neutral"), "the normal special slot is untouched")
	_teardown()


func test_alt_cooldown_blocks_a_second_use() -> void:
	_build()
	await wait_frames(30)
	_input.tap_special2()
	await wait_frames(26)
	_input.tap_special2()
	await wait_frames(2)
	check(_a.current_attack_name() != _a.data.specials.alt_neutral.display_name, "still cooling down: a plain attack instead")
	_teardown()


func test_the_hud_gets_eight_cooldown_slots() -> void:
	_build()
	await wait_frames(5)
	var seen: Array = []
	var listener := func(id: int, fractions: PackedFloat32Array) -> void:
		if id == 1:
			seen.append(fractions.size())
	Events.fighter_cooldowns_changed.connect(listener)
	_a.reset_cooldowns()
	Events.fighter_cooldowns_changed.disconnect(listener)
	check(not seen.is_empty() and seen[0] == 8, "four Special and four Special 2 pips")
	_teardown()


func test_a_teleport_hurts_along_its_path() -> void:
	_build("swordsman", 100.0)
	# stand the target in the middle of the Shunpo Slash path (110 units), not at its end
	_b.global_position = _a.global_position + Vector2(55.0, 0.0)
	await wait_frames(30)
	_b.global_position = _a.global_position + Vector2(55.0, 0.0)
	_input.held_move = Vector2(1.0, 0.0)
	_input.tap_special2()
	await wait_frames(25)
	check(_b.percent > 0.0, "the target in the middle of the teleport is hit")
	_teardown()


func test_a_dash_hits_a_target_it_passes() -> void:
	_build("swordsman", 100.0)
	await wait_frames(30)
	_b.global_position = _a.global_position + Vector2(48.0, 0.0)
	_input.held_move = Vector2(1.0, 0.0)
	_input.tap_special() # Dash Slash
	await wait_frames(30)
	check(_b.percent > 0.0, "the dash connects on its way")
	_teardown()
