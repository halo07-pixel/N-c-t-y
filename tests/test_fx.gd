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


func test_settings_switch_for_screen_effects() -> void:
	var before := GameSettings.screen_effects
	var menu := SettingsMenu.new()
	menu.change(&"effects", 1)
	check_eq(GameSettings.screen_effects, not before, "the row flips the setting")
	check_eq(menu.value_text(&"effects"), "ON" if GameSettings.screen_effects else "OFF", "row text")
	menu.change(&"effects", 1)
	check_eq(GameSettings.screen_effects, before, "and flips back")
	menu.free()


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
