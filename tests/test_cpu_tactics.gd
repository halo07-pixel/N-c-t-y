extends TestCase
## The CPU's second presses follow what the skill is for, and Ichigo's combo is pressed in the beat.

var _rng := RandomNumberGenerator.new()


func _kit(name: String) -> SpecialSet:
	return (load("res://resources/characters/%s.tres" % name) as CharacterData).specials


func _plan(skill: SpecialData, distance: float, extra: Dictionary = {}) -> Dictionary:
	var situation := {"distance": distance, "target_attacking": false, "self_percent": 20.0, "target_percent": 40.0, "released": false}
	situation.merge(extra, true)
	_rng.seed = 7
	return CpuTactics.plan(skill, situation, _rng)


func test_byakuya_binds_when_close_and_right_after_the_dash() -> void:
	var step := _kit("noble").forward
	var close := _plan(step, 50.0)
	check(close["use"], "binds a close target")
	check(close["delay"] <= step.startup_frames + 4, "straight after the dash (%d)" % close["delay"])
	check(not _plan(step, 220.0)["use"], "no binding from far away")


func test_kenpachi_releases_only_when_healthy_and_not_already() -> void:
	var smash := _kit("brute").down
	check(_plan(smash, 50.0)["use"], "healthy: tears off the eyepatch")
	check(not _plan(smash, 50.0, {"self_percent": 150.0})["use"], "badly hurt: keeps the defence")
	check(not _plan(smash, 50.0, {"released": true})["use"], "already released: no second time")


func test_kenpachi_rushes_through_an_attack() -> void:
	var cleave := _kit("brute").forward
	check(_plan(cleave, 140.0, {"target_attacking": true})["use"], "armour beats an attack")
	check(not _plan(cleave, 140.0)["use"], "no reason to rush from far when they are idle")


func test_rukia_walls_up_when_they_attack_at_mid_range() -> void:
	var step := _kit("ice").forward
	check(_plan(step, 100.0, {"target_attacking": true})["use"], "a wall against an attack")
	check(not _plan(step, 300.0, {"target_attacking": true})["use"], "not for someone far away")


func test_renji_spins_up_close_and_pulls_from_afar() -> void:
	var lieutenant := _kit("lieutenant")
	var whirl := _plan(lieutenant.forward, 40.0)
	check(whirl["use"] and whirl["hold"] > 0, "holds the ring when they are close")
	check(not _plan(lieutenant.forward, 160.0)["use"], "no ring from far away")
	check(_plan(lieutenant.neutral, 150.0)["use"], "the chain drags someone keeping away")
	check(not _plan(lieutenant.neutral, 40.0)["use"], "no chain when already in range")


func test_uryu_streams_from_afar_and_recalls_when_they_walk_up() -> void:
	var archer := _kit("archer")
	var stream := _plan(archer.neutral, 160.0)
	check(stream["use"] and stream["hold"] > 0, "a held volley from a distance")
	check(not _plan(archer.neutral, 40.0)["use"], "no volley point blank")
	var blades := _plan(archer.forward, 60.0)
	check(blades["use"] and blades["delay"] > archer.forward.startup_frames + 8, "the blades come home late")
	check(not _plan(archer.forward, 250.0)["use"], "they stay planted while nobody is near")


func test_ichigo_fires_the_cross_from_a_distance() -> void:
	var getsuga := _kit("swordsman").neutral
	check(_plan(getsuga, 150.0)["use"], "the cross follows the first wave")
	check(not _plan(getsuga, 30.0)["use"], "not point blank")


func test_the_rhythm_press_only_comes_in_the_beat() -> void:
	var ichigo := load("res://resources/characters/swordsman.tres") as CharacterData
	var jab := ichigo.moveset.ground_neutral
	check(jab.rhythm_bonus > 0.0, "Ichigo's jab carries the rhythm rider")
	var end := jab.startup_frames + jab.active_frames
	var early := 0
	var in_beat := 0
	for i in 200:
		_rng.seed = i
		if CpuTactics.rhythm_press(jab, end - 3, end, _rng):
			early += 1
		_rng.seed = i
		if CpuTactics.rhythm_press(jab, end + 2, end, _rng):
			in_beat += 1
	check_eq(early, 0, "never mashes before the hit ends")
	check(in_beat > 40, "usually presses in the beat (%d/200)" % in_beat)
	var other := (load("res://resources/characters/noble.tres") as CharacterData).moveset.ground_neutral
	check(not CpuTactics.rhythm_press(other, end, end, _rng), "only for a fighter with the rider")
