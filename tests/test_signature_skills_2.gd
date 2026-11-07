extends TestCase
## Byakuya binds and strikes from afar; Renji spins a ring of chain and drags people in.

const STAGE_SCENE: PackedScene = preload("res://scenes/stages/test_stage.tscn")
const FIGHTER_SCENE: PackedScene = preload("res://scenes/fighter/fighter.tscn")
const BYAKUYA: CharacterData = preload("res://resources/characters/noble.tres")
const RENJI: CharacterData = preload("res://resources/characters/lieutenant.tres")


func test_byakuya_kit_data() -> void:
	for set: SpecialSet in [BYAKUYA.specials, BYAKUYA.bankai_specials]:
		var bind := set.forward.follow_up
		check(bind != null and bind.bind_frames > 0, "Rikujōkōrō binds")
		check_eq(bind.projectiles.size(), 6, "six bars of light")
		check(bind.base_knockback == 0.0, "the bars do not launch")
		var bolt := set.up.follow_up
		check(bolt != null and bolt.projectiles[0].velocity.length() >= 800.0, "Byakurai is fast")


func test_renji_kit_data() -> void:
	for set: SpecialSet in [RENJI.specials, RENJI.bankai_specials]:
		var ring := set.forward.follow_up
		check(ring != null and ring.is_spin() and ring.hitbox_size.x >= 60.0, "a wide spinning ring")
		var pull := set.neutral.follow_up
		check(pull != null and pull.angle_degrees > 150.0, "the chain pulls toward Renji")


var _shots: Array[Projectile] = []


func _on_shot(projectile: Projectile) -> void:
	_shots.append(projectile)
	tree.root.add_child(projectile)


func _duel(character: CharacterData, gap: float) -> Array:
	var stage := STAGE_SCENE.instantiate() as Stage
	tree.root.add_child(stage)
	var a := FIGHTER_SCENE.instantiate() as Fighter
	a.player_id = 1
	a.data = character
	a.position = Vector2(0.0, 50.0)
	tree.root.add_child(a)
	var b := FIGHTER_SCENE.instantiate() as Fighter
	b.player_id = 2
	b.data = BYAKUYA if character != BYAKUYA else RENJI
	b.position = Vector2(gap, 50.0)
	tree.root.add_child(b)
	var input_a := ScriptedInput.new()
	a.set_input_source(input_a)
	var input_b := ScriptedInput.new()
	b.set_input_source(input_b)
	for old in _shots:
		if is_instance_valid(old):
			old.free()
	_shots.clear()
	a.projectile_spawned.connect(_on_shot)
	return [stage, a, b, input_a, input_b]


func test_a_bound_fighter_cannot_move_but_can_guard() -> void:
	var rig := _duel(BYAKUYA, 60.0)
	var b: Fighter = rig[2]
	var input_b: ScriptedInput = rig[4]
	await wait_frames(30)
	b.bound_frames = 40
	input_b.held_move = Vector2.RIGHT
	var x := b.global_position.x
	await wait_frames(20)
	check_near(b.global_position.x, x, 1.0, "a bound fighter stays put")
	input_b.held_move = Vector2.ZERO
	input_b.tap_guard()
	input_b.held_guard = true
	await wait_frames(4)
	check(b.is_guarding(), "but the guard still works")
	input_b.held_guard = false
	await wait_frames(40)
	input_b.held_move = Vector2.RIGHT
	await wait_frames(20)
	check(absf(b.global_position.x - x) > 5.0, "free again afterwards")
	for n in [rig[1], b, rig[0]]:
		n.free()


func test_rikujokoro_binds_the_target_without_launching() -> void:
	var rig := _duel(BYAKUYA, 70.0)
	var a: Fighter = rig[1]
	var b: Fighter = rig[2]
	var input_a: ScriptedInput = rig[3]
	a.reiatsu = 100.0
	b.knockback_scale = 0.0
	await wait_frames(30)
	input_a.held_move = Vector2.RIGHT
	input_a.tap_special() # Flash Step
	await wait_frames(8)
	input_a.held_move = Vector2.ZERO
	input_a.tap_special() # the follow-up
	await wait_frames(30)
	check(b.bound_frames > 0 or b.percent > 12.0, "the bars reached the target")
	check(absf(b.global_position.x - 70.0) < 12.0, "and did not knock them away")
	for n in [a, b, rig[0]]:
		n.free()


func test_the_spin_keeps_striking_while_held() -> void:
	var rig := _duel(RENJI, 40.0)
	var a: Fighter = rig[1]
	var b: Fighter = rig[2]
	var input_a: ScriptedInput = rig[3]
	a.reiatsu = 100.0
	b.knockback_scale = 0.0
	await wait_frames(30)
	input_a.held_move = Vector2.RIGHT
	input_a.tap_special() # Fang Dash
	await wait_frames(10)
	input_a.held_move = Vector2.ZERO
	input_a.tap_special() # Whirl
	input_a.held_special = true
	await wait_frames(70)
	input_a.held_special = false
	check(a.reiatsu < 100.0 or b.percent > 0.0, "the ring struck")
	check(b.percent > 15.0, "several times (%.1f)" % b.percent)
	for n in [a, b, rig[0]]:
		n.free()


func test_byakurai_bends_with_the_held_direction() -> void:
	var bolt: ProjectileData = BYAKUYA.specials.up.follow_up.projectiles[0]
	check(bolt.aim > 0.0, "the bolt can be aimed")
	var rig := _duel(BYAKUYA, 300.0)
	var a: Fighter = rig[1]
	var input_a: ScriptedInput = rig[3]
	await wait_frames(20)
	input_a.held_move = Vector2(0.0, -1.0)
	await wait_frames(2)
	a.spawn_projectile(bolt, BYAKUYA.specials.up.follow_up, 0.0)
	var up_shot := _shots[_shots.size() - 1]
	input_a.held_move = Vector2(0.0, 1.0)
	await wait_frames(2)
	a.spawn_projectile(bolt, BYAKUYA.specials.up.follow_up, 0.0)
	var down_shot := _shots[_shots.size() - 1]
	input_a.held_move = Vector2.ZERO
	await wait_frames(2)
	a.spawn_projectile(bolt, BYAKUYA.specials.up.follow_up, 0.0)
	var flat_shot := _shots[_shots.size() - 1]
	await wait_frames(4)
	check(up_shot.global_position.y < flat_shot.global_position.y, "held up: a flatter bolt")
	check(down_shot.global_position.y > flat_shot.global_position.y, "held down: a steeper one")
	for n in [a, rig[2], rig[0]]:
		n.free()
