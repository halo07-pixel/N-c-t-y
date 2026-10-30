extends TestCase
## Screen effects: shake, camera helpers, shadow, hit flash, KO burst, slow motion,
## the cut-in and the Settings switch.

const MATCH_SCENE := "res://scenes/match/versus_match.tscn"


func test_shake_grows_with_launch_speed() -> void:
	check_eq(FightCamera.shake_for_launch(100.0), 0.0, "weak hits do not shake")
	check(FightCamera.shake_for_launch(400.0) > 0.0, "a medium hit shakes a little")
	check(
		FightCamera.shake_for_launch(600.0) > FightCamera.shake_for_launch(400.0),
		"harder hits shake more"
	)
	check_near(
		FightCamera.shake_for_launch(5000.0), FightCamera.SHAKE_MAX_AMPLITUDE, 0.001,
		"the shake has a ceiling"
	)


func test_zoom_steps_and_pixel_snapping() -> void:
	var steps := PackedFloat32Array([0.9, 1.5, 2.1])
	check_eq(FightCamera.snap_zoom(1.7, steps), 1.5, "rests on the step that still shows everything")
	check_eq(FightCamera.snap_zoom(0.5, steps), 0.5, "never crops below the lowest step")
	check_eq(FightCamera.snap_zoom(1.7, PackedFloat32Array()), 1.7, "no steps means free zoom")
	var snapped := FightCamera.snap_to_pixel_grid(Vector2(10.3, 5.8), 1.5)
	check_near(snapped.x * 1.5, roundf(snapped.x * 1.5), 0.0001, "x lands on a whole pixel")
	check_near(snapped.y * 1.5, roundf(snapped.y * 1.5), 0.0001, "y lands on a whole pixel")


func test_burst_stays_inside_the_view() -> void:
	var screen := Vector2(720.0, 405.0)
	var margin := MatchFx.EDGE_MARGIN * RenderScale.FACTOR
	var far := MatchFx.burst_screen_position(Vector2(900.0, 0.0), Vector2.ZERO, 1.5, screen)
	check_near(far.x, screen.x - margin, 0.001, "pulled in from the right edge")
	var near := MatchFx.burst_screen_position(Vector2(10.0, 0.0), Vector2.ZERO, 1.5, screen)
	check_near(near.x, screen.x * 0.5 + 15.0, 0.001, "an on-screen KO stays where it is")
	check(MatchFx.is_final_ko(100, 99), "a KO right before the end is the final KO")
	check(not MatchFx.is_final_ko(500, 99), "a KO long before is not")


func test_shadow_look_fades_with_height() -> void:
	var on_ground := GroundShadow.look_for_drop(0.0)
	var high := GroundShadow.look_for_drop(GroundShadow.MAX_DROP * 0.8)
	check_near(on_ground.x, 1.0, 0.001, "full size on the ground")
	check(high.x < on_ground.x and high.y < on_ground.y, "smaller and fainter in the air")


func test_cutin_slides_in_then_rests() -> void:
	check_near(MatchHud.cutin_slide(0), 0.0, 0.001, "starts off screen")
	check_near(MatchHud.cutin_slide(30), 1.0, 0.001, "ends in place")
	check(MatchHud.cutin_slide(3) < MatchHud.cutin_slide(6), "moves in steadily")


func test_settings_cycle_through_the_effect_levels() -> void:
	var before := GameSettings.effects_level
	var menu := SettingsMenu.new()
	var seen: Array[String] = []
	for i in 4:
		menu.change(&"effects", 1)
		seen.append(menu.value_text(&"effects"))
	check_eq(GameSettings.effects_level, before, "four steps come back around")
	check(seen.has("OFF") and seen.has("LOW") and seen.has("NORMAL") and seen.has("HIGH"), "all four levels show")
	GameSettings.effects_level = GameSettings.EffectsLevel.OFF
	check(not GameSettings.screen_effects, "off means no screen effects")
	GameSettings.effects_level = GameSettings.EffectsLevel.LOW
	check(GameSettings.screen_effects and GameSettings.effect_amount() < 1.0, "low is a lighter version")
	GameSettings.effects_level = GameSettings.EffectsLevel.HIGH
	check(GameSettings.effect_amount() > 1.0, "high is stronger")
	GameSettings.effects_level = before
	menu.free()


