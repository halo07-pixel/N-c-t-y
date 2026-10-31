extends TestCase
## Throws: guard + attack next to an opponent grabs through their guard.

const STAGE_SCENE: PackedScene = preload("res://scenes/stages/test_stage.tscn")
const FIGHTER_SCENE: PackedScene = preload("res://scenes/fighter/fighter.tscn")
const SETS: Array[String] = [
	"res://resources/movesets/swordsman_moveset.tres",
	"res://resources/movesets/archer_moveset.tres",
	"res://resources/movesets/noble_moveset.tres",
	"res://resources/movesets/emperor_moveset.tres",
]

var _stage: Stage
var _a: Fighter
var _b: Fighter
var _input_a: ScriptedInput
var _input_b: ScriptedInput


func _build(gap: float = 24.0) -> void:
	_stage = STAGE_SCENE.instantiate() as Stage
	tree.root.add_child(_stage)
	_a = _spawn(1, Vector2(-gap * 0.5, 50.0), 1)
	_b = _spawn(2, Vector2(gap * 0.5, 50.0), -1)
	_input_a = ScriptedInput.new()
	_input_b = ScriptedInput.new()
	_a.set_input_source(_input_a)
	_b.set_input_source(_input_b)


func _spawn(id: int, pos: Vector2, facing: int) -> Fighter:
	var fighter := FIGHTER_SCENE.instantiate() as Fighter
	fighter.player_id = id
	fighter.data = load("res://resources/characters/swordsman.tres")
	fighter.position = pos
	fighter.facing = facing
	tree.root.add_child(fighter)
	return fighter


func _teardown() -> void:
	_a.free()
	_b.free()
	_stage.free()


func _start_throw() -> void:
	await wait_frames(30)
	_input_a.held_guard = true
	_input_a.tap_guard()
	await wait_frames(2)
	_input_a.tap_attack()
	await wait_frames(2)


func test_every_character_has_a_throw() -> void:
	for path in SETS:
		var throw := (load(path) as MoveSet).throw_move
		check(throw != null and throw.is_throw, "%s has a throw" % path)
		check(throw.startup_frames >= 12, "%s: the throw is telegraphed" % path)
		check(throw.damage >= 7.0, "%s: the throw pays for the risk" % path)


func test_throw_starts_only_next_to_an_opponent() -> void:
	_build(24.0)
	await wait_frames(30)
	check(_a.can_throw(), "adjacent: a throw is possible")
	_teardown()
	_build(140.0)
	await wait_frames(30)
	check(not _a.can_throw(), "far away: no throw")
	_teardown()


func test_guard_plus_attack_throws_through_a_guard() -> void:
	_build(24.0)
	await wait_frames(30)
	_input_b.held_guard = true
	_input_b.tap_guard()
	await wait_frames(GuardRules.PERFECT_WINDOW_FRAMES + 3) # past the perfect window
	await _start_throw()
	check_eq(_a.current_attack_name(), _a.data.moveset.throw_move.display_name, "the throw plays")
	check(_a.throw_cooldown > 0, "and goes on cooldown")
	await wait_frames(_a.data.moveset.throw_move.startup_frames + 4)
	check(_b.percent >= _a.data.moveset.throw_move.damage - 0.1, "full damage through the guard")
	check_eq(_b.get_state_name(), &"Hitstun", "the target is launched")
	_input_a.held_guard = false
	_input_b.held_guard = false
	_teardown()


func test_a_shunpo_avoids_a_throw() -> void:
	_build(24.0)
	await _start_throw()
	var throw := _a.data.moveset.throw_move
	await wait_frames(throw.startup_frames - 6)
	_input_b.held_move = Vector2(1.0, 0.0)
	_input_b.tap_guard()
	await wait_frames(throw.active_frames + 6)
	check_eq(_b.percent, 0.0, "the Shunpo slips out of the throw")
	_input_a.held_guard = false
	_input_b.held_move = Vector2.ZERO
	_teardown()


func test_throw_has_a_cooldown() -> void:
	_build(24.0)
	await _start_throw()
	await wait_frames(60)
	_a.set_percent(0.0)
	check(_a.throw_cooldown > 0 and not _a.can_throw(), "no second throw during the cooldown")
	_input_a.held_guard = false
	_teardown()
