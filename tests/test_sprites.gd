extends TestCase
## Sprite sets, the loader, the animation mapping and the fallback to the
## placeholder body. Ichigo and Uryu live in assets/local (the owner's rips); their
## checks are skipped on a clone that does not have those files.

const ORIGINAL_SETS := [
	["res://assets/original/noble/", "noble"],
	["res://assets/original/sovereign/", "sovereign"],
]
const LOCAL_SETS := [
	["res://assets/local/ichigo/", "ichigo"],
	["res://assets/local/uryu/", "uryu"],
]
const REQUIRED_ANIMATIONS: Array[StringName] = [
	&"idle", &"run", &"jump", &"fall", &"hitstun", &"attack_neutral", &"attack_forward",
	&"attack_up", &"attack_down", &"air_attack", &"special",
]


func _check_set(dir: String, id: String) -> void:
	var set := SpriteSetLoader.load_set(dir, id)
	check(set != null, "%s loads" % id)
	if set == null:
		return
	for animation in REQUIRED_ANIMATIONS:
		check(set.frame_count(animation) > 0, "%s has %s" % [id, animation])
	check(set.anchor.x > 0.0 and set.anchor.y > 0.0, "%s has an anchor" % id)
	check(set.top_px > 16.0 and set.top_px < 120.0, "%s has a sensible height (%d)" % [id, int(set.top_px)])
	check(not set.effects.is_empty(), "%s has effect art" % id)
	var texture: Texture2D = set.frames.get_frame_texture(&"idle", 0)
	check(texture.get_width() > 0 and texture.get_height() > 0, "%s idle frame has a size" % id)


func test_original_sets_are_complete() -> void:
	for entry in ORIGINAL_SETS:
		_check_set(entry[0], entry[1])


func test_local_sets_are_complete_when_present() -> void:
	for entry in LOCAL_SETS:
		if SpriteSetLoader.load_set(entry[0], entry[1]) == null:
			continue # the owner's local art is not on this computer
		_check_set(entry[0], entry[1])


func test_every_character_points_at_a_sprite_folder() -> void:
	for path in MatchConfig.ROSTER_PATHS + PackedStringArray([ArcadeRun.BOSS_PATH]):
		var character := load(path) as CharacterData
		check(character.sprite_dir.begins_with("res://assets/"), "%s has a sprite folder" % character.display_name)
		check(character.sprite_id != "", "%s has a sprite id" % character.display_name)


func test_missing_art_falls_back_to_the_placeholder() -> void:
	var character := CharacterData.new()
	character.sprite_dir = "res://assets/nowhere/"
	character.sprite_id = "ghost"
	check(not BodyFactory.has_sprites(character), "no sprites for a missing set")
	var body := BodyFactory.create(character, 1)
	check(body is PlaceholderBody, "the placeholder is used")
	body.free()
	var noble := (load("res://resources/characters/noble.tres") as CharacterData).duplicate() as CharacterData
	noble.rig = null # a character without a rig falls back to its sprites
	var sprite_body := BodyFactory.create(noble, 2)
	check(sprite_body is SpriteBody, "sprites are used when they exist")
	sprite_body.free()


func test_state_to_animation_mapping() -> void:
	check_eq(SpriteBody.animation_for(&"Idle", &"", false, false), &"idle", "idle")
	check_eq(SpriteBody.animation_for(&"Run", &"", false, false), &"run", "run")
	check_eq(SpriteBody.animation_for(&"Hitstun", &"", false, false), &"hitstun", "hitstun")
	check_eq(SpriteBody.animation_for(&"Charge", &"", false, false), &"charge", "charge")
	check_eq(SpriteBody.animation_for(&"Transform", &"", false, false), &"charge", "transform")
	check_eq(SpriteBody.animation_for(&"Attack", &"forward", false, false), &"attack_forward", "forward attack")
	check_eq(SpriteBody.animation_for(&"Attack", &"up", false, false), &"attack_up", "up attack")
	check_eq(SpriteBody.animation_for(&"Attack", &"down", true, false), &"air_attack", "any aerial")
	check_eq(SpriteBody.animation_for(&"Attack", &"neutral", false, true), &"special", "specials")


func test_attack_frames_follow_the_phases() -> void:
	for count in [1, 2, 3, 4, 5, 8]:
		var startup := SpriteBody.attack_frame(count, &"startup", 0)
		var active := SpriteBody.attack_frame(count, &"active", 0)
		var recovery := SpriteBody.attack_frame(count, &"recovery", 99)
		check(startup >= 0 and recovery <= count - 1, "frames stay in range for %d frames" % count)
		check(startup <= active and active <= recovery, "phases never go backwards for %d frames" % count)
	check_eq(SpriteBody.attack_frame(2, &"startup", 0), 0, "two frames: wind-up first")
	check_eq(SpriteBody.attack_frame(2, &"active", 0), 1, "two frames: strike second")
	check_eq(SpriteBody.attack_frame(5, &"startup", 99), 1, "a long startup stays on its last wind-up frame")
	check_eq(SpriteBody.attack_frame(5, &"recovery", 0), 4, "the last frame is the recovery")


func test_body_follows_the_fighter_and_borrows_missing_animations() -> void:
	var noble := (load("res://resources/characters/noble.tres") as CharacterData).duplicate() as CharacterData
	noble.rig = null
	var body := BodyFactory.create(noble, 1) as SpriteBody
	body.sync_to(&"Run", -1, Vector2(100.0, 0.0))
	check_eq(body._sprite.animation, &"run", "runs while running")
	check(body._pivot.scale.x < 0.0, "mirrored when facing left")
	body.set_pose(&"Attack")
	body.set_attack_visual(&"forward", &"active", false, false)
	check_eq(body._sprite.animation, &"attack_forward", "forward attack animation")
	check_eq(body.resolve_animation(&"nonexistent"), &"idle", "unknown names end on idle")
	check_near(body._pivot.scale.y, RenderScale.sprite(), 0.001, "sprites are drawn at the screen scale")
	body.free()


func test_projectile_art_comes_from_the_owners_sprite_set() -> void:
	var noble := (load("res://resources/characters/noble.tres") as CharacterData).duplicate() as CharacterData
	noble.rig = null
	var body := BodyFactory.create(noble, 1)
	check(body.effect_texture(&"petal0") != null, "a named effect has a texture")
	check(body.effect_texture(&"nothing") == null, "an unknown effect has none")
	var drawn := 0
	for projectile in noble.ultimate.projectiles:
		if projectile.art != &"" and body.effect_texture(projectile.art) != null:
			drawn += 1
	check_eq(drawn, noble.ultimate.projectiles.size(), "every ultimate projectile has art")
	body.free()


func test_screen_is_one_and_a_half_times_the_world_view() -> void:
	check_near(RenderScale.FACTOR * RenderScale.sprite(), 1.0, 0.0001, "sprite scale undoes the screen scale")
	check_eq(int(ProjectSettings.get_setting("display/window/size/viewport_width")), int(480.0 * RenderScale.FACTOR), "viewport width")
	check_eq(int(ProjectSettings.get_setting("display/window/size/viewport_height")), int(270.0 * RenderScale.FACTOR), "viewport height")
	var camera := FightCamera.new()
	check_near(camera.max_zoom, 1.4 * RenderScale.FACTOR, 0.001, "camera zoom limits follow the screen scale")
	camera.free()
