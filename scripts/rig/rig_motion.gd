class_name RigMotion
extends RefCounted
## What makes each fighter move like itself. Every fighter shares the pose library (RigPoses);
## a motion profile only changes how it is played: breathing, run stride and lean, a few joint
## offsets per animation (key "animation" or "animation:phase") and how snappy the body is.

const PROFILES := {
	# Ichigo: heavy, low stance, big swings.
	&"swordsman": {
		"idle_speed": 1.15, "idle_amp": 1.3, "cycles": 2.6, "stride": 1.1, "arm_swing": 1.15,
		"lean": 4.0, "rate": 1.0,
		"offsets": {
			&"idle": {"thigh_f": 6.0, "knee_f": 6.0, "thigh_b": -6.0, "knee_b": 6.0, "torso": 2.0, "hip_y": 0.6},
			&"attack_forward:active": {"torso": 6.0, "hip_x": 1.0},
			&"attack_neutral:active": {"torso": 4.0},
			&"guard": {"knee_f": 8.0, "knee_b": 8.0},
		},
	},
	# Byakuya: upright, light and exact.
	&"noble": {
		"idle_speed": 0.8, "idle_amp": 0.7, "cycles": 2.2, "stride": 0.95, "arm_swing": 0.7,
		"lean": -3.0, "rate": 1.1,
		"offsets": {
			&"idle": {"torso": -3.0, "knee_f": -6.0, "knee_b": -4.0, "arm_f": 8.0, "elbow_f": -8.0},
			&"attack_forward:active": {"torso": 2.0, "hip_x": 1.0},
			&"attack_neutral:startup": {"torso": -3.0},
			&"guard": {"torso": -4.0},
		},
	},
	# Uryu: side-on archer's stance, quick feet, a steady bow arm.
	&"archer": {
		"idle_speed": 1.0, "idle_amp": 1.0, "cycles": 2.8, "stride": 1.0, "arm_swing": 0.6,
		"lean": 8.0, "rate": 1.05,
		"offsets": {
			&"idle": {"torso": 5.0, "thigh_f": 10.0, "knee_f": 10.0, "thigh_b": -12.0, "knee_b": 6.0},
			&"guard": {"torso": 4.0},
		},
	},
	# Renji: loose and long-limbed, leaning into every lash.
	&"whip": {
		"idle_speed": 1.05, "idle_amp": 1.1, "cycles": 2.7, "stride": 1.15, "arm_swing": 1.0,
		"lean": 6.0, "rate": 1.0,
		"offsets": {
			&"idle": {"torso": 3.0, "thigh_f": 8.0, "knee_f": 8.0, "thigh_b": -8.0, "knee_b": 6.0},
			&"attack_forward:active": {"torso": 8.0, "hip_x": 2.0},
			&"guard": {"knee_f": 6.0, "knee_b": 6.0},
		},
	},
	# Yhwach: stately, slow breathing, heavy blows.
	&"emperor": {
		"idle_speed": 0.7, "idle_amp": 0.6, "cycles": 2.0, "stride": 0.9, "arm_swing": 0.5,
		"lean": 2.0, "rate": 0.9,
		"offsets": {
			&"idle": {"torso": -3.0, "knee_f": -8.0, "knee_b": -6.0, "thigh_f": -2.0, "thigh_b": 2.0},
			&"attack_forward:active": {"torso": 8.0, "hip_x": 2.0},
			&"attack_neutral:active": {"torso": 6.0},
		},
	},
}
const IDLE_KEYS: PackedStringArray = ["torso", "head", "arm_f", "arm_b", "thigh_f", "knee_f", "knee_b"]


static func profile(motion: StringName) -> Dictionary:
	return PROFILES.get(motion, {})


## The animation clock for a profile: idle breathes at its own speed, runs at its own cadence.
static func time_for(motion: StringName, animation: StringName, time: float, base_cycles: float) -> float:
	var data := profile(motion)
	if data.is_empty():
		return time
	if animation == &"idle":
		return time * float(data["idle_speed"])
	if animation == &"run":
		return time * float(data["cycles"]) / base_cycles
	return time


## Reshapes a finished pose for this fighter.
static func apply(pose: Dictionary, motion: StringName, animation: StringName, phase: StringName, neutral: Dictionary) -> void:
	var data := profile(motion)
	if data.is_empty():
		return
	if animation == &"idle":
		for key in IDLE_KEYS:
			pose[key] = neutral[key] + (float(pose[key]) - float(neutral[key])) * float(data["idle_amp"])
	elif animation == &"run":
		var stride := float(data["stride"])
		for key in ["thigh_f", "thigh_b", "knee_f", "knee_b"]:
			pose[key] = float(pose[key]) * stride
		pose["arm_b"] = float(pose["arm_b"]) * float(data["arm_swing"])
		pose["torso"] = float(pose["torso"]) + float(data["lean"])
	var offsets: Dictionary = data["offsets"]
	for key: StringName in [animation, StringName("%s:%s" % [animation, phase])]:
		var deltas: Dictionary = offsets.get(key, {})
		for joint: String in deltas:
			pose[joint] = float(pose.get(joint, 0.0)) + float(deltas[joint])


static func rate_scale(motion: StringName) -> float:
	return float(profile(motion).get("rate", 1.0))
