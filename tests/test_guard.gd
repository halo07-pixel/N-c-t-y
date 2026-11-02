extends TestCase
## Guard, parry, guard lock, guard break and dash with real fighters.

const STAGE_SCENE: PackedScene = preload("res://scenes/stages/test_stage.tscn")
const FIGHTER_SCENE: PackedScene = preload("res://scenes/fighter/fighter.tscn")
const SWORDSMAN: CharacterData = preload("res://resources/characters/swordsman.tres")

var _stage: Stage
var _a: Fighter
var _b: Fighter
var _input_a: ScriptedInput
var _guarded: Array = []
var _broken: Array = []


func _on_guarded(victim: int, attacker: int, perfect: bool, _spot: Vector2) -> void:
	_guarded.append([victim, attacker, perfect])


func _on_broken(player_id: int) -> void:
	_broken.append(player_id)


func _build_world() -> void:
	_guarded.clear()
	_broken.clear()
	_stage = STAGE_SCENE.instantiate() as Stage
	tree.root.add_child(_stage)
	_a = _spawn(1, Vector2(-40.0, 50.0), 1)
	_b = _spawn(2, Vector2(60.0, 50.0), -1)
	_input_a = ScriptedInput.new()
	_a.set_input_source(_input_a)
	_b.set_input_source(ScriptedInput.new())
	Events.fighter_guarded.connect(_on_guarded)
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
	await wait_frames(GuardRules.PARRY_WINDOW_FRAMES + 2)
	var before := _a.guard_energy
	_a.hurtbox.receive_hit(_hit(10.0))
	check_near(_a.percent, 10.0 * GuardRules.DAMAGE_SCALE, 0.001, "only 20%% of the damage")
	check_eq(_a.get_state_name(), &"Guard", "still guarding")
	check_near(before - _a.guard_energy, 10.0 * GuardRules.BLOCK_DRAIN_PER_DAMAGE, 0.5, "the guard energy takes the hit")
	check_eq(_guarded.size(), 1, "the block is announced")
	check(not _guarded[0][2], "and it was not a parry")
	check(_a.gauge > 0.0, "blocking fills the Combat Gauge a little")
	_input_a.held_guard = false
	_teardown_world()


func test_parry_takes_nothing_and_freezes_the_attacker() -> void:
	_build_world()
	await _start_guard()
	check(_a.hurtbox.parrying, "inside the parry window")
	var energy := _a.guard_energy
	_a.hurtbox.receive_hit(_hit(15.0))
	check_eq(_a.percent, 0.0, "no damage")
	check_near(_a.velocity.x, 0.0, 0.001, "no knockback")
	check_near(_a.guard_energy, energy, 0.001, "no guard energy spent")
	check_near(_a.gauge, GuardRules.PARRY_GAUGE, 0.001, "the Combat Gauge is rewarded")
	check(_guarded.size() == 1 and _guarded[0][2], "announced as a parry")
	check(_b.hitlag_left >= GuardRules.PARRY_ATTACKER_HITLAG - 1, "the attacker is held in hitlag")
	_input_a.held_guard = false
	_teardown_world()


func test_the_parry_window_is_ten_frames_and_closes() -> void:
	check_eq(GuardRules.PARRY_WINDOW_FRAMES, 10, "ten frames")
	_build_world()
	await _start_guard()
	await wait_frames(GuardRules.PARRY_WINDOW_FRAMES + 3)
	check(not _a.hurtbox.parrying, "no longer parrying after the window")
	_input_a.held_guard = false
	_teardown_world()


func test_a_parry_can_be_followed_by_an_attack_at_once() -> void:
	_build_world()
	await _start_guard()
	_a.hurtbox.receive_hit(_hit(10.0))
	_input_a.tap_attack()
	await wait_frames(2)
	check_eq(_a.get_state_name(), &"Attack", "attack cancels the guard right after a parry")
	_input_a.held_guard = false
	_teardown_world()


func test_a_parry_sends_a_normal_shot_back() -> void:
	_build_world()
	await _start_guard()
	var shot_data := ProjectileData.new()
	shot_data.velocity = Vector2(200.0, 0.0)
	shot_data.lifetime_frames = 120
	shot_data.size = Vector2(10.0, 10.0)
	var move := MoveData.new()
	move.damage = 8.0
	var shot := Projectile.new()
	shot.launch(shot_data, move, 2, -1, 1.0, _a.global_position + Vector2(20.0, -14.0))
	tree.root.add_child(shot)
	var info := _hit(8.0)
	info.projectile = shot
	_a.hurtbox.receive_hit(info)
	check_eq(shot.owner_id, 1, "the shot now belongs to the parrying fighter")
	check_eq(_b.hitlag_left, 0, "its shooter is not frozen")
	check_eq(_a.percent, 0.0, "nothing landed")
	shot.free()
	_input_a.held_guard = false
	_teardown_world()


func test_a_parry_does_not_send_back_a_trap_or_an_ultimate() -> void:
	var trap_data := ProjectileData.new()
	trap_data.trap = true
	var trap := Projectile.new()
	trap.launch(trap_data, MoveData.new(), 2, 1, 1.0, Vector2.ZERO)
	check(not trap.can_reflect(), "traps stay")
	trap.free()
	var ult := SpecialData.new()
	ult.cinematic_frames = 60
	var big := Projectile.new()
	big.launch(ProjectileData.new(), ult, 2, 1, 1.0, Vector2.ZERO)
	check(not big.can_reflect(), "ultimates are not reflected")
	big.free()


