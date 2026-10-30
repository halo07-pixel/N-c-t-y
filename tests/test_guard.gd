extends TestCase
## Guard, Perfect Guard, guard break, Shunpo and perfect dodges with real fighters.

const STAGE_SCENE: PackedScene = preload("res://scenes/stages/test_stage.tscn")
const FIGHTER_SCENE: PackedScene = preload("res://scenes/fighter/fighter.tscn")
const SWORDSMAN: CharacterData = preload("res://resources/characters/swordsman.tres")

var _stage: Stage
var _a: Fighter
var _b: Fighter
var _input_a: ScriptedInput
var _guarded: Array = []
var _dodged: Array = []
var _broken: Array = []


func _on_guarded(victim: int, attacker: int, perfect: bool, _spot: Vector2) -> void:
	_guarded.append([victim, attacker, perfect])


func _on_dodged(victim: int, attacker: int, _spot: Vector2) -> void:
	_dodged.append([victim, attacker])


func _on_broken(player_id: int) -> void:
	_broken.append(player_id)


func _build_world() -> void:
	_guarded.clear()
	_dodged.clear()
	_broken.clear()
	_stage = STAGE_SCENE.instantiate() as Stage
	tree.root.add_child(_stage)
	_a = _spawn(1, Vector2(-40.0, 50.0), 1)
	_b = _spawn(2, Vector2(60.0, 50.0), -1)
	_input_a = ScriptedInput.new()
	_a.set_input_source(_input_a)
	_b.set_input_source(ScriptedInput.new())
	Events.fighter_guarded.connect(_on_guarded)
	Events.fighter_dodged.connect(_on_dodged)
	Events.fighter_guard_broken.connect(_on_broken)


func _spawn(id: int, pos: Vector2, facing: int) -> Fighter:
	var fighter := FIGHTER_SCENE.instantiate() as Fighter
	fighter.player_id = id
	fighter.data = SWORDSMAN
	fighter.position = pos
	fighter.facing = facing
	tree.root.add_child(fighter)
	return fighter


func _teardown_world() -> void:
	Events.fighter_guarded.disconnect(_on_guarded)
	Events.fighter_dodged.disconnect(_on_dodged)
	Events.fighter_guard_broken.disconnect(_on_broken)
	_a.free()
	_b.free()
	_stage.free()


func _hit(damage: float = 10.0) -> HitInfo:
	var info := HitInfo.new()
	info.attacker_id = 2
	info.damage = damage
	info.base_knockback = 200.0
	info.knockback_growth = 1.0
	info.direction = Vector2(-1.0, -0.3).normalized()
	return info


func _start_guard() -> void:
	await wait_frames(30)
	_input_a.held_guard = true
	_input_a.tap_guard()
	await wait_frames(2)


func test_guard_is_held_and_released() -> void:
	_build_world()
	await _start_guard()
	check_eq(_a.get_state_name(), &"Guard", "guarding while the key is held")
	_input_a.held_guard = false
	await wait_frames(3)
	check_eq(_a.get_state_name(), &"Idle", "back to idle on release")
	_teardown_world()


func test_guard_drains_while_held_and_recovers_after() -> void:
	_build_world()
	await _start_guard()
	await wait_frames(30)
	check(_a.guard_energy < GuardRules.ENERGY_MAX - 5.0, "the guard energy drains while held")
	var drained := _a.guard_energy
	_input_a.held_guard = false
	await wait_frames(30)
	check(_a.guard_energy > drained, "and comes back after release")
	_teardown_world()


func test_a_blocked_hit_does_a_fraction_of_the_damage() -> void:
	_build_world()
	await _start_guard()
	await wait_frames(GuardRules.PERFECT_WINDOW_FRAMES + 2)
	var before := _a.guard_energy
	_a.hurtbox.receive_hit(_hit(10.0))
	check_near(_a.percent, 10.0 * GuardRules.DAMAGE_SCALE, 0.001, "only a fraction of the damage")
	check_eq(_a.get_state_name(), &"Guard", "still guarding")
	check(_a.guard_energy < before - 10.0, "the guard energy takes the hit")
	check_eq(_guarded.size(), 1, "the block is announced")
	check(not _guarded[0][2], "and it was not perfect")
	check(_a.gauge > 0.0, "blocking fills the Combat Gauge a little")
	_input_a.held_guard = false
	_teardown_world()


func test_perfect_guard_takes_nothing_and_freezes_the_attacker() -> void:
	_build_world()
	await _start_guard()
	check(_a.hurtbox.evading, "inside the perfect window")
	_a.hurtbox.receive_hit(_hit(15.0))
	check_eq(_a.percent, 0.0, "no damage")
	check_near(_a.gauge, GuardRules.PERFECT_GAUGE, 0.001, "the Combat Gauge is rewarded")
	check(_guarded.size() == 1 and _guarded[0][2], "announced as perfect")
	check(_b.hitlag_left >= GuardRules.PERFECT_ATTACKER_HITLAG - 1, "the attacker is held in hitlag")
	_input_a.held_guard = false
	_teardown_world()


