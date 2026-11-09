extends TestCase
## Skill effects: the halo around shots, a Bankai's brighter glow, and the chips of a heavy hit.

const CHARACTERS := ["swordsman", "archer", "noble", "lieutenant", "ice", "brute", "emperor"]


func _projectiles(set: SpecialSet) -> Array[ProjectileData]:
	var found: Array[ProjectileData] = []
	for slot in [set.neutral, set.forward, set.up, set.down]:
		var move: SpecialData = slot
		while move != null:
			for shot in move.projectiles:
				found.append(shot)
			move = move.follow_up
	return found


func test_every_bankai_shot_glows_and_the_normal_ones_do_not_need_to() -> void:
	for name in CHARACTERS:
		var data := load("res://resources/characters/%s.tres" % name) as CharacterData
		var shots := _projectiles(data.bankai_specials)
		check(not shots.is_empty(), "%s has Bankai shots" % name)
		for shot in shots:
			check(shot.glow.a > 0.0, "%s: every Bankai shot has a glow" % name)
		for shot in _projectiles(data.specials):
			check_eq(shot.glow.a, 0.0, "%s: the normal kit keeps the faint default halo" % name)


func test_each_bankai_glows_in_its_own_colour() -> void:
	var seen := {}
	for name in CHARACTERS:
		var data := load("res://resources/characters/%s.tres" % name) as CharacterData
		seen[_projectiles(data.bankai_specials)[0].glow] = name
	check_eq(seen.size(), CHARACTERS.size(), "no two Bankai share a glow")


func test_a_glowing_shot_has_a_stronger_halo() -> void:
	check(ProjectileArt.halo_alpha(Color(1, 0, 0, 1)) > ProjectileArt.halo_alpha(Color(0, 0, 0, 0)), "Bankai shots glow harder")
	check(ProjectileArt.halo_alpha(Color(0, 0, 0, 0)) > 0.0, "and a normal one still glows a little")


func test_terrain_and_zones_get_no_halo() -> void:
	for style in [&"pillar", &"wall", &"mine", &"rune"]:
		check(ProjectileArt.NO_HALO.has(style), "%s is terrain or a zone" % style)
	check(not ProjectileArt.NO_HALO.has(&"crescent"), "a crescent is light, it glows")


func test_only_heavy_hits_throw_chips() -> void:
	check_eq(HitSpark.debris_count(0), 0, "no chips for a light hit")
	check_eq(HitSpark.debris_count(1), 0, "nor a solid one")
	check(HitSpark.debris_count(2) > 0, "a heavy hit breaks something")


func test_drawing_every_style_with_a_glow_does_not_fail() -> void:
	var holder := Node2D.new()
	tree.root.add_child(holder)
	for style in ProjectileArt.STYLES:
		var probe := _Probe.new()
		probe.style = style
		holder.add_child(probe)
	await wait_frames(2)
	check(true, "all styles drew")
	holder.free()


class _Probe:
	extends Node2D
	var style: StringName = &"crescent"

	func _draw() -> void:
		ProjectileArt.draw(self, style, Vector2(24, 12), Color(0.5, 0.9, 1.0), 0.0, 0.3, PackedVector2Array(), Color(0, 0, 0, 0), Color(1, 0.2, 0.2, 1))

	func _ready() -> void:
		queue_redraw()
