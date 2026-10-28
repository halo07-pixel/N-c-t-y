extends TestCase
## The jointed rig: pose library, skeleton, ground contact, facing, flash and the factory.

const NOBLE_RIG := "res://resources/rigs/noble_rig.tres"
const NOBLE := "res://resources/characters/noble.tres"


func _noble_with_rig() -> CharacterData:
	var character := (load(NOBLE) as CharacterData).duplicate() as CharacterData
	character.rig = load(NOBLE_RIG)
	return character


func _body() -> RigBody:
	var body := BodyFactory.create(_noble_with_rig(), 1) as RigBody
	tree.root.add_child(body)
	return body


func test_every_animation_has_a_complete_pose() -> void:
	for animation in RigPoses.ANIMATIONS:
		for phase in [&"startup", &"active", &"recovery"]:
			var info := RigPoses.target(animation, 0.3, phase)
			var pose: Dictionary = info["pose"]
			for key: String in RigPoses.NEUTRAL:
				check(pose.has(key), "%s/%s has %s" % [animation, phase, key])
			check(float(info["rate"]) > 0.0, "%s has a smoothing rate" % animation)


func test_attack_phases_differ_and_strike_reaches_forward() -> void:
	for animation: StringName in [&"attack_neutral", &"attack_forward", &"attack_up", &"attack_down", &"air_attack", &"special"]:
		var startup: Dictionary = RigPoses.target(animation, 0.0, &"startup")["pose"]
		var active: Dictionary = RigPoses.target(animation, 0.0, &"active")["pose"]
		check(startup["blade"] != active["blade"], "%s winds up differently than it strikes" % animation)
	var forward: Dictionary = RigPoses.target(&"attack_forward", 0.0, &"active")["pose"]
	check_near(forward["blade"], 90.0, 10.0, "a forward strike points the blade ahead")
	var up: Dictionary = RigPoses.target(&"attack_up", 0.0, &"active")["pose"]
	check(up["blade"] > 150.0, "an up strike points the blade up")


func test_run_cycle_swings_the_legs_and_loops() -> void:
	var first: Dictionary = RigPoses.target(&"run", 0.0)["pose"]
	var half: Dictionary = RigPoses.target(&"run", 0.5 / RigPoses.RUN_CYCLES_PER_SECOND)["pose"]
	var full: Dictionary = RigPoses.target(&"run", 1.0 / RigPoses.RUN_CYCLES_PER_SECOND)["pose"]
	check_near(first["thigh_f"], -half["thigh_f"] + 0.0, 0.01, "the legs swap halfway through the cycle")
	check_near(first["thigh_f"], full["thigh_f"], 0.01, "the cycle loops")
	check_near(first["thigh_f"], -first["thigh_b"], 0.01, "legs swing in opposition")


func test_weapon_angle_is_relative_to_the_forearm() -> void:
	var pose := RigPoses.NEUTRAL.duplicate()
	var relative := RigPoses.weapon_relative(pose)
	var forearm: float = pose["arm_f"] + pose["elbow_f"] - pose["torso"] - pose["body"]
	check_near(forearm + relative, pose["blade"], 0.001, "forearm plus weapon gives the wanted blade angle")


func test_factory_draws_a_rig_when_the_character_has_one() -> void:
	var body := BodyFactory.create(_noble_with_rig(), 1)
	check(body is RigBody, "a character with a rig gets a RigBody")
	body.free()
	var without := _noble_with_rig()
	without.rig = null
	var plain := BodyFactory.create(without, 1)
	check(plain is SpriteBody, "without a rig the sprites are still used")
	plain.free()
	for path in MatchConfig.ROSTER_PATHS + PackedStringArray([ArcadeRun.BOSS_PATH]):
		check((load(path) as CharacterData).rig != null, "%s has a rig" % path)


func test_standing_rig_rests_on_the_ground() -> void:
	var body := _body()
	for animation: StringName in [&"idle", &"run", &"land", &"guard", &"attack_forward", &"attack_down"]:
		body.preview(animation, 0.2, &"active")
		check_near(body._lowest_foot_y(), 0.0, 0.6, "%s keeps the lowest foot on the ground" % animation)
	check(body.rig.height() > 30.0 and body.rig.height() < 40.0, "the body is about 34 units tall")
	body.queue_free()


func test_facing_mirrors_the_rig_and_the_blade_leads() -> void:
	var body := _body()
	body.preview(&"attack_forward", 0.0, &"active")
	body.sync_to(&"Idle", 1, Vector2.ZERO)
	body._apply(body._current, true, 0.0)
	check(body.weapon_tip().x > 12.0, "facing right the blade reaches to the right")
	body.sync_to(&"Idle", -1, Vector2.ZERO)
	body._apply(body._current, true, 0.0)
	check(body.weapon_tip().x < -12.0, "facing left it reaches to the left")
	body.queue_free()


func test_rig_body_follows_the_fighter_states() -> void:
	var body := _body()
	body.sync_to(&"Idle", 1, Vector2.ZERO)
	body._land_time = 0.0
	body.sync_to(&"Run", 1, Vector2(120.0, 0.0))
	body._process(0.016)
	check_eq(body._animation, &"run", "runs while running")
	body.sync_to(&"Fall", 1, Vector2(0.0, 200.0))
	body.sync_to(&"Idle", 1, Vector2.ZERO)
	check(body._land_time > 0.0 and body._squash > 0.0, "landing squashes the body")
	body._process(0.016)
	check_eq(body._animation, &"land", "and plays the landing pose briefly")
	for _i in 10:
		body._process(0.016)
	check_eq(body._animation, &"idle", "then stands up again without needing more updates from the fighter")
	body.set_pose(&"Attack")
	body.set_attack_visual(&"up", &"startup")
	body._process(0.016)
	check_eq(body._animation, &"attack_up", "an up attack plays the up animation")
	body.queue_free()


