class_name TrialLibrary
extends RefCounted
## The exercises of a character, built from its own data so the move names never go out of date.
## Four per fighter, each teaching one thing: the jab string, a cancel into a skill, a dash attack
## into a skill, and a Gauge Cancel that restarts the string.

const GAUGE_FOR_CANCEL := 60.0
## Where the player stands when an exercise starts (just above the floor); the dummy is in front.
const PRACTICE_ORIGIN := Vector2(-40.0, 50.0)


## The skill a hit may be cancelled into: the forward one when it can be, otherwise the neutral one.
static func cancel_skill(character: CharacterData, prefer_forward: bool) -> SpecialData:
	var kit := character.specials
	var options: Array = [kit.forward, kit.neutral] if prefer_forward else [kit.neutral, kit.forward]
	for skill: SpecialData in options:
		if skill != null and CombatGauge.CANCEL_ROLES.has(skill.role):
			return skill
	return null


static func for_character(character: CharacterData) -> Array[ComboTrial]:
	var trials: Array[ComboTrial] = []
	var moves := character.moveset
	var jab := moves.ground_neutral
	var second := jab.next_in_chain
	var finisher := second.next_in_chain
	var name_key := character.display_name.to_lower().replace(" ", "_")

	var string_trial := ComboTrial.new()
	string_trial.title = "Jab string"
	string_trial.description = "Tap Attack three times: each hit must land before the next."
	string_trial.steps = PackedStringArray([jab.display_name, second.display_name, finisher.display_name])
	trials.append(string_trial)

	var zone := cancel_skill(character, false)
	var cancel_trial := ComboTrial.new()
	cancel_trial.title = "Cancel into a skill"
	cancel_trial.description = "After the jab hits, press the skill key within 12 frames."
	cancel_trial.steps = PackedStringArray([jab.display_name, zone.display_name])
	trials.append(cancel_trial)

	var rush := cancel_skill(character, true)
	var dash_trial := ComboTrial.new()
	dash_trial.title = "Dash attack"
	dash_trial.description = "Double-tap forward, attack out of the dash, then cancel the hit into a skill."
	dash_trial.steps = PackedStringArray([ComboTrial.TOKEN_DASH, moves.ground_forward.display_name, rush.display_name])
	dash_trial.dummy_distance = 78.0
	trials.append(dash_trial)

	var gauge_trial := ComboTrial.new()
	gauge_trial.title = "Gauge Cancel"
	gauge_trial.description = "Hit with the jab, press the charge key to Gauge Cancel (40 Gauge), then start the string again."
	gauge_trial.steps = PackedStringArray([jab.display_name, ComboTrial.TOKEN_GAUGE_CANCEL, jab.display_name, second.display_name])
	gauge_trial.start_gauge = GAUGE_FOR_CANCEL
	trials.append(gauge_trial)

	for i in trials.size():
		trials[i].key = "%s_%d" % [name_key, i + 1]
	return trials
