extends TestCase
## Normal-attack combo chains: jab -> second hit -> finisher / launcher / sweep.

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
var _input: ScriptedInput


func _build() -> void:
	_stage = STAGE_SCENE.instantiate() as Stage
	tree.root.add_child(_stage)
	_a = FIGHTER_SCENE.instantiate() as Fighter
	_a.player_id = 1
	_a.data = load("res://resources/characters/swordsman.tres")
	_a.position = Vector2(-40.0, 50.0)
	tree.root.add_child(_a)
	_input = ScriptedInput.new()
	_a.set_input_source(_input)


func _teardown() -> void:
	_a.free()
	_stage.free()


func _start_jab() -> void:
	await wait_frames(30)
	_input.tap_attack()
	await wait_frames(1)


## Waits until the first attack's active frames have passed.
func _wait_active_over() -> void:
	var jab: MoveData = _a.data.moveset.ground_neutral
	await wait_frames(jab.startup_frames + jab.active_frames)


func test_every_character_has_a_chain() -> void:
	for path in SETS:
		var set := load(path) as MoveSet
		var jab := set.ground_neutral
		check(jab.has_chain(), "%s: the jab chains" % path)
		var second := jab.next_in_chain
		check(second != null and second.has_chain(), "%s: hit two continues" % path)
		check(second.chain_up != null and second.chain_down != null, "%s: hit two branches up and down" % path)
		check(second.next_in_chain.damage > second.damage, "%s: the finisher hits harder" % path)
		check(not second.next_in_chain.has_chain(), "%s: the string ends at the finisher" % path)
		check(jab.chain_for(0.0) == second, "%s: neutral picks the next hit" % path)
		check(second.chain_for(-1.0) == second.chain_up, "%s: up picks the launcher" % path)
		check(second.chain_for(1.0) == second.chain_down, "%s: down picks the sweep" % path)


func test_chain_needs_a_connected_hit() -> void:
	_build()
	await _start_jab()
	await _wait_active_over()
	_input.tap_attack()
	await wait_frames(30)
	check_eq(_a.current_attack_name(), "", "a whiffed jab does not chain")
	_teardown()


func test_chain_continues_after_a_hit() -> void:
	_build()
	await _start_jab()
	_a.hit_connected = true
	await _wait_active_over()
	_input.tap_attack()
	await wait_frames(2)
	check_eq(_a.current_attack_name(), _a.data.moveset.ground_neutral.next_in_chain.display_name, "the second hit follows")
	_teardown()


func test_a_buffered_press_chains_when_the_jab_ends() -> void:
	_build()
	await _start_jab()
	_a.hit_connected = true
	var jab: MoveData = _a.data.moveset.ground_neutral
	await wait_frames(jab.startup_frames)
	_input.tap_attack() # pressed early, during the active frames
	await wait_frames(jab.active_frames + 2)
	check_eq(_a.current_attack_name(), jab.next_in_chain.display_name, "an early press is remembered")
	_teardown()


func test_holding_up_picks_the_launcher() -> void:
	_build()
	await _start_jab()
	_a.hit_connected = true
	await _wait_active_over()
	_input.tap_attack()
	await wait_frames(2)
	_a.hit_connected = true
	var second: MoveData = _a.data.moveset.ground_neutral.next_in_chain
	await wait_frames(second.startup_frames + second.active_frames)
	_input.held_move = Vector2(0.0, -1.0)
	_input.tap_attack()
	await wait_frames(2)
	check_eq(_a.current_attack_name(), second.chain_up.display_name, "up chooses the launcher")
	_input.held_move = Vector2.ZERO
	_teardown()