func test_the_budget_drops_effects_over_the_cap() -> void:
	var before := GameSettings.effects_level
	GameSettings.effects_level = GameSettings.EffectsLevel.LOW
	FxBudget.reset()
	var holder := Node2D.new()
	tree.root.add_child(holder)
	var kept := 0
	for i in 30:
		if FxBudget.spawn(holder, Node2D.new()):
			kept += 1
	check_eq(kept, FxBudget.cap(), "only the cap is kept (%d)" % kept)
	holder.free()
	await wait_frames(2)
	FxBudget.reset()
	GameSettings.effects_level = GameSettings.EffectsLevel.OFF
	check(not FxBudget.spawn(tree.root, Node2D.new()), "nothing at all when effects are off")
	GameSettings.effects_level = before


func test_every_character_has_an_effect_profile() -> void:
	for path in MatchConfig.ROSTER_PATHS:
		var character := load(path) as CharacterData
		check(character.fx_profile != null, "%s has a profile" % character.display_name)
	var boss := load("res://resources/characters/emperor.tres") as CharacterData
	check(boss.fx_profile != null and boss.fx_profile.impact_style == &"ink", "Yhwach bursts like ink")


func test_slow_motion_only_after_a_final_ko_and_always_ends() -> void:
	var fx := MatchFx.new()
	tree.root.add_child(fx)
	var effects_before := GameSettings.screen_effects
	GameSettings.screen_effects = true
	Events.match_ended.emit(1)
	check_eq(Engine.time_scale, 1.0, "a match won on the clock is not slowed")
	Events.fighter_ko.emit(2, Vector2.ZERO)
	Events.match_ended.emit(1)
	check_near(Engine.time_scale, MatchFx.SLOWMO_SCALE, 0.001, "the final KO slows time")
	fx.queue_free()
	await tree.process_frame
	check_eq(Engine.time_scale, 1.0, "leaving the match restores normal speed")
	GameSettings.screen_effects = effects_before
	Engine.time_scale = 1.0


func test_effects_off_means_no_slow_motion_and_no_flash() -> void:
	var effects_before := GameSettings.screen_effects
	GameSettings.screen_effects = false
	var fx := MatchFx.new()
	tree.root.add_child(fx)
	Events.fighter_ko.emit(2, Vector2.ZERO)
	Events.match_ended.emit(1)
	check_eq(Engine.time_scale, 1.0, "no slow motion when the switch is off")
	fx.queue_free()
	var body := PlaceholderBody.new()
	tree.root.add_child(body)
	body.flash_hit()
	check(not body.is_flashing(), "no flash when the switch is off")
	GameSettings.screen_effects = true
	body.flash_hit()
	check(body.is_flashing(), "flash when the switch is on")
	check(body.material != null, "the white shader is applied")
	for _i in FighterBody.FLASH_FRAMES + 1:
		await tree.physics_frame
	check(not body.is_flashing(), "the flash ends")
	check(body.material == null, "and the shader is removed")
	body.queue_free()
	GameSettings.screen_effects = effects_before


func test_fighters_have_a_shadow_on_the_floor_and_hits_flash_and_shake() -> void:
	var effects_before := GameSettings.screen_effects
	GameSettings.screen_effects = true
	var match_scene: Node = (load(MATCH_SCENE) as PackedScene).instantiate()
	tree.root.add_child(match_scene)
	await wait_frames(40)
	var fighter: Fighter = match_scene._fighters[1]
	var shadow: GroundShadow
	for child in fighter.get_children():
		if child is GroundShadow:
			shadow = child
	check(shadow != null, "every fighter has a ground shadow")
	if shadow != null:
		check(shadow.visible, "the shadow shows under a fighter standing on the stage")
		check_near(shadow.global_position.y, fighter.global_position.y, 3.0, "and sits at the feet")
	var camera: FightCamera = match_scene._camera
	Events.fighter_launched.emit(2, 650.0, Vector2.RIGHT)
	check(camera._shake_amplitude > 1.0, "a hard hit shakes the camera")
	Events.fighter_ko.emit(2, Vector2(0.0, 0.0))
	check(camera._push > 1.0, "a KO pushes the camera in")
	var burst_count := 0
	for layer in match_scene.get_node("MatchFx").get_children():
		for child in layer.get_children():
			if child is EdgeBurst:
				burst_count += 1
	check_eq(burst_count, 1, "a KO creates one edge burst")
	GameSettings.screen_effects = false
	camera._shake_amplitude = 0.0
	Events.fighter_launched.emit(2, 650.0, Vector2.RIGHT)
	check_eq(camera._shake_amplitude, 0.0, "no shake when the switch is off")
	GameSettings.screen_effects = effects_before
	match_scene.queue_free()
	await tree.process_frame
	Engine.time_scale = 1.0