func test_tapping_guard_with_nothing_to_parry_locks_the_guard() -> void:
	_build_world()
	await wait_frames(30)
	_input_a.held_guard = true
	_input_a.tap_guard()
	await wait_frames(3)
	_input_a.held_guard = false
	await wait_frames(2)
	check(_a.guard_lock_left > 0, "released inside the window with nothing hit: locked")
	_input_a.tap_guard()
	await wait_frames(2)
	check(_a.get_state_name() != &"Guard", "no guard while locked")
	await wait_frames(GuardRules.GUARD_LOCK_FRAMES + 2)
	check_eq(_a.guard_lock_left, 0, "the lock ends")
	_teardown_world()


func test_guard_that_parried_is_not_locked_on_release() -> void:
	_build_world()
	await _start_guard()
	_a.hurtbox.receive_hit(_hit(5.0))
	_input_a.held_guard = false
	await wait_frames(3)
	check_eq(_a.guard_lock_left, 0, "a guard that did something is free")
	_teardown_world()


func test_guard_breaks_when_the_energy_runs_out() -> void:
	_build_world()
	await _start_guard()
	await wait_frames(GuardRules.PARRY_WINDOW_FRAMES + 2)
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


func test_dash_covers_ground_and_is_not_invincible() -> void:
	_build_world()
	await wait_frames(30)
	var start_x := _a.global_position.x
	_input_a.tap_dash(1)
	await wait_frames(3)
	check_eq(_a.get_state_name(), &"Dash", "a double tap is a dash")
	check(not _a.hurtbox.parrying and not _a.hurtbox.evading, "no invincibility while dashing")
	_a.hurtbox.receive_hit(_hit(10.0))
	check(_a.percent > 0.0, "a hit lands on a dashing fighter")
	_teardown_world()
	_build_world()
	await wait_frames(30)
	start_x = _a.global_position.x
	_input_a.tap_dash(1)
	await wait_frames(GuardRules.DASH_FRAMES + 4)
	var moved := _a.global_position.x - start_x
	check(moved > GuardRules.DASH_DISTANCE * 0.7 and moved < GuardRules.DASH_DISTANCE * 1.6, "about %d units (%d)" % [int(GuardRules.DASH_DISTANCE), int(moved)])
	_teardown_world()


func test_dash_does_not_turn_around() -> void:
	_build_world()
	await wait_frames(30)
	_input_a.tap_dash(1)
	await wait_frames(3)
	_input_a.held_move = Vector2(-1.0, 0.0)
	await wait_frames(5)
	check(_a.velocity.x > 0.0, "still moving the same way")
	_input_a.held_move = Vector2.ZERO
	_teardown_world()


func test_dash_has_a_cooldown() -> void:
	_build_world()
	await wait_frames(30)
	_input_a.tap_dash(1)
	await wait_frames(GuardRules.DASH_FRAMES + 1)
	check(_a.dash_cooldown > 0, "cooling down")
	_input_a.tap_dash(1)
	await wait_frames(2)
	check(_a.get_state_name() != &"Dash", "no second dash right away")
	_teardown_world()


func test_air_dash_once_per_time_in_the_air() -> void:
	_build_world()
	await wait_frames(30)
	_a.global_position = Vector2(-40.0, -40.0)
	_a.velocity = Vector2.ZERO
	await wait_frames(3)
	_input_a.tap_dash(1)
	await wait_frames(3)
	check_eq(_a.get_state_name(), &"Dash", "dash in the air")
	check(_a.air_dash_used, "the air dash is spent")
	_a.dash_cooldown = 0
	check(not _a.can_dash(), "no second air dash")
	_a.refill_jumps()
	check(_a.can_dash(), "being hit or landing gives it back")
	_teardown_world()


func test_dash_attack_comes_out_after_the_early_frames() -> void:
	_build_world()
	await wait_frames(30)
	_input_a.tap_dash(1)
	await wait_frames(GuardRules.DASH_ATTACK_FRAME + 1)
	_input_a.tap_attack()
	await wait_frames(2)
	check_eq(_a.get_state_name(), &"Attack", "attack out of the dash")
	check_eq(_a.current_attack_name(), _a.data.moveset.ground_forward.display_name, "it is the forward attack")
	_teardown_world()


func test_double_tap_is_found_from_the_keys() -> void:
	var tap := DashTap.new()
	check_eq(tap.update(1.0), 0, "first press")
	check_eq(tap.update(0.0), 0, "release")
	check_eq(tap.update(1.0), 1, "second press in time is a dash")
	var slow := DashTap.new()
	slow.update(1.0)
	for i in GuardRules.DASH_DOUBLE_TAP_FRAMES + 3:
		slow.update(0.0)
	check_eq(slow.update(1.0), 0, "too slow is not a dash")
	var other := DashTap.new()
	other.update(1.0)
	other.update(0.0)
	check_eq(other.update(-1.0), 0, "the other direction is not a dash")
	var held := DashTap.new()
	held.update(1.0)
	check_eq(held.update(1.0), 0, "holding the key is not a dash")


func test_guard_and_dash_state_resets_on_ko() -> void:
	_build_world()
	_a.guard_energy = 10.0
	_a.guard_lock_left = 5
	_a.enter_ko()
	check_eq(_a.guard_lock_left, 0, "no guard lock left")
	check_near(_a.guard_energy, GuardRules.ENERGY_MAX, 0.001, "guard energy restored")
	_teardown_world()