func test_hit_flash_uses_the_root_and_hair_lags_behind_motion() -> void:
	var effects_before := GameSettings.screen_effects
	GameSettings.screen_effects = true
	var body := _body()
	body.flash_hit()
	check(body._root.material != null, "the white flash is on the rig root")
	body.sync_to(&"Run", 1, Vector2(150.0, 0.0))
	for _i in 30:
		body._process(0.016)
	check(body._lag < -3.0, "hair and cape trail behind a running fighter")
	body.queue_free()
	GameSettings.screen_effects = effects_before


const REACH_SLOTS := {
	"ground_neutral": "attack_neutral", "ground_forward": "attack_forward", "ground_up": "attack_up",
	"ground_down": "attack_down", "air_neutral": "air_attack", "air_forward": "air_attack",
	"air_up": "air_up", "air_down": "air_down",
}


## What you see is what hits: in the strike pose the weapon tip sits at the far edge of the
## move's hitbox (see tools/rig_reach.gd and tools/align_hitboxes.py).
func test_every_hitbox_matches_the_weapon_reach() -> void:
	for path in MatchConfig.ROSTER_PATHS + PackedStringArray([ArcadeRun.BOSS_PATH]):
		var character := load(path) as CharacterData
		var body := BodyFactory.create(character, 1) as RigBody
		tree.root.add_child(body)
		for slot: String in REACH_SLOTS:
			var move: MoveData = character.moveset.get(slot)
			body.preview(StringName(REACH_SLOTS[slot]), 0.0, &"active")
			var tip := body.weapon_tip()
			var box := Rect2(move.hitbox_offset - move.hitbox_size * 0.5, move.hitbox_size)
			var gap := box.end.x - tip.x
			match move.direction:
				&"up":
					gap = tip.y - box.position.y
				&"down":
					gap = box.end.y - tip.y
			var label := "%s %s" % [character.display_name, slot]
			check(gap >= -1.5 and gap <= 5.5, "%s: hitbox edge is %.1f from the blade tip" % [label, gap])
		body.queue_free()


func test_a_swing_leaves_a_trail_only_with_effects_on() -> void:
	var effects_before := GameSettings.screen_effects
	GameSettings.screen_effects = true
	var body := _body()
	body.sync_to(&"Idle", 1, Vector2.ZERO)
	body.set_pose(&"Attack")
	body.set_attack_visual(&"forward", &"startup")
	for _i in 4:
		body._process(0.016)
	check(body._trail.is_empty(), "no trail while winding up")
	body.set_attack_visual(&"forward", &"active")
	for _i in 4:
		body._process(0.016)
	check(not body._trail.is_empty(), "a trail follows the blade while the swing is active")
	body.queue_free()
	GameSettings.screen_effects = false
	var calm := _body()
	calm.sync_to(&"Idle", 1, Vector2.ZERO)
	calm.set_pose(&"Attack")
	calm.set_attack_visual(&"forward", &"active")
	for _i in 4:
		calm._process(0.016)
	check(calm._trail.is_empty(), "no trail when screen effects are off")
	calm.queue_free()
	GameSettings.screen_effects = effects_before


func test_spring_settles_on_target_and_overshoots_when_underdamped() -> void:
	var x := 0.0
	var v := 0.0
	var peak := 0.0
	for _i in 120:
		var result: Vector2 = RigBody.spring(x, v, 1.0, 20.0, 0.5, 1.0 / 60.0)
		x = result.x
		v = result.y
		peak = maxf(peak, x)
	check(peak > 1.0, "an underdamped spring overshoots a little")
	check_near(x, 1.0, 0.02, "and then settles on the target")


func test_stick_style_draws_lines_and_ghosts_follow_effects_setting() -> void:
	var effects_before := GameSettings.screen_effects
	var stick := load("res://resources/rigs/swordsman_rig.tres") as CharacterRigData
	check(stick.style == &"stick", "Ichigo uses the stick style")
	var character: CharacterData = (load("res://resources/characters/swordsman.tres") as CharacterData).duplicate()
	check(character.rig != null, "Ichigo has a rig")
	var body := BodyFactory.create(character, 1) as RigBody
	tree.root.add_child(body)
	check(not body.snapshot().is_empty(), "a stick body reports its line segments")
	GameSettings.screen_effects = true
	body.sync_to(&"Run", 1, Vector2(300, 0))
	for _i in 6:
		body._process(0.05)
	check(body._ghosts.count() > 0, "fast motion leaves afterimages")
	body.queue_free()
	GameSettings.screen_effects = false
	var calm := BodyFactory.create(character, 1) as RigBody
	tree.root.add_child(calm)
	calm.sync_to(&"Run", 1, Vector2(300, 0))
	for _i in 6:
		calm._process(0.05)
	check(calm._ghosts.count() == 0, "no afterimages when screen effects are off")
	calm.queue_free()
	GameSettings.screen_effects = effects_before