func test_hit_power_grows_with_damage_and_speed() -> void:
	check(HitSpark.power_for(3.0, 150.0) < HitSpark.power_for(18.0, 700.0), "a big hit is bigger")
	check(HitSpark.power_for(0.0, 0.0) >= 0.15 and HitSpark.power_for(99.0, 9999.0) <= 1.0, "power is clamped")


func test_crescent_is_a_valid_polygon_with_a_forward_bulge() -> void:
	var points := ProjectileArt.crescent_points(22.0, 14.0)
	check(not Geometry2D.triangulate_polygon(points).is_empty(), "the crescent triangulates")
	var front := -INF
	for point in points:
		front = maxf(front, point.x)
	check_near(front, 11.0, 0.01, "its convex side reaches half the width forward")


func test_every_special_projectile_style_is_known() -> void:
	for path in ["archer_specials", "swordsman_specials", "noble_specials", "emperor_specials", "swordsman_ultimate", "emperor_ultimate", "noble_ultimate", "archer_ultimate"]:
		var text := FileAccess.get_file_as_string("res://resources/specials/%s.tres" % path)
		check(text.contains("style = &\""), "%s has procedural projectile styles" % path)


func test_hits_and_landings_spawn_effects_only_when_enabled() -> void:
	var before := GameSettings.screen_effects
	var fx := CombatFx.new()
	tree.root.add_child(fx)
	GameSettings.screen_effects = true
	Events.hit_impact.emit(Vector2.ZERO, Vector2.RIGHT, 10.0, 400.0, 1)
	Events.dust_puff.emit(Vector2.ZERO, 1.0)
	check_eq(fx.get_child_count(), 2, "a spark and a puff appear")
	GameSettings.screen_effects = false
	Events.hit_impact.emit(Vector2.ZERO, Vector2.RIGHT, 10.0, 400.0, 1)
	check_eq(fx.get_child_count(), 2, "nothing appears with effects off")
	fx.queue_free()
	GameSettings.screen_effects = before


func test_hit_tiers_and_impact_styles() -> void:
	check_eq(HitSpark.tier_for(0.2), 0, "a light hit")
	check_eq(HitSpark.tier_for(0.5), 1, "a solid hit")
	check_eq(HitSpark.tier_for(0.9), 2, "a heavy hit")
	var styles: Array[StringName] = []
	for path in MatchConfig.ROSTER_PATHS:
		styles.append((load(path) as CharacterData).fx_profile.impact_style)
	check_eq(styles.size(), 3, "three roster characters")
	check(styles[0] != styles[1] and styles[1] != styles[2] and styles[0] != styles[2], "each bursts differently")


func test_every_impact_style_draws() -> void:
	for style: StringName in [&"slash", &"shards", &"petals", &"ink"]:
		for power in [0.2, 0.9]:
			var spark := HitSpark.new()
			spark.style = style
			spark.power = power
			tree.root.add_child(spark)
			await wait_frames(6)
			check(is_instance_valid(spark), "%s at %.1f draws" % [style, power])
			if is_instance_valid(spark):
				spark.free()


func test_the_final_ko_slows_more_on_higher_levels() -> void:
	check(MatchFx.slowmo_scale(GameSettings.EffectsLevel.HIGH) < MatchFx.slowmo_scale(GameSettings.EffectsLevel.NORMAL), "slower on high")
	check(MatchFx.slowmo_scale(GameSettings.EffectsLevel.NORMAL) < MatchFx.slowmo_scale(GameSettings.EffectsLevel.LOW), "slower on normal than low")
	check(MatchFx.slowmo_seconds(GameSettings.EffectsLevel.HIGH) > MatchFx.slowmo_seconds(GameSettings.EffectsLevel.LOW), "and for longer")


func test_a_projectile_announces_its_appearance_and_fade() -> void:
	var flashes: Array = []
	var listener := func(_p: Vector2, _d: Vector2, _c: Color, dissolve: bool) -> void: flashes.append(dissolve)
	Events.projectile_flash.connect(listener)
	var data := (load("res://resources/characters/swordsman.tres") as CharacterData).specials.neutral
	var shot := Projectile.new()
	shot.launch(data.projectiles[0], data, 1, 1, 1.0, Vector2.ZERO)
	tree.root.add_child(shot)
	await wait_frames(data.projectiles[0].lifetime_frames + 5)
	Events.projectile_flash.disconnect(listener)
	check(flashes.has(false), "a flash when it appears")
	check(flashes.has(true), "and one when it fades")
	if is_instance_valid(shot):
		shot.free()