func test_the_perfect_window_closes() -> void:
	_build_world()
	await _start_guard()
	await wait_frames(GuardRules.PERFECT_WINDOW_FRAMES + 3)
	check(not _a.hurtbox.evading, "no longer evading after the window")
	_input_a.held_guard = false
	_teardown_world()


func test_guard_breaks_when_the_energy_runs_out() -> void:
	_build_world()
	await _start_guard()
	await wait_frames(GuardRules.PERFECT_WINDOW_FRAMES + 2)
	_a.guard_energy = 5.0
	_a.hurtbox.receive_hit(_hit(12.0))
	check_eq(_a.get_state_name(), &"Hitstun", "stunned when the guard breaks")
	check_eq(_a.hitstun_frames_left, GuardRules.BREAK_STUN_FRAMES, "for a long time")
	check_eq(_broken, [1], "announced")
	check_near(_a.guard_energy, GuardRules.BREAK_RESTORE, 0.001, "with a little energy given back")
	_input_a.held_guard = false
	_teardown_world()


func test_cannot_guard_with_no_energy() -> void:
	_build_world()
	await wait_frames(30)
	_a.guard_energy = 2.0
	_input_a.tap_guard()
	await wait_frames(3)
	check(_a.get_state_name() != &"Guard", "too little energy to guard")
	_teardown_world()


func test_shunpo_steps_ahead_and_dodges_at_first() -> void:
	_build_world()
	await wait_frames(30)
	var start_x := _a.global_position.x
	_input_a.held_move = Vector2(1.0, 0.0)
	_input_a.tap_guard()
	await wait_frames(3)
	check_eq(_a.get_state_name(), &"Shunpo", "guard plus a direction is a Shunpo")
	check(_a.hurtbox.evading, "dodging at the start")
	_a.hurtbox.receive_hit(_hit(10.0))
	check_eq(_a.percent, 0.0, "the hit missed")
	check_eq(_dodged.size(), 1, "a perfect dodge is announced")
	check_near(_a.gauge, GuardRules.PERFECT_GAUGE, 0.001, "and rewarded")
	_input_a.held_move = Vector2.ZERO
	await wait_frames(GuardRules.SHUNPO_FRAMES + 4)
	var moved := _a.global_position.x - start_x
	check(moved > GuardRules.SHUNPO_DISTANCE * 0.7 and moved < GuardRules.SHUNPO_DISTANCE * 1.6, "it covered about %d units (%d)" % [int(GuardRules.SHUNPO_DISTANCE), int(moved)])
	check(not _a.hurtbox.evading, "hittable again afterwards")
	_teardown_world()


func test_shunpo_has_a_cooldown() -> void:
	_build_world()
	await wait_frames(30)
	_input_a.held_move = Vector2(1.0, 0.0)
	_input_a.tap_guard()
	await wait_frames(GuardRules.SHUNPO_FRAMES + 3)
	check(_a.shunpo_cooldown > 0, "cooling down")
	_input_a.tap_guard()
	await wait_frames(2)
	check(_a.get_state_name() != &"Shunpo", "no second Shunpo right away")
	_input_a.held_move = Vector2.ZERO
	_teardown_world()


func test_air_shunpo_has_a_longer_cooldown_instead_of_a_limit() -> void:
	_build_world()
	await wait_frames(30)
	_a.global_position = Vector2(-40.0, -40.0)
	_a.velocity = Vector2.ZERO
	await wait_frames(3) # now in the air
	_input_a.held_move = Vector2(1.0, 0.0)
	_input_a.tap_guard()
	await wait_frames(3)
	check_eq(_a.get_state_name(), &"Shunpo", "Shunpo in the air")
	check(_a.shunpo_cooldown > GuardRules.SHUNPO_COOLDOWN, "the air cooldown is longer than on the ground")
	check(not _a.can_shunpo(), "no second one right away")
	_a.shunpo_cooldown = 0
	check(_a.can_shunpo(), "but there is no limit once the cooldown is over")
	_input_a.held_move = Vector2.ZERO
	_teardown_world()


func test_guard_and_dodge_state_resets_on_ko() -> void:
	_build_world()
	_a.guard_energy = 10.0
	_a.dodge_frames_left = 5
	_a.enter_ko()
	check_eq(_a.dodge_frames_left, 0, "no dodge window left")
	check_near(_a.guard_energy, GuardRules.ENERGY_MAX, 0.001, "guard energy restored")
	_teardown_world()
