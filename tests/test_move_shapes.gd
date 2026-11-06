extends TestCase
## The up, down and air normal attacks are not one template with different numbers: each fighter
## launches, steps and times them in a way of their own.

const ROSTER := [
	"res://resources/characters/swordsman.tres", "res://resources/characters/archer.tres",
	"res://resources/characters/noble.tres", "res://resources/characters/lieutenant.tres",
	"res://resources/characters/ice.tres", "res://resources/characters/brute.tres",
]
const SLOTS: Array[StringName] = [&"ground_up", &"ground_down", &"air_neutral", &"air_up", &"air_down"]


func _shape(move: MoveData) -> String:
	return "%d/%d/%d/%d" % [int(move.angle_degrees), int(move.base_knockback), move.startup_frames, int(move.lunge_speed)]


func test_no_two_fighters_share_the_shape_of_a_slot() -> void:
	for slot in SLOTS:
		var seen := {}
		for path in ROSTER:
			var character := load(path) as CharacterData
			var shape := _shape(character.moveset.get(slot) as MoveData)
			check(not seen.has(shape), "%s: %s has its own %s (%s)" % [slot, character.display_name, slot, shape])
			seen[shape] = true


func test_the_slots_keep_their_job() -> void:
	for path in ROSTER:
		var character := load(path) as CharacterData
		var set := character.moveset
		check(set.ground_up.angle_degrees > 55.0, "%s: up hits launch upward" % character.display_name)
		check(set.ground_down.angle_degrees < 45.0, "%s: down hits keep low" % character.display_name)
		check(set.air_down.angle_degrees < -40.0, "%s: the air down hit spikes" % character.display_name)
		check(set.air_up.angle_degrees > 55.0, "%s: the air up hit launches upward" % character.display_name)


func test_each_air_spike_comes_down_its_own_way() -> void:
	var angles := {}
	for path in ROSTER:
		var character := load(path) as CharacterData
		angles[int(character.moveset.air_down.angle_degrees)] = true
	check_eq(angles.size(), ROSTER.size(), "six different spike angles")


func test_the_fighters_have_a_style_in_how_they_move_while_hitting() -> void:
	var ichigo := load(ROSTER[0]) as CharacterData
	var uryu := load(ROSTER[1]) as CharacterData
	var kenpachi := load(ROSTER[5]) as CharacterData
	check(ichigo.moveset.ground_down.lunge_speed > 0.0 and ichigo.moveset.air_down.lunge_speed > 0.0, "Ichigo drives into every swing")
	check(uryu.moveset.ground_up.angle_degrees > 90.0, "Uryu's anti-air flips the target over him")
	check(kenpachi.moveset.air_down.damage > ichigo.moveset.air_down.damage and kenpachi.moveset.air_down.startup_frames > ichigo.moveset.air_down.startup_frames, "Kenpachi's drop is the slowest and the heaviest")
