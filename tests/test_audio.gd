extends TestCase


func test_every_recipe_builds_a_non_silent_stream() -> void:
	for kind in SfxSynth.RECIPES:
		var stream := SfxSynth.stream_for(kind)
		check(stream.data.size() > 100, "%s has samples" % kind)
		var peak := 0
		for i in range(0, stream.data.size() / 2, 7):
			peak = maxi(peak, absi(stream.data.decode_s16(i * 2)))
		check(peak > 500, "%s is audible" % kind)
		check(is_same(stream, SfxSynth.stream_for(kind)), "%s is built once" % kind)


func test_sounds_are_deterministic() -> void:
	var recipe := SfxSynth.RECIPES[&"hit_light"]
	check(recipe["duration"] > 0.0, "recipe is data")
	var first := SfxSynth._build(&"hit_light").data
	var second := SfxSynth._build(&"hit_light").data
	check(first == second, "same noise every build")


func test_hit_sound_depends_on_damage_and_launch() -> void:
	check_eq(AudioBus.hit_sound(5.0, 100.0), &"hit_light", "small hit")
	check_eq(AudioBus.hit_sound(15.0, 100.0), &"hit_heavy", "big damage")
	check_eq(AudioBus.hit_sound(3.0, 900.0), &"hit_heavy", "hard launch")


func test_volume_setting_maps_to_decibels() -> void:
	check_eq(AudioBus.volume_db_for(0), -80.0, "zero is silent")
	check_near(AudioBus.volume_db_for(10), 0.0, 0.01, "full is 0 dB")
	check(AudioBus.volume_db_for(5) < AudioBus.volume_db_for(8), "louder setting is louder")


func test_signals_trigger_sounds_and_rapid_repeats_are_limited() -> void:
	var bus := tree.root.get_node("AudioBus")
	bus.recent.clear()
	bus._last_play_ms.clear()
	Events.fighter_ko.emit(1, Vector2.ZERO)
	Events.hit_impact.emit(Vector2.ZERO, Vector2.RIGHT, 20.0, 100.0, 1)
	Events.hit_impact.emit(Vector2.ZERO, Vector2.RIGHT, 20.0, 100.0, 1)
	check(bus.recent.has(&"ko"), "KO plays a sound")
	check_eq(bus.recent.count(&"hit_heavy"), 1, "the second hit in the same instant is limited")
	bus.recent.clear()
	Events.transform_started.emit(1, "BANKAI", 60)
	Events.ultimate_started.emit(1, 40, "X")
	Events.match_ended.emit(1)
	check(bus.recent.has(&"transform") and bus.recent.has(&"ultimate") and bus.recent.has(&"match_end"), "big moments have sounds")


func test_sfx_bus_exists_and_follows_settings() -> void:
	var index := AudioServer.get_bus_index(&"SFX")
	check(index != -1, "SFX bus created")
	var before := GameSettings.sfx_volume
	GameSettings.sfx_volume = 0
	Events.settings_changed.emit()
	check_eq(AudioServer.get_bus_volume_db(index), -80.0, "muted")
	GameSettings.sfx_volume = before
	Events.settings_changed.emit()


func test_music_tracks_loop_and_are_audible() -> void:
	for track in MusicSynth.TRACKS:
		var stream := MusicSynth.stream_for(track)
		check_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, "%s loops" % track)
		check_eq(stream.loop_end, stream.data.size() / 2, "%s loops over its whole length" % track)
		check_near(float(stream.data.size() / 2) / float(MusicSynth.MIX_RATE), MusicSynth.loop_seconds(track), 0.05, "%s length matches the score" % track)
		var peak := 0
		for i in range(0, stream.data.size() / 2, 11):
			peak = maxi(peak, absi(stream.data.decode_s16(i * 2)))
		check(peak > 1500 and peak < 32000, "%s is audible and does not clip" % track)


func test_screens_pick_music() -> void:
	check_eq(AudioBus.track_for_screen(&"versus_match"), &"fight", "match screens")
	check_eq(AudioBus.track_for_screen(&"training_match"), &"fight", "training")
	check_eq(AudioBus.track_for_screen(&"main_menu"), &"menu", "menus")


func test_music_switches_with_screens_and_matches() -> void:
	var bus := tree.root.get_node("AudioBus")
	bus.current_track = &""
	tree.root.get_node("ScreenRouter").enabled = false
	Events.screen_requested.emit(&"main_menu")
	check_eq(bus.current_track, &"menu", "menu music on the menu")
	Events.match_started.emit()
	check_eq(bus.current_track, &"fight", "fight music when a match starts")
	Events.match_ended.emit(1)
	check_eq(bus.current_track, &"menu", "back to menu music after the match")
	tree.root.get_node("ScreenRouter").enabled = true
